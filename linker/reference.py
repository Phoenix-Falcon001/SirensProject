"""Munition reference library (recognition/cataloguing, public info only).

This layer answers a simple question — "when the tool recognises an object type,
what publicly-known, category-level facts should the analyst or first responder
see?" — WITHOUT crossing into positive identification or device-handling.

It is deliberately reference-grade, not operational:
  * Facts are general and public (calibre families, nominal ranges, ammunition
    *categories*, how a class is broadly employed) — the sort of information in
    Wikipedia or the Open Source Munitions Portal.
  * It contains NO fuzing/arming detail, NO render-safe or defeat procedure,
    NO emplacement or firing instructions. Every entry carries a do-not-approach
    responder note and the library carries an identification/handling disclaimer.

The keys are the taxonomy's own ``object_type`` values, so anything the
extractor recognises can be looked up directly.
"""
from __future__ import annotations

import json
import pathlib
from functools import lru_cache

DEFAULT_PATH = (pathlib.Path(__file__).resolve().parent.parent
                / "data" / "reference" / "munition_reference.json")


@lru_cache(maxsize=4)
def _load(path: str | None = None) -> dict:
    p = pathlib.Path(path or DEFAULT_PATH)
    return json.loads(p.read_text(encoding="utf-8"))


def disclaimer(path: str | None = None) -> str:
    """The library-wide identification/handling disclaimer."""
    return _load(path).get(
        "_disclaimer",
        "General public reference for recognition only — not identification or "
        "device-handling guidance. Do not approach; contact EOD.",
    )


def get(object_type: str | None, path: str | None = None) -> dict | None:
    """Return the reference entry for a taxonomy object_type value, or None.

    The returned dict is a shallow copy with the object_type key added, so
    callers can render it without reaching back into the file.
    """
    if not object_type:
        return None
    entry = _load(path).get("entries", {}).get(object_type)
    if not entry:
        return None
    out = dict(entry)
    out["object_type"] = object_type
    return out


def all_entries(path: str | None = None) -> list[dict]:
    """Every entry, each tagged with its object_type, sorted by label."""
    entries = _load(path).get("entries", {})
    out = [dict(v, object_type=k) for k, v in entries.items()]
    out.sort(key=lambda e: e.get("label", e["object_type"]).lower())
    return out


def types_in(incident, path: str | None = None) -> list[dict]:
    """Reference entries for the object_type features present on an incident.

    De-duplicated and order-preserving, so a report that recognised a
    '120mm mortar' surfaces the mortar_round card exactly once.
    """
    seen: set[str] = set()
    out: list[dict] = []
    for f in getattr(incident, "features", []):
        if f.facet == "object_type" and f.value not in seen:
            entry = get(f.value, path)
            if entry:
                seen.add(f.value)
                out.append(entry)
    return out
