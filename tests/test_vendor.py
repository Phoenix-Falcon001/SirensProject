"""Front-end libraries are served locally and no page pulls anything from the internet.

This checks the files and templates. The true "network off" check is opening
/vendor-check in a browser with Wi-Fi turned off.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
SKIP_DIRS = {".git", ".venv", "venv", "_attic", "tests", "__pycache__", "vendor"}
# <script src="http(s)://..."> or <link href="//...">: external code or stylesheets.
EXTERNAL = re.compile(r"<(script|link)\b[^>]*\b(src|href)\s*=\s*[\"']?(https?:)?//", re.I)


def test_vendor_files_are_served(client):
    for name in ("htmx.min.js", "chart.umd.js"):
        r = client.get(f"/static/vendor/{name}")
        assert r.status_code == 200, name
        assert len(r.data) > 10_000, name
        r.close()


def test_vendor_check_page_uses_local_files(client):
    r = client.get("/vendor-check")
    assert r.status_code == 200
    html = r.data.decode()
    assert "/static/vendor/htmx.min.js" in html
    assert "/static/vendor/chart.umd.js" in html
    assert 'hx-get="/vendor-check/ping"' in html


def test_htmx_fragment_route(client):
    r = client.get("/vendor-check/ping")
    assert r.status_code == 200
    assert b"htmx swap works" in r.data


def test_no_template_loads_external_script_or_stylesheet():
    offenders = []
    for path in ROOT.rglob("*"):
        if path.suffix not in {".py", ".html", ".htm"} or SKIP_DIRS & set(path.relative_to(ROOT).parts):
            continue
        for n, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
            if EXTERNAL.search(line):
                offenders.append(f"{path.relative_to(ROOT)}:{n}")
    assert not offenders, "external script/stylesheet sources: " + ", ".join(offenders)
