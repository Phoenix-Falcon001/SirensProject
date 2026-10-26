"""Military analysis over /api/v1: network, brief, links, dashboard, map.
Everything is limited to the user's regions."""
import pytest

from linker import accounts, decisions, store

PW = "correct-horse-1"


@pytest.fixture
def api(client, tmp_path):
    client.post("/seed")                      # the 40 fabricated demo incidents
    import app as sirens_app
    cazas = sirens_app._regions_of(store.all_incidents())
    counts = {}
    for c in cazas.values():
        counts[c] = counts.get(c, 0) + 1
    busiest = sorted((c for c in counts if c), key=lambda c: -counts[c])
    client.cazas, client.home, client.away = cazas, busiest[0], busiest[1]
    accounts.create_user("admin", PW, "admin")
    accounts.create_user("analyst", PW, "military", level="analyst", regions=[client.home])
    accounts.create_user("field", PW, "military", level="field", regions=[client.home])
    client.application.config["SIRENS_MAP_FILE"] = str(tmp_path / "lebanon.pmtiles")
    return client


def auth(c, user):
    r = c.post("/api/v1/auth/login", json={"username": user, "password": PW})
    return {"Authorization": "Bearer " + r.json["token"]}


def ids_in(c, caza):
    return {i for i, z in c.cazas.items() if z == caza}


def test_links_only_between_visible_incidents(api):
    mine = ids_in(api, api.home)
    rows = api.get("/api/v1/links", headers=auth(api, "analyst")).json
    assert rows["links"], "demo data should give links inside the busiest caza"
    for r in rows["links"]:
        assert r["a"]["id"] in mine and r["b"]["id"] in mine
        assert r["band"] in ("weak", "medium", "strong") and r["reasons"]
    every = api.get("/api/v1/links", headers=auth(api, "admin")).json["links"]
    assert len(every) > len(rows["links"])
    assert api.get("/api/v1/links", headers=auth(api, "field")).status_code == 403
    assert api.get("/api/v1/links?show=bogus", headers=auth(api, "admin")).status_code == 400


def test_decide_undo_and_note(api):
    h = auth(api, "analyst")
    link = api.get("/api/v1/links", headers=h).json["links"][0]
    pair = {"a": link["a"]["id"], "b": link["b"]["id"]}
    r = api.post("/api/v1/links/decision", headers=h, json={**pair, "decision": "confirm"})
    assert r.status_code == 200 and r.json["decision"] == "confirm"
    assert decisions.current_decision(pair["a"], pair["b"]) == "confirm"
    hist = decisions.decision_history(pair["a"], pair["b"])
    assert hist[-1]["analyst"] == "analyst"           # the account, not free text
    tally = api.get("/api/v1/links", headers=h).json["tally"]
    assert tally["confirm"] == 1
    opened = api.get("/api/v1/links?show=open", headers=h).json["links"]
    assert all(x["decision"] is None for x in opened)
    r = api.post("/api/v1/links/decision", headers=h, json={**pair, "decision": "undo"})
    assert r.json["decision"] is None
    r = api.post("/api/v1/links/note", headers=h, json={**pair, "note": "Same wiring style"})
    assert r.json["notes"][-1]["note"] == "Same wiring style"
    assert api.post("/api/v1/links/note", headers=h, json={**pair, "note": " "}).status_code == 400
    assert api.post("/api/v1/links/decision", headers=h,
                    json={**pair, "decision": "maybe"}).status_code == 400


def test_cannot_decide_on_links_outside_regions(api):
    away = sorted(ids_in(api, api.away))
    mine = sorted(ids_in(api, api.home))
    h = auth(api, "analyst")
    for a, b in ((away[0], away[1]), (mine[0], away[0])):
        r = api.post("/api/v1/links/decision", headers=h,
                     json={"a": a, "b": b, "decision": "reject"})
        assert r.status_code == 404
        assert api.post("/api/v1/links/note", headers=h,
                        json={"a": a, "b": b, "note": "x"}).status_code == 404


