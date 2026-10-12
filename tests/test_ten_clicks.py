"""Scripted 10-click walk through the analyst workflow: zero server errors.

Each step is what one click in the browser sends (htmx clicks are plain
POSTs). Runs against a temporary database.
"""
import re

from linker import decisions


def test_ten_clicks_zero_server_errors(client):
    log = []

    def click(label, method, url, **data):
        r = client.get(url) if method == "GET" else client.post(url, data=data)
        log.append(f"{len(log) + 1:2}. {label:<28} {method} {url} -> {r.status_code}")
        assert r.status_code < 500, "\n".join(log)
        assert b"Traceback" not in r.data
        return r

    click("open console", "GET", "/")
    click("nav: demo data", "GET", "/demo")
    click("Load demo data", "POST", "/seed")
    html = click("nav: review links", "GET", "/review").data.decode()
    a, b = re.search(r'name="a" value="([^"]+)"><input type="hidden" name="b" value="([^"]+)"', html).groups()
    click("Confirm", "POST", "/review/decide", a=a, b=b, decision="confirm", analyst="BE")
    click("Reject (change mind)", "POST", "/review/decide", a=a, b=b, decision="reject", analyst="BE")
    click("Undo", "POST", "/review/decide", a=a, b=b, decision="undo", analyst="BE")
    click("Add note", "POST", "/review/note", a=a, b=b, note="Dates two months apart.", analyst="BE")
    click("filter: no decision", "GET", "/review?show=open")
    click("nav: link tree", "GET", "/tree")

    assert len(log) == 10
    assert decisions.current_decision(a, b) is None          # undone
    assert len(decisions.decision_history(a, b)) == 3          # history kept
    assert len(decisions.notes_for(a, b)) == 1
    print("\n".join(log))
