"""Tests for the added product layers: database, semantic matching, web app.

These don't require an API key or the vector model — the semantic layer falls
back to lexical similarity, and the AI panel is simply skipped when no key is set.
"""
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from linker import store, semantic
from linker.models import Feature, Incident


@pytest.fixture
def tmp_db(tmp_path, monkeypatch):
    db = tmp_path / "test.db"
    monkeypatch.setattr(store, "DEFAULT_DB", db)
    return db


def _mk(id_, narrative, feats=()):
    inc = Incident(incident_id=id_, narrative=narrative)
    inc.features = [Feature(f, v, s) for (f, v, s) in feats]
    return inc


def test_store_roundtrip(tmp_db):
    inc = _mk("INC-001", "A buried device on Route Copper.",
              feats=[("trigger", "pressure_plate", "pressure plate")])
    inc.phones.add("0791-555-0182")
    store.add_incident(inc)
    assert store.count() == 1
    back = store.all_incidents()[0]
    assert back.incident_id == "INC-001"
    assert back.narrative == inc.narrative
    assert ("trigger", "pressure_plate") in back.feature_keys()
    assert "0791-555-0182" in back.phones


def test_store_upsert_and_next_id(tmp_db):
    store.add_incident(_mk("INC-001", "one"))
    store.add_incident(_mk("INC-001", "one edited"))  # same id -> update, not dup
    assert store.count() == 1
    store.add_incident(_mk("INC-004", "four"))
    assert store.next_incident_id() == "INC-005"


def test_store_clear(tmp_db):
    store.add_incident(_mk("INC-001", "x"))
    store.clear()
    assert store.count() == 0


def test_semantic_similarity_bounds():
    s = semantic.similarity("a buried IED on the road", "a device concealed in the road")
    assert 0.0 <= s <= 1.0
    # identical text is maximally similar
    assert semantic.similarity("same text here", "same text here") >= 0.9


def test_semantic_ranks_related_above_unrelated():
    a = "a buried victim operated IED struck a convoy on the road"
    related = "a concealed device detonated under a vehicle on the route"
    unrelated = "a green finned rocket was recovered intact by the market"
    assert semantic.similarity(a, related) > semantic.similarity(a, unrelated)


def test_web_app_analyse_returns_results(tmp_db):
    import app as web
    store.add_incident(_mk("INC-001",
        "buried pressure plate IED with pressure cooker on Route Copper"))
    client = web.app.test_client()
    r = client.post("/analyse", data={
        "incident_id": "INC-900",
        "narrative": "a concealed pressure plate device on the Copper route",
        "action": "analyse"})
    assert r.status_code == 200
    body = r.get_data(as_text=True)
    assert "Signature extracted" in body
    assert "INC-900" in body


def test_cli_import_and_db_share_one_store(tmp_db, capsys):
    """A report imported via the CLI and one saved elsewhere both land in the
    same database, and `cli db` analyses all of them — the single source of truth."""
    import types
    import cli
    samples = str(cli.pathlib.Path(cli.__file__).parent / "data" / "sample_incidents")

    rc = cli.cmd_import(types.SimpleNamespace(
        target=samples, taxonomy=str(cli.TAXONOMY), no_ner=False))
    assert rc == 0
    n = store.count()
    assert n >= 10

    rc = cli.cmd_db(types.SimpleNamespace(threshold=0.25, html=None, json=None))
    assert rc == 0
    assert "LINK ANALYSIS" in capsys.readouterr().out

    # simulate the web console saving a new report into the same store
    store.add_incident(_mk("INC-777",
        "command wire complex ambush secondary device, the Northern Cell"))
    assert store.count() == n + 1

    cli.cmd_db(types.SimpleNamespace(threshold=0.25, html=None, json=None))
    assert f"analysing {n + 1}" in capsys.readouterr().out


