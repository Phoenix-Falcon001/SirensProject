"""Demo mode loads the fabricated sample set (against a temporary database)."""
from linker import store


def test_demo_page_is_labelled_fabricated(client):
    r = client.get("/demo")
    assert r.status_code == 200
    html = r.data.decode()
    assert "fabricated" in html.lower()
    assert 'action="/seed"' in html
    assert "Incidents currently on record: 0" in html


def test_demo_button_loads_40_incidents(client):
    assert store.count() == 0
    r = client.post("/seed")          # what the demo button submits
    assert r.status_code == 302       # success: redirect back to the console
    assert store.count() == 40
    client.post("/seed")              # pressing it again adds no duplicates
    assert store.count() == 40
    assert "Incidents currently on record: 40" in client.get("/demo").data.decode()


def test_console_links_to_demo(client):
    assert b'href="/demo"' in client.get("/").data
