"""Mobile app interface for the internal (Army) server: /api/v1.

Used by military and admin phones over the Army VPN. Every call except login
needs ``Authorization: Bearer <token>``; every answer is JSON.

Access is decided here, on the server, never on the phone:
* the account's role level gives its permissions (linker/accounts.py);
* incidents, civilian reports and warnings are filtered to the account's
  assigned cazas. A record outside them answers 404, exactly as if it did not
  exist, so its existence is not revealed.

Wired into app.py with ``api_bp.register(app, ...)``; app.py passes in the
helpers it owns (caza of an incident, the extractor, the metadata sidecar)
so this module does not import app.py.
"""
from __future__ import annotations

import dataclasses
import pathlib
import re
from collections import Counter
from datetime import date
from functools import wraps

from flask import Blueprint, Response, g, jsonify, request, send_file

import dashboard_bp
import map_bp
import review_bp
from linker import accounts, civil, decisions, regions, stats, store
from linker.ai import _score_band
from linker.cluster import Clusterer
from linker.grid_ref import to_mgrs
from linker.match import Matcher
from linker.models import Incident
from linker.query import area_brief

api_bp = Blueprint("api", __name__, url_prefix="/api/v1")

API_VERSION = 1
_HELPERS: dict = {}


def register(app, *, regions_of, extractor, put_meta, fmt_grid, munitions, map_markers):
    """regions_of(incidents) -> {incident id: caza or None}; extractor.extract(incident);
    put_meta(incident_id, dict); fmt_grid(lat, lon) -> display label;
    munitions: [(key, label, colour)];
    map_markers(incidents) -> (markers, legend, unplaced)."""
    _HELPERS.update(regions_of=regions_of, extractor=extractor, put_meta=put_meta,
                    fmt_grid=fmt_grid, munitions=munitions, map_markers=map_markers)
    app.register_blueprint(api_bp)


# -- plumbing ----------------------------------------------------------------
def _err(msg: str, status: int):
    return jsonify({"error": msg}), status


@api_bp.errorhandler(accounts.AccountError)
@api_bp.errorhandler(civil.CivilError)
def _rule_broken(e):
    return _err(str(e), 400)


@api_bp.after_request
def _no_store(resp: Response):
    # Nothing from this API may sit in a shared cache or a proxy.
    resp.headers["Cache-Control"] = "no-store"
    return resp


def _body() -> dict:
    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else {}


def _token() -> str:
    h = request.headers.get("Authorization", "")
    return h[7:].strip() if h.lower().startswith("bearer ") else ""


def login_required(perm: str | None = None):
    def deco(fn):
        @wraps(fn)
        def inner(*a, **kw):
            user = accounts.user_for_token(_token())
            if not user:
                return _err("not signed in", 401)
            if perm and not accounts.can(user, perm):
                return _err("your role does not allow this", 403)
            g.user = user
            return fn(*a, **kw)
        return inner
    return deco


def _me(user: dict) -> dict:
    return {**user, "permissions": sorted(accounts.permissions(user)),
            "all_regions": user["role"] == "admin"}


# -- auth --------------------------------------------------------------------
@api_bp.post("/auth/login")
def login():
    b = _body()
    try:
        token, user, expires = accounts.login(b.get("username", ""), b.get("password", ""))
    except accounts.AccountError as e:
        return _err(str(e), 401)
    return jsonify({"token": token, "expires_at": expires, "user": _me(user)})


@api_bp.post("/auth/logout")
@login_required()
def logout():
    accounts.logout(_token())
    return jsonify({"ok": True})


@api_bp.get("/me")
@login_required()
def me():
    return jsonify(_me(g.user))


@api_bp.post("/me/password")
@login_required()
def my_password():
    b = _body()
    accounts.change_password(g.user["id"], b.get("current", ""), b.get("new", ""))
    return jsonify({"ok": True})


@api_bp.get("/meta")
@login_required()
def meta():
    """Lists the app needs for its forms."""
    return jsonify({
        "api_version": API_VERSION,
        "regions": regions.names(),
        "levels": list(accounts.LEVELS),
        "munitions": [{"key": k, "label": l} for k, l, _c in _HELPERS["munitions"]],
        "civil_statuses": list(civil.STATUSES),
        "warning_severities": list(civil.SEVERITIES),
    })


# -- incidents ---------------------------------------------------------------
LINK_THRESHOLD = 0.25    # same as the link tree, review page and dashboard


