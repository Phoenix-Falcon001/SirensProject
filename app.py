"""Sirens — web console.

A browser front-end over the same analysis pipeline the CLI uses. Paste or type a
report; Sirens extracts its signature, compares it against every incident in the
local database (by shared features AND by meaning), and — if an Anthropic key is
configured — has Claude write a plain-English linkage assessment. Anything you
save is remembered and becomes part of what the next report is checked against.

Run:
    python app.py
Then open http://127.0.0.1:5000 in your browser.
"""
from __future__ import annotations

import pathlib
import re
import webbrowser
import random
from threading import Timer

from flask import (Flask, redirect, render_template_string, request,
                   send_from_directory, url_for)

from linker.ingest import load_incidents
from linker.extract import FeatureExtractor
from linker.match import Matcher
from linker.cluster import Clusterer
from linker import store, semantic, ai, reference, report
from linker.models import Incident

ROOT = pathlib.Path(__file__).resolve().parent
TAXONOMY = ROOT / "data" / "taxonomy" / "cied_lexicon.json"
SAMPLES = ROOT / "data" / "sample_incidents"
PHOTOS_DIR = ROOT / "data" / "photos"
PHOTOS_DIR.mkdir(parents=True, exist_ok=True)

# Images we accept for filing. They are stored and shown for the analyst to
# eyeball against linked incidents — never machine-analysed (that stays out of
# scope). One image per incident, named after the incident id.
ALLOWED_PHOTO_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif"}

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 8 * 1024 * 1024  # 8 MB cap per upload

from brief_bp import brief_bp
app.register_blueprint(brief_bp)
from vendor_bp import vendor_bp; app.register_blueprint(vendor_bp)
from demo_bp import demo_bp; app.register_blueprint(demo_bp)
from review_bp import review_bp; app.register_blueprint(review_bp)
from dashboard_bp import dashboard_bp; app.register_blueprint(dashboard_bp)

# Load the extractor once (spaCy start-up cost paid a single time).
_EXTRACTOR = FeatureExtractor(TAXONOMY, use_ner=True)


def _slug_city(location: str | None) -> str:
    """Turn a free-text location into a filename-safe place slug.

    'Route Copper, Al-Fakir District' -> 'route-copper' (primary place only).
    Empty/odd input falls back to 'site' so a file is always nameable.
    """
    if not location:
        return "site"
    primary = location.split(",")[0]                      # keep the main place
    slug = re.sub(r"[^a-z0-9]+", "-", primary.lower()).strip("-")
    return slug or "site"


def _next_index(slug: str) -> int:
    """Next free sequence number for a place, e.g. route-copper-03 -> 4."""
    hi = 0
    for p in PHOTOS_DIR.glob(f"{slug}-*"):
        m = re.fullmatch(rf"{re.escape(slug)}-(\d+)", p.stem)
        if m:
            hi = max(hi, int(m.group(1)))
    return hi + 1


def _save_photo(file_storage, location, previous_photo: str | None = None) -> str | None:
    """Persist an uploaded image under a human-readable, location-based name.

    The stored name records *where the object was found*, e.g. 'beirut-02.jpg'
    or 'route-copper-05.png' — never a meaningless upload name. Returns the
    stored filename, or None if nothing usable was uploaded. Any image already
    on record for this incident is removed first, so a record carries one image.
    """
    if not file_storage or not file_storage.filename:
        return None
    ext = pathlib.Path(file_storage.filename).suffix.lower()
    if ext not in ALLOWED_PHOTO_EXT:
        return None
    slug = _slug_city(location)
    stored = f"{slug}-{_next_index(slug):02d}{ext}"
    try:
        file_storage.save(str(PHOTOS_DIR / stored))     # write the new image first
    except OSError:
        return None
    if previous_photo and previous_photo != stored:     # only then drop the old one
        try:
            (PHOTOS_DIR / previous_photo).unlink()
        except OSError:
            pass
    return stored


@app.route("/photos/<path:name>")
def photo(name):
    """Serve a filed incident image. send_from_directory blocks path traversal."""
    return send_from_directory(PHOTOS_DIR, name)


@app.template_global()
def photo_url(inc):
    """URL for an incident's filed image, or None if there is no real file.

    Old text-only references (e.g. sample data that names 'img_003.jpg' with no
    actual file) return None and simply render as no image — nothing breaks.
    """
    name = getattr(inc, "photo", None)
    if name and (PHOTOS_DIR / name).exists():
        return url_for("photo", name=name)
    return None


@app.template_global()
def ref_all():
    """Every reference entry, for the browse picker."""
    return reference.all_entries()


@app.template_global()
def ref_disclaimer():
    """Library-wide recognition/handling disclaimer, shown on every panel."""
    return reference.disclaimer()


def _score_band(x: float) -> str:
    return "strong" if x >= 0.66 else "medium" if x >= 0.40 else "weak"


def _analyse(new_inc: Incident, run_llm: bool):
    """Compare a freshly-extracted incident against the stored history."""
    history = store.all_incidents()
    history = [h for h in history if h.incident_id != new_inc.incident_id]

    # Structured (taxonomy) matches — fit corpus stats on history + the new one.
    structured = []
    matcher = Matcher().fit(history + [new_inc])
    for h in history:
        link = matcher.score(new_inc, h)
        if link.score > 0 and (link.shared_features or link.shared_entities):
            structured.append((h, link))
    structured.sort(key=lambda t: t[1].score, reverse=True)
    structured = structured[:6]

    # Meaning matches (offline).
    sem = semantic.SemanticIndex(history).top_matches(
        new_inc.narrative, k=6, exclude_id=new_inc.incident_id) if history else []

    # LLM assessment (optional).
    assessment = None
    if run_llm:
        assessment = ai.assess(new_inc, structured[:4], sem[:4])

    return {
        "structured": [(h, link, _score_band(link.score)) for h, link in structured],
        "semantic": [(h, s, _score_band(s)) for h, s in sem],
        "assessment": assessment,
    }


@app.route("/", methods=["GET"])
def index():
    return render_template_string(
        TEMPLATE,
        result=None, form={}, status=_status(),
        suggested_id=store.next_incident_id(),
        **_form_options({}),
    )


@app.route("/analyse", methods=["POST"])
def analyse():
    f = request.form
    narrative = (f.get("narrative") or "").strip()
    incident_id = (f.get("incident_id") or store.next_incident_id()).strip()
    opts = _form_options(f)

    # Validate the one thing Sirens actually needs *before* writing anything to
    # disk, so a rejected report never leaves a stray uploaded photo behind.
    if not narrative:
        return render_template_string(
            TEMPLATE, result=None, form=f, status=_status(),
            suggested_id=incident_id,
            error="Paste a report narrative first — that's what Sirens reads.",
            **opts)

    # Structured place: caza (dropdown) is authoritative for the map; street is
    # the exact where. A human-readable location string is composed from both,
    # falling back to any legacy free-text location field.
    caza = (f.get("caza") or "").strip()
    street = (f.get("street") or "").strip()
    location = ", ".join(p for p in (street, caza) if p) or (f.get("location") or None)

    existing = store.get_incident(incident_id)
    prev_photo = existing.photo if existing else None
    stored_photo = _save_photo(request.files.get("photo_file"), location,
                               previous_photo=prev_photo)
    if stored_photo is None:
        stored_photo = prev_photo or (f.get("photo") or None)

    inc = Incident(
        incident_id=incident_id,
        date=(f.get("date") or None),
        location=location,
        narrative=narrative,
        photo=stored_photo,
    )
    _EXTRACTOR.extract(inc)
    save = f.get("action") == "save"

    # Optional precise grid (UTM or lat/lon) -> lat, lon + a display label.
    lat, lon, grid, grid_err = _resolve_grid(f)
    munition = (f.get("munition") or "").strip()
    item_color = (f.get("item_color") or "").strip()
    conditions = f.getlist("condition")

    if save:
        store.add_incident(inc)
        _put_meta(incident_id, {
            "caza": caza or None,
            "street": street or None,
            "munition": munition or None,
            "color": item_color or None,
            "condition": conditions,
            "lat": lat, "lon": lon, "grid": grid,
        })

    result = _analyse(inc, run_llm=(f.get("use_ai") == "on"))
    result["incident"] = inc
    result["saved"] = save
    result["reference"] = reference.types_in(inc)
    result["meta"] = {
        "caza": caza, "street": street,
        "munition": munition, "munition_label": _MUNITION_LABEL.get(munition, ""),
        "color": item_color, "condition": conditions, "grid": grid,
    }
    return render_template_string(
        TEMPLATE, result=result, form={}, status=_status(),
        suggested_id=store.next_incident_id(), error=grid_err,
        **_form_options({}))


@app.route("/seed", methods=["POST"])
def seed():
    incidents = load_incidents(SAMPLES)
    _EXTRACTOR.extract_all(incidents)
    store.add_incidents(incidents)
    return redirect(url_for("index"))


@app.route("/clear", methods=["POST"])
def clear():
    store.clear()
    # The metadata sidecar and filed photos are app.py's own; keep them in step
    # with the database so a wipe doesn't leave orphaned records behind.
    try:
        META_FILE.unlink()
    except OSError:
        pass
    for p in PHOTOS_DIR.glob("*"):
        if p.is_file():
            try:
                p.unlink()
            except OSError:
                pass
    return redirect(url_for("index"))


def _status() -> dict:
    ai_ok, ai_reason = ai.available()
    return {
        "db_count": store.count(),
        "sem_mode": semantic.mode(),
        "sem_ok": semantic.has_vectors(),
        "ai_ok": ai_ok,
        "ai_reason": ai_reason,
    }


