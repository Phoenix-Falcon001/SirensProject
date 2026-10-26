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

import re
from datetime import date
from functools import wraps

from flask import Blueprint, Response, g, jsonify, request

from linker import accounts, civil, regions, store
from linker.grid_ref import to_mgrs
from linker.models import Incident

api_bp = Blueprint("api", __name__, url_prefix="/api/v1")

API_VERSION = 1
_HELPERS: dict = {}


def register(app, *, region_of, extractor, put_meta, fmt_grid, munitions):
    """region_of(incident) -> caza or None; extractor.extract(incident);
    put_meta(incident_id, dict); fmt_grid(lat, lon) -> display label;
    munitions: [(key, label, colour)]."""
    _HELPERS.update(region_of=region_of, extractor=extractor, put_meta=put_meta,
                    fmt_grid=fmt_grid, munitions=munitions)
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
def _incident_summary(inc: Incident, caza) -> dict:
    snip = (inc.narrative or "").strip().replace("\n", " ")
    return {"id": inc.incident_id, "date": inc.date, "location": inc.location,
            "caza": caza, "summary": snip[:160] + ("…" if len(snip) > 160 else "")}


@api_bp.get("/incidents")
@login_required("incidents:read")
def incidents():
    want = request.args.get("caza")
    out = []
    for inc in store.all_incidents():
        caza = _HELPERS["region_of"](inc)
        if not accounts.sees_region(g.user, caza) or (want and caza != want):
            continue
        out.append(_incident_summary(inc, caza))
    out.sort(key=lambda d: d["date"] or "", reverse=True)
    return jsonify({"incidents": out})


@api_bp.get("/incidents/<incident_id>")
@login_required("incidents:read")
def incident(incident_id):
    inc = store.get_incident(incident_id)
    caza = _HELPERS["region_of"](inc) if inc else None
    if not inc or not accounts.sees_region(g.user, caza):
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

    inc = Incident(incident_id=store.next_incident_id(), date=when,
                   location=", ".join(p for p in (street, caza) if p),
                   narrative=narrative)
    _HELPERS["extractor"].extract(inc)
    store.add_incident(inc)
    _HELPERS["put_meta"](inc.incident_id, {
        "caza": caza, "street": street or None, "munition": munition,
        "lat": lat, "lon": lon, "grid": grid})
    accounts.audit(g.user["username"], "incident.create",
                   {"id": inc.incident_id, "caza": caza})
    d = inc.to_dict()
    d["caza"] = caza
    d["mgrs"] = to_mgrs(lat, lon) if lat is not None else None
    return jsonify(d), 201


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