def test_cli_db_empty_is_graceful(tmp_db, capsys):
    import types
    import cli
    rc = cli.cmd_db(types.SimpleNamespace(threshold=0.25, html=None, json=None))
    assert rc == 2
    assert "empty" in capsys.readouterr().out.lower()


# --- photo upload: real file saved with the record and served back ----------
# The app files images by extension and round-trips raw bytes; it never decodes
# them, so a small deterministic byte string with a PNG header is enough here.
_PNG_1x1 = b"\x89PNG\r\n\x1a\n" + b"sirens-test-image-payload" * 4


def _mk_png():
    import io
    return (io.BytesIO(_PNG_1x1), "field_snap.png")


def test_photo_upload_saves_and_serves(tmp_db, tmp_path, monkeypatch):
    """Uploading an image on Save files it under a location-based name, records
    it on the incident, serves it back, and shows it beside a linked incident."""
    import app as web
    monkeypatch.setattr(web, "PHOTOS_DIR", tmp_path / "photos")
    (tmp_path / "photos").mkdir()

    client = web.app.test_client()

    # Save a first incident WITH a photo and a location.
    r = client.post("/analyse", data={
        "incident_id": "INC-001",
        "location": "Route Copper, Al-Fakir District",
        "narrative": "buried pressure plate IED with pressure cooker on Route Copper",
        "action": "save",
        "photo_file": _mk_png(),
    }, content_type="multipart/form-data")
    assert r.status_code == 200

    # The file is named for the place it was found, and the DB row records it.
    assert (tmp_path / "photos" / "route-copper-01.png").exists()
    assert store.get_incident("INC-001").photo == "route-copper-01.png"

    # It is served back over HTTP.
    served = client.get("/photos/route-copper-01.png")
    assert served.status_code == 200
    assert served.data == _PNG_1x1

    # A new related report links to INC-001 and the page shows its thumbnail.
    r2 = client.post("/analyse", data={
        "incident_id": "INC-900",
        "narrative": "a concealed pressure plate device on the Copper route",
        "action": "analyse",
    }, content_type="multipart/form-data")
    body = r2.get_data(as_text=True)
    assert "/photos/route-copper-01.png" in body    # matched incident's photo shown


def test_photo_names_number_up_per_city(tmp_db, tmp_path, monkeypatch):
    """A second photo from the same city gets the next sequence number."""
    import app as web
    monkeypatch.setattr(web, "PHOTOS_DIR", tmp_path / "photos")
    (tmp_path / "photos").mkdir()
    client = web.app.test_client()
    for i in (1, 2):
        client.post("/analyse", data={
            "incident_id": f"INC-00{i}", "location": "Beirut",
            "narrative": f"device number {i} found in Beirut", "action": "save",
            "photo_file": _mk_png(),
        }, content_type="multipart/form-data")
    assert (tmp_path / "photos" / "beirut-01.png").exists()
    assert (tmp_path / "photos" / "beirut-02.png").exists()
    assert store.get_incident("INC-002").photo == "beirut-02.png"


def test_photo_fallback_when_no_location(tmp_db, tmp_path, monkeypatch):
    """No location given => a neutral 'site' slug, still descriptive not random."""
    import app as web
    monkeypatch.setattr(web, "PHOTOS_DIR", tmp_path / "photos")
    (tmp_path / "photos").mkdir()
    client = web.app.test_client()
    client.post("/analyse", data={
        "incident_id": "INC-001", "narrative": "a device with no location noted",
        "action": "save", "photo_file": _mk_png(),
    }, content_type="multipart/form-data")
    assert store.get_incident("INC-001").photo == "site-01.png"


