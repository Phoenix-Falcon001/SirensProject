"""Dashboard: charts match the data and filters work (temporary database)."""
import json
import re


def _page(client, query=""):
    r = client.get("/dashboard" + query)
    assert r.status_code == 200
    html = r.data.decode()
    data = json.loads(re.search(r'<script id="dash-data" type="application/json">(.*?)</script>',
                                html, re.S).group(1))
    tiles = [int(x) for x in re.findall(r'<div class="v">(\d+)</div>', html)]
    return html, data, tiles


def test_empty_database_points_to_demo(client):
    r = client.get("/dashboard")
    assert r.status_code == 200 and b'href="/demo"' in r.data


def test_charts_add_up_to_the_incidents_in_view(client):
    client.post("/seed")
    html, d, tiles = _page(client)
    assert tiles[0] == 40
    assert sum(d["timeline"]["values"]) + d["timeline"]["undated"] == 40
    assert sum(d["area"]["values"]) == 40
    assert len(d["timeline"]["labels"]) >= 3                     # a real timeline
    assert "/static/vendor/chart.umd.js" in html
    for cid in ("c-timeline", "c-area", "c-init"):
        assert f'id="{cid}"' in html
    assert html.count("Show table") == 3                          # every chart has a table twin


def test_each_initiation_bar_matches_its_filter(client):
    client.post("/seed")
    _, d, _ = _page(client)
    for key, value in zip(d["initiation"]["keys"], d["initiation"]["values"]):
        assert _page(client, f"?initiation={key}")[2][0] == value, key


def test_area_and_date_filters(client):
    client.post("/seed")
    _, d, _ = _page(client)
    top_area, top_n = d["area"]["keys"][0], d["area"]["values"][0]
    _, fd, tiles = _page(client, f"?area={top_area}")
    assert tiles[0] == top_n and fd["area"]["labels"] == [top_area]
    _, _, all_tiles = _page(client)
    _, fd, tiles = _page(client, "?from=2026-04-01&to=2026-04-30")
    assert tiles[0] == sum(fd["timeline"]["values"]) and 0 < tiles[0] < 40
    assert fd["timeline"]["labels"] == ["Apr 2026"]
    assert tiles[2] <= all_tiles[2]                               # fewer incidents, fewer links


def test_bad_filter_values_are_ignored_not_errors(client):
    client.post("/seed")
    _, _, tiles = _page(client, "?from=notadate&to=2026-13-99x&area=Nowhere&initiation=%3Cscript%3E")
    assert tiles[0] == 40


def test_no_match_message(client):
    client.post("/seed")
    r = client.get("/dashboard?from=2030-01-01")
    assert r.status_code == 200 and b"No incidents match" in r.data


def test_confirmed_tile_counts_analyst_decisions(client):
    client.post("/seed")
    html = client.get("/review").data.decode()
    a, b = re.search(r'name="a" value="([^"]+)"><input type="hidden" name="b" value="([^"]+)"', html).groups()
    client.post("/review/decide", data={"a": a, "b": b, "decision": "confirm"})
    assert _page(client)[2][3] == 1


def test_console_links_to_dashboard(client):
    assert b'href="/dashboard"' in client.get("/").data
