"""Link review: the analyst's Confirm / Reject / Unsure workbench.

A standalone Flask Blueprint (wired into app.py with one line). /review lists
every link the link tree shows (same matcher, same threshold) with its score,
band and the machine's reasons, and lets the analyst record a decision and
notes on each one. Buttons use htmx (served from static/vendor/), so only the
link card being changed is swapped: no page reload.

Analyst decisions live in linker/decisions.py's own append-only tables. The
machine output (scores, reasons, clusters) is never modified, and every
decision can be undone. Decided or annotated links stay listed even if their
score later falls below the threshold, so no decision is ever hidden.
"""
from __future__ import annotations

import re

from flask import Blueprint, abort, render_template_string, request

from linker import decisions, store
from linker.ai import _score_band
from linker.match import Matcher
import report_view

review_bp = Blueprint("review", __name__)

THRESHOLD = 0.25        # same as /tree, so both pages show the same links
FILTERS = ("all", "open", "confirm", "reject", "unsure")


def _on_tree(link) -> bool:
    """The rule Matcher.all_pairs uses to keep a link."""
    return link.score >= THRESHOLD and bool(link.shared_features or link.shared_entities)


def _dom_id(a: str, b: str) -> str:
    return "lk-" + re.sub(r"[^A-Za-z0-9_-]", "_", f"{a}--{b}")


def _row(link, by_id, decided, notes) -> dict:
    a, b = sorted((link.a, link.b))
    return {
        "a": a, "b": b, "inc_a": by_id[a], "inc_b": by_id[b],
        "dom_id": _dom_id(a, b),
        "score": link.score, "band": _score_band(link.score),
        "reasons": [report_view.reason_label(x) for x in link.reasons],
        "text_a": report_view.highlight(by_id[a].narrative or "",
                                        report_view.shared_terms(by_id[a], set(link.shared_features))),
        "text_b": report_view.highlight(by_id[b].narrative or "",
                                        report_view.shared_terms(by_id[b], set(link.shared_features))),
        "search": " ".join([a, b, by_id[a].location or "", by_id[b].location or ""]).lower(),
        "below": not _on_tree(link),
        "decision": decided.get((a, b)),
        "notes": notes.get((a, b), []),
    }


def build_rows() -> list[dict]:
    """Every link on the tree, plus any decided/annotated link that dropped off it."""
    incidents = store.all_incidents()
    by_id = {i.incident_id: i for i in incidents}
    matcher = Matcher().fit(incidents)
    decided = decisions.current_decisions()
    notes = decisions.all_notes()
    links = matcher.all_pairs(incidents, threshold=THRESHOLD)
    seen = {tuple(sorted((l.a, l.b))) for l in links}
    for a, b in sorted((set(decided) | set(notes)) - seen):
        if a in by_id and b in by_id:
            links.append(matcher.score(by_id[a], by_id[b]))
    rows = [_row(l, by_id, decided, notes) for l in links]
    rows.sort(key=lambda r: r["score"], reverse=True)
    return rows


def _one_row(a: str, b: str) -> dict:
    incidents = store.all_incidents()
    by_id = {i.incident_id: i for i in incidents}
    if a not in by_id or b not in by_id:
        abort(404, "unknown incident id")
    link = Matcher().fit(incidents).score(by_id[a], by_id[b])
    a, b = sorted((a, b))
    return _row(link, by_id,
                {(a, b): decisions.current_decision(a, b)},
                {(a, b): decisions.notes_for(a, b)})


def _tally(rows=None) -> dict:
    """Decisions made, plus how many links are listed and still open."""
    counts = {d: 0 for d in decisions.DECISIONS}
    for d in decisions.current_decisions().values():
        counts[d] = counts.get(d, 0) + 1
    rows = build_rows() if rows is None else rows
    counts["all"] = len(rows)
    counts["open"] = sum(1 for r in rows if not r["decision"])
    counts["done_pct"] = round(100 * (len(rows) - counts["open"]) / len(rows)) if rows else 0
    return counts


@review_bp.route("/review")
def review_page():
    show = request.args.get("show", "all")
    if show not in FILTERS:
        show = "all"
    rows = build_rows()
    if show == "open":
        shown = [r for r in rows if not r["decision"]]
    elif show != "all":
        shown = [r for r in rows if r["decision"] == show]
    else:
        shown = rows
    return render_template_string(_CARD + _PAGE, rows=shown, total=len(rows),
                                  show=show, filters=FILTERS, tally=_tally(rows),
                                  db_count=store.count())


