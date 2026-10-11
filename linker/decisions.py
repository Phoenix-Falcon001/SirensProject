"""Analyst decisions and notes on links (SQLite).

Machine output (scores, clusters) is never modified here. Analyst judgements
live in their own tables and are append-only, so every decision is
reversible: the current decision for a link is the newest row, and
"clearing" a decision adds a 'cleared' row instead of deleting history.

A link is identified by its two incident ids, stored in sorted order, so
(INC-002, INC-001) and (INC-001, INC-002) are the same link.

Self-check (uses a temporary database, never touches data/sirens.db):
    python -m linker.decisions
"""
from __future__ import annotations

from datetime import datetime, timezone

from . import store

DECISIONS = ("confirm", "reject", "unsure")
_ALLOWED = DECISIONS + ("cleared",)

_SCHEMA = """
CREATE TABLE IF NOT EXISTS link_decisions (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_a  TEXT NOT NULL,
    incident_b  TEXT NOT NULL,
    decision    TEXT NOT NULL
                CHECK (decision IN ('confirm', 'reject', 'unsure', 'cleared')),
    analyst     TEXT NOT NULL DEFAULT '',
    created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_link_decisions_pair
    ON link_decisions (incident_a, incident_b);

CREATE TABLE IF NOT EXISTS link_notes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_a  TEXT NOT NULL,
    incident_b  TEXT NOT NULL,
    note        TEXT NOT NULL,
    analyst     TEXT NOT NULL DEFAULT '',
    created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_link_notes_pair
    ON link_notes (incident_a, incident_b);
"""


def connect(db_path=None):
    """Open the shared database and make sure the decision tables exist."""
    conn = store.connect(db_path)
    conn.executescript(_SCHEMA)
    return conn


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _pair(a: str, b: str) -> tuple[str, str]:
    a, b = str(a or "").strip(), str(b or "").strip()
    if not a or not b:
        raise ValueError("both incident ids are required")
    if a == b:
        raise ValueError("a link needs two different incidents")
    return tuple(sorted((a, b)))


# -- decisions ---------------------------------------------------------------
def set_decision(a: str, b: str, decision: str, analyst: str = "", db_path=None) -> None:
    """Record a decision for the link a<->b (appends; never overwrites)."""
    decision = str(decision or "").strip().lower()
    if decision not in _ALLOWED:
        raise ValueError(f"decision must be one of {_ALLOWED}, got {decision!r}")
    x, y = _pair(a, b)
    conn = connect(db_path)
    try:
        conn.execute(
            "INSERT INTO link_decisions (incident_a, incident_b, decision, analyst, created_at)"
            " VALUES (?, ?, ?, ?, ?)",
            (x, y, decision, analyst.strip(), _now()),
        )
        conn.commit()
    finally:
        conn.close()


def clear_decision(a: str, b: str, analyst: str = "", db_path=None) -> None:
    """Undo: the link goes back to 'no decision', history is kept."""
    set_decision(a, b, "cleared", analyst=analyst, db_path=db_path)


def current_decision(a: str, b: str, db_path=None) -> str | None:
    """Newest decision for a<->b, or None if none / cleared."""
    x, y = _pair(a, b)
    conn = connect(db_path)
    try:
        row = conn.execute(
            "SELECT decision FROM link_decisions"
            " WHERE incident_a = ? AND incident_b = ? ORDER BY id DESC LIMIT 1",
            (x, y),
        ).fetchone()
    finally:
        conn.close()
    if row is None or row["decision"] == "cleared":
        return None
    return row["decision"]


def current_decisions(db_path=None) -> dict[tuple[str, str], str]:
    """All links that currently have a decision: {(a, b): decision}."""
    conn = connect(db_path)
    try:
        rows = conn.execute(
            "SELECT d.incident_a, d.incident_b, d.decision FROM link_decisions d"
            " WHERE d.id = (SELECT MAX(id) FROM link_decisions"
            "               WHERE incident_a = d.incident_a AND incident_b = d.incident_b)"
        ).fetchall()
    finally:
        conn.close()
    return {
        (r["incident_a"], r["incident_b"]): r["decision"]
        for r in rows
        if r["decision"] != "cleared"
    }