def _visible(incidents=None) -> list[tuple[Incident, str | None]]:
    """(incident, caza) for every incident in the user's regions."""
    incidents = store.all_incidents() if incidents is None else incidents
    cazas = _HELPERS["regions_of"](incidents)
    return [(i, cazas[i.incident_id]) for i in incidents
            if accounts.sees_region(g.user, cazas[i.incident_id])]


def _one_visible(incident_id):
    inc = store.get_incident(incident_id)
    if not inc:
        return None, None
    caza = _HELPERS["regions_of"]([inc])[inc.incident_id]
    return (inc, caza) if accounts.sees_region(g.user, caza) else (None, None)


def _incident_summary(inc: Incident, caza) -> dict:
    snip = (inc.narrative or "").strip().replace("\n", " ")
    return {"id": inc.incident_id, "date": inc.date, "location": inc.location,
            "caza": caza, "summary": snip[:160] + ("…" if len(snip) > 160 else "")}


@api_bp.get("/incidents")
@login_required("incidents:read")
def incidents():
    want = request.args.get("caza")
    out = [_incident_summary(inc, caza) for inc, caza in _visible()
           if not want or caza == want]
    out.sort(key=lambda d: d["date"] or "", reverse=True)
    return jsonify({"incidents": out})


@api_bp.get("/incidents/<incident_id>")
@login_required("incidents:read")
def incident(incident_id):
    inc, caza = _one_visible(incident_id)
    if not inc:
        return _err("not found", 404)
    d = inc.to_dict()
    d["caza"] = caza
    return jsonify(d)


_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


@api_bp.post("/incidents")
@login_required("incidents:create")
def file_incident():
    """File a new report. Same rules as the web form: a narrative is required;
    the caza must be one of the user's regions."""
    b = _body()
    narrative = (b.get("narrative") or "").strip()
    caza = (b.get("caza") or "").strip()
    street = (b.get("street") or "").strip()
    when = (b.get("date") or date.today().isoformat()).strip()
    if not narrative:
        return _err("a report narrative is required", 400)
    if caza not in regions.names():
        return _err("choose a caza from the list", 400)
    if not accounts.sees_region(g.user, caza):
        return _err("that caza is outside your assigned regions", 403)
    if not _DATE.match(when):
        return _err("date must be YYYY-MM-DD", 400)
    munition = (b.get("munition") or "").strip() or None
    if munition and munition not in {k for k, _l, _c in _HELPERS["munitions"]}:
        return _err("unknown munition type", 400)
    lat, lon = b.get("lat"), b.get("lon")
    grid = None
    if lat is not None or lon is not None:
        try:
            lat, lon = float(lat), float(lon)
        except (TypeError, ValueError):
            return _err("lat and lon must both be numbers", 400)
        if regions.caza_at(lat, lon) is None:
            return _err("that position is outside Lebanon", 400)
        grid = _HELPERS["fmt_grid"](lat, lon)

    client_ref = (b.get("client_ref") or "").strip()[:64] or None
    if client_ref:
        done = _ref_lookup(g.user["id"], client_ref)
        if done and store.get_incident(done):
            # A retry from the phone's queue: answer with the report already filed.
            d = store.get_incident(done).to_dict()
            d["caza"], d["duplicate"] = caza, True
            return jsonify(d), 200
    inc = Incident(incident_id=store.next_incident_id(), date=when,
                   location=", ".join(p for p in (street, caza) if p),
                   narrative=narrative)
    _HELPERS["extractor"].extract(inc)
    store.add_incident(inc)
    _HELPERS["put_meta"](inc.incident_id, {
        "caza": caza, "street": street or None, "munition": munition,
        "lat": lat, "lon": lon, "grid": grid})
    if client_ref:
        _ref_save(g.user["id"], client_ref, inc.incident_id)
    accounts.audit(g.user["username"], "incident.create",
                   {"id": inc.incident_id, "caza": caza})
    d = inc.to_dict()
    d["caza"] = caza
    d["mgrs"] = to_mgrs(lat, lon) if lat is not None else None
    d["network"] = _network(inc.incident_id)
    return jsonify(d), 201


_REFS_SCHEMA = """CREATE TABLE IF NOT EXISTS api_client_refs (
    user_id INTEGER NOT NULL, client_ref TEXT NOT NULL, incident_id TEXT NOT NULL,
    PRIMARY KEY (user_id, client_ref))"""


def _ref_lookup(user_id, ref):
    conn = store.connect()
    conn.execute(_REFS_SCHEMA)
    r = conn.execute("SELECT incident_id FROM api_client_refs WHERE user_id=? AND client_ref=?",
                     (user_id, ref)).fetchone()
    conn.close()
    return r["incident_id"] if r else None