TEMPLATE = r"""{% macro ref_card(e) %}
<div class="refcard">
  <div class="reftitle">{{ e.label }} <span class="refkey mono">{{ e.object_type }}</span></div>
  {% if e.summary %}<p class="refsum">{{ e.summary }}</p>{% endif %}
  {% if e.specs %}
    <table class="refspecs">{% for row in e.specs %}<tr><th>{{ row[0] }}</th><td>{{ row[1] }}</td></tr>{% endfor %}</table>
  {% endif %}
  {% if e.ammunition %}
    <div class="reflab">Ammunition categories</div>
    <ul class="reflist">{% for a in e.ammunition %}<li>{{ a }}</li>{% endfor %}</ul>
  {% endif %}
  {% if e.deployment %}
    <div class="reflab">Employment</div>
    <ul class="reflist">{% for d in e.deployment %}<li>{{ d }}</li>{% endfor %}</ul>
  {% endif %}
  {% if e.responder_note %}<div class="refnote"><strong>Responder note.</strong> {{ e.responder_note }}</div>{% endif %}
  {% if e.sources %}<div class="refsrc">{{ e.sources|join('; ') }}</div>{% endif %}
</div>
{% endmacro %}
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sirens — Incident Link Console</title>
<style>
  :root{
    --ink:#16202b; --ink-soft:#3a4652; --line:#e2e6e3; --line-2:#eef0ee;
    --surface:#f4f6f3; --panel:#ffffff; --sig:#b5761f; --sig-soft:#f3e7d3;
    --strong:#1f7a4d; --strong-bg:#e7f2ec; --medium:#8a6a13; --medium-bg:#f6efdc;
    --weak:#7a8791; --weak-bg:#eef1f0; --link:#2d5b8e;
    --mono:ui-monospace,"SF Mono",Menlo,Consolas,"Roboto Mono",monospace;
    --sans:system-ui,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--surface);color:var(--ink);font-family:var(--sans);
       line-height:1.5;-webkit-font-smoothing:antialiased;position:relative}
  body::before{content:"";position:fixed;inset:0;z-index:0;pointer-events:none;
       background:url('/static/siren-mark.jpeg') no-repeat center center;
       background-size:min(70vw,1100px);opacity:.06;filter:grayscale(1)}
  .bar,.wrap{position:relative;z-index:1}
  a{color:var(--link)}
  .bar{display:flex;align-items:center;gap:20px;flex-wrap:wrap;
       padding:18px 32px;background:var(--ink);color:#eef2f5;
       border-bottom:3px solid var(--sig)}
  .brand{font-family:var(--mono);font-weight:600;letter-spacing:.16em;
         text-transform:uppercase;font-size:15px}
  .brand small{display:block;letter-spacing:.06em;font-size:10px;color:#9fb0bd;
               font-weight:400;margin-top:2px}
  .badges{margin-left:auto;display:flex;gap:10px;flex-wrap:wrap}
  .badge{font-family:var(--mono);font-size:11px;letter-spacing:.04em;
         padding:5px 10px;border-radius:2px;background:#22303d;color:#cdd8e0;
         border:1px solid #2c3c4a;white-space:nowrap}
  .badge .dot{display:inline-block;width:7px;height:7px;border-radius:50%;
              margin-right:6px;vertical-align:middle;background:var(--weak)}
  .badge.on .dot{background:#54d08a}.badge.off .dot{background:#d0574f}
  .wrap{max-width:1720px;margin:0 auto;padding:40px 48px 90px}
  .grid{display:grid;grid-template-columns:minmax(0,560px) minmax(0,1fr);gap:40px;align-items:start}
  @media(max-width:1100px){.wrap{padding:28px 20px 60px}.grid{grid-template-columns:1fr}}
  @media(max-width:840px){.grid{grid-template-columns:1fr}}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:9px;
        box-shadow:0 1px 2px rgba(22,32,43,.04),0 4px 16px rgba(22,32,43,.05)}
  .card h2{margin:0;padding:14px 18px;border-bottom:1px solid var(--line-2);
           font-size:12px;letter-spacing:.14em;text-transform:uppercase;
           color:var(--ink-soft);font-family:var(--mono);font-weight:600}
  .card .body{padding:24px 26px}
  label{display:block;font-size:12px;letter-spacing:.03em;color:var(--ink-soft);
        margin:0 0 5px;font-weight:600}
  input[type=text],textarea{width:100%;padding:9px 11px;border:1px solid var(--line);
        border-radius:4px;font-family:var(--sans);font-size:14px;color:var(--ink);
        background:#fcfdfc}
  input[type=text]:focus,textarea:focus{outline:2px solid var(--link);
        outline-offset:1px;border-color:var(--link)}
  textarea{min-height:230px;resize:vertical;line-height:1.6}
  .row{display:flex;gap:12px}.row>div{flex:1;min-width:0}
  .field{margin-bottom:20px}
  .mono{font-family:var(--mono)}
  .hint{font-size:12px;color:var(--weak);margin-top:5px}
  .checks{display:flex;flex-wrap:wrap;gap:12px 22px;margin-top:4px}
  .chk{display:inline-flex;align-items:center;gap:8px;margin:0;font-weight:500;
       font-size:14px;color:var(--ink-soft);cursor:pointer;padding:4px 0}
  .chk input{width:17px;height:17px;margin:0}
  .gridmode{display:flex;gap:18px;margin-bottom:4px}
  .gridrow{margin-top:8px}
  .mini{font-size:11px;letter-spacing:.02em;color:var(--weak);margin:0 0 4px;font-weight:600}
  input[type=file]{width:100%;font-size:13px;color:var(--ink-soft)}
  input[type=file]::file-selector-button{font-family:var(--sans);font-size:13px;
        font-weight:600;padding:8px 13px;margin-right:11px;border:1px solid var(--ink);
        border-radius:4px;background:#fff;color:var(--ink);cursor:pointer}
  input[type=file]::file-selector-button:hover{background:var(--line-2)}
  .shot{display:block;margin-top:6px;width:max-content;max-width:100%}
  .shot img{max-width:100%;max-height:300px;border:1px solid var(--line);
        border-radius:5px;display:block}
  .thumb{display:inline-block;margin-top:9px;line-height:0}
  .thumb img{width:78px;height:78px;object-fit:cover;border:1px solid var(--line);
        border-radius:4px;display:block}
  /* munitions reference */
  select{width:100%;padding:9px 11px;border:1px solid var(--line);border-radius:4px;
        font-family:var(--sans);font-size:14px;color:var(--ink);background:#fcfdfc}
  select:focus{outline:2px solid var(--link);outline-offset:1px;border-color:var(--link)}
  .refcard{border:1px solid var(--line);border-left:4px solid var(--sig);border-radius:5px;
        padding:13px 15px;margin-bottom:12px;background:#fffdf9}
  .reftitle{font-weight:700;font-size:15px;color:var(--ink);display:flex;
        align-items:center;gap:9px;flex-wrap:wrap}
  .refkey{font-size:11px;font-weight:600;color:#7a4e12;background:var(--sig-soft);
        border:1px solid #e6d3b0;border-radius:3px;padding:2px 7px}
  .refsum{font-size:13.5px;color:var(--ink-soft);margin:8px 0 10px;line-height:1.55}
  .refspecs{width:100%;border-collapse:collapse;font-size:13px;margin:0 0 10px}
  .refspecs th{text-align:left;font-weight:600;color:var(--ink-soft);white-space:nowrap;
        padding:3px 12px 3px 0;vertical-align:top;width:38%}
  .refspecs td{padding:3px 0;color:var(--ink)}
  .reflab{font-size:10.5px;letter-spacing:.12em;text-transform:uppercase;color:var(--weak);
        font-family:var(--mono);margin:6px 0 5px}
  .reflist{margin:0 0 10px;padding-left:18px;font-size:13px;color:var(--ink-soft)}
  .reflist li{padding:1px 0}
  .refnote{font-size:13px;color:#8a3b12;background:#fbf0e6;border:1px solid #eecdb0;
        border-radius:4px;padding:9px 12px;margin:4px 0 8px}
  .refsrc{font-size:11.5px;color:var(--weak)}
  .actions{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-top:6px}
  .btn{font-family:var(--sans);font-size:14px;font-weight:600;padding:10px 16px;
       border-radius:4px;border:1px solid var(--ink);background:var(--ink);
       color:#fff;cursor:pointer}
  .btn:hover{background:#22303d}
  .btn.ghost{background:#fff;color:var(--ink)}
  .btn.ghost:hover{background:var(--line-2)}
  .toggle{display:flex;align-items:center;gap:7px;font-size:13px;color:var(--ink-soft);
          margin-left:auto;font-weight:500}
  .toggle input{width:16px;height:16px}
  .toggle.disabled{opacity:.5}
  .err{background:#fbeceb;border:1px solid #e7b7b2;color:#a4332b;padding:10px 14px;
       border-radius:4px;font-size:13px;margin-bottom:14px}
  .note{font-size:12.5px;color:var(--ink-soft);background:var(--line-2);
        border-radius:4px;padding:9px 12px;margin-bottom:14px}
  .empty{color:var(--weak);font-size:14px;padding:8px 2px}
  /* extracted signature chips */
  .chips{display:flex;flex-wrap:wrap;gap:6px;margin-top:4px}
  .chip{font-family:var(--mono);font-size:11.5px;padding:3px 8px;border-radius:3px;
        background:var(--sig-soft);color:#7a4e12;border:1px solid #e6d3b0}
  .chip.ent{background:#e9eef4;color:#274a6e;border-color:#cdd9e6}
  .subhead{font-size:11px;letter-spacing:.12em;text-transform:uppercase;
           color:var(--weak);font-family:var(--mono);margin:16px 0 8px}
  .subhead:first-child{margin-top:0}
  /* match cards — the signature element */
  .match{border:1px solid var(--line);border-left:4px solid var(--weak);
         border-radius:5px;padding:12px 14px;margin-bottom:10px;background:#fff}
  .match.strong{border-left-color:var(--strong)}
  .match.medium{border-left-color:var(--medium)}
  .match .top{display:flex;align-items:center;gap:10px}
  .score{font-family:var(--mono);font-weight:700;font-size:13px;padding:3px 8px;
         border-radius:3px;min-width:52px;text-align:center;color:var(--weak);
         background:var(--weak-bg)}
  .score.strong{color:var(--strong);background:var(--strong-bg)}
  .score.medium{color:var(--medium);background:var(--medium-bg)}
  .mid{font-family:var(--mono);font-weight:600;font-size:13px}
  .loc{color:var(--weak);font-size:12.5px;margin-left:auto;text-align:right}
  .reasons{margin:8px 0 0;padding-left:2px;list-style:none;font-size:13px;color:var(--ink-soft)}
  .reasons li{padding:2px 0 2px 16px;position:relative}
  .reasons li:before{content:"";position:absolute;left:2px;top:10px;width:6px;height:6px;
        background:var(--sig);border-radius:50%}
  .snippet{font-size:13px;color:var(--ink-soft);margin-top:6px}
  /* AI panel */
  .ai{border:1px solid #cdd9e6;background:#f5f9fd;border-radius:6px;padding:0;margin-top:4px}
  .ai h3{margin:0;padding:11px 16px;font-size:11px;letter-spacing:.12em;text-transform:uppercase;
         font-family:var(--mono);color:#274a6e;border-bottom:1px solid #dce6f0;
         display:flex;align-items:center;gap:8px}
  .ai .txt{padding:14px 16px;font-size:14px;line-height:1.6;white-space:pre-wrap}
  .ai .off{padding:12px 16px;font-size:13px;color:var(--ink-soft)}
  .tag{font-family:var(--mono);font-size:10px;background:#274a6e;color:#fff;
       padding:2px 7px;border-radius:2px;margin-left:auto;letter-spacing:.05em}
  footer{max-width:1180px;margin:0 auto;padding:0 22px 40px;color:var(--weak);
         font-size:12px}
  @media(prefers-reduced-motion:no-preference){
    .result-card{animation:rise .28s ease both}
    @keyframes rise{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:none}}
  }
</style>
</head>
<body>
<div class="bar">
  <div class="brand">Sirens<small>C-IED Incident Link Console</small></div>
  <a href="/map" style="color:#cdd8e0;font-family:var(--mono);font-size:11px;text-decoration:none;border:1px solid #2c3c4a;padding:5px 10px;border-radius:2px">map &#8599;</a>
  <a href="/tree" style="color:#cdd8e0;font-family:var(--mono);font-size:11px;text-decoration:none;border:1px solid #2c3c4a;padding:5px 10px;border-radius:2px">link tree &#8599;</a>
  <a href="/review" style="color:#cdd8e0;font-family:var(--mono);font-size:11px;text-decoration:none;border:1px solid #2c3c4a;padding:5px 10px;border-radius:2px">review links</a>
  <a href="/dashboard" style="color:#cdd8e0;font-family:var(--mono);font-size:11px;text-decoration:none;border:1px solid #2c3c4a;padding:5px 10px;border-radius:2px">dashboard</a>
  <a href="/brief" style="color:#cdd8e0;font-family:var(--mono);font-size:11px;text-decoration:none;border:1px solid #2c3c4a;padding:5px 10px;border-radius:2px">brief &#8599;</a>
  <a href="/demo" style="color:#cdd8e0;font-family:var(--mono);font-size:11px;text-decoration:none;border:1px solid #2c3c4a;padding:5px 10px;border-radius:2px">demo data</a>
  <div class="badges">
    <span class="badge {{ 'on' if status.db_count else 'off' }}"><span class="dot"></span>{{ status.db_count }} in database</span>
    <span class="badge {{ 'on' if status.sem_ok else 'off' }}"><span class="dot"></span>meaning: {{ 'vectors' if status.sem_ok else 'lexical' }}</span>
    <span class="badge {{ 'on' if status.ai_ok else 'off' }}"><span class="dot"></span>AI: {{ 'ready' if status.ai_ok else 'off' }}</span>
  </div>
</div>

<div class="wrap">
{% if error %}<div class="err">{{ error }}</div>{% endif %}
<div class="grid">

  <!-- LEFT: input -->
  <section class="card">
    <h2>New report</h2>
    <div class="body">
      <form method="post" action="/analyse" enctype="multipart/form-data">
        <div class="row">
          <div class="field">
            <label for="incident_id">Incident ID</label>
            <input type="text" id="incident_id" name="incident_id" class="mono"
                   value="{{ form.incident_id or suggested_id }}">
          </div>
          <div class="field">
            <label for="date">Date</label>
            <input type="text" id="date" name="date" placeholder="2026-03-04"
                   value="{{ form.date or '' }}">
          </div>
        </div>
        <div class="row">
          <div class="field">
            <label for="caza">Caza (district)</label>
            <select id="caza" name="caza">
              <option value="">&mdash; select caza &mdash;</option>
              {% for cz in cazas %}<option value="{{ cz }}"{{ ' selected' if form.caza == cz else '' }}>{{ cz }}</option>{% endfor %}
            </select>
            <div class="hint">Sets where this report lands on the map.</div>
          </div>
          <div class="field">
            <label for="street">Street / exact place</label>
            <input type="text" id="street" name="street"
                   placeholder="Route Copper, near junction" value="{{ form.street or '' }}">
          </div>
        </div>
        <div class="row">
          <div class="field">
            <label for="munition">Munition / device type</label>
            <select id="munition" name="munition">
              <option value="">&mdash; select type &mdash;</option>
              {% for k, l, c in munitions %}<option value="{{ k }}"{{ ' selected' if form.munition == k else '' }}>{{ l }}</option>{% endfor %}
            </select>
            <div class="hint">Colours the pin on the map.</div>
          </div>
          <div class="field">
            <label for="item_color">Item colour / markings</label>
            <input type="text" id="item_color" name="item_color" list="colorlist"
                   placeholder="olive, rust, unpainted&hellip;" value="{{ form.item_color or '' }}">
            <datalist id="colorlist">{% for c in colors %}<option value="{{ c }}">{% endfor %}</datalist>
          </div>
        </div>
        <div class="field">
          <label>Condition <span style="font-weight:400;color:var(--weak)">(tick all that apply)</span></label>
          <div class="checks">
            {% for cnd in conditions %}
            <label class="chk"><input type="checkbox" name="condition" value="{{ cnd }}"{{ ' checked' if cnd in sel_conditions else '' }}> {{ cnd }}</label>
            {% endfor %}
          </div>
        </div>
        <div class="field">
          <label>Grid reference <span style="font-weight:400;color:var(--weak)">(optional &mdash; drops a precise pin inside the caza)</span></label>
          <div class="gridmode">
            <label class="chk"><input type="radio" name="grid_mode" value="utm"{{ ' checked' if (form.grid_mode or 'utm') == 'utm' else '' }}> UTM</label>
            <label class="chk"><input type="radio" name="grid_mode" value="latlon"{{ ' checked' if form.grid_mode == 'latlon' else '' }}> Lat / Lon</label>
          </div>
          <div class="row gridrow" id="utmrow">
            <div style="flex:0 0 92px">
              <label for="utm_zone" class="mini">Zone</label>
              <select id="utm_zone" name="utm_zone">
                <option value="36"{{ ' selected' if form.utm_zone != '37' else '' }}>36N</option>
                <option value="37"{{ ' selected' if form.utm_zone == '37' else '' }}>37N</option>
              </select>
            </div>
            <div><label for="utm_e" class="mini">Easting</label>
              <input type="text" id="utm_e" name="utm_e" class="mono" inputmode="decimal" placeholder="731351" value="{{ form.utm_e or '' }}"></div>
            <div><label for="utm_n" class="mini">Northing</label>
              <input type="text" id="utm_n" name="utm_n" class="mono" inputmode="decimal" placeholder="3753199" value="{{ form.utm_n or '' }}"></div>
          </div>
          <div class="row gridrow" id="llrow" style="display:none">
            <div><label for="lat" class="mini">Latitude</label>
              <input type="text" id="lat" name="lat" class="mono" inputmode="decimal" placeholder="33.8938" value="{{ form.lat or '' }}"></div>
            <div><label for="lon" class="mini">Longitude</label>
              <input type="text" id="lon" name="lon" class="mono" inputmode="decimal" placeholder="35.5018" value="{{ form.lon or '' }}"></div>
          </div>
          <div class="hint">Lebanon spans UTM <span class="mono">36N</span> (coast &amp; most of the country) and <span class="mono">37N</span> (eastern Beqaa / Baalbek-Hermel). Leave blank to pin at the caza centre.</div>
        </div>
        <div class="field">
          <label for="narrative">Report narrative</label>
          <textarea id="narrative" name="narrative"
            placeholder="Paste the incident report here. Sirens reads the free text and pulls out the device signature, names, groups and numbers.">{{ form.narrative or '' }}</textarea>
          <div class="hint">Free text is fine — messy field reporting is what it's built for.</div>
        </div>
        <div class="field">
          <label for="photo_file">Photo <span style="font-weight:400;color:var(--weak)">(optional &mdash; filed &amp; shown for comparison, not analysed)</span></label>
          <input type="file" id="photo_file" name="photo_file" accept="image/*">
          <div class="hint">JPG, PNG, WEBP or GIF, up to 8&nbsp;MB. Filed under the <strong>location</strong> it was found (e.g. <span class="mono">route-copper-03.jpg</span>) and shown beside any incident it links to. Saved with the record on <strong>Save to database</strong>.</div>
        </div>
        <div class="actions">
          <button class="btn" type="submit" name="action" value="analyse">Analyse</button>
          <button class="btn ghost" type="submit" name="action" value="save">Save to database</button>
          <label class="toggle {{ '' if status.ai_ok else 'disabled' }}">
            <input type="checkbox" name="use_ai" {{ 'checked' if status.ai_ok else 'disabled' }}>
            AI assessment
          </label>
        </div>
        {% if not status.ai_ok %}
          <div class="hint">AI assessment is off — {{ status.ai_reason }}</div>
        {% endif %}
      </form>
    </div>
  </section>

  <!-- RIGHT: results -->
  <section>
  {% if not result %}
    <div class="card"><div class="body">
      {% if status.db_count == 0 %}
        <p class="empty">The database is empty. Load the 13 sample incidents to try it, then paste a new report to see what it links to.</p>
        <form method="post" action="/seed"><button class="btn" type="submit">Load sample incidents</button></form>
      {% else %}
        <p class="empty">Paste a report on the left and press <strong>Analyse</strong>. Sirens checks it against the {{ status.db_count }} incidents on record — by shared signature and by meaning — and, with AI on, explains the strongest links.</p>
        <form method="post" action="/clear" onsubmit="return confirm('Delete all stored incidents?')">
          <button class="btn ghost" type="submit">Clear database</button></form>
      {% endif %}
    </div></div>
  {% else %}
    <div class="card result-card">
      <h2>Signature extracted &mdash; <span class="mono">{{ result.incident.incident_id }}</span>{% if result.saved %} &nbsp;·&nbsp; saved{% endif %}</h2>
      <div class="body">
        {% set inc = result.incident %}
        <div class="subhead">Device / TTP features</div>
        {% if inc.features %}
          <div class="chips">{% for f in inc.features %}<span class="chip">{{ f.facet }}={{ f.value }}</span>{% endfor %}</div>
        {% else %}<div class="empty">No taxonomy features matched this text.</div>{% endif %}

        {% if inc.persons or inc.groups or inc.phones %}
          <div class="subhead">Entities</div>
          <div class="chips">
            {% for p in inc.persons %}<span class="chip ent">person: {{ p }}</span>{% endfor %}
            {% for g in inc.groups %}<span class="chip ent">group: {{ g }}</span>{% endfor %}
            {% for ph in inc.phones %}<span class="chip ent">phone: {{ ph }}</span>{% endfor %}
          </div>
        {% endif %}

        {% set m = result.meta %}
        {% if m and (m.caza or m.street or m.munition_label or m.color or m.condition or m.grid) %}
          <div class="subhead">Filed details{% if not result.saved %} <span style="color:var(--weak);text-transform:none;letter-spacing:0">(save to keep them with the record)</span>{% endif %}</div>
          <div class="chips">
            {% if m.caza %}<span class="chip ent">caza: {{ m.caza }}</span>{% endif %}
            {% if m.street %}<span class="chip ent">place: {{ m.street }}</span>{% endif %}
            {% if m.munition_label %}<span class="chip">type: {{ m.munition_label }}</span>{% endif %}
            {% if m.color %}<span class="chip">colour: {{ m.color }}</span>{% endif %}
            {% for cnd in m.condition %}<span class="chip">{{ cnd }}</span>{% endfor %}
            {% if m.grid %}<span class="chip mono">{{ m.grid }}</span>{% endif %}
          </div>
        {% endif %}

        {% set purl = photo_url(inc) %}
        {% if purl %}
          <div class="subhead">Photo on file{% if not result.saved %} <span style="color:var(--weak);text-transform:none;letter-spacing:0">(save to keep it with the record)</span>{% endif %}</div>
          <a class="shot" href="{{ purl }}" target="_blank" rel="noopener">
            <img src="{{ purl }}" alt="Filed photo for {{ inc.incident_id }}"></a>
          <div class="hint mono">{{ inc.photo }}</div>
        {% endif %}
      </div>
    </div>

    {% if result.reference %}
      <div class="card result-card" style="margin-top:16px">
        <h2>Type reference &mdash; recognised in this report</h2>
        <div class="body">
          <div class="note">{{ ref_disclaimer() }}</div>
          {% for e in result.reference %}{{ ref_card(e) }}{% endfor %}
        </div>
      </div>
    {% endif %}

    {% if result.assessment %}
      <div class="ai result-card">
        <h3>AI linkage assessment
          {% if result.assessment.ok %}<span class="tag">{{ result.assessment.model }}</span>{% endif %}</h3>
        {% if result.assessment.ok %}
          <div class="txt">{{ result.assessment.text }}</div>
          <div class="off" style="border-top:1px solid #dce6f0;padding-top:9px;margin-top:2px">
            Generated by a small local model ({{ result.assessment.model }}) — verify every
            claim against the <strong>Links found</strong> panel below before acting on it.
          </div>
        {% else %}
          <div class="off">Assessment unavailable — {{ result.assessment.reason }}</div>
        {% endif %}
      </div>
    {% endif %}

    <div class="card result-card" style="margin-top:16px">
      <h2>Links found</h2>
      <div class="body">
        <div class="subhead">By shared signature</div>
        {% if result.structured %}
          {% for h, link, band in result.structured %}
          <div class="match {{ band }}">
            <div class="top">
              <span class="score {{ band }}">{{ '%.2f'|format(link.score) }}</span>
              <span class="mid">{{ h.incident_id }}</span>
              <span class="loc">{{ h.location or '—' }}{% if h.date %} · {{ h.date }}{% endif %}</span>
            </div>
            {% if link.reasons %}<ul class="reasons">{% for r in link.reasons %}<li>{{ r }}</li>{% endfor %}</ul>{% endif %}
            {% set hp = photo_url(h) %}
            {% if hp %}<a class="thumb" href="{{ hp }}" target="_blank" rel="noopener"><img src="{{ hp }}" alt="Photo on file for {{ h.incident_id }}"></a>{% endif %}
          </div>
          {% endfor %}
        {% else %}<div class="empty">No shared-signature links above threshold.</div>{% endif %}

        <div class="subhead">By meaning ({{ 'word vectors' if status.sem_ok else 'text overlap' }})</div>
        {% if result.semantic %}
          {% for h, sim, band in result.semantic %}
          <div class="match {{ band }}">
            <div class="top">
              <span class="score {{ band }}">{{ '%.2f'|format(sim) }}</span>
              <span class="mid">{{ h.incident_id }}</span>
              <span class="loc">{{ h.location or '—' }}</span>
            </div>
            <div class="snippet">{{ h.narrative[:160] }}{% if h.narrative|length > 160 %}…{% endif %}</div>
            {% set hp = photo_url(h) %}
            {% if hp %}<a class="thumb" href="{{ hp }}" target="_blank" rel="noopener"><img src="{{ hp }}" alt="Photo on file for {{ h.incident_id }}"></a>{% endif %}
          </div>
          {% endfor %}
        {% else %}<div class="empty">Nothing to compare against yet — save a few incidents first.</div>{% endif %}
      </div>
    </div>
  {% endif %}
  </section>
</div>

<section class="card" style="margin-top:22px">
  <h2>Munitions reference</h2>
  <div class="body">
    <div class="note">{{ ref_disclaimer() }}</div>
    <label for="reftype">Object type &mdash; pick a type to see public reference information</label>
    <select id="reftype" onchange="showRef(this.value)">
      <option value="">&mdash; select a type &mdash;</option>
      {% for e in ref_all() %}<option value="{{ e.object_type }}">{{ e.label }}</option>{% endfor %}
    </select>
    <div id="refpanels" style="margin-top:14px">
      {% for e in ref_all() %}
        <div class="refwrap" id="ref-{{ e.object_type }}" style="display:none">{{ ref_card(e) }}</div>
      {% endfor %}
    </div>
  </div>
</section>
</div>
<script>
function showRef(v){
  var all = document.querySelectorAll('.refwrap');
  for (var i = 0; i < all.length; i++){ all[i].style.display = 'none'; }
  if (v){ var t = document.getElementById('ref-' + v); if (t){ t.style.display = 'block'; } }
}
(function(){
  function syncGrid(){
    var m = document.querySelector('input[name="grid_mode"]:checked');
    var utm = document.getElementById('utmrow'), ll = document.getElementById('llrow');
    if (!m || !utm || !ll) return;
    var isLL = m.value === 'latlon';
    utm.style.display = isLL ? 'none' : 'flex';
    ll.style.display  = isLL ? 'flex' : 'none';
  }
  var radios = document.querySelectorAll('input[name="grid_mode"]');
  for (var i = 0; i < radios.length; i++){ radios[i].addEventListener('change', syncGrid); }
  syncGrid();
})();
</script>
<footer>Decision-support for incident link analysis — every value traces to source text; a human analyst confirms any link. Photos are filed and shown beside linked incidents for the analyst to compare — never machine-analysed.</footer>
</body>
</html>"""


