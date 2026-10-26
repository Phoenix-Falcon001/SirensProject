"""Civilian reports and area warnings, as held on the internal server.

Civilian reports are pulled in from the public gateway by the sync job
(sync_gateway.py). Each gets a caza from its GPS point, so only commanders
assigned to that caza (and admins) see it. A commander moves it through
``received -> under_review -> closed`` (or ``rejected``); the status, and
nothing else, goes back to the civilian.

Warnings are written by commanders for one of their own cazas and pushed out
to the gateway, where civilians read them. A warning carries only what the
civilian should do; never incident details.
"""
from __future__ import annotations

import json
from datetime import datetime, timezone

from . import store
from .grid_ref import to_mgrs
from .regions import caza_at

STATUSES = ("received", "under_review", "closed", "rejected")
SEVERITIES = ("info", "caution", "danger")

_SCHEMA = """
CREATE TABLE IF NOT EXISTS civil_reports (
    id            TEXT PRIMARY KEY,          -- the gateway's report id
    received_at   TEXT NOT NULL,
    submitted_at  TEXT NOT NULL,
    observed_at   TEXT,
    reporter_ref  TEXT NOT NULL,             -- gateway account id, not the phone
    reporter_phone TEXT,
    lat           REAL,
    lon           REAL,
    accuracy_m    REAL,
    caza          TEXT,
    mgrs          TEXT,
    category      TEXT,
    description   TEXT NOT NULL DEFAULT '',
    photo         BLOB,
    photo_type    TEXT,
    status        TEXT NOT NULL DEFAULT 'received',
    status_note   TEXT NOT NULL DEFAULT '',
    status_by     TEXT,
    status_at     TEXT,
    status_synced INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS warnings (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    caza        TEXT NOT NULL,
    severity    TEXT NOT NULL,
    title       TEXT NOT NULL,             -- JSON {"ar":..,"en":..,"fr":..}
    body        TEXT NOT NULL,             -- JSON, same languages
    created_by  TEXT NOT NULL,
    created_at  TEXT NOT NULL,
    expires_at  TEXT NOT NULL,
    withdrawn   INTEGER NOT NULL DEFAULT 0
);
"""


class CivilError(ValueError):
    pass


def connect(db_path=None):
    conn = store.connect(db_path)
    conn.executescript(_SCHEMA)
    # Databases created before observed_at existed get the column added.
    cols = {r[1] for r in conn.execute("PRAGMA table_info(civil_reports)")}
    if "observed_at" not in cols:
        conn.execute("ALTER TABLE civil_reports ADD COLUMN observed_at TEXT")
        conn.commit()
    return conn


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


