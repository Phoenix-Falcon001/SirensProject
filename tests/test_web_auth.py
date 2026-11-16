"""Sign-in for the web console: pages need an account, levels and regions apply."""
import re

import pytest

from linker import accounts, store

PW = "correct-horse-1"


@pytest.fixture
def web(client):
    """The app with sign-in switched ON, demo data loaded, and three accounts."""
    client.post("/seed")                                   # while sign-in is still off
    import app as sirens_app
    cazas = sirens_app._regions_of(store.all_incidents())
    counts = {}
    for c in cazas.values():
        counts[c] = counts.get(c, 0) + 1
    busiest = sorted((c for c in counts if c), key=lambda c: -counts[c])
    client.home, client.away, client.cazas = busiest[0], busiest[1], cazas
    accounts.create_user("boss", PW, "admin")
    accounts.create_user("field1", PW, "military", level="field", regions=[client.home])
    accounts.create_user("analyst1", PW, "military", level="analyst", regions=[client.home])
    sirens_app.app.config["LOGIN_DISABLED"] = False
    return client


def login(c, user, pw=PW):
    return c.post("/login", data={"username": user, "password": pw})


def test_pages_need_sign_in(web):
    for path in ("/", "/report", "/review", "/dashboard", "/map", "/brief", "/munitions", "/demo", "/accounts"):
        r = web.get(path)
        assert r.status_code == 302 and "/login" in r.headers["Location"], path
    assert web.post("/analyse", data={"narrative": "x"}).status_code == 401
    assert web.post("/clear", data={"confirm": "CLEAR"}).status_code == 401
    assert store.count() == 40
    assert web.get("/login").status_code == 200
    assert web.get("/static/sirens.css").status_code == 200


def test_sign_in_and_out(web):
    bad = login(web, "boss", "wrong-password")
    assert bad.status_code == 401 and b"Wrong username or password" in bad.data
    r = login(web, "boss")
    assert r.status_code == 302 and r.headers["Location"].endswith("/")
    home = web.get("/").data.decode()
    assert "Sign out" in home and "Administrator" in home
    web.post("/logout")
    assert web.get("/").status_code == 302


def test_next_only_goes_to_local_pages(web):
    r = web.post("/login", data={"username": "boss", "password": PW, "next": "https://evil.example/x"})
    assert r.headers["Location"].endswith("/")
    web.post("/logout")
    r = web.post("/login", data={"username": "boss", "password": PW, "next": "/review"})
    assert r.headers["Location"].endswith("/review")


def test_levels_limit_pages_and_menu(web):
    login(web, "field1")
    assert web.get("/report").status_code == 200 and web.get("/map").status_code == 200
    for path in ("/review", "/dashboard", "/tree", "/demo", "/accounts"):
        assert web.get(path).status_code == 403, path
    menu = web.get("/").data.decode()
    assert 'href="/report"' in menu and 'href="/accounts"' not in menu
    assert not re.search(r'class="sm-item[^"]*"[^>]*href="/review"', menu)
    web.post("/logout")
    login(web, "analyst1")
    assert web.get("/review").status_code == 200 and web.get("/dashboard").status_code == 200
    assert web.get("/accounts").status_code == 403
    assert web.post("/clear", data={"confirm": "CLEAR"}).status_code == 403
    assert store.count(unscoped=True) == 40


def test_military_user_sees_only_their_cazas(web):
    mine = {i for i, c in web.cazas.items() if c == web.home}
    login(web, "analyst1")
    home = web.get("/").data.decode()
    assert f"{len(mine)} reports on record" in home
    review = web.get("/review").data.decode()
    ids = set(re.findall(r'<span class="mono">(INC-\d+)</span>', review))
    assert ids and ids <= mine
    away = next(i for i, c in web.cazas.items() if c == web.away)
    assert web.get(f"/network/{away}/panel").status_code == 404
    web.post("/logout")
    login(web, "boss")
    assert "40 reports on record" in web.get("/").data.decode()


