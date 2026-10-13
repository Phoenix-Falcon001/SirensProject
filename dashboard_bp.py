"""Dashboard: timeline + two breakdown charts over the incidents on record.

A standalone Flask Blueprint (wired into app.py with one line). One filter
row (date range, area, initiation method) scopes every tile, chart and table
on the page. Charts use the vendored Chart.js (static/vendor/), so the page
works with no network. Every chart has a table twin with the exact numbers.

Counts only: the page describes what is on record, it draws no conclusions.
"""
from __future__ import annotations

import re
from collections import Counter
from datetime import date

from flask import Blueprint, render_template_string, request

from linker import decisions, store
from linker.match import Matcher

dashboard_bp = Blueprint("dashboard", __name__)

THRESHOLD = 0.25          # same link threshold as /tree and /review
TOP_AREAS = 10            # more areas than this fold into "Other"
_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_MONTHS = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split()


def _label(value: str) -> str:
    return value.replace("_", " ")


def _initiations(inc) -> set[str]:
    return {v for (k, v) in inc.feature_keys() if k == "initiation"}


def read_filters(args, incidents) -> dict:
    """Validated filters; anything malformed is ignored rather than erroring."""
    areas = sorted({i.location for i in incidents if i.location})
    inits = sorted({v for i in incidents for (k, v) in i.feature_keys() if k == "initiation"})
    f = {
        "start": args.get("from", "") if _DATE.match(args.get("from", "")) else "",
        "end": args.get("to", "") if _DATE.match(args.get("to", "")) else "",
        "area": args.get("area", "") if args.get("area", "") in areas else "",
        "initiation": args.get("initiation", "") if args.get("initiation", "") in inits else "",
    }
    return f | {"areas": areas, "inits": inits}


def apply_filters(incidents, f) -> list:
    out = []
    for i in incidents:
        if (f["start"] or f["end"]) and not i.date:
            continue                       # undated reports can't sit in a date range
        if f["start"] and (i.date or "") < f["start"]:
            continue
        if f["end"] and (i.date or "") > f["end"]:
            continue
        if f["area"] and i.location != f["area"]:
            continue
        if f["initiation"] and f["initiation"] not in _initiations(i):
            continue
        out.append(i)
    return out


def timeline(incidents) -> dict:
    """Incidents per month, every month between the first and last present (zeros kept)."""
    months = Counter(i.date[:7] for i in incidents if i.date and _DATE.match(i.date))
    labels, values = [], []
    if months:
        y, m = map(int, min(months).split("-"))
        y_end, m_end = map(int, max(months).split("-"))
        while (y, m) <= (y_end, m_end):
            labels.append(f"{_MONTHS[m - 1]} {y}")
            values.append(months.get(f"{y:04d}-{m:02d}", 0))
            y, m = (y + 1, 1) if m == 12 else (y, m + 1)
    undated = sum(1 for i in incidents if not (i.date and _DATE.match(i.date)))
    return {"labels": labels, "values": values, "undated": undated}


def by_area(incidents) -> dict:
    counts = Counter(i.location or "no location" for i in incidents).most_common()
    top, rest = counts[:TOP_AREAS], counts[TOP_AREAS:]
    labels = [a for a, _ in top]
    values = [n for _, n in top]
    if rest:
        labels.append(f"Other ({len(rest)} areas)")
        values.append(sum(n for _, n in rest))
    return {"labels": labels, "values": values, "keys": [a for a, _ in top]}


def by_initiation(incidents) -> dict:
    """An incident reporting two methods counts under both, matching the filter."""
    counts = Counter(v for i in incidents for v in _initiations(i)).most_common()
    missing = sum(1 for i in incidents if not _initiations(i))
    labels = [_label(k) for k, _ in counts] + (["not recorded"] if missing else [])
    values = [n for _, n in counts] + ([missing] if missing else [])
    multi = sum(1 for i in incidents if len(_initiations(i)) > 1)
    return {"labels": labels, "values": values, "keys": [k for k, _ in counts], "multi": multi}