# ---------------------------------------------------------------------------
# Incident map — real choropleth of Lebanon's cazas (districts), shaded by
# incident count. Fully offline: the boundary geometry is bundled in
# data/regions.json (GADM v4.1 level 2) and projected + drawn as SVG right here.
# No map tiles, no geocoding, no API key, no CDN, no network. Reachable at /map.
#
# Interactive: wheel/drag to zoom + pan, hover for a caza tooltip, click a caza
# to zoom to it and pop up every report on record there (with its exact place
# text) right on the map. Sample incidents use invented place names;
# _LOCATION_ALIASES maps each onto a real caza. Typing a real caza in the
# Location field matches directly.
# ---------------------------------------------------------------------------
import json
import math

REGIONS_FILE = ROOT / "data" / "regions.json"

_HEAT = ["#eceeec", "#ede4d2", "#dfc9a0", "#c99b5f", "#a86b38"]      # cold -> hot, muted
_HEAT_INK = ["#9aa1a8", "#8a7048", "#7a5c38", "#5f4326", "#e8e2d6"]  # text per level, softer
# --- Report attributes -----------------------------------------------------
# Caza fill shows *concentration* (the heat ramp above). Individual reports
# drop a coloured pin inside their caza, coloured by *munition type* — so the
# two never fight over one fill. (key, human label, pin colour).
_MUNITIONS = [
    ("ied",       "IED / roadside device", "#c0663f"),
    ("vbied",     "VBIED (vehicle-borne)",  "#7a3a3a"),
    ("uxo",       "UXO (unexploded ord.)",  "#c99a4a"),
    ("mine",      "Landmine / mine",        "#8770a0"),
    ("mortar",    "Mortar",                 "#5a80a3"),
    ("rocket",    "Rocket",                 "#4a9a8f"),
    ("missile",   "Missile / ATGM",         "#a3568f"),
    ("artillery", "Artillery shell",        "#8a7451"),
    ("grenade",   "Grenade / RPG",          "#6a9a6e"),
    ("cache",     "Weapons cache",          "#6b7c86"),
    ("other",     "Other / unknown",        "#9aa1a8"),
]
_MUNITION_COLOR = {k: c for k, _l, c in _MUNITIONS}
_MUNITION_LABEL = {k: l for k, l, _c in _MUNITIONS}

