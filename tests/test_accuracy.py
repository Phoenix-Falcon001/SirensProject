"""Accuracy guard: fails if linking gets worse on the bundled synthetic set,
and checks that a place name is never read as a person or group."""
import pathlib

import pytest

from linker.extract import FeatureExtractor
from linker.match import LINK_THRESHOLD, Matcher
from linker.models import Incident

ROOT = pathlib.Path(__file__).resolve().parents[1]
TAXONOMY = ROOT / "data" / "taxonomy" / "cied_lexicon.json"


@pytest.fixture(scope="module")
def extractor():
    return FeatureExtractor(TAXONOMY, use_ner=True, known_places={"Khiam", "Marjaayoun"})


def test_f1_does_not_regress():
    """Measured 0.811 (precision 0.754, recall 0.878) on data/generated at the
    shared threshold. Synthetic data only; not a claim about real reports."""
    import evaluate
    r = evaluate.evaluate(str(ROOT / "data" / "generated"), LINK_THRESHOLD, str(TAXONOMY), True)
    assert r["f1"] >= 0.78, r
    assert r["precision"] >= 0.72, r
    assert r["recall"] >= 0.84, r


def test_link_threshold_is_the_measured_one():
    assert LINK_THRESHOLD == 0.35


def _extract(extractor, text, location=None):
    return extractor.extract(Incident(incident_id="T", narrative=text, location=location))


def test_village_name_is_not_a_person(extractor):
    inc = _extract(extractor, "On 13 an IED targeted a patrol near Meiss ej-Jabal. A pressure plate was found.",
                   location="Meiss ej-Jabal")
    assert not any("meiss" in p.lower() for p in inc.persons | inc.groups), (inc.persons, inc.groups)


def test_known_places_and_place_words_are_not_people(extractor):
    inc = _extract(extractor, "The device was found outside Khiam, on the road towards Marjaayoun.")
    assert not inc.persons and not ({"Khiam", "Marjaayoun"} & inc.groups)


def test_real_names_and_phones_are_kept(extractor):
    inc = _extract(extractor, "The convoy was reported by Hassan Darwish, who called from +961 70 123 456 near Khiam.",
                   location="Khiam")
    assert any("Darwish" in p for p in inc.persons), inc.persons
    assert inc.phones


def test_two_reports_from_one_village_do_not_share_a_person(extractor):
    a = _extract(extractor, "On 13 an IED targeted a resupply patrol near Meiss ej-Jabal. A pressure plate.",
                 "Meiss ej-Jabal")
    a.incident_id = "A"
    b = _extract(extractor, "On 18 an IED was located near Meiss ej-Jabal. A radio control.", "Meiss ej-Jabal")
    b.incident_id = "B"
    link = Matcher().fit([a, b]).score(a, b)
    assert not any(e.startswith("person:") for e in link.shared_entities), link.shared_entities