def link_stats(all_incidents, shown) -> dict:
    """Links whose two incidents are both in view (scored against the full record)."""
    ids = {i.incident_id for i in shown}
    links = Matcher().fit(all_incidents).all_pairs(all_incidents, threshold=THRESHOLD) if all_incidents else []
    pairs = {tuple(sorted((l.a, l.b))) for l in links if l.a in ids and l.b in ids}
    confirmed = sum(1 for p, d in decisions.current_decisions().items() if d == "confirm" and p in pairs)
    return {"links": len(pairs), "confirmed": confirmed}


@dashboard_bp.route("/dashboard")
def dashboard_page():
    incidents = store.all_incidents()
    f = read_filters(request.args, incidents)
    shown = apply_filters(incidents, f)
    active = any(f[k] for k in ("start", "end", "area", "initiation"))
    return render_template_string(
        _TEMPLATE, f=f, active=active, total=len(incidents), shown=shown,
        n_areas=len({i.location for i in shown if i.location}),
        stats=link_stats(incidents, shown),
        charts={"timeline": timeline(shown), "area": by_area(shown),
                "initiation": by_initiation(shown)},
        label=_label, today=date.today().isoformat())


_TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sirens — Dashboard</title>
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
  a{color:var(--link)}
  .bar{display:flex;align-items:center;gap:20px;flex-wrap:wrap;
       padding:18px 32px;background:var(--ink);color:#eef2f5;
       border-bottom:3px solid var(--sig)}
  .brand{font-family:var(--mono);font-weight:600;letter-spacing:.16em;
         text-transform:uppercase;font-size:15px}
  .brand small{display:block;letter-spacing:.06em;font-size:10px;color:#9fb0bd;
               font-weight:400;margin-top:2px}
  .nav{margin-left:auto;display:flex;gap:8px;flex-wrap:wrap}
  .nav a{color:#cdd8e0;font-family:var(--mono);font-size:11px;
    text-decoration:none;border:1px solid #2c3c4a;padding:5px 10px;border-radius:2px}
  .wrap{max-width:1400px;margin:0 auto;padding:32px 48px 90px}
  @media(max-width:1000px){.wrap{padding:22px 18px 60px}}
  h1{font-size:20px;font-weight:600;margin:0 0 14px}
  .filters{display:flex;flex-wrap:wrap;gap:14px 18px;align-items:flex-end;background:var(--panel);
        border:1px solid var(--line);border-radius:9px;padding:16px 20px;margin-bottom:22px;
        box-shadow:0 1px 2px rgba(22,32,43,.04),0 4px 16px rgba(22,32,43,.05)}
  .filters label{display:block;font-size:11.5px;font-weight:600;color:var(--ink-soft);margin-bottom:4px}
  .filters input,.filters select{padding:7px 9px;border:1px solid var(--line);border-radius:4px;
        font-family:var(--sans);font-size:13.5px;background:#fcfdfc;color:var(--ink);min-width:150px}
  .btn{font-family:var(--sans);font-size:13.5px;font-weight:600;padding:8px 15px;border-radius:4px;
       border:1px solid var(--ink);background:var(--ink);color:#fff;cursor:pointer}
  .reset{font-size:13px;margin-left:4px}
  .scope{font-size:13px;color:var(--ink-soft);margin:-8px 0 20px}
  .tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:16px;margin-bottom:22px}
  .tile{background:var(--panel);border:1px solid var(--line);border-radius:9px;padding:16px 20px;
        box-shadow:0 1px 2px rgba(22,32,43,.04),0 4px 16px rgba(22,32,43,.05)}
  .tile .k{font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--weak);font-family:var(--mono)}
  .tile .v{font-size:30px;font-weight:600;margin-top:4px}
  .tile .s{font-size:12px;color:var(--weak)}
  .grid{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:22px}
  @media(max-width:1000px){.grid{grid-template-columns:1fr}}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:9px;
        box-shadow:0 1px 2px rgba(22,32,43,.04),0 4px 16px rgba(22,32,43,.05)}
  .card.wide{grid-column:1/-1}
  .card h2{margin:0;padding:14px 20px;border-bottom:1px solid var(--line-2);
           font-size:12px;letter-spacing:.14em;text-transform:uppercase;
           color:var(--ink-soft);font-family:var(--mono);font-weight:600}
  .card .body{padding:18px 20px 16px}
  .plot{position:relative;height:260px}
  .plot.tall{height:320px}
  .hint{font-size:12px;color:var(--weak);margin-top:8px}
  details{margin-top:10px;font-size:13px}
  summary{cursor:pointer;color:var(--link)}
  table{border-collapse:collapse;margin-top:8px;font-variant-numeric:tabular-nums}
  th,td{text-align:left;padding:4px 18px 4px 0;border-bottom:1px solid var(--line-2)}
  td.n{text-align:right}
  .empty{color:var(--weak);padding:20px 2px}