def _ref_save(user_id, ref, incident_id):
    conn = store.connect()
    conn.execute(_REFS_SCHEMA)
    conn.execute("INSERT OR IGNORE INTO api_client_refs VALUES (?,?,?)",
                 (user_id, ref, incident_id))
    conn.commit()
    conn.close()


# -- analysis: network, brief, links, dashboard ------------------------------
def _scored(incidents):
    """Links over the whole record (same matcher and threshold as the web
    pages, so scores agree everywhere)."""
    return Matcher().fit(incidents).all_pairs(incidents, threshold=LINK_THRESHOLD)


def _network(incident_id) -> dict:
    """The incident's candidate network, limited to what the user may see."""
    incidents = store.all_incidents()
    seen = dict((i.incident_id, c) for i, c in _visible(incidents))
    by_id = {i.incident_id: i for i in incidents}
    links = _scored(incidents)
    clusters = Clusterer(incidents, links).clusters(singletons=False) if links else []
    cluster = next((c for c in clusters if incident_id in c.members), None)
    current = decisions.current_decisions()
    own = []
    for l in links:
        if incident_id not in (l.a, l.b):
            continue
        other = l.b if l.a == incident_id else l.a
        if other not in seen or not cluster or other not in cluster.members:
            continue
        own.append({"other": _incident_summary(by_id[other], seen[other]),
                    "score": round(l.score, 3), "band": _score_band(l.score),
                    "reasons": l.reasons,
                    "decision": current.get(tuple(sorted((l.a, l.b))))})
    own.sort(key=lambda x: x["score"], reverse=True)
    members = [m for m in (cluster.members if cluster else []) if m in seen]
    return {"cluster": cluster.cluster_id if cluster and members else None,
            "members": members, "signature": cluster.signature if cluster else [],
            "links": own,
            "tentative": bool(own) and all(x["band"] == "weak" for x in own),
            "note": "Leads for a human analyst, never conclusions."}


@api_bp.get("/incidents/<incident_id>/network")
@login_required("incidents:read")
def incident_network(incident_id):
    inc, _caza = _one_visible(incident_id)
    if not inc:
        return _err("not found", 404)
    return jsonify(_network(incident_id))


@api_bp.get("/brief")
@login_required("brief")
def brief():
    """Pre-arrival brief: retrieves and ranks past reporting in the user's
    regions. Never identifies what is in front of the responder and gives no
    handling guidance."""
    location = (request.args.get("location") or "").strip()
    describe = (request.args.get("describe") or "").strip() or None
    if not location:
        return _err("enter a location to brief on", 400)
    vis = _visible()
    cazas = {i.incident_id: c for i, c in vis}
    b = area_brief([i for i, _c in vis], location=location, describe=describe,
                   extractor=_HELPERS["extractor"])
    return jsonify({
        "location": location, "describe": describe, "n_in_area": b.n_in_area,
        "object_profile": [{"type": t, "count": n, "last_seen": d}
                           for t, n, d in b.object_profile],
        "area_signature": b.area_signature,
        "matches": [{k: v for k, v in dataclasses.asdict(m).items() if k != "photo"}
                    for m in b.matches],
        "area_incidents": [_incident_summary(i, cazas.get(i.incident_id))
                           for i in b.area_incidents[:20]],
        "note": "Record-based only: what has been reported here before. "
                "It does not identify any object and gives no handling guidance.",
    })


def _link_row(r, cazas) -> dict:
    return {"a": _incident_summary(r["inc_a"], cazas.get(r["a"])),
            "b": _incident_summary(r["inc_b"], cazas.get(r["b"])),
            "score": round(r["score"], 3), "band": r["band"], "reasons": r["reasons"],
            "below_threshold": r["below"], "decision": r["decision"],
            "notes": [{"note": n["note"], "analyst": n.get("analyst", ""),
                       "at": n.get("created_at", "")} for n in r["notes"]]}


@api_bp.get("/links")
@login_required("review")
def links():
    show = request.args.get("show", "all")
    if show not in review_bp.FILTERS:
        return _err(f"show must be one of {', '.join(review_bp.FILTERS)}", 400)
    cazas = {i.incident_id: c for i, c in _visible()}
    rows = [r for r in review_bp.build_rows() if r["a"] in cazas and r["b"] in cazas]
    tally = Counter(r["decision"] or "open" for r in rows)
    if show == "open":
        rows = [r for r in rows if not r["decision"]]
    elif show != "all":
        rows = [r for r in rows if r["decision"] == show]
    return jsonify({"links": [_link_row(r, cazas) for r in rows],
                    "tally": {k: tally.get(k, 0) for k in ("open", *decisions.DECISIONS)}})