_CONDITIONS = ["buried", "surface-laid", "freshly emplaced", "aged / weathered",
               "damaged", "burned", "corroded", "intact"]
_ITEM_COLORS = ["black", "grey", "olive / green", "tan / sand", "brown / rust",
                "blue", "red", "yellow", "camouflage", "unpainted metal"]

# Keyword fallback so sample data (and any report filed without an explicit
# type) still gets a meaningful pin colour, read straight from its own text.
# Order matters: more specific patterns first. Overridden by an explicit type.
_MUNITION_HINTS = [
    ("vbied",     r"vbied|car\s?bomb|vehicle[- ]borne|truck bomb"),
    ("cache",     r"cache|weapons? (?:store|dump)|stockpile|arms dump"),
    ("mine",      r"landmine|minefield|\bmine\b"),
    ("mortar",    r"\bmortar"),
    ("rocket",    r"\brocket|107\s?mm|122\s?mm|\bgrad\b"),
    ("missile",   r"\bmissile|\batgm\b|kornet|guided munition"),
    ("artillery", r"artillery|\bshell\b|155\s?mm|130\s?mm|105\s?mm"),
    ("grenade",   r"grenade|\brpg\b"),
    ("uxo",       r"\buxo\b|unexploded|\bdud\b|\berw\b|abandoned ordnance"),
    ("ied",       r"\bied\b|improvised|roadside|pressure[- ]plate|command[- ]wire|"
                  r"victim[- ]operated|pipe bomb|\bdevice\b|\bvoied\b"),
]