def decision_history(a: str, b: str, db_path=None) -> list[dict]:
    """Every decision ever recorded for a<->b, oldest first."""
    x, y = _pair(a, b)
    conn = connect(db_path)
    try:
        rows = conn.execute(
            "SELECT decision, analyst, created_at FROM link_decisions"
            " WHERE incident_a = ? AND incident_b = ? ORDER BY id",
            (x, y),
        ).fetchall()
    finally:
        conn.close()
    return [dict(r) for r in rows]


# -- notes -------------------------------------------------------------------
def add_note(a: str, b: str, note: str, analyst: str = "", db_path=None) -> None:
    """Attach a free-text analyst note to the link a<->b."""
    note = str(note or "").strip()
    if not note:
        raise ValueError("note is empty")
    x, y = _pair(a, b)
    conn = connect(db_path)
    try:
        conn.execute(
            "INSERT INTO link_notes (incident_a, incident_b, note, analyst, created_at)"
            " VALUES (?, ?, ?, ?, ?)",
            (x, y, note, analyst.strip(), _now()),
        )
        conn.commit()
    finally:
        conn.close()


def notes_for(a: str, b: str, db_path=None) -> list[dict]:
    """All notes on a<->b, oldest first."""
    x, y = _pair(a, b)
    conn = connect(db_path)
    try:
        rows = conn.execute(
            "SELECT note, analyst, created_at FROM link_notes"
            " WHERE incident_a = ? AND incident_b = ? ORDER BY id",
            (x, y),
        ).fetchall()
    finally:
        conn.close()
    return [dict(r) for r in rows]


# -- self-check --------------------------------------------------------------
def _self_check() -> None:
    import pathlib
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        db = pathlib.Path(tmp) / "check.db"

        conn = connect(db)
        names = {r["name"] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        conn.close()
        assert {"incidents", "link_decisions", "link_notes"} <= names, names
        print("OK  tables exist:", sorted(names))

        assert current_decision("INC-001", "INC-002", db_path=db) is None
        set_decision("INC-002", "INC-001", "Confirm", analyst="test", db_path=db)
        assert current_decision("INC-001", "INC-002", db_path=db) == "confirm"
        print("OK  decision saved, pair order does not matter")

        set_decision("INC-001", "INC-002", "reject", db_path=db)
        assert current_decision("INC-001", "INC-002", db_path=db) == "reject"
        clear_decision("INC-001", "INC-002", db_path=db)
        assert current_decision("INC-001", "INC-002", db_path=db) is None
        assert len(decision_history("INC-001", "INC-002", db_path=db)) == 3
        print("OK  change + undo work, history kept (3 rows)")

        set_decision("INC-003", "INC-004", "unsure", db_path=db)
        assert current_decisions(db_path=db) == {("INC-003", "INC-004"): "unsure"}
        print("OK  current_decisions skips cleared links")

        for bad in (lambda: set_decision("INC-001", "INC-002", "maybe", db_path=db),
                    lambda: set_decision("INC-001", "INC-001", "confirm", db_path=db),
                    lambda: add_note("INC-001", "INC-002", "   ", db_path=db)):
            try:
                bad()
            except ValueError:
                pass
            else:
                raise AssertionError("bad input was accepted")
        print("OK  bad input rejected")

        add_note("INC-001", "INC-002", "Same group named in both reports.", db_path=db)
        notes = notes_for("INC-002", "INC-001", db_path=db)
        assert len(notes) == 1 and notes[0]["note"].startswith("Same group"), notes
        print("OK  notes saved and read back")

        assert store.count(db_path=db) == 0
        print("OK  incidents table untouched")

    print("SELF-CHECK PASSED")


if __name__ == "__main__":
    _self_check()