def test_military_user_files_only_in_their_cazas(web):
    login(web, "field1")
    text = "Fabricated test. Pressure plate found near the road."
    r = web.post("/analyse", data={"action": "save", "incident_id": "INC-090", "narrative": text,
                                   "caza": web.away}).data.decode()
    assert "is outside your regions" in r
    r = web.post("/analyse", data={"action": "save", "incident_id": "INC-090", "narrative": text}).data.decode()
    assert "Choose the caza or place a pin" in r
    taken = next(i for i, c in web.cazas.items() if c == web.away)      # an ID they cannot see
    r = web.post("/analyse", data={"action": "save", "incident_id": taken, "narrative": text,
                                   "caza": web.home}).data.decode()
    assert "already in use" in r
    assert store.get_incident(taken, unscoped=True).narrative != text   # not overwritten
    ok = web.post("/analyse", data={"action": "save", "incident_id": "INC-090", "narrative": text,
                                    "caza": web.home}).data.decode()
    assert "INC-090 is on record" in ok


def test_review_decisions_carry_the_account(web):
    from linker import decisions
    login(web, "analyst1")
    html = web.get("/review").data.decode()
    a, b = re.search(r'name="a" value="([^"]+)"><input type="hidden" name="b" value="([^"]+)"', html).groups()
    web.post("/review/decide", data={"a": a, "b": b, "decision": "confirm", "analyst": "someone else"})
    assert decisions.decision_history(a, b)[-1]["analyst"] == "analyst1"


def test_cross_site_posts_are_refused(web):
    login(web, "boss")
    r = web.post("/clear", data={"confirm": "CLEAR"}, headers={"Origin": "https://evil.example"})
    assert r.status_code == 403 and store.count() == 40
    r = web.post("/login", data={"username": "boss", "password": PW}, headers={"Origin": "https://evil.example"})
    assert r.status_code == 403


def test_admin_manages_accounts(web):
    login(web, "boss")
    r = web.post("/accounts/new", data={"username": "lt_nader", "role": "military", "level": "analyst",
                                        "regions": [web.home], "display_name": "Lt. Nader"})
    assert r.status_code == 302
    page = web.get(r.headers["Location"]).data.decode()
    pw = re.search(r"<code>([^<]+)</code>", page).group(1)
    assert "Temporary password for lt_nader" in page
    assert pw not in web.get("/accounts").data.decode()            # shown once
    uid = next(u["id"] for u in accounts.list_users() if u["username"] == "lt_nader")
    bad = web.post("/accounts/new", data={"username": "x", "role": "military", "level": "field"})
    assert bad.status_code == 400 and b"at least one region" in bad.data
    web.post(f"/accounts/{uid}", data={"action": "save", "level": "commander", "regions": [web.home], "active": "on"})
    assert accounts.get_user(uid)["level"] == "commander"
    me = next(u["id"] for u in accounts.list_users() if u["username"] == "boss")
    r = web.post(f"/accounts/{me}", data={"action": "save"})        # would disable self
    assert r.status_code == 400 and accounts.get_user(me)["active"]
    web.post("/logout")
    assert login(web, "lt_nader", pw).status_code == 302            # the temporary password works


def test_disabling_an_account_ends_its_session(web):
    login(web, "field1")
    assert web.get("/report").status_code == 200
    uid = next(u["id"] for u in accounts.list_users() if u["username"] == "field1")
    accounts.update_user(uid, actor="boss", active=False)
    assert web.get("/report").status_code == 302


def test_change_own_password(web):
    login(web, "field1")
    r = web.post("/password", data={"current": PW, "new": "a-new-password-1", "new2": "a-new-password-1"})
    assert b"Password changed" in r.data
    web.post("/logout")
    assert login(web, "field1", "a-new-password-1").status_code == 302


def test_first_run_creates_the_first_admin(client):
    import app as sirens_app
    sirens_app.app.config["LOGIN_DISABLED"] = False
    page = client.get("/login").data.decode()
    assert "Create the first administrator" in page
    r = client.post("/setup", data={"username": "chief", "password": PW, "password2": PW})
    assert r.status_code == 302 and client.get("/").status_code == 200
    client.post("/logout")
    assert client.post("/setup", data={"username": "second", "password": PW, "password2": PW}).status_code == 403
    assert "Create the first administrator" not in client.get("/login").data.decode()