def _infer_munition(inc, explicit):
    """Explicit type if filed; else guess from the narrative + extracted features."""
    if explicit:
        return explicit
    text = (getattr(inc, "narrative", "") or "").lower()
    feats = " ".join(
        f"{getattr(x, 'facet', '')} {getattr(x, 'value', '')}"
        for x in (getattr(inc, "features", None) or [])
    ).lower()
    hay = text + " " + feats
    for key, pat in _MUNITION_HINTS:
        if re.search(pat, hay):
            return key
    return "other"


# --- Per-report metadata sidecar -------------------------------------------
# app.py owns this file entirely; it never touches the linker store. It records
# the structured fields the form now captures (caza, street, type, colour,
# condition, precise lat/lon) keyed by incident id. The map reads it; missing
# entries simply fall back to the old alias behaviour, so nothing breaks.
META_FILE = ROOT / "data" / "report_meta.json"


def _load_meta():
    try:
        return json.loads(META_FILE.read_text())
    except (OSError, ValueError):
        return {}


def _save_meta(meta):
    try:
        META_FILE.write_text(json.dumps(meta, indent=2, ensure_ascii=False))
    except OSError:
        pass


def _put_meta(incident_id, rec):
    """Store non-empty fields for an incident (or drop the record if all empty)."""
    rec = {k: v for k, v in rec.items() if v not in (None, "", [], {})}
    meta = _load_meta()
    if rec:
        meta[incident_id] = rec
    else:
        meta.pop(incident_id, None)
    _save_meta(meta)


