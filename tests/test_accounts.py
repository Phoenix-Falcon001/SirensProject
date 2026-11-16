"""Accounts, role levels and region rules (linker/accounts.py)."""
import pytest

from linker import accounts as acc

PW = "correct-horse-1"


@pytest.fixture
def db(tmp_path, monkeypatch):
    from linker import store
    monkeypatch.setattr(store, "DEFAULT_DB", tmp_path / "t.db")
    return tmp_path / "t.db"


def test_level_permissions_are_cumulative():
    field = {"role": "military", "level": "field", "regions": ["Sour"]}
    analyst = {**field, "level": "analyst"}
    commander = {**field, "level": "commander"}
    admin = {"role": "admin", "level": None, "regions": []}
    assert acc.can(field, "incidents:create") and not acc.can(field, "review")
    assert acc.can(analyst, "review") and acc.can(analyst, "brief")
    assert not acc.can(analyst, "warnings:publish")
    assert acc.can(commander, "warnings:publish") and acc.can(commander, "dashboard")
    assert not acc.can(commander, "users:manage")
    assert acc.can(admin, "users:manage") and acc.can(admin, "warnings:publish")


def test_region_rule():
    u = {"role": "military", "level": "field", "regions": ["Sour", "Saida"]}
    assert acc.sees_region(u, "Sour")
    assert not acc.sees_region(u, "Beirut")
    assert not acc.sees_region(u, None)     # unknown caza: admins only
    assert acc.sees_region({"role": "admin", "regions": []}, None)


def test_military_needs_level_and_region(db):
    with pytest.raises(acc.AccountError):
        acc.create_user("a", PW, "military", level=None, regions=["Sour"])
    with pytest.raises(acc.AccountError):
        acc.create_user("a", PW, "military", level="field", regions=[])
    with pytest.raises(acc.AccountError):
        acc.create_user("a", PW, "military", level="field", regions=["Atlantis"],
                        known_regions={"Sour"})
    with pytest.raises(acc.AccountError):
        acc.create_user("a", "short", "military", level="field", regions=["Sour"])


def test_login_token_and_logout(db):
    acc.create_user("Sgt.Haddad", PW, "military", level="field", regions=["Sour"])
    token, user, _exp = acc.login("sgt.haddad", PW)          # username not case-sensitive
    assert user["level"] == "field"
    assert acc.user_for_token(token)["username"] == "Sgt.Haddad"
    acc.logout(token)
    assert acc.user_for_token(token) is None


def test_tokens_are_not_stored_in_clear(db):
    acc.create_user("u1", PW, "admin")
    token, *_ = acc.login("u1", PW)
    raw = db.read_bytes()
    assert token.encode() not in raw
    assert PW.encode() not in raw


def test_lockout_after_failed_logins(db):
    acc.create_user("u1", PW, "admin")
    for _ in range(acc.MAX_FAILED):
        with pytest.raises(acc.AccountError, match="wrong"):
            acc.login("u1", "nope-nope-nope")
    with pytest.raises(acc.AccountError, match="locked"):
        acc.login("u1", PW)


def test_same_message_for_unknown_user_and_wrong_password(db):
    acc.create_user("u1", PW, "admin")
    with pytest.raises(acc.AccountError) as a:
        acc.login("nobody", PW)
    with pytest.raises(acc.AccountError) as b:
        acc.login("u1", "wrong-wrong-wrong")
    assert str(a.value) == str(b.value)


def test_disable_and_reset_end_sessions(db):
    acc.create_user("boss", PW, "admin")
    u = acc.create_user("u1", PW, "military", level="field", regions=["Sour"])
    t1, *_ = acc.login("u1", PW)
    acc.update_user(u["id"], actor="boss", password="new-password-99")
    assert acc.user_for_token(t1) is None
    t2, *_ = acc.login("u1", "new-password-99")
    acc.update_user(u["id"], actor="boss", active=False)
    assert acc.user_for_token(t2) is None
    with pytest.raises(acc.AccountError, match="disabled"):
        acc.login("u1", "new-password-99")


def test_last_admin_cannot_be_disabled(db):
    a = acc.create_user("boss", PW, "admin")
    with pytest.raises(acc.AccountError, match="last active admin"):
        acc.update_user(a["id"], actor="boss", active=False)


def test_audit_log_records_changes_without_passwords(db):
    acc.create_user("boss", PW, "admin")
    u = acc.create_user("u1", PW, "military", level="field", regions=["Sour"])
    acc.update_user(u["id"], actor="boss", level="analyst", password="another-pass-1")
    acc.login("u1", "another-pass-1")
    actions = [e["action"] for e in acc.audit_entries()]
    assert {"user.create", "user.update", "login.ok"} <= set(actions)
    assert "another-pass-1" not in str(acc.audit_entries())
