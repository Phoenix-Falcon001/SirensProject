"""Link review page: decisions and notes on every link, swapped in place (temp DB)."""
import re

from linker import decisions, store


def _seed_and_first_pair(client):
    client.post("/seed")
    html = client.get("/review").data.decode()
    a, b = re.search(r'name="a" value="([^"]+)"><input type="hidden" name="b" value="([^"]+)"', html).groups()
    return html, a, b


def test_every_tree_link_has_decision_buttons(client):
    from linker.match import Matcher
    html, _, _ = _seed_and_first_pair(client)
    incs = store.all_incidents()
    n_links = len(Matcher().fit(incs).all_pairs(incs, threshold=0.25))
    assert n_links > 0
    assert html.count('<article class="link') == n_links
    for d in ("confirm", "reject", "unsure"):
        assert html.count(f'"decision": "{d}"') == n_links
    assert "/static/vendor/htmx.min.js" in html


def test_decide_returns_only_the_card_not_a_page(client):
    _, a, b = _seed_and_first_pair(client)
    r = client.post("/review/decide", data={"a": a, "b": b, "decision": "confirm", "analyst": "BE"})
    assert r.status_code == 200
    body = r.data.decode()
    assert "<html" not in body                       # a fragment: htmx swaps it, no reload
    assert "is-confirm" in body and 'hx-swap-oob="true"' in body
    assert decisions.current_decision(a, b) == "confirm"


def test_change_undo_and_history_kept(client):
    _, a, b = _seed_and_first_pair(client)
    client.post("/review/decide", data={"a": a, "b": b, "decision": "reject"})
    client.post("/review/decide", data={"a": b, "b": a, "decision": "unsure"})
    assert decisions.current_decision(a, b) == "unsure"
    client.post("/review/decide", data={"a": a, "b": b, "decision": "undo"})
    assert decisions.current_decision(a, b) is None
    assert [h["decision"] for h in decisions.decision_history(a, b)] == ["reject", "unsure", "cleared"]


def test_note_is_saved_and_shown(client):
    _, a, b = _seed_and_first_pair(client)
    r = client.post("/review/note", data={"a": a, "b": b, "note": "Check the dates.", "analyst": "BE"})
    assert r.status_code == 200 and "Check the dates." in r.data.decode()
    assert decisions.notes_for(a, b)[0]["analyst"] == "BE"


def test_machine_scores_unchanged_by_decisions(client):
    html, a, b = _seed_and_first_pair(client)
    score = lambda h: re.search(r'<span class="score">([\d.]+)</span>', h).group(1)
    client.post("/review/decide", data={"a": a, "b": b, "decision": "reject"})
    assert score(client.get("/review").data.decode()) == score(html)


def test_bad_input_is_refused(client):
    _, a, b = _seed_and_first_pair(client)
    assert client.post("/review/decide", data={"a": a, "b": b, "decision": "maybe"}).status_code == 400
    assert client.post("/review/decide", data={"a": a, "b": a, "decision": "confirm"}).status_code == 400
    assert client.post("/review/decide", data={"a": "NOPE", "b": b, "decision": "confirm"}).status_code == 404
    assert client.post("/review/note", data={"a": a, "b": b, "note": "   "}).status_code == 400
    assert decisions.current_decisions() == {}


def test_filters(client):
    _, a, b = _seed_and_first_pair(client)
    client.post("/review/decide", data={"a": a, "b": b, "decision": "unsure"})
    count = lambda q: client.get(f"/review?show={q}").data.decode().count('<article class="link')
    assert count("unsure") == 1 and count("confirm") == 0
    assert count("open") == count("all") - 1


def test_empty_database_points_to_demo(client):
    r = client.get("/review")
    assert r.status_code == 200 and b'href="/demo"' in r.data


def test_console_links_to_review(client):
    assert b'href="/review"' in client.get("/").data
