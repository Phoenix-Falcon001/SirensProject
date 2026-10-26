"""Public gateway for civilians (gateway/app.py) and the sync job."""
from datetime import datetime, timedelta, timezone

import pytest

from gateway import push, sms
from gateway.app import create_app, normalize_phone

KEY = "test-sync-key-0123456789"
JPEG = b"\xff\xd8\xff\xe0" + b"0" * 100


@pytest.fixture
def gw(tmp_path):
    sender, pusher = sms.ConsoleSender(), push.RecordingPush()
    app = create_app(db_path=tmp_path / "gw.db", sync_key=KEY, sms_sender=sender,
                     push_sender=pusher, dev=True)
    app.config["TESTING"] = True
    c = app.test_client()
    c.sms, c.push = sender, pusher
    return c


def sign_in(gw, phone="03 123 456"):
    r = gw.post("/gw/v1/auth/request-code", json={"phone": phone, "lang": "ar"})
    assert r.status_code == 200, r.json
    code = gw.sms.sent[-1][1]
    r = gw.post("/gw/v1/auth/verify", json={"phone": phone, "code": code, "lang": "ar"})
    assert r.status_code == 200, r.json
    return {"Authorization": "Bearer " + r.json["token"]}, r.json


SYNC = {"X-Sync-Key": KEY}


def test_phone_numbers():
    assert normalize_phone("03 123 456") == "+9613123456"
    assert normalize_phone("70-123456") == "+96170123456"
    assert normalize_phone("+961 71 123 456") == "+96171123456"
    assert normalize_phone("0033 6 12 34 56 78") == "+33612345678"
    assert normalize_phone("hello") is None


def test_production_refuses_unsafe_settings(tmp_path, monkeypatch):
    monkeypatch.delenv("SIRENS_GW_DEV", raising=False)
    with pytest.raises(RuntimeError, match="SYNC_KEY"):
        create_app(db_path=tmp_path / "a.db", sync_key="short", dev=False)
    with pytest.raises(RuntimeError, match="SECRET"):
        create_app(db_path=tmp_path / "a.db", sync_key=KEY, dev=False)
    monkeypatch.setenv("SIRENS_GW_SECRET", "s" * 40)
    with pytest.raises(RuntimeError, match="SMS"):
        create_app(db_path=tmp_path / "a.db", sync_key=KEY, dev=False)


def test_sign_up_and_sign_in(gw):
    h, first = sign_in(gw)
    assert first["new_account"] and first["citizen"]["phone"] == "+9613123456"
    _h2, again = sign_in(gw)
    assert not again["new_account"]
    assert gw.get("/gw/v1/me", headers=h).json["lang"] == "ar"


def test_wrong_and_reused_codes(gw):
    gw.post("/gw/v1/auth/request-code", json={"phone": "03123456"})
    code = gw.sms.sent[-1][1]
    bad = "000000" if code != "000000" else "111111"
    assert gw.post("/gw/v1/auth/verify", json={"phone": "03123456", "code": bad}).status_code == 400
    assert gw.post("/gw/v1/auth/verify", json={"phone": "03123456", "code": code}).status_code == 200
    # A code works once.
    assert gw.post("/gw/v1/auth/verify", json={"phone": "03123456", "code": code}).status_code == 400


def test_code_attempts_and_request_limits(gw):
    gw.post("/gw/v1/auth/request-code", json={"phone": "03123456"})
    code = gw.sms.sent[-1][1]
    bad = "000000" if code != "000000" else "111111"
    for _ in range(5):
        gw.post("/gw/v1/auth/verify", json={"phone": "03123456", "code": bad})
    r = gw.post("/gw/v1/auth/verify", json={"phone": "03123456", "code": code})
    assert r.status_code == 429
    gw.post("/gw/v1/auth/request-code", json={"phone": "03123456"})
    gw.post("/gw/v1/auth/request-code", json={"phone": "03123456"})
    r = gw.post("/gw/v1/auth/request-code", json={"phone": "03123456"})
    assert r.status_code == 429


def test_codes_are_not_stored_in_clear(gw, tmp_path):
    gw.post("/gw/v1/auth/request-code", json={"phone": "03123456"})
    code = gw.sms.sent[-1][1]
    assert code.encode() not in (tmp_path / "gw.db").read_bytes()


