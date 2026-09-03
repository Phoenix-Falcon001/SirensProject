# Sirens — C-IED Incident Link Analysis

Ingests incident reports, pulls out the descriptive features analysts already
write down (initiation method, trigger, emplacement, container, TTP), and
shows which reports look like they belong to the same builder or network. This
is the "these six strikes look like the same guy" judgement C-IED cells make
by hand — done consistently, on paper, in seconds.

Runs fully offline. Every link shown comes with a reason: which shared
features and identities produced it.

## Quickstart

```bash
bash setup.sh
source .venv/bin/activate
python sirens.py
```

Windows: `python -m venv .venv`, `.venv\Scripts\activate`, install with the
two `pip install` lines below, then `python sirens.py`.

## Scope

Defensive analytical tool. It works on *incident reporting* — after-action
descriptions of things that already happened. The taxonomy is descriptive
categories only (initiation method, trigger type, emplacement, container,
TTP labels). No construction, formulation, or quantity information anywhere
in the tool. All bundled data is fabricated.

## Pipeline

- `ingest.py` — reads JSON or free-text `.txt` reports.
- `extract.py` — a taxonomy gazetteer maps surface wording to canonical
  features (`command-wire` / `hard wire` / `CW` → `trigger=command_wire`),
  spaCy NER pulls persons/groups/places, regex pulls phone numbers and grids.
- `match.py` — scores every pair. Rare shared features count more than
  common ones. A shared phone number or named individual is a strong link on
  its own. Every link keeps its reasons.
- `cluster.py` — builds a graph, groups connected incidents, and computes
  each cluster's common signature.
- `report.py` — console summary, PNG link chart, and a self-contained HTML
  link chart.

## Install

```bash
pip install -r requirements.txt
pip install https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl
```

## Use

```bash
python cli.py data/sample_incidents/
python cli.py data/sample_incidents/ --html link_chart.html
python cli.py data/sample_incidents/ --png link_chart.png --json result.json
python cli.py data/sample_incidents/ --threshold 0.30 --no-ner
```

Input JSON is a list of `{id, date, location, grid, narrative}` objects. A
`.txt` file is treated as one narrative, filename as id.

```python
from linker import load_incidents, FeatureExtractor, Matcher, Clusterer
incs = load_incidents("data/sample_incidents/")
FeatureExtractor("data/taxonomy/cied_lexicon.json").extract_all(incs)
links = Matcher().fit(incs).all_pairs(incs, threshold=0.25)
clusters = Clusterer(incs, links).clusters()
```

## Test

```bash
python -m pytest tests/ -q
```

## Pre-arrival brief

Answers a different question: "what does the record say about this place and
this object?" — so a specialist arrives already knowing what's turned up
there before.

```bash
python cli.py brief data/sample_incidents/ \
    --location "Route Copper" \
    --describe "small green fin-stabilised rocket, intact, nose fuze fitted, about 1 m" \
    --photo responder_snap.jpg
```

Returns, from past reporting only: object types seen in that area, the device
signature that tends to show up there, and the closest past records to the
description, each with its source incident and any reference photo on file.

The brief retrieves and ranks past reporting. It does not identify what's in
front of the responder, does not analyse the responder's photo (it's just
attached for the specialist), and gives no handling or render-safe guidance.
A qualified specialist confirms every identification — that boundary is what
keeps this a linkage tool and not something in the operator's lane.

## Generating data & measuring accuracy

```bash
python generate_incidents.py --n 100 --networks 5 --out data/generated --seed 7
python evaluate.py --data data/generated --sweep
```

`generate_incidents.py` writes `incidents.json` (fabricated, deliberately
messy reports in real South Lebanon place names, with wording variants,
partial reports, dropped fields) and `ground_truth.json` (which network each
incident actually belongs to, or NOISE). `evaluate.py` scores the pipeline's
clustering against that key with pairwise precision/recall/F1.

Clustering defaults to community detection (Louvain, weight-aware) —
connected-components clustering fuses two real networks the moment one weak
bridge link shows up. Pass `method="components"` for the simpler behaviour on
small sets.

**Current measured accuracy** (100-incident synthetic set, seed 7): best F1
0.736 at threshold 0.25 (precision 0.628, recall 0.888). Clusters correctly
identify a dominant true network at 67–86% purity each. Two fixes got it
here from an earlier, genuinely broken state (F1 ~0.67 with *no* dominant
network per cluster — everything blended into one blob):

1. `match.py` was scoring on decorative descriptors (colour, shape, size,
   condition) alongside real behavioural facets. With only a handful of
   possible values per decorative facet, unrelated incidents coincidentally
   shared them often, producing false "shared signature" links. Only
   `initiation`, `trigger`, `emplacement`, `container`, `charge_label`,
   `ttp`, and `object_type` now count as link evidence
   (`SIGNATURE_FACETS`).
2. Jaccard similarity is unreliable on very small feature sets — an incident
   with only one extracted signature facet gave any other incident sharing
   that one facet a near-perfect score. `MIN_SHARED_SIGNATURE_FACETS = 2`
   in `match.py` now requires at least two independently shared facets
   before feature similarity contributes to the score at all.

Remaining precision loss (~37% of predicted links still false) is mostly
noise incidents coincidentally sharing 2+ facets by chance, plus some
cross-network bleed. This is likely partly an artifact of the synthetic
generator's small controlled vocabulary (4 initiation types, 5 trigger
types, etc.) — real field reporting has more natural variation and may not
hit this ceiling as hard. Not yet verified against real data.

## Extending

- **Taxonomy** — add facets/aliases in `data/taxonomy/cied_lexicon.json`, no
  code changes needed.
- **Weights** — tune `Matcher(w_features=…, w_location=…, entity_bonus=…)`
  for how much you trust signature vs. identity vs. geography.
- **New identity types** — email, callsign, vehicle-plate detectors slot into
  `extract.py` and become new strong-link entities in `match.py`.
- **Structure** — swap connected-components for community detection to split
  large loose clusters.

## Known limitations

- Extraction is only as good as the taxonomy + base NER model — every link is
  a lead for a human analyst, not a conclusion.
- English only, single language model (`en_core_web_sm`).
- Pairwise matching is O(n²) — fine for hundreds of incidents, needs
  blocking/indexing for very large corpora.
- Free-text location parsing is heuristic; explicit `location`/`grid` fields
  in JSON work better.

> Fabricated data only. Don't load real classified or personal data into a
> demo environment — run this inside your own controlled system.
