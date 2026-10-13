"""Analyst link decisions and notes (linker/decisions.py), on temporary databases."""
from linker import decisions, store


def test_builtin_self_check_passes(capsys):
    decisions._self_check()           # uses its own temporary database
    assert capsys.readouterr().out.strip().endswith("SELF-CHECK PASSED")


def test_decisions_are_reversible_and_kept_apart_from_incidents(tmp_path):
    db = tmp_path / "t.db"
    decisions.set_decision("INC-010", "INC-003", "confirm", analyst="a", db_path=db)
    decisions.clear_decision("INC-003", "INC-010", db_path=db)
    assert decisions.current_decision("INC-003", "INC-010", db_path=db) is None
    assert [h["decision"] for h in decisions.decision_history("INC-003", "INC-010", db_path=db)] \
        == ["confirm", "cleared"]
    decisions.add_note("INC-003", "INC-010", "Check the date again.", db_path=db)
    assert len(decisions.notes_for("INC-010", "INC-003", db_path=db)) == 1
    assert store.count(db_path=db) == 0
