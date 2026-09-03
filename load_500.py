"""Load the generated 500-incident set into the Sirens store, WITH extraction."""
import pathlib
from linker.ingest import load_incidents
from linker.extract import FeatureExtractor
from linker import store

ROOT = pathlib.Path(__file__).resolve().parent
TAXONOMY = ROOT / "data" / "taxonomy" / "cied_lexicon.json"
SRC = ROOT / "data" / "generated_large" / "incidents.json"

# Optional: start clean so the old sample INC-0xx set doesn't mix in.
# Comment out to keep existing incidents.
store.clear()

ex = FeatureExtractor(TAXONOMY, use_ner=True)
incs = load_incidents(SRC)
print(f"loaded {len(incs)} raw incidents")

def enrich(inc):
    for name in ("extract", "annotate", "process", "__call__"):
        fn = getattr(ex, name, None)
        if callable(fn):
            out = fn(inc)
            return out if out is not None else inc
    raise SystemExit("No extractor method found — paste linker/extract.py and I'll fix this line.")

enriched = [enrich(i) for i in incs]
with_feats = sum(1 for i in enriched if getattr(i, "features", None))
print(f"extracted features on {with_feats}/{len(enriched)} incidents")

n = store.add_incidents(enriched)
print(f"saved {n} -> {store.DEFAULT_DB}")
print("store now holds:", store.count())