def test_submit_and_track_reports(gw):
    h, _ = sign_in(gw)
    r = gw.post("/gw/v1/reports", headers=h, data={
        "category": "suspicious_object", "description": "Metal box by the school wall",
        "lat": "33.27", "lon": "35.20", "accuracy_m": "8",
        "photo": (__import__("io").BytesIO(JPEG), "p.jpg")},
        content_type="multipart/form-data")
    assert r.status_code == 201 and r.json["id"].startswith("CR-")
    mine = gw.get("/gw/v1/reports", headers=h).json["reports"]
    assert mine[0]["status"] == "received" and not mine[0]["delivered"]
    assert "description" not in mine[0]
    # Another citizen does not see it.
    other, _ = sign_in(gw, "71 999 888")
    assert gw.get("/gw/v1/reports", headers=other).json["reports"] == []


def test_report_validation(gw):
    h, _ = sign_in(gw)
    post = lambda **b: gw.post("/gw/v1/reports", headers=h, json=b)
    assert post().status_code == 400                                  # nothing to report
    assert post(description="x", category="weapons").status_code == 400
    assert post(description="x", lat=48.8, lon=2.3).status_code == 400  # not Lebanon
    assert post(description="x", lat=33.3).status_code == 400
    assert post(description="x" * 2001).status_code == 400
    r = gw.post("/gw/v1/reports", headers=h, data={
        "description": "x", "photo": (__import__("io").BytesIO(b"GIF89a..."), "p.gif")},
        content_type="multipart/form-data")
    assert r.status_code == 400 and "JPEG" in r.json["error"]
    assert gw.post("/gw/v1/reports", json={"description": "x"}).status_code == 401


def test_daily_report_limit(gw):
    h, _ = sign_in(gw)
    for _ in range(10):
        assert gw.post("/gw/v1/reports", headers=h, json={"description": "x"}).status_code == 201
    assert gw.post("/gw/v1/reports", headers=h, json={"description": "x"}).status_code == 429


def test_public_pages_need_no_sign_in(gw):
    s = gw.get("/gw/v1/safety").json
    assert s["status"] == "placeholder" and set(s["steps"]) == {"ar", "en", "fr"}
    assert gw.get("/gw/v1/warnings").json["warnings"] == []


def test_sync_needs_the_key(gw):
    assert gw.get("/gw/v1/sync/reports").status_code == 403
    assert gw.get("/gw/v1/sync/reports", headers={"X-Sync-Key": "nope"}).status_code == 403


def test_delete_account_keeps_report_without_phone(gw):
    h, _ = sign_in(gw)
    gw.post("/gw/v1/reports", headers=h, json={"description": "box"})
    assert gw.delete("/gw/v1/me", headers=h).status_code == 200
    assert gw.get("/gw/v1/me", headers=h).status_code == 401
    rep = gw.get("/gw/v1/sync/reports", headers=SYNC).json["reports"][0]
    assert rep["reporter_phone"] is None and rep["reporter_ref"] == "deleted"


# -- end to end: gateway <-> internal server through sync_gateway ------------
def transport_for(gw):
    def call(method, path, payload=None):
        r = gw.open("/gw/v1/sync" + path, method=method, json=payload, headers=SYNC)
        assert r.status_code == 200, r.json
        return r.json
    return call


