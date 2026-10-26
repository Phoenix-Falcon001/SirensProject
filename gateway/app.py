"""Sirens public gateway: the internet-facing service for civilians.

This is a separate, small Flask app with its own database. It is the only
part of Sirens on the public internet. It never connects to the internal
Army server; the internal server's sync job (sync_gateway.py) connects to it,
collects new civilian reports, and hands back statuses and warnings.

Civilians (/gw/v1, JSON):
    POST /auth/request-code   {phone, lang}       -> SMS code (rate-limited)
    POST /auth/verify         {phone, code, lang} -> token (first time = sign-up)
    GET  /me                  DELETE /me
    POST /reports             multipart or JSON   -> {id, status}
    GET  /reports             the caller's own reports, status only after sync
    POST /devices             {push_token, platform}
    GET  /warnings            active warnings (no sign-in needed)
    GET  /safety              safety steps and hotlines (no sign-in needed)

Internal server only (/gw/v1/sync, header X-Sync-Key):
    GET  /sync/reports        reports not yet collected, with photo
    POST /sync/ack            {ids}: collected; the gateway then wipes their
                              text, position and photo, keeping only status
    POST /sync/status         {updates: [{id, status}]}
    PUT  /sync/warnings       {warnings: [...]}: replaces the active list

Run (development):
    SIRENS_GW_DEV=1 SIRENS_GW_SYNC_KEY=change-me python -m gateway.app
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import pathlib
import re
import secrets
import sqlite3
from datetime import datetime, timedelta, timezone
from functools import wraps

from flask import Flask, Response, g, jsonify, request

from . import push as push_mod
from . import sms as sms_mod

ROOT = pathlib.Path(__file__).resolve().parent
SAFETY_FILE = ROOT / "safety.json"

CODE_TTL = timedelta(minutes=5)
CODE_ATTEMPTS = 5
CODES_PER_PHONE = 3            # per CODE_WINDOW
CODES_PER_IP = 10              # per CODE_WINDOW
CODE_WINDOW = timedelta(minutes=30)
SESSION_TTL = timedelta(days=90)
REPORTS_PER_DAY = 10
MAX_DESCRIPTION = 2000
MAX_PHOTO = 5 * 1024 * 1024
CATEGORIES = ("suspicious_object", "unexploded_ordnance", "suspicious_vehicle",
              "suspicious_activity", "other")
STATUSES = ("received", "under_review", "closed", "rejected")
LANGS = ("ar", "en", "fr")
# Rough box around Lebanon; the internal server does the exact caza check.
LEB_BOX = (33.0, 35.0, 34.75, 36.7)   # lat_min, lon_min, lat_max, lon_max

_SCHEMA = """
CREATE TABLE IF NOT EXISTS citizens (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    phone      TEXT NOT NULL UNIQUE,
    lang       TEXT NOT NULL DEFAULT 'ar',
    created_at TEXT NOT NULL,
    last_seen  TEXT NOT NULL,
    disabled   INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS codes (
    phone      TEXT PRIMARY KEY,
    code_hash  TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    attempts   INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS code_requests (
    phone TEXT NOT NULL,
    ip    TEXT NOT NULL,
    at    TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    citizen_id INTEGER NOT NULL,
    expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS reports (
    id           TEXT PRIMARY KEY,
    citizen_id   INTEGER,
    reporter_phone TEXT,
    submitted_at TEXT NOT NULL,
    category     TEXT NOT NULL,
    description  TEXT NOT NULL DEFAULT '',
    lat          REAL,
    lon          REAL,
    accuracy_m   REAL,
    photo        BLOB,
    photo_type   TEXT,
    status       TEXT NOT NULL DEFAULT 'received',
    status_at    TEXT,
    collected    INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS devices (
    citizen_id INTEGER NOT NULL,
    push_token TEXT NOT NULL UNIQUE,
    platform   TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS warnings (
    id      INTEGER PRIMARY KEY,
    payload TEXT NOT NULL
);
"""


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.isoformat(timespec="seconds")


def _sha(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()


def normalize_phone(raw: str) -> str | None:
    """Lebanese numbers in any common form -> +961XXXXXXXX; other countries
    must be given with + or 00. Returns None if it is not a phone number."""
    s = re.sub(r"[\s\-().]", "", raw or "")
    if s.startswith("00"):
        s = "+" + s[2:]
    if not s.startswith("+"):
        s = s[1:] if s.startswith("0") else s
        s = "+961" + s
    return s if re.fullmatch(r"\+\d{8,15}", s) else None


def _photo_type(data: bytes) -> str | None:
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    return None


def create_app(db_path=None, sync_key=None, sms_sender=None, push_sender=None,
               safety_file=None, dev=None) -> Flask:
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = MAX_PHOTO + 64 * 1024
    dev = os.environ.get("SIRENS_GW_DEV") == "1" if dev is None else dev
    db_path = str(db_path or os.environ.get("SIRENS_GW_DB")
                  or ROOT.parent / "data" / "gateway.db")
    sync_key = sync_key or os.environ.get("SIRENS_GW_SYNC_KEY", "")
    if len(sync_key) < 16 and not dev:
        raise RuntimeError("set SIRENS_GW_SYNC_KEY (at least 16 characters)")
    secret = os.environ.get("SIRENS_GW_SECRET", "")
    if len(secret) < 32:
        if not dev:
            raise RuntimeError("set SIRENS_GW_SECRET (at least 32 characters); "
                               "it protects the SMS codes and must be the same on "
                               "every gateway process")
        secret = secrets.token_hex(32)
    sms = sms_sender or sms_mod.ConsoleSender()
    if sms.name == "console" and not dev:
        raise RuntimeError("no SMS provider configured; the console sender is for "
                           "development only (SIRENS_GW_DEV=1)")
    pusher = push_sender or push_mod.DisabledPush()
    safety_path = pathlib.Path(safety_file or SAFETY_FILE)
    sync_ips = {ip.strip() for ip in os.environ.get("SIRENS_GW_SYNC_IPS", "").split(",")
                if ip.strip()}

    pathlib.Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(db_path) as c:
        c.executescript(_SCHEMA)

    app.extensions["sirens_gw"] = {"sms": sms, "push": pusher, "db": db_path}

    def db() -> sqlite3.Connection:
        if "db" not in g:
            g.db = sqlite3.connect(db_path)
            g.db.row_factory = sqlite3.Row
        return g.db

    @app.teardown_appcontext
    def _close(_exc):
        conn = g.pop("db", None)
        if conn is not None:
            conn.close()

    @app.after_request
    def _headers(resp: Response):
        resp.headers["Cache-Control"] = "no-store"
        resp.headers["X-Content-Type-Options"] = "nosniff"
        return resp

    def err(msg, status):
        return jsonify({"error": msg}), status

    def body() -> dict:
        d = request.get_json(silent=True)
        return d if isinstance(d, dict) else {}

    def code_hash(phone, code):
        return hmac.new(secret.encode(), f"{phone}:{code}".encode(), "sha256").hexdigest()

    def citizen_required(fn):
        @wraps(fn)
        def inner(*a, **kw):
            h = request.headers.get("Authorization", "")
            tok = h[7:].strip() if h.lower().startswith("bearer ") else ""
            r = db().execute(
                """SELECT c.* FROM sessions s JOIN citizens c ON c.id = s.citizen_id
                   WHERE s.token_hash=? AND s.expires_at > ? AND c.disabled=0""",
                (_sha(tok), _iso(_now()))).fetchone() if tok else None
            if not r:
                return err("not signed in", 401)
            g.citizen = r
            return fn(*a, **kw)
        return inner

    def sync_required(fn):
        @wraps(fn)
        def inner(*a, **kw):
            given = request.headers.get("X-Sync-Key", "")
            if not sync_key or not hmac.compare_digest(given, sync_key):
                return err("forbidden", 403)
            if sync_ips and request.remote_addr not in sync_ips:
                return err("forbidden", 403)
            return fn(*a, **kw)
        return inner

    # -- sign-in by SMS code -------------------------------------------------
    @app.post("/gw/v1/auth/request-code")
    def request_code():
        b = body()
        phone = normalize_phone(b.get("phone", ""))
        lang = b.get("lang") if b.get("lang") in LANGS else "ar"
        if not phone:
            return err("enter a valid phone number", 400)
        conn, now = db(), _now()
        since = _iso(now - CODE_WINDOW)
        conn.execute("DELETE FROM code_requests WHERE at < ?", (since,))
        by_phone = conn.execute("SELECT COUNT(*) FROM code_requests WHERE phone=?",
                                (phone,)).fetchone()[0]
        by_ip = conn.execute("SELECT COUNT(*) FROM code_requests WHERE ip=?",
                             (request.remote_addr or "",)).fetchone()[0]
        if by_phone >= CODES_PER_PHONE or by_ip >= CODES_PER_IP:
            conn.commit()
            return err("too many codes requested; wait and try again", 429)
        code = f"{secrets.randbelow(10**6):06d}"
        conn.execute("INSERT INTO code_requests VALUES (?,?,?)",
                     (phone, request.remote_addr or "", _iso(now)))
        conn.execute("INSERT OR REPLACE INTO codes VALUES (?,?,?,0)",
                     (phone, code_hash(phone, code), _iso(now + CODE_TTL)))
        conn.commit()
        sms.send_code(phone, code, lang)
        return jsonify({"ok": True, "phone": phone, "expires_in": int(CODE_TTL.total_seconds())})

    @app.post("/gw/v1/auth/verify")
    def verify():
        b = body()
        phone = normalize_phone(b.get("phone", ""))
        code = str(b.get("code", "")).strip()
        lang = b.get("lang") if b.get("lang") in LANGS else "ar"
        conn, now = db(), _now()
        r = conn.execute("SELECT * FROM codes WHERE phone=?", (phone,)).fetchone() if phone else None
        if not r or r["expires_at"] < _iso(now):
            return err("the code has expired; request a new one", 400)
        if r["attempts"] >= CODE_ATTEMPTS:
            return err("too many wrong codes; request a new one", 429)
        if not hmac.compare_digest(r["code_hash"], code_hash(phone, code)):
            conn.execute("UPDATE codes SET attempts = attempts + 1 WHERE phone=?", (phone,))
            conn.commit()
            return err("wrong code", 400)
        conn.execute("DELETE FROM codes WHERE phone=?", (phone,))
        c = conn.execute("SELECT * FROM citizens WHERE phone=?", (phone,)).fetchone()
        new = c is None
        if new:
            conn.execute("INSERT INTO citizens (phone, lang, created_at, last_seen) "
                         "VALUES (?,?,?,?)", (phone, lang, _iso(now), _iso(now)))
            c = conn.execute("SELECT * FROM citizens WHERE phone=?", (phone,)).fetchone()
        elif c["disabled"]:
            conn.commit()
            return err("this account is disabled", 403)
        token = secrets.token_urlsafe(32)
        conn.execute("INSERT INTO sessions VALUES (?,?,?)",
                     (_sha(token), c["id"], _iso(now + SESSION_TTL)))
        conn.execute("UPDATE citizens SET last_seen=?, lang=? WHERE id=?",
                     (_iso(now), lang, c["id"]))
        conn.execute("DELETE FROM sessions WHERE expires_at < ?", (_iso(now),))
        conn.commit()
        return jsonify({"token": token, "expires_at": _iso(now + SESSION_TTL),
                        "new_account": new, "citizen": _citizen(c)})

    def _citizen(c):
        return {"id": c["id"], "phone": c["phone"], "lang": c["lang"],
                "created_at": c["created_at"]}

    @app.post("/gw/v1/auth/logout")
    @citizen_required
    def logout():
        h = request.headers.get("Authorization", "")[7:].strip()
        db().execute("DELETE FROM sessions WHERE token_hash=?", (_sha(h),))
        db().commit()
        return jsonify({"ok": True})

    @app.get("/gw/v1/me")
    @citizen_required
    def me():
        return jsonify(_citizen(g.citizen))

    @app.delete("/gw/v1/me")
    @citizen_required
    def delete_me():
        """Delete the account. Reports already sent stay with the Army; reports
        not yet collected are still delivered, without the phone number."""
        cid, conn = g.citizen["id"], db()
        conn.execute("UPDATE reports SET citizen_id=NULL, reporter_phone=NULL "
                     "WHERE citizen_id=?", (cid,))
        conn.execute("DELETE FROM sessions WHERE citizen_id=?", (cid,))
        conn.execute("DELETE FROM devices WHERE citizen_id=?", (cid,))
        conn.execute("DELETE FROM citizens WHERE id=?", (cid,))
        conn.commit()
        return jsonify({"ok": True})

    # -- reports -------------------------------------------------------------
    def _num(v):
        if v in (None, ""):
            return None
        return float(v)

    @app.post("/gw/v1/reports")
    @citizen_required
    def submit_report():
        f = request.form if request.files or request.form else body()
        category = f.get("category") or "suspicious_object"
        description = (f.get("description") or "").strip()
        if category not in CATEGORIES:
            return err("unknown category", 400)
        if len(description) > MAX_DESCRIPTION:
            return err(f"description is longer than {MAX_DESCRIPTION} characters", 400)
        try:
            lat, lon, acc = _num(f.get("lat")), _num(f.get("lon")), _num(f.get("accuracy_m"))
        except (TypeError, ValueError):
            return err("position must be numbers", 400)
        if (lat is None) != (lon is None):
            return err("send both lat and lon, or neither", 400)
        if lat is not None and not (LEB_BOX[0] <= lat <= LEB_BOX[2]
                                    and LEB_BOX[1] <= lon <= LEB_BOX[3]):
            return err("that position is outside Lebanon", 400)
        photo = ptype = None
        upload = request.files.get("photo")
        if upload:
            photo = upload.read(MAX_PHOTO + 1)
            if len(photo) > MAX_PHOTO:
                return err("photo is larger than 5 MB", 413)
            ptype = _photo_type(photo)
            if not ptype:
                return err("photo must be a JPEG or PNG image", 400)
        if not description and not photo:
            return err("add a short description or a photo", 400)
        conn, now = db(), _now()
        today = conn.execute(
            "SELECT COUNT(*) FROM reports WHERE citizen_id=? AND submitted_at > ?",
            (g.citizen["id"], _iso(now - timedelta(days=1)))).fetchone()[0]
        if today >= REPORTS_PER_DAY:
            return err("daily report limit reached; call the hotline instead", 429)
        rid = "CR-" + secrets.token_hex(5).upper()
        conn.execute(
            """INSERT INTO reports (id, citizen_id, reporter_phone, submitted_at, category,
                 description, lat, lon, accuracy_m, photo, photo_type)
               VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
            (rid, g.citizen["id"], g.citizen["phone"], _iso(now), category, description,
             lat, lon, acc, photo, ptype))
        conn.commit()
        return jsonify({"id": rid, "status": "received", "submitted_at": _iso(now)}), 201

    @app.get("/gw/v1/reports")
    @citizen_required
    def my_reports():
        rows = db().execute(
            """SELECT id, submitted_at, category, status, status_at, collected
               FROM reports WHERE citizen_id=? ORDER BY submitted_at DESC""",
            (g.citizen["id"],)).fetchall()
        return jsonify({"reports": [
            {"id": r["id"], "submitted_at": r["submitted_at"], "category": r["category"],
             "status": r["status"], "status_at": r["status_at"],
             "delivered": bool(r["collected"])} for r in rows]})

    @app.post("/gw/v1/devices")
    @citizen_required
    def register_device():
        b = body()
        tok, platform = (b.get("push_token") or "").strip(), b.get("platform")
        if not tok or platform not in ("android", "ios"):
            return err("push_token and platform (android|ios) are required", 400)
        db().execute("INSERT OR REPLACE INTO devices VALUES (?,?,?,?)",
                     (g.citizen["id"], tok, platform, _iso(_now())))
        db().commit()
        return jsonify({"ok": True, "push": pusher.name})

    # -- public information --------------------------------------------------
    def _active_warnings():
        now = _iso(_now())
        out = []
        for r in db().execute("SELECT payload FROM warnings ORDER BY id DESC"):
            w = json.loads(r["payload"])
            if w.get("expires_at", "") > now:
                out.append(w)
        return out

    @app.get("/gw/v1/warnings")
    def warnings():
        caza = request.args.get("caza")
        ws = [w for w in _active_warnings() if not caza or w.get("caza") == caza]
        return jsonify({"warnings": ws, "push": pusher.name})

    @app.get("/gw/v1/safety")
    def safety():
        try:
            return jsonify(json.loads(safety_path.read_text(encoding="utf-8")))
        except (OSError, ValueError):
            return err("safety information unavailable", 503)

    # -- sync: called only by the internal server ---------------------------
    @app.get("/gw/v1/sync/reports")
    @sync_required
    def sync_reports():
        limit = min(max(request.args.get("limit", 50, type=int), 1), 200)
        rows = db().execute(
            "SELECT * FROM reports WHERE collected=0 ORDER BY submitted_at LIMIT ?",
            (limit,)).fetchall()
        return jsonify({"reports": [{
            "id": r["id"], "submitted_at": r["submitted_at"],
            "reporter_ref": r["citizen_id"] if r["citizen_id"] is not None else "deleted",
            "reporter_phone": r["reporter_phone"], "category": r["category"],
            "description": r["description"], "lat": r["lat"], "lon": r["lon"],
            "accuracy_m": r["accuracy_m"], "photo_type": r["photo_type"],
            "photo": base64.b64encode(r["photo"]).decode() if r["photo"] else None,
        } for r in rows]})

    @app.post("/gw/v1/sync/ack")
    @sync_required
    def sync_ack():
        ids = [str(i) for i in (body().get("ids") or [])]
        conn = db()
        conn.executemany(
            """UPDATE reports SET collected=1, description='', lat=NULL, lon=NULL,
                 accuracy_m=NULL, photo=NULL, photo_type=NULL, reporter_phone=NULL
               WHERE id=?""", [(i,) for i in ids])
        conn.commit()
        return jsonify({"ok": True, "acknowledged": len(ids)})

    @app.post("/gw/v1/sync/status")
    @sync_required
    def sync_status():
        done, conn = [], db()
        for u in body().get("updates") or []:
            if u.get("status") in STATUSES:
                cur = conn.execute("UPDATE reports SET status=?, status_at=? WHERE id=?",
                                   (u["status"], _iso(_now()), str(u.get("id"))))
                if cur.rowcount:
                    done.append(u["id"])
        conn.commit()
        return jsonify({"ok": True, "updated": done})

    @app.put("/gw/v1/sync/warnings")
    @sync_required
    def sync_warnings():
        incoming = body().get("warnings")
        if not isinstance(incoming, list):
            return err("warnings must be a list", 400)
        keep = ("id", "caza", "severity", "title", "body", "created_at", "expires_at")
        clean = [{k: w.get(k) for k in keep} for w in incoming if isinstance(w, dict)]
        conn = db()
        before = {r["id"]: r["payload"] for r in conn.execute("SELECT * FROM warnings")}
        after = {int(w["id"]): json.dumps(w, ensure_ascii=False, sort_keys=True)
                 for w in clean}
        changed = before != after
        conn.execute("DELETE FROM warnings")
        conn.executemany("INSERT INTO warnings VALUES (?,?)", list(after.items()))
        conn.commit()
        notified = 0
        if changed and after:
            tokens = [r["push_token"] for r in conn.execute("SELECT push_token FROM devices")]
            notified = pusher.notify_warnings_changed(tokens) if tokens else 0
        return jsonify({"ok": True, "count": len(after), "changed": changed,
                        "notified": notified})

    return app


if __name__ == "__main__":
    create_app().run(host=os.environ.get("SIRENS_GW_HOST", "127.0.0.1"),
                     port=int(os.environ.get("SIRENS_GW_PORT", "5100")))