@review_bp.route("/review/decide", methods=["POST"])
def decide():
    a, b = request.form.get("a", ""), request.form.get("b", "")
    decision = request.form.get("decision", "")
    analyst = request.form.get("analyst", "")[:40]
    if decision == "undo":
        _one_row(a, b)                         # 404 on unknown ids
        decisions.clear_decision(a, b, analyst=analyst)
    else:
        try:
            _one_row(a, b)
            decisions.set_decision(a, b, decision, analyst=analyst)
        except ValueError as e:
            return str(e), 400
    return _fragment(a, b)


@review_bp.route("/review/note", methods=["POST"])
def note():
    a, b = request.form.get("a", ""), request.form.get("b", "")
    try:
        _one_row(a, b)
        decisions.add_note(a, b, request.form.get("note", "")[:2000],
                           analyst=request.form.get("analyst", "")[:40])
    except ValueError as e:
        return str(e), 400
    return _fragment(a, b)


def _fragment(a, b):
    """The refreshed link card, plus the decision tally swapped out-of-band."""
    return render_template_string(_CARD + "{{ card(r) }}" + _TALLY_OOB,
                                  r=_one_row(a, b), tally=_tally())


_CARD = r"""{% import "forms_ui.html" as f %}{% macro card(r) %}
<article class="link{% if r.decision %} is-{{ r.decision }}{% endif %}" id="{{ r.dom_id }}" tabindex="-1" data-search="{{ r.search }}">
  <div class="top">
    <span class="band {{ r.band }}">{{ r.band|capitalize }}</span>
    <span class="score">{{ '%.2f'|format(r.score) }}</span>
    <span class="pair"><span class="mono">{{ r.a }}</span> and <span class="mono">{{ r.b }}</span></span>
    {% if r.below %}<span class="below">below the link threshold now</span>{% endif %}
    <span class="verdict v-{{ r.decision or 'open' }}">{{ {'confirm':'Confirmed','reject':'Rejected','unsure':'Unsure'}.get(r.decision, 'Not reviewed') }}</span>
  </div>
  <div class="why">
    {% if r.reasons %}<ul>{% for x in r.reasons %}<li>{{ x }}</li>{% endfor %}</ul>
    {% else %}<p class="weak">No shared evidence at the current score.</p>{% endif %}
  </div>
  <details class="cmp">
    <summary>Compare the two reports</summary>
    <div class="cmp-cols">
      {% for id, inc, text in [(r.a, r.inc_a, r.text_a), (r.b, r.inc_b, r.text_b)] %}
      <div><h3><span class="mono">{{ id }}</span> {{ inc.location or 'No location' }}{% if inc.date %}, {{ inc.date }}{% endif %}</h3>
        <p dir="auto">{{ text }}</p>
        {% set hp = photo_url(inc) %}{% if hp %}<a href="{{ hp }}" target="_blank" rel="noopener"><img src="{{ hp }}" alt="Photo on file for {{ id }}"></a>{% endif %}</div>
      {% endfor %}
    </div>
  </details>
  <div class="actions">
    {% for d, label, key in [('confirm','Confirm','C'),('reject','Reject','R'),('unsure','Unsure','U')] %}
    <button type="button" class="dbtn d-{{ d }}{% if r.decision == d %} on{% endif %}" data-key="{{ key }}"
      hx-post="{{ url_for('review.decide') }}" hx-include="#analyst"
      hx-vals='{{ {"a": r.a, "b": r.b, "decision": d}|tojson }}'
      hx-target="#{{ r.dom_id }}" hx-swap="outerHTML"><kbd>{{ key }}</kbd>{{ label }}</button>
    {% endfor %}
    {% if r.decision %}
    <button type="button" class="dbtn undo" data-key="Z"
      hx-post="{{ url_for('review.decide') }}" hx-include="#analyst"
      hx-vals='{{ {"a": r.a, "b": r.b, "decision": "undo"}|tojson }}'
      hx-target="#{{ r.dom_id }}" hx-swap="outerHTML"><kbd>Z</kbd>Undo</button>
    {% endif %}
  </div>
  <div class="notes">
    {% for n in r.notes %}
    <div class="note"><span class="meta">{{ n.created_at.replace('T', ' ')[:16] }}{% if n.analyst %}, {{ n.analyst }}{% endif %}</span> <span dir="auto">{{ n.note }}</span></div>
    {% endfor %}
    <form class="f-form f-inline" novalidate hx-post="{{ url_for('review.note') }}" hx-include="#analyst"
          hx-target="#{{ r.dom_id }}" hx-swap="outerHTML">
      <input type="hidden" name="a" value="{{ r.a }}"><input type="hidden" name="b" value="{{ r.b }}">
      {{ f.input("note", "Add a note", "note", id="note-" ~ r.dom_id, placeholder="e.g. dates two months apart",
                 rules="required", required_msg="Write a note before adding it.", extra='maxlength="2000"') }}
      <button type="submit" class="f-btn ghost small" data-busy-text="Saving…">Add note</button>
    </form>
  </div>
</article>
{% endmacro %}"""