def _visible_pair(b):
    a_id, b_id = str(b.get("a", "")), str(b.get("b", ""))
    a, ca = _one_visible(a_id)
    c, cb = _one_visible(b_id)
    if not a or not c or a_id == b_id:
        return None
    return {a_id: ca, b_id: cb}


@api_bp.post("/links/decision")
@login_required("review")
def link_decision():
    b = _body()
    cazas = _visible_pair(b)
    if not cazas:
        return _err("not found", 404)
    decision = b.get("decision")
    if decision == "undo":
        decisions.clear_decision(b["a"], b["b"], analyst=g.user["username"])
    elif decision in decisions.DECISIONS:
        decisions.set_decision(b["a"], b["b"], decision, analyst=g.user["username"])
    else:
        return _err("decision must be confirm, reject, unsure or undo", 400)
    accounts.audit(g.user["username"], "link.decision",
                   {"a": b["a"], "b": b["b"], "decision": decision})
    return jsonify(_link_row(review_bp._one_row(b["a"], b["b"]), cazas))


@api_bp.post("/links/note")
@login_required("review")
def link_note():
    b = _body()
    cazas = _visible_pair(b)
    if not cazas:
        return _err("not found", 404)
    note = (b.get("note") or "").strip()
    if not note:
        return _err("write a note first", 400)
    if len(note) > 2000:
        return _err("note is longer than 2000 characters", 400)
    decisions.add_note(b["a"], b["b"], note, analyst=g.user["username"])
    return jsonify(_link_row(review_bp._one_row(b["a"], b["b"]), cazas))


@api_bp.get("/dashboard")
@login_required("dashboard")
def dashboard():
    """Counts only, over the incidents in the user's regions (optionally one
    caza and a date range). No conclusions."""
    start, end = request.args.get("from") or "", request.args.get("to") or ""
    want = request.args.get("caza") or ""
    for v in (start, end):
        if v and not _DATE.match(v):
            return _err("dates must be YYYY-MM-DD", 400)
    incidents = store.all_incidents()
    vis = _visible(incidents)
    shown = [i for i, c in vis
             if (not want or c == want)
             and (not start or (i.date or "") >= start)
             and (not end or (i.date or "") <= end)
             and (not (start or end) or i.date)]
    cazas = {i.incident_id: c for i, c in vis}
    links = _scored(incidents)
    view = stats.links_in_view(links, shown)
    nets = stats.networks(incidents, links, shown)
    for r in nets["rows"]:
        r.pop("size", None)   # whole-network size could count reports in other regions
    quality = stats.quality(shown)
    return jsonify({
        "total": len(shown),
        "filters": {"from": start, "to": end, "caza": want},
        "timeline": dashboard_bp.timeline(shown),
        "by_caza": [{"caza": c or "unknown", "n": n} for c, n in
                    sorted(Counter(cazas[i.incident_id] for i in shown).items(),
                           key=lambda kv: (-kv[1], kv[0] or ""))],
        "by_initiation": dashboard_bp.by_initiation(shown),
        "links": stats.link_strength(view, decisions.current_decisions()),
        "networks": {"rows": nets["rows"], "unlinked": nets["unlinked"]},
        "quality": {"overall": quality["overall"], "fields": quality["fields"]},
        "note": "Counts only. Every link is a lead for a human analyst, never a conclusion.",
    })


# -- map ---------------------------------------------------------------------
@api_bp.get("/map/markers")
@login_required("map")
def map_markers():
    markers, legend, unplaced = _HELPERS["map_markers"]([i for i, _c in _visible()])
    return jsonify({"markers": markers, "legend": legend, "unplaced": unplaced})


@api_bp.get("/map/info")
@login_required("map")
def map_info():
    """Whether the offline street map can be downloaded to the phone, and its size."""
    f = map_bp.map_file()
    sha = pathlib.Path(str(f) + ".sha256")
    return jsonify({
        "available": f.is_file(),
        "size": f.stat().st_size if f.is_file() else 0,
        "sha256": sha.read_text().split()[0] if sha.is_file() else None,
        "bounds": map_bp.bounds(),
        "attribution": map_bp.ATTRIBUTION,
    })


