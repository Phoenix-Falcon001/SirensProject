"""Descriptive statistics for the dashboard (counts only, no conclusions).

Every function takes the incidents currently in view (after the dashboard's
filters) and, where links matter, the links already scored over the full
record with the same matcher and threshold as the link tree. Bands are the
code-computed ones used everywhere (weak < 0.40 <= medium < 0.66 <= strong).
"""
from __future__ import annotations

from collections import Counter

from .ai import _score_band
from .cluster import Clusterer
from .match import SIGNATURE_FACETS

# Display order for the signature selector (initiation has its own chart too).
FACETS = [f for f in ("trigger", "emplacement", "container", "charge_label", "ttp",
                      "object_type", "initiation") if f in SIGNATURE_FACETS]
FACET_LABELS = {"trigger": "Trigger", "emplacement": "Emplacement", "container": "Container",
                "charge_label": "Charge label", "ttp": "TTP / target", "object_type": "Object type",
                "initiation": "Initiation method"}
BANDS = ("strong", "medium", "weak")
REVIEW = (("confirm", "Confirmed"), ("reject", "Rejected"), ("unsure", "Unsure"), (None, "Not reviewed yet"))

# Fields counted for data quality, in display order: (key, label, test).
QUALITY_FIELDS = [
    ("date", "Date", lambda i: bool(i.date)),
    ("location", "Location", lambda i: bool(i.location)),
] + [(f, FACET_LABELS[f], (lambda f: lambda i: any(k == f for k, _ in i.feature_keys()))(f))
     for f in ("initiation", "trigger", "emplacement", "container", "charge_label", "object_type", "ttp")
     if f in SIGNATURE_FACETS] + [
    ("entities", "Any person / group / phone", lambda i: bool(i.persons or i.groups or i.phones)),
]


def label(value: str) -> str:
    return str(value).replace("_", " ")


def signatures(incidents) -> dict:
    """Per facet: how many incidents in view report each value (an incident can report several)."""
    out = {}
    for f in FACETS:
        counts = Counter(v for i in incidents for v in {v for (k, v) in i.feature_keys() if k == f})
        missing = sum(1 for i in incidents if not any(k == f for k, _ in i.feature_keys()))
        ranked = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))   # ties: A-Z, stable
        out[f] = {"name": FACET_LABELS[f],
                  "keys": [k for k, _ in ranked],
                  "labels": [label(k) for k, _ in ranked] + (["not recorded"] if missing else []),
                  "values": [n for _, n in ranked] + ([missing] if missing else []),
                  "missing": missing}
    return out


def links_in_view(links, shown) -> list:
    ids = {i.incident_id for i in shown}
    return [l for l in links if l.a in ids and l.b in ids]


def networks(all_incidents, links, shown) -> dict:
    """Candidate networks (same clustering as the link tree) that have members in view."""
    by_id = {i.incident_id: i for i in all_incidents}
    ids = {i.incident_id for i in shown}
    clusters = Clusterer(all_incidents, links).clusters(singletons=False) if links else []
    rows = []
    for c in clusters:
        here = [m for m in c.members if m in ids]
        if not here:
            continue
        dates = sorted(by_id[m].date for m in here if by_id[m].date)
        internal = [l for l in links if l.a in c.members and l.b in c.members]
        best = max((l.score for l in internal), default=0.0)
        rows.append({"id": c.cluster_id, "size": c.size, "in_view": len(here), "members": here,
                     "signature": c.signature, "first": dates[0] if dates else "",
                     "last": dates[-1] if dates else "", "areas": len({by_id[m].location for m in here if by_id[m].location}),
                     "best": best, "best_band": _score_band(best) if internal else ""})
    rows.sort(key=lambda r: (-r["in_view"], r["id"]))
    in_networks = {m for r in rows for m in r["members"]}
    return {"rows": rows, "unlinked": len(ids - in_networks),
            "labels": [r["id"] for r in rows], "values": [r["in_view"] for r in rows]}


def link_strength(view_links, current_decisions) -> dict:
    """Band counts, a score histogram and analyst review progress for links in view."""
    bands = Counter(_score_band(l.score) for l in view_links)
    edges = [round(0.25 + 0.05 * k, 2) for k in range(16)]          # 0.25 .. 1.00
    hist = [0] * 15
    for l in view_links:
        hist[min(int((l.score - 0.25) / 0.05 + 1e-9), 14)] += 1
    review = Counter(current_decisions.get(tuple(sorted((l.a, l.b)))) for l in view_links)
    total = len(view_links)
    return {"total": total,
            "bands": [{"band": b, "n": bands.get(b, 0)} for b in BANDS],
            "hist_labels": [f"{edges[k]:.2f}–{edges[k + 1]:.2f}" for k in range(15)],
            "hist_values": hist,
            "review": [{"key": k or "open", "label": lab, "n": review.get(k, 0),
                        "pct": round(100 * review.get(k, 0) / total) if total else 0} for k, lab in REVIEW],
            "reviewed_pct": round(100 * (total - review.get(None, 0)) / total) if total else 0}


def quality(incidents) -> dict:
    """Share of reports in view that carry each field, plus the least complete reports."""
    n = len(incidents)
    fields = []
    for key, name, test in QUALITY_FIELDS:
        have = sum(1 for i in incidents if test(i))
        fields.append({"key": key, "label": name, "n": have, "pct": round(100 * have / n) if n else 0})
    per_report = []
    for i in incidents:
        missing = [name for _, name, test in QUALITY_FIELDS if not test(i)]
        per_report.append({"id": i.incident_id, "location": i.location or "", "date": i.date or "",
                           "missing": missing,
                           "pct": round(100 * (len(QUALITY_FIELDS) - len(missing)) / len(QUALITY_FIELDS))})
    per_report.sort(key=lambda r: (r["pct"], r["id"]))
    overall = round(sum(r["pct"] for r in per_report) / n) if n else 0
    return {"fields": fields, "overall": overall, "weakest": per_report[:5],
            "n_fields": len(QUALITY_FIELDS)}
