"""Web routes for the record-based pre-arrival brief.

A standalone Flask Blueprint so this feature can be wired into app.py with a
two-line import/registration, rather than another edit to the large app.py
template string. Retrieval-only: never identifies what's in front of the
responder, never gives handling/render-safe guidance — see linker/query.py.
"""
from __future__ import annotations

import pathlib
from datetime import date

from flask import Blueprint, render_template_string, request

from linker import store, ai
from linker.extract import FeatureExtractor
from linker.query import area_brief
import report_view
import ui_icons

ROOT = pathlib.Path(__file__).resolve().parent
TAXONOMY = ROOT / "data" / "taxonomy" / "cied_lexicon.json"

brief_bp = Blueprint("brief", __name__)
brief_bp.add_app_template_filter(lambda k: report_view.feature_label(k), "feature_label")
_EXTRACTOR = FeatureExtractor(TAXONOMY, use_ner=True)


@brief_bp.route("/brief", methods=["GET", "POST"])
def brief_page():
    result = None
    error = None
    form = {}
    assessment = None
    if request.method == "POST":
        location = (request.form.get("location") or "").strip()
        describe = (request.form.get("describe") or "").strip() or None
        use_ai = request.form.get("use_ai") == "on"
        form = {"location": location, "describe": describe or "", "use_ai": use_ai}
        if not location:
            error = "Enter a location to brief on — e.g. a town or street name used in your reports."
        else:
            incidents = store.all_incidents()
            result = area_brief(incidents, location=location, describe=describe,
                                 extractor=_EXTRACTOR)
            if use_ai:
                assessment = ai.assess_area(result)
    all_locations = sorted({i.location for i in store.all_incidents() if i.location})
    ai_ok, ai_reason = ai.available()
    span = ""
    if result and result.area_incidents:
        dates = sorted(i.date for i in result.area_incidents if i.date)
        if dates:
            span = dates[0] if dates[0] == dates[-1] else f"{dates[0]} to {dates[-1]}"
    return render_template_string(_TEMPLATE, brief=result, form=form, error=error,
                                   db_count=store.count(), locations=all_locations,
                                   assessment=assessment, ai_ok=ai_ok, ai_reason=ai_reason,
                                   span=span, today=date.today().isoformat(), icon=ui_icons.icon,
                                   feature_label=report_view.feature_label,
                                   value_label=report_view.value_label)


