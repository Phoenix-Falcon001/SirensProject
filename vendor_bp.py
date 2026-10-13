"""Vendor check page: proves htmx and Chart.js load from static/vendor/.

A standalone Flask Blueprint (wired into app.py with one line). The page loads
both libraries through url_for('static', ...) only, shows the version each one
reports, draws one tiny chart and has one htmx button that swaps in a small
fragment from the server. No CDN, no network: if this page works with Wi-Fi
off, the front-end libraries are truly offline.
"""
from __future__ import annotations

from datetime import datetime

from flask import Blueprint, render_template_string

vendor_bp = Blueprint("vendor", __name__)

# What static/vendor/README.md says we committed.
EXPECTED = {"htmx": "2.0.11", "Chart.js": "4.5.1"}


@vendor_bp.route("/vendor-check")
def vendor_check():
    return render_template_string(_TEMPLATE, expected=EXPECTED)


@vendor_bp.route("/vendor-check/ping")
def vendor_ping():
    """Tiny HTML fragment for the htmx button to swap into the page."""
    now = datetime.now().strftime("%H:%M:%S")
    return render_template_string(
        '<span class="ok">htmx swap works</span> '
        '<span class="stat">fragment served by Flask at {{ now }}</span>', now=now)


_TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sirens — Vendor check</title>
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
  .wrap{max-width:1100px;margin:0 auto;padding:40px 48px 90px}
  @media(max-width:1000px){.wrap{padding:28px 20px 60px}}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:9px;margin-bottom:24px;
        box-shadow:0 1px 2px rgba(22,32,43,.04),0 4px 16px rgba(22,32,43,.05)}
  .card h2{margin:0;padding:14px 18px;border-bottom:1px solid var(--line-2);
           font-size:12px;letter-spacing:.14em;text-transform:uppercase;
           color:var(--ink-soft);font-family:var(--mono);font-weight:600}
  .card .body{padding:24px 26px}
  table{border-collapse:collapse;font-size:14px}
  th,td{text-align:left;padding:6px 18px 6px 0;border-bottom:1px solid var(--line-2)}
  th{color:var(--ink-soft);font-weight:600}
  .mono{font-family:var(--mono)}
  .ok{color:#3d6b45;font-weight:600}
  .bad{color:#a4332b;font-weight:600}
  .stat{font-family:var(--mono);font-size:12px;color:var(--weak)}
  .note{font-size:13px;color:var(--ink-soft);background:var(--line-2);
        border-radius:4px;padding:10px 12px;margin-top:16px}
  .btn{font-family:var(--sans);font-size:14px;font-weight:600;padding:9px 15px;
       border-radius:4px;border:1px solid var(--ink);background:var(--ink);
       color:#fff;cursor:pointer;margin-right:14px}
  .btn:hover{background:#22303d}
  .chartbox{max-width:420px;height:180px}
</style>
</head>
<body>
<div class="bar">
  <div class="brand">Sirens<small>vendor check · offline front-end libraries</small></div>
  <nav class="nav">
    <a href="{{ url_for('incident_map') }}">map</a>
    <a href="{{ url_for('link_tree') }}">link tree</a>
    <a href="{{ url_for('brief.brief_page') }}">brief</a>
    <a href="{{ url_for('index') }}">&#8592; console</a>
  </nav>
</div>
<div class="wrap">
  <div class="card"><h2>Libraries served from static/vendor/</h2><div class="body">
    <table>
      <tr><th>Library</th><th>Expected</th><th>Detected in browser</th><th>Status</th></tr>
      <tr><td>htmx</td><td class="mono">{{ expected['htmx'] }}</td>
          <td class="mono" id="v-htmx">not loaded</td><td id="s-htmx" class="bad">missing</td></tr>
      <tr><td>Chart.js</td><td class="mono">{{ expected['Chart.js'] }}</td>
          <td class="mono" id="v-chart">not loaded</td><td id="s-chart" class="bad">missing</td></tr>
    </table>
    <p class="note">This page loads no external resources. The real offline test is to open it
      with Wi-Fi turned off: both rows should read "ok", the chart should draw and the button should work.</p>
  </div></div>

  <div class="card"><h2>Chart.js: one tiny chart</h2><div class="body">
    <div class="chartbox"><canvas id="tiny"></canvas></div>
    <p class="stat">Placeholder values for the check only, not incident data.</p>
  </div></div>

  <div class="card"><h2>htmx: swap a fragment from the server</h2><div class="body">
    <button class="btn" hx-get="{{ url_for('vendor.vendor_ping') }}" hx-target="#pong" hx-swap="innerHTML">Ask the server</button>
    <span id="pong" class="stat">no request sent yet</span>
  </div></div>
</div>

<script src="{{ url_for('static', filename='vendor/htmx.min.js') }}"></script>
<script src="{{ url_for('static', filename='vendor/chart.umd.js') }}"></script>
<script>
  function mark(lib, ver, expected){
    var v = document.getElementById('v-' + lib), s = document.getElementById('s-' + lib);
    if (!ver) return;
    v.textContent = ver;
    s.textContent = ver === expected ? 'ok' : 'loaded, unexpected version';
    s.className = ver === expected ? 'ok' : 'bad';
  }
  mark('htmx', window.htmx && htmx.version, {{ expected['htmx']|tojson }});
  mark('chart', window.Chart && Chart.version, {{ expected['Chart.js']|tojson }});
  if (window.Chart) {
    new Chart(document.getElementById('tiny'), {
      type: 'bar',
      data: {labels: ['A', 'B', 'C', 'D'],
             datasets: [{label: 'placeholder', data: [3, 5, 2, 4],
                         backgroundColor: '#a8703a', borderRadius: 3}]},
      options: {responsive: true, maintainAspectRatio: false, animation: false,
                plugins: {legend: {display: false}},
                scales: {y: {beginAtZero: true, ticks: {precision: 0}}}}
    });
  }
</script>
</body>
</html>
"""
