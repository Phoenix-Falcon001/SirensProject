"""Shared pytest fixtures.

`client` gives a Flask test client whose database, photo folder and metadata
file all live in a fresh temporary folder, so tests never touch data/sirens.db.
"""
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


@pytest.fixture
def client(tmp_path, monkeypatch):
    from linker import store
    monkeypatch.setattr(store, "DEFAULT_DB", tmp_path / "test.db")
    import app as sirens_app
    monkeypatch.setattr(sirens_app, "PHOTOS_DIR", tmp_path / "photos")
    monkeypatch.setattr(sirens_app, "META_FILE", tmp_path / "report_meta.json")
    sirens_app.app.config["TESTING"] = True
    return sirens_app.app.test_client()
