from linker.ingest import load_incidents
from linker.extract import FeatureExtractor
from linker import store

ROOT = pathlib.Path(__file__).resolve().parent
TAXONOMY = ROOT / "data" / "taxonomy" / "cied_lexicon.json"
SRC = ROOT / "data" / "generated_large" / "incidents.json"

store.clear()  # drop the 14 old samples; comment out to keep them
ex = FeatureExtractor(TAXONOMY, use_ner=True)

incs = load_incidents(SRC)
print(f"loaded {len(incs)} raw incidents")

enriched = ex.extract_all(incs)
with_feats = sum(1 for i in enriched if i.features)
print(f"features populated on {with_feats}/{len(enriched)} incidents")

store.add_incidents(enriched)
print("store now holds:", store.count())