# -- civilian reports --------------------------------------------------------
def receive(report: dict, db_path=None) -> bool:
    """Store one report pulled from the gateway. Returns False if already held
    (sync can safely re-send)."""
    conn = connect(db_path)
    try:
        if conn.execute("SELECT 1 FROM civil_reports WHERE id=?", (report["id"],)).fetchone():
            return False
        lat, lon = report.get("lat"), report.get("lon")
        caza = mgrs = None
        if lat is not None and lon is not None:
            caza = caza_at(lat, lon)
            try:
                mgrs = to_mgrs(lat, lon)
            except ValueError:
                mgrs = None
        conn.execute(
            """INSERT INTO civil_reports (id, received_at, submitted_at, observed_at,
                 reporter_ref, reporter_phone, lat, lon, accuracy_m, caza, mgrs, category,
                 description, photo, photo_type)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (report["id"], _now(), report["submitted_at"], report.get("observed_at"),
             str(report["reporter_ref"]),
             report.get("reporter_phone"), lat, lon, report.get("accuracy_m"), caza, mgrs,
             report.get("category"), report.get("description") or "",
             report.get("photo"), report.get("photo_type")))
        conn.commit()
        return True
    finally:
        conn.close()


def _report_row(r, with_photo=False) -> dict:
    d = {k: r[k] for k in r.keys() if k not in ("photo",)}
    d["has_photo"] = r["photo"] is not None
    if with_photo:
        d["photo"] = r["photo"]
    return d


def list_reports(status: str | None = None, db_path=None) -> list[dict]:
    conn = connect(db_path)
    q, args = "SELECT * FROM civil_reports", ()
    if status:
        q, args = q + " WHERE status=?", (status,)
    rows = conn.execute(q + " ORDER BY submitted_at DESC", args).fetchall()
    conn.close()
    return [_report_row(r) for r in rows]


def get_report(report_id: str, with_photo=False, db_path=None) -> dict | None:
    conn = connect(db_path)
    r = conn.execute("SELECT * FROM civil_reports WHERE id=?", (report_id,)).fetchone()
    conn.close()
    return _report_row(r, with_photo) if r else None


def set_status(report_id: str, status: str, by: str, note: str = "", db_path=None) -> dict:
    if status not in STATUSES:
        raise CivilError(f"status must be one of {', '.join(STATUSES)}")
    conn = connect(db_path)
    try:
        cur = conn.execute(
            """UPDATE civil_reports SET status=?, status_note=?, status_by=?, status_at=?,
                 status_synced=0 WHERE id=?""",
            (status, (note or "").strip(), by, _now(), report_id))
        if not cur.rowcount:
            raise CivilError("no such report")
        conn.commit()
    finally:
        conn.close()
    return get_report(report_id, db_path=db_path)


def unsynced_statuses(db_path=None) -> list[dict]:
    conn = connect(db_path)
    rows = conn.execute(
        "SELECT id, status FROM civil_reports WHERE status_synced=0").fetchall()
    conn.close()
    return [{"id": r["id"], "status": r["status"]} for r in rows]


def mark_statuses_synced(sent: list[dict], db_path=None) -> None:
    """Mark sent statuses as delivered, unless the status changed again since."""
    conn = connect(db_path)
    conn.executemany("UPDATE civil_reports SET status_synced=1 WHERE id=? AND status=?",
                     [(u["id"], u["status"]) for u in sent])
    conn.commit()
    conn.close()


# -- warnings ----------------------------------------------------------------
def _texts(value, field) -> dict:
    """Accept a plain string or {"ar","en","fr"}; at least one language required."""
    if isinstance(value, str):
        value = {"en": value}
    if not isinstance(value, dict):
        raise CivilError(f"{field} must be text or a {{ar, en, fr}} object")
    out = {k: str(v).strip() for k, v in value.items() if k in ("ar", "en", "fr") and str(v).strip()}
    if not out:
        raise CivilError(f"{field} needs text in at least one of ar, en, fr")
    return out


def create_warning(caza: str, severity: str, title, body, expires_at: str, by: str,
                   db_path=None) -> dict:
    if severity not in SEVERITIES:
        raise CivilError(f"severity must be one of {', '.join(SEVERITIES)}")
    try:
        exp = datetime.fromisoformat(expires_at)
    except (TypeError, ValueError):
        raise CivilError("expires_at must be an ISO date-time") from None
    if exp.tzinfo is None:
        exp = exp.replace(tzinfo=timezone.utc)
    exp = exp.astimezone(timezone.utc)   # stored in UTC so text comparison works
    if exp <= datetime.now(timezone.utc):
        raise CivilError("expires_at must be in the future")
    t, b = _texts(title, "title"), _texts(body, "body")
    conn = connect(db_path)
    cur = conn.execute(
        """INSERT INTO warnings (caza, severity, title, body, created_by, created_at, expires_at)
           VALUES (?,?,?,?,?,?,?)""",
        (caza, severity, json.dumps(t, ensure_ascii=False), json.dumps(b, ensure_ascii=False),
         by, _now(), exp.isoformat(timespec="seconds")))
    conn.commit()
    wid = cur.lastrowid
    conn.close()
    return get_warning(wid, db_path=db_path)


def _warning_row(r) -> dict:
    return {"id": r["id"], "caza": r["caza"], "severity": r["severity"],
            "title": json.loads(r["title"]), "body": json.loads(r["body"]),
            "created_by": r["created_by"], "created_at": r["created_at"],
            "expires_at": r["expires_at"], "withdrawn": bool(r["withdrawn"])}


def get_warning(wid: int, db_path=None) -> dict | None:
    conn = connect(db_path)
    r = conn.execute("SELECT * FROM warnings WHERE id=?", (wid,)).fetchone()
    conn.close()
    return _warning_row(r) if r else None


def list_warnings(active_only=False, db_path=None) -> list[dict]:
    conn = connect(db_path)
    q, args = "SELECT * FROM warnings", ()
    if active_only:
        q, args = q + " WHERE withdrawn=0 AND expires_at > ?", (_now(),)
    rows = conn.execute(q + " ORDER BY created_at DESC", args).fetchall()
    conn.close()
    return [_warning_row(r) for r in rows]


def withdraw_warning(wid: int, db_path=None) -> dict:
    conn = connect(db_path)
    cur = conn.execute("UPDATE warnings SET withdrawn=1 WHERE id=?", (wid,))
    conn.commit()
    conn.close()
    if not cur.rowcount:
        raise CivilError("no such warning")
    return get_warning(wid, db_path=db_path)


def public_warnings(db_path=None) -> list[dict]:
    """What the gateway may show civilians: active warnings, without who wrote them."""
    return [{k: w[k] for k in ("id", "caza", "severity", "title", "body", "created_at",
                               "expires_at")}
            for w in list_warnings(active_only=True, db_path=db_path)]
