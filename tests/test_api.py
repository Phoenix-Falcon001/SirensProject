"""Mobile app interface on the internal server (/api/v1, api_bp.py)."""
from datetime import datetime, timedelta, timezone

import pytest

from linker import accounts, civil

PW = "correct-horse-1"


@pytest.fixture
def api(client):
    accounts.create_user("admin", PW, "admin")
    accounts.create_user("field_sour", PW, "military", level="field", regions=["Sour"])
    accounts.create_user("analyst_sour", PW, "military", level="analyst", regions=["Sour"])
    accounts.create_user("cmd_sour", PW, "military", level="commander", regions=["Sour"])
    accounts.create_user("cmd_beirut", PW, "military", level="commander", regions=["Beirut"])
    return client


def auth(client, user):
    r = client.post("/api/v1/auth/login", json={"username": user, "password": PW})
    assert r.status_code == 200, r.json
    return {"Authorization": "Bearer " + r.json["token"]}


def file(client, h, caza="Sour", **kw):
    body = {"narrative": "An IED with a pressure plate was found by the road.",
            "caza": caza, "date": "2026-10-20", **kw}
    return client.post("/api/v1/incidents", json=body, headers=h)


def test_everything_needs_sign_in(api):
    for path in ("/api/v1/me", "/api/v1/incidents", "/api/v1/meta", "/api/v1/warnings"):
        assert api.get(path).status_code == 401
    assert api.get("/api/v1/me", headers={"Authorization": "Bearer junk"}).status_code == 401


def test_bad_login(api):
    r = api.post("/api/v1/auth/login", json={"username": "admin", "password": "x"})
    assert r.status_code == 401 and "wrong" in r.json["error"]


def test_me_lists_permissions_from_the_server(api):
    me = api.get("/api/v1/me", headers=auth(api, "field_sour")).json
    assert me["level"] == "field" and me["regions"] == ["Sour"]
    assert "incidents:create" in me["permissions"] and "review" not in me["permissions"]
    assert "users:manage" in api.get("/api/v1/me", headers=auth(api, "admin")).json["permissions"]


def test_logout_ends_the_session(api):
    h = auth(api, "field_sour")
    assert api.post("/api/v1/auth/logout", headers=h).status_code == 200
    assert api.get("/api/v1/me", headers=h).status_code == 401


def test_file_report_in_own_region_only(api):
    h = auth(api, "field_sour")
    r = file(api, h, lat=33.27, lon=35.20)
    assert r.status_code == 201
    assert r.json["caza"] == "Sour" and r.json["mgrs"].startswith("36S")
    assert any(f.startswith("trigger=") for f in r.json["features"])
    assert file(api, h, caza="Beirut").status_code == 403
    assert file(api, h, caza="Nowhere").status_code == 400
    assert file(api, h, narrative="").status_code == 400
    assert file(api, h, date="20/10/2026").status_code == 400
    assert file(api, h, lat=48.8, lon=2.3).status_code == 400


def test_incidents_are_filtered_by_region(api):
    file(api, auth(api, "field_sour"))
    file(api, auth(api, "admin"), caza="Beirut")
    sour = api.get("/api/v1/incidents", headers=auth(api, "field_sour")).json["incidents"]
    assert [i["caza"] for i in sour] == ["Sour"]
    every = api.get("/api/v1/incidents", headers=auth(api, "admin")).json["incidents"]
    assert {i["caza"] for i in every} == {"Sour", "Beirut"}
    beirut_id = next(i["id"] for i in every if i["caza"] == "Beirut")
    # Outside the user's regions it looks exactly like a missing record.
    r = api.get(f"/api/v1/incidents/{beirut_id}", headers=auth(api, "field_sour"))
    assert r.status_code == 404
    assert api.get("/api/v1/incidents/INC-999", headers=auth(api, "field_sour")).status_code == 404
    assert api.get(f"/api/v1/incidents/{beirut_id}", headers=auth(api, "admin")).status_code == 200


def test_level_limits(api):
    h = auth(api, "field_sour")
    assert api.get("/api/v1/civil-reports", headers=h).status_code == 403
    assert api.get("/api/v1/admin/users", headers=h).status_code == 403
    assert api.get("/api/v1/civil-reports",
                   headers=auth(api, "analyst_sour")).status_code == 403
    assert api.get("/api/v1/civil-reports",
                   headers=auth(api, "cmd_sour")).status_code == 200
    assert api.get("/api/v1/admin/users",
                   headers=auth(api, "cmd_sour")).status_code == 403


def _civil(rid, lat, lon):
    civil.receive({"id": rid, "submitted_at": "2026-10-25T10:00:00+00:00",
                   "reporter_ref": 7, "reporter_phone": "+96170000000",
                   "category": "suspicious_object", "description": "bag by the road",
                   "lat": lat, "lon": lon, "photo": b"\xff\xd8\xff-jpeg",
                   "photo_type": "image/jpeg"})