def test_reupload_replaces_previous_photo(tmp_db, tmp_path, monkeypatch):
    """Re-uploading for the same incident removes its old file (one per record)."""
    import io
    import app as web
    monkeypatch.setattr(web, "PHOTOS_DIR", tmp_path / "photos")
    (tmp_path / "photos").mkdir()
    client = web.app.test_client()
    client.post("/analyse", data={
        "incident_id": "INC-001", "location": "Tyre",
        "narrative": "first photo", "action": "save", "photo_file": _mk_png(),
    }, content_type="multipart/form-data")
    assert (tmp_path / "photos" / "tyre-01.png").exists()
    # second upload for the SAME incident
    client.post("/analyse", data={
        "incident_id": "INC-001", "location": "Tyre",
        "narrative": "replacement photo", "action": "save",
        "photo_file": (io.BytesIO(_PNG_1x1), "new.png"),
    }, content_type="multipart/form-data")
    files = sorted(p.name for p in (tmp_path / "photos").glob("*"))
    assert files == ["tyre-01.png"]                # old one gone, slot reused, one file
    assert store.get_incident("INC-001").photo == "tyre-01.png"


def test_analyse_without_photo_still_works(tmp_db, tmp_path, monkeypatch):
    """No upload => no photo, no error (guards the common path)."""
    import app as web
    monkeypatch.setattr(web, "PHOTOS_DIR", tmp_path / "photos")
    (tmp_path / "photos").mkdir()
    client = web.app.test_client()
    r = client.post("/analyse", data={
        "incident_id": "INC-010",
        "narrative": "a command wire ambush near the bridge",
        "action": "analyse",
    }, content_type="multipart/form-data")
    assert r.status_code == 200
    assert "Signature extracted" in r.get_data(as_text=True)


def test_rejects_non_image_upload(tmp_db, tmp_path, monkeypatch):
    """A non-image upload is ignored, not filed."""
    import io
    import app as web
    monkeypatch.setattr(web, "PHOTOS_DIR", tmp_path / "photos")
    (tmp_path / "photos").mkdir()
    client = web.app.test_client()
    client.post("/analyse", data={
        "incident_id": "INC-020",
        "narrative": "a device on the road",
        "action": "save",
        "photo_file": (io.BytesIO(b"not an image"), "malware.exe"),
    }, content_type="multipart/form-data")
    assert list((tmp_path / "photos").glob("*")) == []
    assert store.get_incident("INC-020").photo is None


# --- munitions reference library (public, category-level recognition) --------
def test_reference_lookup_and_guardrails():
    from linker import reference
    from linker.models import Feature, Incident
    e = reference.get("mortar_round")
    assert e and e["label"].startswith("Mortar round") and e["object_type"] == "mortar_round"
    assert e["responder_note"]                      # every entry carries a safety note
    assert reference.get(None) is None
    assert reference.get("does_not_exist") is None
    # disclaimer states the identification / handling boundary
    d = reference.disclaimer().lower()
    assert "not identification" in d and ("handling" in d or "eod" in d)


def test_reference_types_in_incident_dedup():
    from linker import reference
    from linker.models import Feature, Incident
    inc = Incident(incident_id="T", narrative="x")
    inc.features = [Feature("object_type", "mortar_round", "120mm mortar"),
                    Feature("object_type", "mortar_round", "mortar"),   # dup
                    Feature("colour", "green", "green")]
    entries = reference.types_in(inc)
    assert [e["object_type"] for e in entries] == ["mortar_round"]        # once only


def test_reference_panel_on_index(tmp_db):
    import app as web
    body = web.app.test_client().get("/").get_data(as_text=True)
    assert "Munitions reference" in body
    assert "Mortar round" in body                   # populated the picker
    assert "not identification" in body.lower()     # disclaimer shown


def test_reference_shows_in_report(tmp_db):
    import app as web
    r = web.app.test_client().post("/analyse", data={
        "incident_id": "INC-050",
        "narrative": "An unexploded 120mm mortar round was found beside the road.",
        "action": "analyse"}, content_type="multipart/form-data")
    body = r.get_data(as_text=True)
    assert "Type reference" in body                 # section rendered
    assert "Mortar round" in body                   # the recognised type's card
    assert "Responder note" in body                 # safety note present