</style>
</head>
<body>
<div class="bar">
  <div class="brand">Sirens<small>dashboard · incidents on record</small></div>
  <nav class="nav">
    <a href="{{ url_for('incident_map') }}">map</a>
    <a href="{{ url_for('link_tree') }}">link tree</a>
    <a href="{{ url_for('review.review_page') }}">review links</a>
    <a href="{{ url_for('brief.brief_page') }}">brief</a>
    <a href="{{ url_for('index') }}">&#8592; console</a>
  </nav>
</div>
<div class="wrap">
  <h1>Dashboard</h1>
  <form class="filters" method="get" action="{{ url_for('dashboard.dashboard_page') }}">
    <div><label for="from">From</label><input type="date" id="from" name="from" value="{{ f.start }}" max="{{ today }}"></div>
    <div><label for="to">To</label><input type="date" id="to" name="to" value="{{ f.end }}" max="{{ today }}"></div>
    <div><label for="area">Area</label>
      <select id="area" name="area"><option value="">all areas</option>
        {% for a in f.areas %}<option value="{{ a }}" {{ 'selected' if a == f.area else '' }}>{{ a }}</option>{% endfor %}
      </select></div>
    <div><label for="initiation">Initiation method</label>
      <select id="initiation" name="initiation"><option value="">all methods</option>
        {% for v in f.inits %}<option value="{{ v }}" {{ 'selected' if v == f.initiation else '' }}>{{ label(v) }}</option>{% endfor %}
      </select></div>
    <div><button class="btn" type="submit">Apply</button>
      {% if active %}<a class="reset" href="{{ url_for('dashboard.dashboard_page') }}">reset</a>{% endif %}</div>
  </form>
  <p class="scope">{% if active %}Showing {{ shown|length }} of {{ total }} incidents matching the filters.{% else %}Showing all {{ total }} incidents on record.{% endif %}
    Counts describe the record only; every link is a lead for an analyst, not a conclusion.</p>

  {% if total == 0 %}
    <p class="empty">No incidents on record yet. <a href="{{ url_for('demo.demo_page') }}">Load the demo data</a> first.</p>
  {% else %}
  <div class="tiles">
    <div class="tile"><div class="k">Incidents</div><div class="v">{{ shown|length }}</div><div class="s">in view</div></div>
    <div class="tile"><div class="k">Areas</div><div class="v">{{ n_areas }}</div><div class="s">with at least one incident</div></div>
    <div class="tile"><div class="k">Links</div><div class="v">{{ stats.links }}</div><div class="s">between incidents in view (score &ge; 0.25)</div></div>
    <div class="tile"><div class="k">Confirmed</div><div class="v">{{ stats.confirmed }}</div><div class="s">of those links, by an analyst (<a href="{{ url_for('review.review_page') }}">review</a>)</div></div>
  </div>

  {% if not shown %}
    <p class="empty">No incidents match these filters. <a href="{{ url_for('dashboard.dashboard_page') }}">Reset</a></p>
  {% else %}
  <div class="grid">
    <section class="card wide"><h2>Incidents per month</h2><div class="body">
      <div class="plot"><canvas id="c-timeline" role="img" aria-label="Bar chart of incidents per month"></canvas></div>
      {% if charts.timeline.undated %}<p class="hint">{{ charts.timeline.undated }} incident(s) without a date are not on the timeline.</p>{% endif %}
      <details><summary>Show table</summary><table><tr><th>Month</th><th>Incidents</th></tr>
        {% for l in charts.timeline.labels %}<tr><td>{{ l }}</td><td class="n">{{ charts.timeline['values'][loop.index0] }}</td></tr>{% endfor %}
      </table></details>
    </div></section>

    <section class="card"><h2>Incidents by area</h2><div class="body">
      <div class="plot tall"><canvas id="c-area" role="img" aria-label="Bar chart of incidents by area"></canvas></div>
      <p class="hint">Click a bar to filter by that area. The grey bar groups the smaller areas.</p>
      <details><summary>Show table</summary><table><tr><th>Area</th><th>Incidents</th></tr>
        {% for l in charts.area.labels %}<tr><td>{{ l }}</td><td class="n">{{ charts.area['values'][loop.index0] }}</td></tr>{% endfor %}
      </table></details>
    </div></section>

    <section class="card"><h2>Initiation method</h2><div class="body">
      <div class="plot tall"><canvas id="c-init" role="img" aria-label="Bar chart of incidents by initiation method"></canvas></div>
      <p class="hint">Click a bar to filter by that method.{% if charts.initiation.multi %}
        {{ charts.initiation.multi }} incident(s) report more than one method and count under each.{% endif %}</p>
      <details><summary>Show table</summary><table><tr><th>Initiation method</th><th>Incidents</th></tr>
        {% for l in charts.initiation.labels %}<tr><td>{{ l }}</td><td class="n">{{ charts.initiation['values'][loop.index0] }}</td></tr>{% endfor %}
      </table></details>
    </div></section>
  </div>
  {% endif %}
  {% endif %}