def test_network_of_an_incident(api):
    h = auth(api, "analyst")
    mine = ids_in(api, api.home)
    some = next(i for i in sorted(mine)
                if api.get(f"/api/v1/incidents/{i}/network", headers=h).json["links"])
    n = api.get(f"/api/v1/incidents/{some}/network", headers=h).json
    assert set(n["members"]) <= mine and some in n["members"]
    assert all(l["other"]["id"] in mine for l in n["links"])
    assert "never conclusions" in n["note"]
    away = next(iter(ids_in(api, api.away)))
    assert api.get(f"/api/v1/incidents/{away}/network", headers=h).status_code == 404


def test_filing_returns_network_and_retry_is_not_duplicated(api):
    h = auth(api, "field")
    body = {"narrative": "IED with a pressure plate and a tripwire near the road, "
                         "main charge homemade explosive.",
            "caza": api.home, "date": "2026-10-20", "client_ref": "phone-123"}
    first = api.post("/api/v1/incidents", headers=h, json=body)
    assert first.status_code == 201 and "network" in first.json
    again = api.post("/api/v1/incidents", headers=h, json=body)
    assert again.status_code == 200 and again.json["incident_id"] == first.json["incident_id"]
    assert again.json["duplicate"] is True
    # Another user's identical reference is a different report.
    other = auth(api, "analyst")
    assert api.post("/api/v1/incidents", headers=other, json=body).status_code == 201


def test_brief_is_region_limited(api):
    h = auth(api, "field")
    inc = store.get_incident(sorted(ids_in(api, api.home))[0])
    place = inc.location.split(",")[0]
    r = api.get("/api/v1/brief", headers=h,
                query_string={"location": place, "describe": "tripwire"})
    assert r.status_code == 200
    assert r.json["n_in_area"] >= 1
    assert all(i["caza"] == api.home for i in r.json["area_incidents"])
    assert "no handling guidance" in r.json["note"]
    away = store.get_incident(sorted(ids_in(api, api.away))[0]).location.split(",")[0]
    r = api.get("/api/v1/brief", headers=h, query_string={"location": away})
    assert r.json["n_in_area"] == 0                     # other regions are not searched
    assert api.get("/api/v1/brief", headers=h).status_code == 400


def test_dashboard_counts_only_own_regions(api):
    h = auth(api, "analyst")
    d = api.get("/api/v1/dashboard", headers=h).json
    assert d["total"] == len(ids_in(api, api.home))
    assert [x["caza"] for x in d["by_caza"]] == [api.home]
    assert sum(d["timeline"]["values"]) + d["timeline"]["undated"] == d["total"]
    assert {"bands", "review", "total"} <= set(d["links"])
    assert all("size" not in r for r in d["networks"]["rows"])
    admin = api.get("/api/v1/dashboard", headers=auth(api, "admin")).json
    assert admin["total"] == 40
    one = api.get("/api/v1/dashboard", headers=auth(api, "admin"),
                  query_string={"caza": api.away}).json
    assert one["total"] == len(ids_in(api, api.away))
    assert api.get("/api/v1/dashboard", headers=auth(api, "field")).status_code == 403
    assert api.get("/api/v1/dashboard?from=2026/01/01", headers=h).status_code == 400


def test_map_markers_and_download(api, tmp_path):
    h = auth(api, "field")
    m = api.get("/api/v1/map/markers", headers=h).json
    assert m["markers"] and all(x["caza"] == api.home for x in m["markers"])
    assert all(x["mgrs"][:3] in ("36S", "37S") for x in m["markers"])
    info = api.get("/api/v1/map/info", headers=h).json
    assert info["available"] is False
    assert api.get("/api/v1/map/lebanon.pmtiles", headers=h).status_code == 404
    (tmp_path / "lebanon.pmtiles").write_bytes(b"PMTiles" + bytes(range(256)) * 4)
    info = api.get("/api/v1/map/info", headers=h).json
    assert info["available"] and info["size"] == 7 + 1024
    part = api.get("/api/v1/map/lebanon.pmtiles", headers={**h, "Range": "bytes=0-6"})
    assert part.status_code == 206 and part.data == b"PMTiles"   # resumable download
    assert api.get("/api/v1/map/lebanon.pmtiles").status_code == 401
