"""Demo mode: one clearly labelled button that loads the fabricated sample set.

A standalone Flask Blueprint (wired into app.py with one line). The button
posts to the existing /seed route in app.py, so the loading logic lives in one
place only. Incidents are keyed on their id, so pressing it twice does not
create duplicates (and a stored incident with a sample's id is overwritten).
"""
from __future__ import annotations

from flask import Blueprint, render_template_string

from linker import store

demo_bp = Blueprint("demo", __name__)


@demo_bp.route("/demo")
def demo_page():
    return render_template_string(_TEMPLATE, db_count=store.count())


_TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sirens — Demo data</title>
<style>
  :root{
    --ink:#16202b; --ink-soft:#3a4652; --line:#e2e6e3; --line-2:#eef0ee;
    --surface:#f4f6f3; --panel:#ffffff; --sig:#a8703a; --sig-soft:#f0e6d4;
    --weak:#7a8791; --link:#2d5b8e;
    --mono:ui-monospace,"SF Mono",Menlo,Consolas,"Roboto Mono",monospace;
    --sans:system-ui,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--surface);color:var(--ink);font-family:var(--sans);
       line-height:1.5;-webkit-font-smoothing:antialiased}
  .bar{display:flex;align-items:center;gap:20px;flex-wrap:wrap;
       padding:18px 32px;background:var(--ink);color:#eef2f5;
       border-bottom:3px solid var(--sig)}
  .brand{font-family:var(--mono);font-weight:600;letter-spacing:.16em;
         text-transform:uppercase;font-size:15px}
  .brand small{display:block;letter-spacing:.06em;font-size:10px;color:#9fb0bd;
               font-weight:400;margin-top:2px}
  .wrap{max-width:820px;margin:0 auto;padding:48px 48px 90px}
  @media(max-width:1000px){.wrap{padding:28px 20px 60px}}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:9px;
        box-shadow:0 1px 2px rgba(22,32,43,.04),0 4px 16px rgba(22,32,43,.05)}
  .card h2{margin:0;padding:14px 18px;border-bottom:1px solid var(--line-2);
           font-size:12px;letter-spacing:.14em;text-transform:uppercase;
           color:var(--ink-soft);font-family:var(--mono);font-weight:600}
  .card .body{padding:26px 28px}
  p{margin:0 0 14px}
  .warn{background:var(--sig-soft);border:1px solid #e6d3b0;color:#6b4410;
        border-radius:4px;padding:11px 14px;font-size:14px;margin-bottom:18px}
  .stat{font-family:var(--mono);font-size:12px;color:var(--weak);margin-top:14px}
  .btn{font-family:var(--sans);font-size:15px;font-weight:600;padding:11px 18px;
       border-radius:4px;border:1px solid var(--ink);background:var(--ink);
       color:#fff;cursor:pointer}
  .btn:hover{background:#22303d}
</style>
</head>
<body>
<div class="bar">
  <div class="brand">Sirens<small>demo mode</small></div>
  {{ sirens_menu('demo') }}
</div>
<div class="wrap">
  <div class="card"><h2>Load demo data</h2><div class="body">
    <div class="warn"><strong>All demo data is fabricated.</strong> The sample incidents
      (INC-001 to INC-040, South Lebanon place names) were invented for testing and
      demonstration. They describe no real events, people, groups or phone numbers.</div>
    <p>This adds the sample incidents to your local database so the map, link tree and
      brief have something to show. Loading again just refreshes the samples; it does not
      create duplicates. Incidents with other ids are kept, but an incident you filed under
      one of the ids INC-001 to INC-040 would be replaced by the sample with that id.</p>
    <form method="post" action="{{ url_for('seed') }}">
      <button class="btn" type="submit">Load demo data (fabricated)</button>
    </form>
    <p class="stat">Incidents currently on record: {{ db_count }}</p>
  </div></div>
</div>
</body>
</html>
"""