def test_civil_reports_by_region_and_status(api):
    _civil("CR-SOUR", 33.27, 35.20)
    _civil("CR-BEY", 33.8938, 35.5018)
    h = auth(api, "cmd_sour")
    rows = api.get("/api/v1/civil-reports", headers=h).json["reports"]
    assert [r["id"] for r in rows] == ["CR-SOUR"]
    assert rows[0]["caza"] == "Sour" and rows[0]["has_photo"] and "photo" not in rows[0]
    assert api.get("/api/v1/civil-reports/CR-BEY", headers=h).status_code == 404
    photo = api.get("/api/v1/civil-reports/CR-SOUR/photo", headers=h)
    assert photo.status_code == 200 and photo.mimetype == "image/jpeg"
    r = api.patch("/api/v1/civil-reports/CR-SOUR", headers=h,
                  json={"status": "under_review", "note": "patrol sent"})
    assert r.json["status"] == "under_review" and r.json["status_by"] == "cmd_sour"
    assert api.patch("/api/v1/civil-reports/CR-SOUR", headers=h,
                     json={"status": "bogus"}).status_code == 400
    assert api.patch("/api/v1/civil-reports/CR-BEY", headers=h,
                     json={"status": "closed"}).status_code == 404
    assert civil.unsynced_statuses() == [{"id": "CR-SOUR", "status": "under_review"}]


def _future(hours=6):
    return (datetime.now(timezone.utc) + timedelta(hours=hours)).isoformat()


def test_warnings_publish_in_own_region(api):
    h = auth(api, "cmd_sour")
    w = {"caza": "Sour", "severity": "danger", "expires_at": _future(),
         "title": {"en": "Avoid the coast road", "ar": "تجنّب الطريق الساحلي"},
         "body": {"en": "Army operation in progress. Keep away."}}
    r = api.post("/api/v1/warnings", headers=h, json=w)
    assert r.status_code == 201 and r.json["title"]["ar"]
    assert api.post("/api/v1/warnings", headers=h,
                    json={**w, "caza": "Beirut"}).status_code == 403
    assert api.post("/api/v1/warnings", headers=h,
                    json={**w, "expires_at": "2000-01-01T00:00:00"}).status_code == 400
    assert api.post("/api/v1/warnings", headers=auth(api, "analyst_sour"),
                    json=w).status_code == 403
    # Other regions do not see it, and cannot withdraw it.
    other = auth(api, "cmd_beirut")
    assert api.get("/api/v1/warnings", headers=other).json["warnings"] == []
    wid = r.json["id"]
    assert api.post(f"/api/v1/warnings/{wid}/withdraw", headers=other).status_code == 404
    assert api.post(f"/api/v1/warnings/{wid}/withdraw", headers=h).json["withdrawn"]
    assert civil.public_warnings() == []


def test_admin_manages_users(api):
    h = auth(api, "admin")
    r = api.post("/api/v1/admin/users", headers=h, json={
        "username": "lt_nader", "password": "a-long-password", "role": "military",
        "level": "analyst", "regions": ["Saida", "Jezzine"]})
    assert r.status_code == 201 and r.json["regions"] == ["Jezzine", "Saida"]
    uid = r.json["id"]
    assert api.post("/api/v1/admin/users", headers=h, json={
        "username": "x", "password": "a-long-password", "role": "military",
        "level": "analyst", "regions": ["Atlantis"]}).status_code == 400
    r = api.patch(f"/api/v1/admin/users/{uid}", headers=h, json={"level": "commander"})
    assert r.json["level"] == "commander"
    r = api.patch(f"/api/v1/admin/users/{uid}", headers=h, json={"active": False})
    assert r.json["active"] is False
    me = api.get("/api/v1/me", headers=h).json
    assert api.patch(f"/api/v1/admin/users/{me['id']}", headers=h,
                     json={"active": False}).status_code == 400
    names = {u["username"] for u in api.get("/api/v1/admin/users", headers=h).json["users"]}
    assert "lt_nader" in names
    entries = api.get("/api/v1/admin/audit", headers=h).json["entries"]
    assert any(e["action"] == "user.update" for e in entries)


def test_change_own_password(api):
    h = auth(api, "field_sour")
    assert api.post("/api/v1/me/password", headers=h,
                    json={"current": "wrong", "new": "brand-new-pass"}).status_code == 400
    assert api.post("/api/v1/me/password", headers=h,
                    json={"current": PW, "new": "brand-new-pass"}).status_code == 200
    r = api.post("/api/v1/auth/login",
                 json={"username": "field_sour", "password": "brand-new-pass"})
    assert r.status_code == 200


def test_meta_and_no_caching(api):
    r = api.get("/api/v1/meta", headers=auth(api, "field_sour"))
    assert "Sour" in r.json["regions"] and r.json["levels"] == ["field", "analyst", "commander"]
    assert r.headers["Cache-Control"] == "no-store"
