"""Decisions and notes survive an app restart.

Each step runs in its own Python process (a real restart: nothing kept in
memory), against the same temporary database file, never data/sirens.db.
"""
import pathlib
import subprocess
import sys
import textwrap

ROOT = pathlib.Path(__file__).resolve().parents[1]

_PRELUDE = textwrap.dedent(f"""
    import pathlib, re, sys
    sys.path.insert(0, {str(ROOT)!r})
    from linker import store
    store.DEFAULT_DB = pathlib.Path(sys.argv[1])
    import app as A
    A.PHOTOS_DIR = store.DEFAULT_DB.parent / "photos"
    A.META_FILE = store.DEFAULT_DB.parent / "meta.json"
    c = A.app.test_client()
""")

_FIRST_RUN = _PRELUDE + textwrap.dedent("""
    assert c.post("/seed").status_code == 302
    html = c.get("/review").data.decode()
    a, b = re.search(r'name="a" value="([^"]+)"><input type="hidden" name="b" value="([^"]+)"', html).groups()
    assert c.post("/review/decide", data={"a": a, "b": b, "decision": "reject", "analyst": "BE"}).status_code == 200
    assert c.post("/review/note", data={"a": a, "b": b, "note": "Kept after restart?"}).status_code == 200
    print(a, b)
""")

_SECOND_RUN = _PRELUDE + textwrap.dedent("""
    from linker import decisions
    a, b = sys.argv[2], sys.argv[3]
    assert decisions.current_decision(a, b) == "reject"
    html = c.get("/review?show=reject").data.decode()
    assert html.count('<article class="link') == 1
    assert "is-reject" in html and "Kept after restart?" in html
    print("PERSISTED")
""")


def _run(code, *args):
    r = subprocess.run([sys.executable, "-c", code, *map(str, args)],
                       capture_output=True, text=True, timeout=300, cwd=ROOT)
    assert r.returncode == 0, r.stderr[-2000:]
    return r.stdout.strip().splitlines()[-1]


def test_decisions_and_notes_survive_restart(tmp_path):
    db = tmp_path / "restart.db"
    a, b = _run(_FIRST_RUN, db).split()
    assert _run(_SECOND_RUN, db, a, b) == "PERSISTED"