# --- UTM <-> geographic (WGS84), pure math, no dependencies ----------------
# Lebanon straddles two UTM zones: 36N covers the coast and most of the country;
# 37N covers the eastern Beqaa / Baalbek-Hermel. Zone is stored per report and
# auto-detected from longitude for the live map read-out.
def _latlon_to_utm(lat, lon, force_zone=None):
    a = 6378137.0
    f = 1 / 298.257223563
    k0 = 0.9996
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    zone = force_zone or (int((lon + 180) // 6) + 1)
    lon0 = math.radians((zone - 1) * 6 - 180 + 3)
    latr = math.radians(lat)
    lonr = math.radians(lon)
    N = a / math.sqrt(1 - e2 * math.sin(latr) ** 2)
    T = math.tan(latr) ** 2
    C = ep2 * math.cos(latr) ** 2
    A = math.cos(latr) * (lonr - lon0)
    M = a * ((1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * latr
             - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * math.sin(2 * latr)
             + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * math.sin(4 * latr)
             - (35 * e2 ** 3 / 3072) * math.sin(6 * latr))
    E = k0 * N * (A + (1 - T + C) * A ** 3 / 6
                  + (5 - 18 * T + T ** 2 + 72 * C - 58 * ep2) * A ** 5 / 120) + 500000
    Nn = k0 * (M + N * math.tan(latr) * (A ** 2 / 2
               + (5 - T + 9 * C + 4 * C ** 2) * A ** 4 / 24
               + (61 - 58 * T + T ** 2 + 600 * C - 330 * ep2) * A ** 6 / 720))
    if lat < 0:
        Nn += 10000000
    return zone, E, Nn


def _utm_to_latlon(easting, northing, zone, north=True):
    a = 6378137.0
    f = 1 / 298.257223563
    k0 = 0.9996
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2))
    x = easting - 500000
    y = northing if north else northing - 10000000
    M = y / k0
    mu = M / (a * (1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256))
    phi1 = (mu + (3 * e1 / 2 - 27 * e1 ** 3 / 32) * math.sin(2 * mu)
            + (21 * e1 ** 2 / 16 - 55 * e1 ** 4 / 32) * math.sin(4 * mu)
            + (151 * e1 ** 3 / 96) * math.sin(6 * mu)
            + (1097 * e1 ** 4 / 512) * math.sin(8 * mu))
    C1 = ep2 * math.cos(phi1) ** 2
    T1 = math.tan(phi1) ** 2
    N1 = a / math.sqrt(1 - e2 * math.sin(phi1) ** 2)
    R1 = a * (1 - e2) / (1 - e2 * math.sin(phi1) ** 2) ** 1.5
    D = x / (N1 * k0)
    lat = phi1 - (N1 * math.tan(phi1) / R1) * (
        D ** 2 / 2 - (5 + 3 * T1 + 10 * C1 - 4 * C1 ** 2 - 9 * ep2) * D ** 4 / 24
        + (61 + 90 * T1 + 298 * C1 + 45 * T1 ** 2 - 252 * ep2 - 3 * C1 ** 2) * D ** 6 / 720)
    lon0 = math.radians((zone - 1) * 6 - 180 + 3)
    lon = lon0 + (D - (1 + 2 * T1 + C1) * D ** 3 / 6
                  + (5 - 2 * C1 + 28 * T1 - 3 * C1 ** 2 + 8 * ep2 + 24 * T1 ** 2)
                  * D ** 5 / 120) / math.cos(phi1)
    return math.degrees(lat), math.degrees(lon)


def _fmt_grid(lat, lon):
    z, E, N = _latlon_to_utm(lat, lon)
    return f"{z}N {E:.0f}E {N:.0f}N"


def _parse_float(s):
    try:
        return float(str(s).strip())
    except (TypeError, ValueError):
        return None


def _resolve_grid(f):
    """Turn whatever grid the form supplied (UTM or lat/lon) into lat, lon, a
    display label, and an optional error message. Out-of-range input is rejected
    with a note rather than silently producing a nonsense pin."""
    mode = f.get("grid_mode") or "utm"
    lat = lon = None
    if mode == "latlon":
        raw_lat, raw_lon = f.get("lat"), f.get("lon")
        if not (raw_lat or raw_lon):
            return None, None, None, None
        lat, lon = _parse_float(raw_lat), _parse_float(raw_lon)
        if lat is None or lon is None:
            return None, None, None, "Enter both latitude and longitude as numbers."
    else:
        raw_e, raw_n = f.get("utm_e"), f.get("utm_n")
        if not (raw_e or raw_n):
            return None, None, None, None
        e, n = _parse_float(raw_e), _parse_float(raw_n)
        if e is None or n is None:
            return None, None, None, "Enter both UTM easting and northing as numbers."
        if not (100000 <= e <= 900000) or not (0 <= n <= 10000000):
            return None, None, None, ("UTM values look out of range — easting "
                                      "100000–900000, northing 0–10 000 000.")
        zone = 37 if (f.get("utm_zone") == "37") else 36
        lat, lon = _utm_to_latlon(e, n, zone, north=True)
    if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
        return None, None, None, "Coordinates are outside valid Earth bounds."
    return round(lat, 6), round(lon, 6), _fmt_grid(lat, lon), None


def _form_options(f):
    """Option lists the New-report form needs, shared by every render path."""
    sel = f.getlist("condition") if hasattr(f, "getlist") else []
    return dict(cazas=_CAZA_NAMES, munitions=_MUNITIONS,
                colors=_ITEM_COLORS, conditions=_CONDITIONS, sel_conditions=sel)


def _pin_xy(lat, lon, centroid, idx):
    """Pixel for a report's pin: its exact lon/lat if known, else a capped
    golden-angle spiral around the caza centre so many pins fan out but
    stay contained near the city instead of drifting off the map."""
    if lat is not None and lon is not None and _PROJ:
        return _PROJ(lon, lat)
    cx, cy = centroid
    if idx <= 0:
        return cx, cy
    ang = idx * 2.399963229728653          # golden angle (radians)
    rad = min(3.0 + 2.2 * math.sqrt(idx), 14.0)   # capped radius
    return cx + rad * math.cos(ang), cy + rad * math.sin(ang)

# Map the sample data's invented locations onto real Lebanese cazas so the
# choropleth has a spread to show. Delete/replace these as you enter real ones.
_LOCATION_ALIASES = {
    # Real South Lebanon towns -> their caza (exact GADM names from regions.json).
    # Bint Jbeil caza
    "Bint Jbeil":     "BintJbayl",
    "Aïn Ebel":       "BintJbayl",
    "Rmeish":         "BintJbayl",
    "Yaroun":         "BintJbayl",
    "Maroun al-Ras":  "BintJbayl",
    "Aitaroun":       "BintJbayl",
    "Chaqra":         "BintJbayl",
    "Tibnin":         "BintJbayl",
    "Ghandouriyeh":   "BintJbayl",
    # Marjaayoun caza
    "Marjayoun":      "Marjaayoun",
    "Khiam":          "Marjaayoun",
    "Kfar Kila":      "Marjaayoun",
    "Blida":          "Marjaayoun",
    "Meiss ej-Jabal": "Marjaayoun",
    "Deir Mimas":     "Marjaayoun",
    "Houla":          "Marjaayoun",
    # Nabatiyeh caza
    "Nabatieh":       "Nabatiyeh",
    "Kfar Tibnit":    "Nabatiyeh",
    "Zawtar":         "Nabatiyeh",
    "Kfar Roummane":  "Nabatiyeh",
    # Sour (Tyre) caza
    "Qana":           "Sour",
    "Tayr Harfa":     "Sour",
    "Naqoura":        "Sour",
    "Srifa":          "Sour",
    # Legacy invented sample-incident names (kept so the 13 demo samples still map).
    "Route Copper":      "Tripoli",
    "Al-Fakir District": "Akkar",
    "Green Village":     "Zahleh",
    "Hazar Junction":    "Baabda",
    "Central Market":    "Beirut",
    "Ministry Road":     "Saida",
    "North Gate":        "Zgharta",
    "Sector 7 bypass":   "Sour",
}


def _norm(s):
    """Loose key for matching place names regardless of case/spacing/punctuation."""
    return re.sub(r"[^a-z0-9]", "", (s or "").lower())


def _load_regions():
    """Load the bundled boundary geometry once, or None if the file is absent
    or malformed (a corrupt file must not crash the whole app at startup)."""
    try:
        return json.loads(REGIONS_FILE.read_text())
    except (OSError, ValueError):
        return None


_REGIONS = _load_regions()


def _rings(geom):
    """Yield every ring (exterior + holes) of a Polygon/MultiPolygon."""
    t = geom["type"]
    c = geom["coordinates"]
    if t == "Polygon":
        for ring in c:
            yield ring
    elif t == "MultiPolygon":
        for poly in c:
            for ring in poly:
                yield ring


def _make_projector(fc, width=560, pad=12):
    """Linear lon/lat -> pixel transform sized to the data's bounding box.

    Longitude is compressed by cos(mid-latitude) so the country isn't stretched,
    and the y-axis is flipped so north points up.
    """
    xs = []
    ys = []
    for f in fc["features"]:
        for ring in _rings(f["geometry"]):
            for lon, lat in ring:
                xs.append(lon)
                ys.append(lat)
    minx, maxx = min(xs), max(xs)
    miny, maxy = min(ys), max(ys)
    kx = math.cos(math.radians((miny + maxy) / 2))
    gw = (maxx - minx) * kx
    gh = (maxy - miny)
    height = (width - 2 * pad) * gh / gw + 2 * pad
    sx = (width - 2 * pad) / gw
    sy = (height - 2 * pad) / gh

    def proj(lon, lat):
        return (pad + (lon - minx) * kx * sx,
                pad + (maxy - lat) * sy)

    params = {"minx": minx, "maxx": maxx, "miny": miny, "maxy": maxy,
              "kx": kx, "sx": sx, "sy": sy, "pad": pad}
    return proj, width, height, params


if _REGIONS:
    _PROJ, _MAP_W, _MAP_H, _PROJ_PARAMS = _make_projector(_REGIONS, width=900)
    _CAZA_NAMES = sorted({f["properties"]["name"] for f in _REGIONS["features"]})
else:
    _PROJ = _MAP_W = _MAP_H = _PROJ_PARAMS = None
    _CAZA_NAMES = []


def _path_d(geom):
    """SVG path data for a projected Polygon/MultiPolygon (holes included)."""
    out = []
    for ring in _rings(geom):
        pts = [_PROJ(lon, lat) for lon, lat in ring]
        out.append("M" + " ".join(f"{x:.1f},{y:.1f}" for x, y in pts) + "Z")
    return "".join(out)


def _centroid(geom):
    """Rough label anchor: mean of the largest ring's projected points."""
    best = None
    bestlen = -1
    for ring in _rings(geom):
        if len(ring) > bestlen:
            bestlen = len(ring)
            best = ring
    xs = [_PROJ(lon, lat)[0] for lon, lat in best]
    ys = [_PROJ(lon, lat)[1] for lon, lat in best]
    return sum(xs) / len(xs), sum(ys) / len(ys)


def _district(location):
    """Real caza for a free-text location: first comma-part -> alias -> caza."""
    if not location or not location.strip():
        return None
    primary = location.split(",")[0].strip()
    return _LOCATION_ALIASES.get(primary, primary)


def _heat_level(count, hi):
    """Bucket a count into 0..4 for the heat ramp (0 only when count is 0)."""
    if count <= 0 or hi <= 0:
        return 0
    return 1 + min(3, int((count - 1) * 4 / max(hi, 1)))


@app.route("/tree")
def link_tree():
    """Interactive force-directed link graph: which incidents connect to
    which, coloured by cluster. Runs the same matcher used by /analyse over
    every incident currently in the database, entirely offline."""
    incidents = store.all_incidents()
    if not incidents:
        return render_template_string(
            "<p style='font-family:monospace;padding:40px'>No incidents in the "
            "database yet. <a href='/'>Go back</a> and load or save some first.</p>")

    matcher = Matcher().fit(incidents)
    links = matcher.all_pairs(incidents, threshold=0.25)
    clusterer = Clusterer(incidents, links)
    clusters = clusterer.clusters(singletons=False)
    payload = clusterer.graph_payload()

    html_page = report.html_report(
        incidents, links, clusters, payload,
        title="Sirens — Incident Link Tree",
    )
    return html_page


@app.route("/map")
def incident_map():
    if not _REGIONS:
        return render_template_string(MAP_TEMPLATE, ready=False)

    # Canonical caza name per normalised key, for tolerant matching.
    canon = {}
    for f in _REGIONS["features"]:
        canon.setdefault(_norm(f["properties"]["name"]), f["properties"]["name"])

    # Label anchor / pin-fallback centre per caza (its largest piece).
    cazapos = {}
    for f in _REGIONS["features"]:
        name = f["properties"]["name"]
        cx, cy = _centroid(f["geometry"])
        span = max(len(r) for r in _rings(f["geometry"]))
        if name not in cazapos or span > cazapos[name]["span"]:
            cazapos[name] = {"x": cx, "y": cy, "span": span}

    meta = _load_meta()
    counts = {}
    reports = {}            # caza -> [ report dicts ]  for the click popup
    pins = []               # one coloured dot per report, on top of the map
    typecounts = {}
    percaza_idx = {}
    unmatched = 0
    for inc in store.all_incidents():
        iid = getattr(inc, "incident_id", "")
        m = meta.get(iid, {})
        # Caza comes from the filed metadata first, then the old location alias.
        d = m.get("caza") or _district(getattr(inc, "location", None))
        key = canon.get(_norm(d)) if d else None
        if not key:
            unmatched += 1
            continue
        counts[key] = counts.get(key, 0) + 1
        mun = _infer_munition(inc, m.get("munition"))
        typecounts[mun] = typecounts.get(mun, 0) + 1

        lat, lon = m.get("lat"), m.get("lon")
        exact = lat is not None and lon is not None
        idx = percaza_idx.get(key, 0)
        percaza_idx[key] = idx + 1
        centre = (cazapos[key]["x"], cazapos[key]["y"])
        px, py = _pin_xy(lat, lon, centre, 0 if exact else idx)

        snip = (getattr(inc, "narrative", "") or "").strip().replace("\n", " ")
        grid = m.get("grid") or (_fmt_grid(lat, lon) if exact else "")
        reports.setdefault(key, []).append({
            "id": iid,
            "date": getattr(inc, "date", "") or "",
            "loc": getattr(inc, "location", "") or "",
            "street": m.get("street", "") or "",
            "type": mun,
            "typelabel": _MUNITION_LABEL.get(mun, mun),
            "color": m.get("color", "") or "",
            "condition": m.get("condition", []) or [],
            "grid": grid,
            "exact": exact,
            "snip": snip[:140] + ("…" if len(snip) > 140 else ""),
        })
        pins.append({"x": round(px, 1), "y": round(py, 1), "type": mun,
                     "fill": _MUNITION_COLOR.get(mun, "#8a929a"),
                     "caza": key, "id": iid, "exact": exact})
    hi = max(counts.values()) if counts else 0

    # One filled path per feature; multi-part cazas share a name and fill.
    shapes = []
    for f in _REGIONS["features"]:
        name = f["properties"]["name"]
        c = counts.get(name, 0)
        shapes.append({"d": _path_d(f["geometry"]), "fill": _HEAT[_heat_level(c, hi)],
                       "name": name, "count": c})

    labels = []
    for name, pos in cazapos.items():
        c = counts.get(name, 0)
        labels.append({"x": pos["x"], "y": pos["y"], "name": name,
                       "count": c, "ink": _HEAT_INK[_heat_level(c, hi)] if c else "#9aa1a8"})

    ranked = sorted(counts.items(), key=lambda t: -t[1])
    legend_types = [{"key": k, "label": l, "color": c, "count": typecounts.get(k, 0)}
                    for k, l, c in _MUNITIONS if typecounts.get(k, 0) > 0]
    return render_template_string(
        MAP_TEMPLATE, ready=True, shapes=shapes, labels=labels, pins=pins,
        w=_MAP_W, h=_MAP_H, heat=_HEAT, ranked=ranked, reports=reports,
        legend_types=legend_types, proj=(_PROJ_PARAMS or {}),
        total=sum(counts.values()), districts=len(counts), unmatched=unmatched)


MAP_TEMPLATE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sirens — Incident Map</title>
<style>
  :root{--ink:#16202b;--soft:#3a4652;--line:#e2e6e3;--surface:#f4f6f3;
    --sig:#a8703a; --sig-soft:#f0e6d4;
    --mono:ui-monospace,Menlo,Consolas,monospace;
    --sans:system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif;}
  *{box-sizing:border-box}
  body{margin:0;background:var(--surface);color:var(--ink);font-family:var(--sans);line-height:1.5}
  .bar{display:flex;align-items:center;gap:18px;padding:14px 26px;background:var(--ink);
    color:#eef2f5;border-bottom:3px solid var(--sig)}
  .brand{font-family:var(--mono);font-weight:600;letter-spacing:.16em;text-transform:uppercase;font-size:15px}
  .brand small{display:block;letter-spacing:.06em;font-size:10px;color:#9fb0bd;font-weight:400;margin-top:2px}
  .bar a{margin-left:auto;color:#cdd8e0;font-family:var(--mono);font-size:12px;
    text-decoration:none;border:1px solid #2c3c4a;padding:6px 12px;border-radius:3px}
  .bar a:hover{background:#22303d}
  .wrap{max-width:1080px;margin:0 auto;padding:26px 22px 60px}
  h1{font-size:14px;letter-spacing:.14em;text-transform:uppercase;color:var(--soft);
    font-family:var(--mono);margin:0 0 4px}
  .sub{color:var(--weak);font-size:13px;margin:0 0 18px}
  .layout{display:grid;grid-template-columns:minmax(0,1fr) 250px;gap:24px;align-items:start}
  @media(max-width:820px){.layout{grid-template-columns:1fr}}
  .mapcard{position:relative;background:#fff;border:1px solid var(--line);border-radius:8px;padding:10px;user-select:none;-webkit-user-select:none}  svg{width:100%;height:auto;display:block;touch-action:none;cursor:grab}
  svg.grabbing{cursor:grabbing}
  .region{stroke:#c7cdc9;stroke-width:.6;cursor:pointer}
  .region.hot{stroke:#16202b;stroke-width:1.1}
  .region.sel{stroke:#16202b;stroke-width:1.4}
  .region.dim{opacity:.35}
  .rlabel{font-family:var(--mono);pointer-events:none;paint-order:stroke;
    stroke:#fff;stroke-width:2.4px;stroke-linejoin:round}
  .rlabel.dim{opacity:.18}
  .rlabel.zero{opacity:.5}
  .pin{stroke:#fff;stroke-width:1;cursor:pointer}
  .pin.hollow{fill-opacity:.45;stroke-dasharray:2 1.4}
  .pin.off{display:none}
  .pin.notcaza{opacity:.15;pointer-events:none}
  .zoom{position:absolute;top:18px;right:18px;display:flex;flex-direction:column;gap:6px;z-index:4}
  .zoom button{width:32px;height:32px;border:1px solid var(--line);background:#fff;border-radius:6px;
    font-size:17px;font-family:var(--mono);color:var(--ink);cursor:pointer;line-height:1;padding:0}
  .zoom button:hover{background:#f1f3f0}
  .tip{position:absolute;pointer-events:none;background:#16202b;color:#eef2f5;font-family:var(--mono);
    font-size:12px;padding:5px 9px;border-radius:4px;white-space:nowrap;opacity:0;transform:translate(-50%,-135%);
    transition:opacity .1s;z-index:5}
  .tip b{color:#fff}.tip .c{color:#e3a95f}
  .readout{position:absolute;left:12px;bottom:12px;background:rgba(22,32,43,.9);color:#eef2f5;
    font-family:var(--mono);font-size:11px;padding:5px 9px;border-radius:4px;opacity:0;
    transition:opacity .12s;pointer-events:none;z-index:5;white-space:nowrap}
  .readout b{color:#e3a95f}
  /* on-map popup */
  .popup{position:absolute;top:14px;left:14px;width:288px;max-height:calc(100% - 28px);overflow:auto;
    background:#fff;border:1px solid var(--line);border-radius:8px;box-shadow:0 8px 26px rgba(20,32,43,.18);
    padding:12px 13px;display:none;z-index:6}
  .popup.on{display:block}
  .pophead{display:flex;align-items:center;gap:8px}
  .pophead .nm{font-family:var(--mono);font-weight:700;font-size:14px}
  .pophead .cnt{font-family:var(--mono);font-size:11px;color:var(--sig)}
  .pophead .x{margin-left:auto;border:none;background:none;font-size:20px;line-height:1;cursor:pointer;color:var(--weak);padding:0 2px}
  .pophead .x:hover{color:var(--ink)}
  .poptypes{display:flex;flex-wrap:wrap;gap:5px;margin:9px 0 4px}
  .tsum{display:inline-flex;align-items:center;gap:5px;font-family:var(--mono);font-size:11px;
    color:var(--soft);background:#f4f6f3;border:1px solid var(--line);border-radius:3px;padding:2px 6px}
  .tsum i{width:8px;height:8px;border-radius:50%;display:inline-block}
  .rep{border:1px solid var(--line);border-left:3px solid var(--sig);border-radius:5px;
    padding:8px 10px;margin-bottom:8px;background:#fffdf9}
  .rep .rline{display:flex;align-items:baseline;gap:8px}
  .rep .rid{font-family:var(--mono);font-weight:700;font-size:12.5px}
  .rep .date{color:var(--weak);font-size:11.5px;margin-left:auto;font-family:var(--mono)}
  .rep .rtype{display:flex;align-items:center;gap:6px;font-size:12px;font-weight:600;color:var(--soft);margin:3px 0}
  .rep .rtype i{width:9px;height:9px;border-radius:50%;display:inline-block}
  .rep .where{font-size:12.5px;color:var(--sig);margin:2px 0 3px}
  .rep .tags{display:flex;flex-wrap:wrap;gap:4px;margin:3px 0}
  .rep .tag{font-family:var(--mono);font-size:10.5px;padding:1px 6px;border-radius:3px;
    background:#eef1f0;color:var(--soft);border:1px solid var(--line)}
  .rep .tag.grid{background:#e9eef4;color:#274a6e;border-color:#cdd9e6}
  .rep .snip{font-size:12px;color:var(--soft);margin-top:3px}
  .side h2{font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--weak);
    font-family:var(--mono);margin:2px 0 10px}
  .rank{display:flex;align-items:center;gap:9px;padding:6px 0;border-bottom:1px solid #eef0ee;font-size:13px;cursor:pointer}
  .rank:hover{color:var(--link)}
  .rank .n{font-family:var(--mono);font-weight:700;min-width:20px;text-align:right}
  .rank .bar2{flex:1;height:8px;background:#eef1f0;border-radius:4px;overflow:hidden}
  .rank .fill{display:block;height:100%;background:var(--sig)}
  .legwrap{margin:14px 0 0}
  .leglab{font-size:10px;letter-spacing:.12em;text-transform:uppercase;color:var(--weak);
    font-family:var(--mono);margin:0 0 6px}
  .legend{display:flex;align-items:center;gap:8px;font-size:11px;color:var(--weak);font-family:var(--mono)}
  .legend i{width:22px;height:12px;border-radius:2px;display:inline-block;border:1px solid var(--line)}
  .tlegend{display:flex;flex-wrap:wrap;gap:6px}
  .tchip{display:inline-flex;align-items:center;gap:6px;font-family:var(--mono);font-size:11px;
    color:var(--soft);background:#fff;border:1px solid var(--line);border-radius:4px;
    padding:3px 8px;cursor:pointer;user-select:none}
  .tchip i{width:9px;height:9px;border-radius:50%;display:inline-block}
  .tchip .tc{color:var(--weak)}
  .tchip.off{opacity:.4;background:#f4f6f3}
  .tchip.off i{filter:grayscale(1)}
  .totals{margin-top:10px;color:var(--weak);font-size:12px}
  .empty{color:var(--weak);font-size:14px}
</style></head><body>
<div class="bar"><div class="brand">Sirens<small>Incident Map — Lebanon by caza</small></div>
  <a href="/">&#8592; console</a></div>
<div class="wrap">
{% if not ready %}
  <h1>Incident map</h1>
  <p class="empty">Boundary file not found. Put <span class="mono">regions.json</span> in the <span class="mono">data/</span> folder and reload this page.</p>
{% else %}
  <h1>Incident spread &mdash; Lebanon</h1>
  <p class="sub">Caza fill shows concentration; each coloured pin is one report, by munition type. Scroll to zoom, drag to pan, hover for the grid read-out, click a caza (or pin) for its reports.</p>
  <div class="layout">
    <div class="mapcard">
      <div class="zoom">
        <button id="zin" title="Zoom in">+</button>
        <button id="zout" title="Zoom out">&minus;</button>
        <button id="zreset" title="Reset view">&#8634;</button>
      </div>
      <div class="tip" id="tip"></div>
      <div class="readout" id="readout"></div>
      <div class="popup" id="popup">
        <div class="pophead"><span class="nm" id="popname"></span><span class="cnt" id="popcnt"></span>
          <button class="x" id="popx" title="Close">&times;</button></div>
        <div class="poptypes" id="poptypes"></div>
        <div id="popbody"></div>
      </div>
      <svg id="lbmap" viewBox="0 0 {{ w|round|int }} {{ h|round|int }}" role="img" aria-label="Choropleth of Lebanon shaded by incident count per caza, with a coloured pin per report by munition type">
        <g id="vp">
          {% for s in shapes %}<path class="region" data-name="{{ s.name }}" data-count="{{ s.count }}" d="{{ s.d }}" fill="{{ s.fill }}"></path>{% endfor %}
          {% for l in labels %}<text class="rlabel{{ ' zero' if not l.count }}" data-name="{{ l.name }}" x="{{ l.x|round(1) }}" y="{{ l.y|round(1) }}" font-size="{{ '9' if l.count else '5.5' }}" font-weight="{{ '700' if l.count else '400' }}" text-anchor="middle" fill="{{ l.ink }}">{{ l.name }}{% if l.count %} &#183; {{ l.count }}{% endif %}</text>{% endfor %}
          {% for p in pins %}<circle class="pin{{ ' hollow' if not p.exact else '' }}" data-type="{{ p.type }}" data-caza="{{ p.caza }}" data-id="{{ p.id }}" cx="{{ p.x }}" cy="{{ p.y }}" r="3.1" fill="{{ p.fill }}"></circle>{% endfor %}
        </g>
      </svg>
      <div class="legwrap">
        <div class="leglab">Concentration (caza fill)</div>
        <div class="legend"><span>none</span>{% for c in heat %}<i style="background:{{ c }}"></i>{% endfor %}<span>hotspot</span></div>
      </div>
      {% if legend_types %}
      <div class="legwrap">
        <div class="leglab">Munition type (pins) &mdash; click to filter</div>
        <div class="tlegend" id="tlegend">
          {% for t in legend_types %}<span class="tchip" data-type="{{ t.key }}"><i style="background:{{ t.color }}"></i>{{ t.label }} <span class="tc">{{ t.count }}</span></span>{% endfor %}
        </div>
      </div>
      {% endif %}
    </div>
    <div class="side">
      <h2>Hotspots</h2>
      {% if ranked %}
        {% set top = ranked[0][1] %}
        {% for name, c in ranked %}
        <div class="rank" data-jump="{{ name }}"><span class="n">{{ c }}</span>
          <span class="bar2"><span class="fill" style="width:{{ (c * 100 // top) }}%"></span></span>
          <span>{{ name }}</span></div>
        {% endfor %}
      {% else %}<p class="empty">No incidents matched a caza yet.</p>{% endif %}
      <p class="totals">{{ total }} incident{{ '' if total == 1 else 's' }} across {{ districts }} caza{{ '' if districts == 1 else 's' }}{% if unmatched %} &#183; {{ unmatched }} unmatched{% endif %}.</p>
    </div>
  </div>
  <script id="rdata" type="application/json">{{ reports|tojson }}</script>
  <script id="tdata" type="application/json">{{ legend_types|tojson }}</script>
  <script id="pdata" type="application/json">{{ proj|tojson }}</script>
  <script>
  (function(){
    var svg=document.getElementById('lbmap'), vp=document.getElementById('vp'),
        tip=document.getElementById('tip'), card=svg.parentNode,
        readout=document.getElementById('readout'),
        popup=document.getElementById('popup'), popname=document.getElementById('popname'),
        popcnt=document.getElementById('popcnt'), poptypes=document.getElementById('poptypes'),
        popbody=document.getElementById('popbody'),
        regions=[].slice.call(document.querySelectorAll('.region')),
        labels=[].slice.call(document.querySelectorAll('.rlabel')),
        pinEls=[].slice.call(document.querySelectorAll('.pin')),
        data=JSON.parse(document.getElementById('rdata').textContent),
        tinfo=JSON.parse(document.getElementById('tdata').textContent),
        PJ=JSON.parse(document.getElementById('pdata').textContent),
        vb=svg.viewBox.baseVal, W=vb.width, H=vb.height,
        scale=1, tx=0, ty=0, selected=null, active={};

    var TCOL={}, TLAB={};
    tinfo.forEach(function(t){ TCOL[t.key]=t.color; TLAB[t.key]=t.label; active[t.key]=true; });

    function apply(){ vp.setAttribute('transform','translate('+tx+' '+ty+') scale('+scale+')'); }
    function clampPan(){ tx=Math.min(0,Math.max(W-W*scale,tx)); ty=Math.min(0,Math.max(H-H*scale,ty)); }
    function zoomAt(mx,my,f){ var ns=Math.min(14,Math.max(1,scale*f));
      tx=mx-(mx-tx)*(ns/scale); ty=my-(my-ty)*(ns/scale); scale=ns; clampPan(); apply(); }
    function toUser(e){ var r=svg.getBoundingClientRect();
      return [(e.clientX-r.left)/r.width*W,(e.clientY-r.top)/r.height*H]; }

    // lat/lon -> UTM (WGS84), zone auto from longitude. Mirrors the server math.
    function llToUtm(lat,lon){
      var a=6378137.0,f=1/298.257223563,k0=0.9996,e2=f*(2-f),ep2=e2/(1-e2);
      var zone=Math.floor((lon+180)/6)+1, lon0=((zone-1)*6-180+3)*Math.PI/180;
      var la=lat*Math.PI/180, lo=lon*Math.PI/180;
      var N=a/Math.sqrt(1-e2*Math.pow(Math.sin(la),2)),
          T=Math.pow(Math.tan(la),2), C=ep2*Math.pow(Math.cos(la),2),
          A=Math.cos(la)*(lo-lon0);
      var M=a*((1-e2/4-3*e2*e2/64-5*e2*e2*e2/256)*la
        -(3*e2/8+3*e2*e2/32+45*e2*e2*e2/1024)*Math.sin(2*la)
        +(15*e2*e2/256+45*e2*e2*e2/1024)*Math.sin(4*la)
        -(35*e2*e2*e2/3072)*Math.sin(6*la));
      var E=k0*N*(A+(1-T+C)*Math.pow(A,3)/6+(5-18*T+T*T+72*C-58*ep2)*Math.pow(A,5)/120)+500000;
      var Nn=k0*(M+N*Math.tan(la)*(A*A/2+(5-T+9*C+4*C*C)*Math.pow(A,4)/24
        +(61-58*T+T*T+600*C-330*ep2)*Math.pow(A,6)/720));
      return {zone:zone,e:E,n:Nn};
    }
    function readAt(e){
      if(PJ.sx===undefined) return;
      var u=toUser(e), bx=(u[0]-tx)/scale, by=(u[1]-ty)/scale;
      var lon=PJ.minx+(bx-PJ.pad)/(PJ.kx*PJ.sx);
      var lat=PJ.maxy-(by-PJ.pad)/PJ.sy;
      var g=llToUtm(lat,lon);
      readout.innerHTML='<b>'+g.zone+'N</b> '+Math.round(g.e)+'E '+Math.round(g.n)+
        'N &nbsp;&#183;&nbsp; '+lat.toFixed(4)+', '+lon.toFixed(4);
      readout.style.opacity='1';
    }

    svg.addEventListener('wheel',function(e){ e.preventDefault(); var p=toUser(e);
      zoomAt(p[0],p[1], e.deltaY<0?1.15:1/1.15); readAt(e); },{passive:false});
    svg.addEventListener('pointermove',readAt);
    svg.addEventListener('pointerleave',function(){ readout.style.opacity='0'; });

    // Pan: only capture the pointer AFTER a real drag begins, so a plain click
    // still reaches a district's (or pin's) click handler.
    var pressing=false, moved=false, lx, ly, captured=false, pid=null;
    svg.addEventListener('pointerdown',function(e){ pressing=true; moved=false; lx=e.clientX; ly=e.clientY; pid=e.pointerId; });
    svg.addEventListener('pointermove',function(e){
      if(!pressing) return;
      if(!moved && Math.abs(e.clientX-lx)+Math.abs(e.clientY-ly)>3){
        moved=true; svg.classList.add('grabbing');
        try{ svg.setPointerCapture(pid); captured=true; }catch(_){}
      }
      if(moved){ var r=svg.getBoundingClientRect();
        tx+=(e.clientX-lx)/r.width*W; ty+=(e.clientY-ly)/r.height*H; lx=e.clientX; ly=e.clientY; clampPan(); apply(); }
    });
    function endPress(){ pressing=false; svg.classList.remove('grabbing');
      if(captured){ try{ svg.releasePointerCapture(pid); }catch(_){} captured=false; } }
    svg.addEventListener('pointerup', endPress);
    svg.addEventListener('pointercancel', endPress);

    function bboxOf(name){ var x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;
      regions.forEach(function(p){ if(p.getAttribute('data-name')===name){ var b=p.getBBox();
        x0=Math.min(x0,b.x); y0=Math.min(y0,b.y); x1=Math.max(x1,b.x+b.width); y1=Math.max(y1,b.y+b.height); } });
      return {x:x0,y:y0,w:x1-x0,h:y1-y0}; }
    function zoomTo(name){ var b=bboxOf(name), pad=1.4,
        ns=Math.min(14,Math.min(W/(b.w*pad),H/(b.h*pad))),
        cx=b.x+b.w/2, cy=b.y+b.h/2;
      scale=ns; tx=W/2-cx*ns; ty=H/2-cy*ns; clampPan(); apply(); }

    function esc(s){ var d=document.createElement('div'); d.textContent=s==null?'':s; return d.innerHTML; }
    function shown(t){ return active[t]!==false; }

    function renderPopup(name){
      var all=data[name]||[], list=all.filter(function(r){ return shown(r.type); });
      popname.textContent=name;
      popcnt.textContent=list.length+' report'+(list.length===1?'':'s')+
        (list.length!==all.length?(' of '+all.length):'');
      // type summary chips
      var by={}; list.forEach(function(r){ by[r.type]=(by[r.type]||0)+1; });
      var th=''; Object.keys(by).forEach(function(t){
        th+='<span class="tsum"><i style="background:'+(TCOL[t]||'#8a929a')+'"></i>'+
            by[t]+' '+esc(TLAB[t]||t)+'</span>'; });
      poptypes.innerHTML=th;
      // rows
      var html=list.length?'':'<p class="empty">No reports match the current filter.</p>';
      list.forEach(function(r){
        var col=TCOL[r.type]||'#8a929a';
        html+='<div class="rep" style="border-left-color:'+col+'">';
        html+='<div class="rline"><span class="rid">'+esc(r.id)+'</span><span class="date">'+esc(r.date)+'</span></div>';
        html+='<div class="rtype"><i style="background:'+col+'"></i>'+esc(r.typelabel)+'</div>';
        html+='<div class="where">'+esc(r.street||r.loc||'location not given')+'</div>';
        var tags='';
        if(r.grid) tags+='<span class="tag grid">'+esc(r.grid)+(r.exact?'':' (approx)')+'</span>';
        if(r.color) tags+='<span class="tag">'+esc(r.color)+'</span>';
        (r.condition||[]).forEach(function(c){ tags+='<span class="tag">'+esc(c)+'</span>'; });
        if(tags) html+='<div class="tags">'+tags+'</div>';
        if(r.snip) html+='<div class="snip">'+esc(r.snip)+'</div>';
        html+='</div>';
      });
      popbody.innerHTML=html;
    }

    function select(name){
      selected=name;
      regions.forEach(function(p){ var m=p.getAttribute('data-name')===name;
        p.classList.toggle('sel',m); p.classList.toggle('dim',!m); p.classList.remove('hot'); });
      labels.forEach(function(t){ t.classList.toggle('dim',t.getAttribute('data-name')!==name); });
      pinEls.forEach(function(c){ c.classList.toggle('notcaza',c.getAttribute('data-caza')!==name); });
      zoomTo(name);
      tip.style.opacity='0';
      renderPopup(name);
      popup.classList.add('on'); popup.scrollTop=0;
    }
    function clearSel(){
      selected=null;
      regions.forEach(function(p){ p.classList.remove('sel','dim','hot'); });
      labels.forEach(function(t){ t.classList.remove('dim'); });
      pinEls.forEach(function(c){ c.classList.remove('notcaza'); });
      popup.classList.remove('on');
      scale=1; tx=0; ty=0; apply();
    }

    function applyFilter(){
      pinEls.forEach(function(c){ c.classList.toggle('off',!shown(c.getAttribute('data-type'))); });
      if(selected) renderPopup(selected);
    }

    regions.forEach(function(p){
      var name=p.getAttribute('data-name'), cnt=p.getAttribute('data-count');
      p.addEventListener('pointerenter',function(){ if(selected)return; p.classList.add('hot');
        tip.innerHTML='<b>'+esc(name)+'</b> <span class="c">'+cnt+'</span>'; tip.style.opacity='1'; });
      p.addEventListener('pointermove',function(e){ var r=card.getBoundingClientRect();
        tip.style.left=(e.clientX-r.left)+'px'; tip.style.top=(e.clientY-r.top)+'px'; });
      p.addEventListener('pointerleave',function(){ p.classList.remove('hot'); if(!selected) tip.style.opacity='0'; });
      p.addEventListener('click',function(){ if(moved)return; select(name); });
    });

    pinEls.forEach(function(c){
      var t=c.getAttribute('data-type'), id=c.getAttribute('data-id'), cz=c.getAttribute('data-caza');
      c.addEventListener('pointerenter',function(e){ if(selected && cz!==selected) return;
        var r=card.getBoundingClientRect();
        tip.innerHTML='<b>'+esc(id)+'</b> <span class="c">'+esc(TLAB[t]||t)+'</span>';
        tip.style.left=(e.clientX-r.left)+'px'; tip.style.top=(e.clientY-r.top)+'px'; tip.style.opacity='1'; });
      c.addEventListener('pointerleave',function(){ if(!selected) tip.style.opacity='0'; });
      c.addEventListener('click',function(ev){ if(moved)return; ev.stopPropagation(); select(cz); });
    });

    [].slice.call(document.querySelectorAll('.tchip')).forEach(function(chip){
      chip.addEventListener('click',function(){
        var t=chip.getAttribute('data-type');
        active[t]=(active[t]===false); chip.classList.toggle('off',active[t]===false);
        applyFilter();
      });
    });

    [].slice.call(document.querySelectorAll('.rank')).forEach(function(row){
      row.addEventListener('click',function(){ select(row.getAttribute('data-jump')); }); });
    document.getElementById('popx').addEventListener('click',clearSel);
    document.getElementById('zin').addEventListener('click',function(){ zoomAt(W/2,H/2,1.4); });
    document.getElementById('zout').addEventListener('click',function(){ zoomAt(W/2,H/2,1/1.4); });
    document.getElementById('zreset').addEventListener('click',clearSel);
    apply();
  })();
  </script>
{% endif %}
</div></body></html>"""


def _open():
    webbrowser.open("http://127.0.0.1:5000")


if __name__ == "__main__":
    store.connect()  # ensure the DB file exists on first run
    Timer(1.2, _open).start()
    app.run(host="127.0.0.1", port=5000, debug=False)