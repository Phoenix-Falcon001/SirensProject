"""Accounts, roles and access rules for the internal (Army) server.

Who can use the internal server:

* ``admin``    – manages accounts, sees every region, can do everything.
* ``military`` – created by an admin only. Each account has a **role level**
  and a list of **assigned regions** (caza names from data/regions.json).

  ======== =========================================================
  level    adds
  ======== =========================================================
  field    file reports, pre-arrival brief, map, read incidents
  analyst  review links, dashboard
  commander triage civilian reports, publish area warnings
  ======== =========================================================

Civilians never have an account here: they sign up on the public gateway
(gateway/), which this server only reaches through the sync job.

Passwords are hashed with werkzeug (ships with Flask). Session tokens are
random, sent to the phone once, and only their SHA-256 is stored, so a copy of
the database cannot be used to log in. Every sign-in and every admin change is
written to an append-only audit log.
"""
from __future__ import annotations

import hashlib
import json
import secrets
from datetime import datetime, timedelta, timezone

from werkzeug.security import check_password_hash, generate_password_hash

from . import store

ROLES = ("admin", "military")
LEVELS = ("field", "analyst", "commander")

# What each level may do. Higher levels include everything below them.
_LEVEL_PERMS = {
    "field": {"incidents:read", "incidents:create", "brief", "map"},
    "analyst": {"review", "dashboard"},
    "commander": {"civil_reports", "warnings:publish"},
}
ADMIN_PERMS = {"users:manage", "audit:read"}

TOKEN_TTL = timedelta(hours=12)        # one working shift; the app asks again after
MIN_PASSWORD = 10
MAX_FAILED = 5                         # wrong passwords before the account locks
LOCK_FOR = timedelta(minutes=15)

_SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT NOT NULL UNIQUE COLLATE NOCASE,
    display_name  TEXT NOT NULL DEFAULT '',
    password_hash TEXT NOT NULL,
    role          TEXT NOT NULL,
    level         TEXT,
    regions       TEXT NOT NULL DEFAULT '[]',
    active        INTEGER NOT NULL DEFAULT 1,
    failed_logins INTEGER NOT NULL DEFAULT 0,
    locked_until  TEXT,
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
    token_hash  TEXT PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id),
    created_at  TEXT NOT NULL,
    expires_at  TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS audit_log (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    at        TEXT NOT NULL,
    actor     TEXT NOT NULL,
    action    TEXT NOT NULL,
    detail    TEXT NOT NULL DEFAULT '{}'
);
"""


class AccountError(ValueError):
    """A request that breaks an account rule; the message is safe to show."""


def connect(db_path=None):
    conn = store.connect(db_path)
    conn.executescript(_SCHEMA)
    return conn


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.isoformat(timespec="seconds")


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


# -- rules -------------------------------------------------------------------
def permissions(user: dict) -> set[str]:
    """Everything this user may do, from role and level."""
    if user["role"] == "admin":
        perms = set(ADMIN_PERMS)
        for p in _LEVEL_PERMS.values():
            perms |= p
        return perms
    perms: set[str] = set()
    for lvl in LEVELS:
        perms |= _LEVEL_PERMS[lvl]
        if lvl == user.get("level"):
            break
    return perms


def can(user: dict, perm: str) -> bool:
    return perm in permissions(user)


def sees_region(user: dict, caza: str | None) -> bool:
    """Admins see every region. Military users see only their assigned cazas;
    a record with no known caza is shown to admins only."""
    if user["role"] == "admin":
        return True
    return bool(caza) and caza in user["regions"]


def _check_fields(role: str, level: str | None, regions: list[str], known_regions) -> None:
    if role not in ROLES:
        raise AccountError(f"role must be one of {', '.join(ROLES)}")
    if role == "military":
        if level not in LEVELS:
            raise AccountError(f"level must be one of {', '.join(LEVELS)}")
        if not regions:
            raise AccountError("a military account needs at least one region")
    unknown = [r for r in regions if known_regions is not None and r not in known_regions]
    if unknown:
        raise AccountError(f"unknown region(s): {', '.join(unknown)}")


def _check_password(pw: str) -> None:
    if len(pw or "") < MIN_PASSWORD:
        raise AccountError(f"password must be at least {MIN_PASSWORD} characters")


# -- users -------------------------------------------------------------------
def _row(r) -> dict:
    return {
        "id": r["id"], "username": r["username"], "display_name": r["display_name"],
        "role": r["role"], "level": r["level"], "regions": json.loads(r["regions"]),
        "active": bool(r["active"]),
    }


def create_user(username: str, password: str, role: str, level: str | None = None,
                regions: list[str] | None = None, display_name: str = "",
                actor: str = "system", known_regions=None, db_path=None) -> dict:
    username = (username or "").strip()
    if not username:
        raise AccountError("username is required")
    regions = sorted(set(regions or []))
    if role == "admin":
        level, regions = None, []
    _check_fields(role, level, regions, known_regions)
    _check_password(password)
    conn = connect(db_path)
    try:
        if conn.execute("SELECT 1 FROM users WHERE username=?", (username,)).fetchone():
            raise AccountError("that username is already taken")
        now = _iso(_now())
        cur = conn.execute(
            """INSERT INTO users (username, display_name, password_hash, role, level,
                                  regions, created_at, updated_at)
               VALUES (?,?,?,?,?,?,?,?)""",
            (username, display_name.strip(), generate_password_hash(password),
             role, level, json.dumps(regions), now, now))
        conn.commit()
        user = get_user(cur.lastrowid, conn=conn)
        audit(actor, "user.create", {"user": username, "role": role, "level": level,
                                     "regions": regions}, conn=conn)
        return user
    finally:
        conn.close()


def get_user(user_id: int, db_path=None, conn=None) -> dict | None:
    own = conn is None
    conn = conn or connect(db_path)
    r = conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
    if own:
        conn.close()
    return _row(r) if r else None


def list_users(db_path=None) -> list[dict]:
    conn = connect(db_path)
    rows = conn.execute("SELECT * FROM users ORDER BY username").fetchall()
    conn.close()
    return [_row(r) for r in rows]


def update_user(user_id: int, actor: str, known_regions=None, db_path=None, **changes) -> dict:
    """Change level, regions, display name, active flag, or reset the password."""
    conn = connect(db_path)
    try:
        cur = get_user(user_id, conn=conn)
        if not cur:
            raise AccountError("no such user")
        level = changes.get("level", cur["level"])
        regions = sorted(set(changes.get("regions", cur["regions"]) or []))
        if cur["role"] == "admin":
            level, regions = None, []
        _check_fields(cur["role"], level, regions, known_regions)
        active = bool(changes.get("active", cur["active"]))
        if cur["role"] == "admin" and not active and _active_admins(conn) <= 1:
            raise AccountError("cannot disable the last active admin")
        sets = {"level": level, "regions": json.dumps(regions), "active": int(active),
                "display_name": (changes.get("display_name", cur["display_name"]) or "").strip(),
                "updated_at": _iso(_now())}
        if changes.get("password"):
            _check_password(changes["password"])
            sets["password_hash"] = generate_password_hash(changes["password"])
            sets["failed_logins"], sets["locked_until"] = 0, None
        conn.execute(
            f"UPDATE users SET {', '.join(f'{k}=?' for k in sets)} WHERE id=?",
            (*sets.values(), user_id))
        if not active or changes.get("password"):
            # Disabling an account or resetting its password ends its sessions.
            conn.execute("DELETE FROM sessions WHERE user_id=?", (user_id,))
        conn.commit()
        logged = {k: v for k, v in changes.items() if k != "password"}
        if changes.get("password"):
            logged["password"] = "reset"
        audit(actor, "user.update", {"user": cur["username"], **logged}, conn=conn)
        return get_user(user_id, conn=conn)
    finally:
        conn.close()


def _active_admins(conn) -> int:
    return conn.execute(
        "SELECT COUNT(*) FROM users WHERE role='admin' AND active=1").fetchone()[0]


# -- sessions ----------------------------------------------------------------
def login(username: str, password: str, db_path=None) -> tuple[str, dict, str]:
    """Return (token, user, expires_at) or raise AccountError with a message
    that does not reveal whether the username exists."""
    bad = AccountError("wrong username or password")
    conn = connect(db_path)
    try:
        r = conn.execute("SELECT * FROM users WHERE username=?",
                         ((username or "").strip(),)).fetchone()
        if not r:
            # Same work as a real check, so timing doesn't reveal valid usernames.
            check_password_hash(_DUMMY_HASH, password or "")
            raise bad
        now = _now()
        if r["locked_until"] and datetime.fromisoformat(r["locked_until"]) > now:
            raise AccountError("account temporarily locked after too many attempts; "
                               "try again later")
        if not check_password_hash(r["password_hash"], password or ""):
            failed = r["failed_logins"] + 1
            locked = _iso(now + LOCK_FOR) if failed >= MAX_FAILED else None
            conn.execute("UPDATE users SET failed_logins=?, locked_until=? WHERE id=?",
                         (0 if locked else failed, locked, r["id"]))
            conn.commit()
            audit(r["username"], "login.fail", {"locked": bool(locked)}, conn=conn)
            raise bad
        if not r["active"]:
            raise AccountError("this account is disabled")
        conn.execute("UPDATE users SET failed_logins=0, locked_until=NULL WHERE id=?",
                     (r["id"],))
        token = secrets.token_urlsafe(32)
        expires = _iso(now + TOKEN_TTL)
        conn.execute("INSERT INTO sessions VALUES (?,?,?,?)",
                     (_hash_token(token), r["id"], _iso(now), expires))
        conn.execute("DELETE FROM sessions WHERE expires_at < ?", (_iso(now),))
        conn.commit()
        audit(r["username"], "login.ok", {}, conn=conn)
        return token, _row(r), expires
    finally:
        conn.close()


_DUMMY_HASH = generate_password_hash("not-a-real-password")


def user_for_token(token: str, db_path=None) -> dict | None:
    if not token:
        return None
    conn = connect(db_path)
    try:
        r = conn.execute(
            """SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id
               WHERE s.token_hash=? AND s.expires_at > ? AND u.active=1""",
            (_hash_token(token), _iso(_now()))).fetchone()
        return _row(r) if r else None
    finally:
        conn.close()


def logout(token: str, db_path=None) -> None:
    conn = connect(db_path)
    conn.execute("DELETE FROM sessions WHERE token_hash=?", (_hash_token(token or ""),))
    conn.commit()
    conn.close()


def change_password(user_id: int, old: str, new: str, db_path=None) -> None:
    conn = connect(db_path)
    try:
        r = conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
        if not r or not check_password_hash(r["password_hash"], old or ""):
            raise AccountError("current password is wrong")
        _check_password(new)
        conn.execute("UPDATE users SET password_hash=?, updated_at=? WHERE id=?",
                     (generate_password_hash(new), _iso(_now()), user_id))
        conn.commit()
        audit(r["username"], "password.change", {}, conn=conn)
    finally:
        conn.close()


# -- audit -------------------------------------------------------------------
def audit(actor: str, action: str, detail: dict, db_path=None, conn=None) -> None:
    own = conn is None
    conn = conn or connect(db_path)
    conn.execute("INSERT INTO audit_log (at, actor, action, detail) VALUES (?,?,?,?)",
                 (_iso(_now()), actor, action, json.dumps(detail, ensure_ascii=False)))
    conn.commit()
    if own:
        conn.close()


def audit_entries(limit: int = 200, db_path=None) -> list[dict]:
    conn = connect(db_path)
    rows = conn.execute("SELECT * FROM audit_log ORDER BY id DESC LIMIT ?",
                        (limit,)).fetchall()
    conn.close()
    return [{"at": r["at"], "actor": r["actor"], "action": r["action"],
             "detail": json.loads(r["detail"])} for r in rows]


# -- command line: create the first admin ------------------------------------
def _main(argv=None) -> int:
    import argparse
    import getpass

    p = argparse.ArgumentParser(
        prog="python -m linker.accounts",
        description="Create the first admin account on the internal server.")
    p.add_argument("command", choices=["create-admin"])
    p.add_argument("username")
    p.add_argument("--name", default="")
    a = p.parse_args(argv)
    pw = getpass.getpass("New password: ")
    if pw != getpass.getpass("Repeat password: "):
        print("Passwords differ; nothing created.")
        return 1
    try:
        create_user(a.username, pw, "admin", display_name=a.name, actor="cli")
    except AccountError as e:
        print(f"Not created: {e}")
        return 1
    print(f"Admin '{a.username}' created.")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