</div>

<script src="{{ url_for('static', filename='vendor/chart.umd.js') }}"></script>
<script id="dash-data" type="application/json">{{ charts|tojson }}</script>
<script>
(function(){
  if (!window.Chart || !document.getElementById('c-timeline')) return;
  var D = JSON.parse(document.getElementById('dash-data').textContent);
  var ACCENT = '#a8703a', MUTED = '#c4cbc6', GRID = '#eef0ee', TICK = '#7a8791';
  Chart.defaults.font.family = getComputedStyle(document.body).fontFamily;
  Chart.defaults.color = TICK;
  function axes(horizontal){
    var value = {beginAtZero: true, ticks: {precision: 0}, grid: {color: GRID}, border: {display: false}};
    var cat = {grid: {display: false}, border: {color: '#e2e6e3'}};
    return horizontal ? {x: value, y: cat} : {x: cat, y: value};
  }
  function bar(id, data, horizontal, onPick){
    // Grouped bars ("Other", "not recorded") are not one category: draw them muted.
    var n = data.keys ? data.keys.length : data.values.length;
    var fill = data.values.map(function(_, i){ return i < n ? ACCENT : MUTED; });
    return new Chart(document.getElementById(id), {
      type: 'bar',
      data: {labels: data.labels, datasets: [{label: 'Incidents', data: data.values,
             backgroundColor: fill, hoverBackgroundColor: fill.map(function(c){ return c === ACCENT ? '#8c5a2b' : '#aeb6b1'; }),
             borderRadius: 4, borderSkipped: 'start',
             categoryPercentage: 0.8, barPercentage: 0.9, maxBarThickness: horizontal ? 22 : 34}]},
      options: {indexAxis: horizontal ? 'y' : 'x', responsive: true, maintainAspectRatio: false,
                animation: false, plugins: {legend: {display: false},
                tooltip: {displayColors: false, callbacks: {label: function(c){
                  return c.parsed[horizontal ? 'x' : 'y'] + ' incident(s)'; }}}},
                scales: axes(horizontal),
                onHover: function(e, els){ e.native.target.style.cursor = (onPick && els.length) ? 'pointer' : 'default'; },
                onClick: function(e, els){ if (onPick && els.length) onPick(els[0].index); }}
    });
  }
  function filterBy(name, keys){
    return function(i){
      if (i >= keys.length) return;          // "Other" / "not recorded" have no single value
      var u = new URL(window.location.href);
      u.searchParams.set(name, keys[i]);
      window.location.href = u.toString();
    };
  }
  bar('c-timeline', D.timeline, false, null);
  bar('c-area', D.area, true, filterBy('area', D.area.keys));
  bar('c-init', D.initiation, true, filterBy('initiation', D.initiation.keys));
})();
</script>
</body>
</html>
"""