_TALLY_OOB = r"""
<span id="tally" hx-swap-oob="true">{{ tally.all - tally.open }} of {{ tally.all }} reviewed<i style="--p:{{ tally.done_pct }}%"></i></span>
{% for key in ['open','all','confirm','reject','unsure'] %}<span class="n" id="n-{{ key }}" hx-swap-oob="true">{{ tally[key] }}</span>{% endfor %}"""

_PAGE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sirens — Review links</title>
<link rel="stylesheet" href="{{ url_for('static', filename='sirens.css') }}">
{{ f.assets() }}
<link rel="stylesheet" href="{{ url_for('static', filename='review.css') }}">
</head>
<body class="rv">
<div class="bar">
  <a class="brand" href="{{ url_for('home.home_page') }}">Sirens<small>C-IED Incident Link Console</small></a>
  {{ sirens_menu('review') }}
</div>
<main class="wrap">
  <div class="rhead">
    <div>
      <h1>Review links</h1>
      <p class="lead">Sirens suggests; you decide. Each link is a lead to check, never a conclusion. Your decisions
        and notes are kept apart from the scores, and every decision can be undone.</p>
    </div>
    <div class="progress"><span id="tally">{{ tally.all - tally.open }} of {{ tally.all }} reviewed<i style="--p:{{ tally.done_pct }}%"></i></span></div>
  </div>

  {% set names = {'all':'all','open':'no decision','confirm':'confirmed','reject':'rejected','unsure':'unsure'} %}
  <div class="tools">
    <nav class="tabs" aria-label="Filter by decision">
      {% for key, label in [('open','Not reviewed'),('all','All'),('confirm','Confirmed'),('reject','Rejected'),('unsure','Unsure')] %}
      <a href="{{ url_for('review.review_page', show=key) }}" class="{{ 'on' if key == show else '' }}"{% if key == show %} aria-current="true"{% endif %}>{{ label }} <span class="n" id="n-{{ key }}">{{ tally[key] }}</span></a>
      {% endfor %}
    </nav>
    <input type="search" id="find" placeholder="Find by ID or place" aria-label="Find links by incident ID or place">
    <form class="f-form who" onsubmit="return false" aria-label="Analyst">
      {{ f.input("analyst", "Your initials", "analyst", placeholder="e.g. BE", optional=True, extra='maxlength="40"') }}
    </form>
  </div>
  {{ f.chips([] if show == 'all' else [("Decision: " ~ names[show], url_for('review.review_page'))], url_for('review.review_page')) }}
  <p class="keys" aria-label="Keyboard shortcuts"><kbd>J</kbd><kbd>K</kbd> next and previous
    <kbd>C</kbd> confirm <kbd>R</kbd> reject <kbd>U</kbd> unsure <kbd>Z</kbd> undo
    <kbd>Enter</kbd> compare <kbd>N</kbd> note</p>
  <div id="flash" role="alert"></div>

  {% if db_count == 0 %}
    <p class="empty">No incidents on record yet. <a href="{{ url_for('demo.demo_page') }}">Load the demo data</a> first.</p>
  {% elif not rows %}
    <p class="empty">{{ 'Nothing left to review. Every link has a decision.' if show == 'open' else 'No links match this filter.' }}</p>
  {% endif %}
  <div id="links">{% for r in rows %}{{ card(r) }}{% endfor %}</div>
  <p class="empty" id="nofind" hidden>No link matches that search.</p>
</main>
<footer>Links shown: score 0.25 or more with shared evidence, the same set as the link tree. Bands: weak under 0.40, medium under 0.66, strong above.</footer>

<script src="{{ url_for('static', filename='vendor/htmx.min.js') }}"></script>
<script src="{{ url_for('static', filename='review.js') }}"></script>
</body>
</html>
"""