def test_sync_round_trip(gw, client):
    """client = internal server (fresh database), gw = public gateway."""
    import sync_gateway
    from linker import civil

    h, _ = sign_in(gw)
    rid = gw.post("/gw/v1/reports", headers=h, data={
        "description": "Wire across the track", "lat": "33.27", "lon": "35.20",
        "photo": (__import__("io").BytesIO(JPEG), "p.jpg")},
        content_type="multipart/form-data").json["id"]
    gw.post("/gw/v1/devices", headers=h, json={"push_token": "tok-1", "platform": "android"})

    t = transport_for(gw)
    out = sync_gateway.run_once(t)
    assert out["reports_pulled"] == 1
    held = civil.get_report(rid, with_photo=True)
    assert held["caza"] == "Sour" and held["photo"] == JPEG and held["mgrs"]
    assert held["reporter_phone"] == "+9613123456"
    assert held["observed_at"] is None
    # The gateway no longer holds the text, position or photo.
    assert gw.get("/gw/v1/sync/reports", headers=SYNC).json["reports"] == []
    import sqlite3
    row = sqlite3.connect(gw.application.extensions["sirens_gw"]["db"]).execute(
        "SELECT description, lat, photo, reporter_phone FROM reports").fetchone()
    assert row == ("", None, None, None)
    assert gw.get("/gw/v1/reports", headers=h).json["reports"][0]["delivered"]

    # A commander reviews it; a warning is published; the next sync carries both.
    civil.set_status(rid, "under_review", by="cmd")
    exp = (datetime.now(timezone.utc) + timedelta(hours=3)).isoformat()
    civil.create_warning("Sour", "danger", {"en": "Avoid the track"},
                         {"en": "Keep away until further notice."}, exp, by="cmd")
    out = sync_gateway.run_once(t)
    assert out == {"reports_pulled": 0, "statuses_sent": 1, "warnings_sent": 1}
    assert gw.get("/gw/v1/reports", headers=h).json["reports"][0]["status"] == "under_review"
    ws = gw.get("/gw/v1/warnings").json["warnings"]
    assert ws[0]["title"]["en"] == "Avoid the track" and "created_by" not in ws[0]
    assert gw.push.calls == [["tok-1"]]
    assert civil.unsynced_statuses() == []

    # Nothing changed: no second push, nothing re-sent.
    assert sync_gateway.run_once(t)["statuses_sent"] == 0
    assert gw.push.calls == [["tok-1"]]


def test_retry_with_client_ref_does_not_duplicate(gw):
    h, _ = sign_in(gw)
    body = {"description": "box", "client_ref": "c2f1-uuid"}
    first = gw.post("/gw/v1/reports", headers=h, json=body)
    again = gw.post("/gw/v1/reports", headers=h, json=body)
    assert first.status_code == 201 and again.status_code == 200
    assert first.json["id"] == again.json["id"]
    assert len(gw.get("/gw/v1/reports", headers=h).json["reports"]) == 1
    # Another citizen may happen to use the same reference.
    other, _ = sign_in(gw, "71 999 888")
    assert gw.post("/gw/v1/reports", headers=other, json=body).status_code == 201


def test_observed_at_is_kept_and_checked(gw):
    h, _ = sign_in(gw)
    seen = (datetime.now(timezone.utc) - timedelta(hours=3)).isoformat()
    assert gw.post("/gw/v1/reports", headers=h,
                   json={"description": "x", "observed_at": seen}).status_code == 201
    rep = gw.get("/gw/v1/sync/reports", headers=SYNC).json["reports"][0]
    assert rep["observed_at"][:13] == seen[:13]
    future = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()
    for bad in (future, "2020-01-01T00:00:00", "yesterday"):
        assert gw.post("/gw/v1/reports", headers=h,
                       json={"description": "x", "observed_at": bad}).status_code == 400


def test_old_gateway_database_is_upgraded(tmp_path):
    import sqlite3
    db = tmp_path / "old.db"
    with sqlite3.connect(db) as c:
        c.execute("""CREATE TABLE reports (id TEXT PRIMARY KEY, citizen_id INTEGER,
            reporter_phone TEXT, submitted_at TEXT NOT NULL, category TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '', lat REAL, lon REAL, accuracy_m REAL,
            photo BLOB, photo_type TEXT, status TEXT NOT NULL DEFAULT 'received',
            status_at TEXT, collected INTEGER NOT NULL DEFAULT 0)""")
    create_app(db_path=db, sync_key=KEY, dev=True)
    cols = {r[1] for r in sqlite3.connect(db).execute("PRAGMA table_info(reports)")}
    assert {"client_ref", "observed_at"} <= cols


def test_app_bundles_the_same_safety_text():
    """mobile/assets/safety_fallback.json is what the app shows with no
    connection at all; it must match what the gateway serves."""
    import json
    import pathlib
    root = pathlib.Path(__file__).resolve().parents[1]
    served = json.loads((root / "gateway" / "safety.json").read_text(encoding="utf-8"))
    bundled = json.loads((root / "mobile" / "assets" / "safety_fallback.json")
                         .read_text(encoding="utf-8"))
    assert bundled == served, ("copy gateway/safety.json to "
                               "mobile/assets/safety_fallback.json")