_TEMPLATE = r"""{% import "forms_ui.html" as f %}<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sirens — Pre-arrival brief{% if brief %}: {{ brief.location_query }}{% endif %}</title>
<link rel="stylesheet" href="{{ url_for('static', filename='sirens.css') }}">
{{ f.assets() }}
<link rel="stylesheet" href="{{ url_for('static', filename='brief.css') }}">
</head>
<body class="bf">
<div class="bar">
  <a class="brand" href="{{ url_for('home.home_page') }}">Sirens<small>C-IED Incident Link Console</small></a>
  {{ sirens_menu('brief') }}
</div>
<main class="wrap">
  <div class="bhead">
    <h1>Pre-arrival brief</h1>
    <p class="lead">What past reports say about a place, before you get there. {{ db_count }} report{{ '' if db_count == 1 else 's' }} on record.</p>
  </div>

  <form class="f-form ask" method="post" action="/brief" novalidate>
    {{ f.form_error(error, lead='Brief not run.') }}
    <div class="ask-grid">
      {{ f.input("location", "Place", "brief_location", id="location", value=form.location, list="recordplaces",
                 placeholder="e.g. Yaroun", rules="required place:recordplaces",
                 required_msg="Enter a place to brief on.",
                 place_msg="This place is not in the record yet; the brief may find no past reporting.") }}
      <datalist id="recordplaces">{% for loc in locations %}<option value="{{ loc }}">{% endfor %}</datalist>
      {{ f.textarea("describe", "Description to compare with", "brief_describe", value=form.describe, optional=True, rows=2,
                    placeholder="e.g. small green fin-stabilised rocket, intact, about 1 m") }}
    </div>
    <div class="f-actions">
      <button class="f-btn" type="submit" data-busy-text="Retrieving…">Get brief</button>
      {{ f.toggle("use_ai", "AI area summary", "brief_use_ai", checked=form.use_ai, disabled=not ai_ok,
                  note=('' if ai_ok else 'Off: the local AI model is not running.')) }}
    </div>
  </form>

  {% if not brief %}
    <p class="hint0">Enter a town, village or street used in your reports. The brief lists the object types reported
      there, the features that tend to appear together, and every report on record for the place.</p>
  {% else %}
  <article class="sheet" aria-labelledby="sheet-t">
    <header class="sheet-head">
      <div>
        <h2 id="sheet-t">{{ brief.location_query }}</h2>
        <p class="when">Brief prepared {{ today }} from {{ brief.n_in_area }} report{{ '' if brief.n_in_area == 1 else 's' }} on record for this place{% if span %}, dated {{ span }}{% endif %}.</p>
      </div>
      <div class="sheet-actions">
        <button type="button" class="btn ghost" onclick="window.print()">Print</button>
        <a class="btn ghost" href="{{ url_for('incident_map') }}">Open the map</a>
      </div>
    </header>
    <div class="caution" role="note">{{ icon('warning') }}<div><strong>Record-based only.</strong> This is what was reported here
      before. It does not identify the object in front of you and gives no handling guidance. A qualified specialist
      confirms every identification.</div></div>

    {% if brief.n_in_area == 0 %}
      <p class="none">No report on record matches this place. Check the spelling, or try the caza or a nearby town.</p>
    {% endif %}

    <div class="cols">
      <section>
        <h3>Object types reported here</h3>
        {% if brief.object_profile %}
          <table class="tbl">
            <thead><tr><th>Type</th><th class="r">Reports</th><th>Most recent</th></tr></thead>
            <tbody>{% for t, c, recent in brief.object_profile %}
            <tr><td><a href="{{ url_for('munitions.munitions_page') }}#ref-{{ t }}">{{ value_label('object_type', t) }}</a></td><td class="r num">{{ c }}</td><td>{{ recent or 'no date' }}</td></tr>
            {% endfor %}</tbody>
          </table>
        {% else %}<p class="muted">No object type is named in the reports for this place.</p>{% endif %}
      </section>
      <section>
        <h3>Features that recur here</h3>
        {% if brief.area_signature %}
          <ul class="feat">{% for s in brief.area_signature %}<li>{{ feature_label(s) }}</li>{% endfor %}</ul>
          <p class="muted small">Present in at least half of the reports for this place.</p>
        {% else %}<p class="muted">No feature appears in most reports for this place.</p>{% endif %}
      </section>
    </div>

    {% if assessment %}
    <section class="ai">
      <h3>AI area summary{% if assessment.ok %} <span class="model">{{ assessment.model }}</span>{% endif %}</h3>
      {% if assessment.ok %}<p>{{ assessment.text }}</p>
        <p class="muted small">Written by a small local model. Check it against the tables above before relying on it.</p>
      {% else %}<p class="muted">Summary unavailable: {{ assessment.reason }}</p>{% endif %}
    </section>
    {% endif %}

    {% if brief.describe_query %}
    <section>
      <h3>Closest past records to the description</h3>
      <p class="muted small">Compared with: “{{ brief.describe_query }}”. Ranking only; it does not say what the object is.</p>
      {% if brief.matches %}
        <ol class="rows">{% for m in brief.matches %}
          <li><span class="score num">{{ '%.2f'|format(m.score) }}</span>
            <span><strong class="mono">{{ m.incident_id }}</strong> {{ m.location or 'No location' }}{% if m.date %}, {{ m.date }}{% endif %}
              <span class="why">Shares {{ m.shared|map('feature_label')|join(', ') }}</span>
              {% if m.photo %}<span class="why">Reference photo on file: {{ m.photo }}</span>{% endif %}</span></li>
        {% endfor %}</ol>
      {% else %}<p class="muted">No record for this place matched the description closely enough.</p>{% endif %}
    </section>
    {% endif %}

    {% if brief.area_incidents %}
    <section>
      <h3>Incidents on record here ({{ brief.area_incidents|length }})</h3>
      <ol class="incs">
        {% for inc in brief.area_incidents %}
        <li>
          <div class="inc-top"><strong class="mono">{{ inc.incident_id }}</strong>
            <span>{{ inc.location or 'No location' }}</span><span class="date">{{ inc.date or 'no date' }}</span></div>
          <p class="text" dir="auto">{{ inc.narrative }}</p>
          {% if inc.features %}<p class="tags">{% for ft in inc.features[:8] %}<span>{{ feature_label(ft.facet ~ '=' ~ ft.value) }}</span>{% endfor %}</p>{% endif %}
          {% if inc.persons or inc.groups or inc.phones %}
          <p class="tags ent">{% for p in inc.persons %}<span>Person: {{ p }}</span>{% endfor %}{% for g in inc.groups %}<span>Group: {{ g }}</span>{% endfor %}{% for ph in inc.phones %}<span>Phone: {{ ph }}</span>{% endfor %}</p>
          {% endif %}
          {% set purl = photo_url(inc) %}
          {% if purl %}<a href="{{ purl }}" target="_blank" rel="noopener"><img src="{{ purl }}" alt="Photo for {{ inc.incident_id }}"></a>{% endif %}
        </li>
        {% endfor %}
      </ol>
    </section>
    {% endif %}
  </article>
  {% endif %}
</main>
<footer>Retrieval from past reporting only. Sirens never identifies an object and never gives handling guidance.</footer>
</body></html>"""