@api_bp.get("/map/lebanon.pmtiles")
@login_required("map")
def map_download():
    """The offline street map file (resumable: supports HTTP Range)."""
    f = map_bp.map_file()
    if not f.is_file():
        return _err("offline map not installed on the server", 404)
    resp = send_file(f, mimetype="application/octet-stream", conditional=True,
                     download_name="lebanon.pmtiles")
    resp.headers["Cache-Control"] = "no-store"
    return resp



# -- civilian reports (commander+) ------------------------------------------
@api_bp.get("/civil-reports")
@login_required("civil_reports")
def civil_reports():
    status = request.args.get("status") or None
    rows = [r for r in civil.list_reports(status)
            if accounts.sees_region(g.user, r["caza"])]
    return jsonify({"reports": rows})


def _visible_report(report_id, with_photo=False):
    r = civil.get_report(report_id, with_photo=with_photo)
    return r if r and accounts.sees_region(g.user, r["caza"]) else None


@api_bp.get("/civil-reports/<report_id>")
@login_required("civil_reports")
def civil_report(report_id):
    r = _visible_report(report_id)
    return jsonify(r) if r else _err("not found", 404)


@api_bp.get("/civil-reports/<report_id>/photo")
@login_required("civil_reports")
def civil_report_photo(report_id):
    r = _visible_report(report_id, with_photo=True)
    if not r or not r["photo"]:
        return _err("not found", 404)
    return Response(r["photo"], mimetype=r["photo_type"] or "application/octet-stream",
                    headers={"Cache-Control": "no-store"})


@api_bp.patch("/civil-reports/<report_id>")
@login_required("civil_reports")
def civil_report_status(report_id):
    if not _visible_report(report_id):
        return _err("not found", 404)
    b = _body()
    r = civil.set_status(report_id, b.get("status"), g.user["username"], b.get("note", ""))
    accounts.audit(g.user["username"], "civil_report.status",
                   {"id": report_id, "status": r["status"]})
    return jsonify(r)


# -- warnings ----------------------------------------------------------------
@api_bp.get("/warnings")
@login_required()
def warnings():
    active = request.args.get("active") == "1"
    rows = [w for w in civil.list_warnings(active_only=active)
            if accounts.sees_region(g.user, w["caza"])]
    return jsonify({"warnings": rows})


@api_bp.post("/warnings")
@login_required("warnings:publish")
def publish_warning():
    b = _body()
    caza = b.get("caza")
    if caza not in regions.names():
        return _err("choose a caza from the list", 400)
    if not accounts.sees_region(g.user, caza):
        return _err("that caza is outside your assigned regions", 403)
    w = civil.create_warning(caza, b.get("severity"), b.get("title"), b.get("body"),
                             b.get("expires_at"), g.user["username"])
    accounts.audit(g.user["username"], "warning.publish", {"id": w["id"], "caza": caza})
    return jsonify(w), 201


@api_bp.post("/warnings/<int:wid>/withdraw")
@login_required("warnings:publish")
def withdraw_warning(wid):
    w = civil.get_warning(wid)
    if not w or not accounts.sees_region(g.user, w["caza"]):
        return _err("not found", 404)
    w = civil.withdraw_warning(wid)
    accounts.audit(g.user["username"], "warning.withdraw", {"id": wid})
    return jsonify(w)


# -- admin -------------------------------------------------------------------
@api_bp.get("/admin/users")
@login_required("users:manage")
def users():
    return jsonify({"users": accounts.list_users()})


@api_bp.post("/admin/users")
@login_required("users:manage")
def create_user():
    b = _body()
    u = accounts.create_user(
        b.get("username", ""), b.get("password", ""), b.get("role", "military"),
        level=b.get("level"), regions=b.get("regions") or [],
        display_name=b.get("display_name", ""), actor=g.user["username"],
        known_regions=set(regions.names()))
    return jsonify(u), 201


@api_bp.patch("/admin/users/<int:user_id>")
@login_required("users:manage")
def update_user(user_id):
    b = _body()
    allowed = {k: b[k] for k in ("level", "regions", "active", "display_name", "password")
               if k in b}
    if user_id == g.user["id"] and allowed.get("active") is False:
        return _err("you cannot disable your own account", 400)
    u = accounts.update_user(user_id, actor=g.user["username"],
                             known_regions=set(regions.names()), **allowed)
    return jsonify(u)


@api_bp.get("/admin/audit")
@login_required("audit:read")
def audit():
    limit = min(max(request.args.get("limit", 200, type=int), 1), 1000)
    return jsonify({"entries": accounts.audit_entries(limit)})
