"""Sign-in for the web console.

Uses the same accounts as the mobile app (linker/accounts.py): an admin, or a
military user with a level (field, analyst, commander) and assigned cazas.

* Every page needs a signed-in user, except the sign-in page and static files.
  The mobile API (/api/...) and the public gateway keep their own sign-in.
* Each page needs a permission from the user's level (PAGE_PERMS). The menu
  only shows what the user may open.
* A military user sees only reports in their cazas: the store's reader scope
  is set here, so every page (home, review, dashboard, map, brief, link tree)
  is limited the same way, and links are worked out within those reports.
* The session cookie holds a random token; only its hash is stored, it ends
  after 12 hours, and disabling an account or resetting its password ends it.
* Forms are protected against cross-site posting: the cookie is SameSite=Lax
  and any POST whose Origin is another site is refused.
* First run: while no account exists, the sign-in page offers to create the
  first administrator, from this computer only.

Tests switch sign-in off with app.config["LOGIN_DISABLED"] = True.
"""
from __future__ import annotations

import os
import pathlib
import secrets
from urllib.parse import urlparse

from flask import (Blueprint, abort, g, has_request_context, redirect, render_template_string,
                   request, session, url_for)

from markupsafe import Markup

from linker import accounts, regions, store

auth_bp = Blueprint("auth", __name__)
_HELPERS: dict = {}

# endpoint (or blueprint name) -> permission needed; None = any signed-in user.
PAGE_PERMS = {
    "home.home_page": None, "munitions.munitions_page": None, "vendor": None,
    "index": "incidents:create", "analyse": "incidents:create",
    "brief.brief_page": "brief",
    "incident_map": "map", "offmap": "map",
    "photo": "incidents:read", "network": "incidents:read",
    "review": "review", "link_tree": "review",
    "dashboard.dashboard_page": "dashboard",
    "demo": "users:manage", "seed": "users:manage", "clear": "users:manage",
    "auth.accounts_page": "users:manage", "auth.account_new": "users:manage",
    "auth.account_edit": "users:manage",
    "auth.password_page": None,
}
OPEN = {"auth.login", "auth.setup", "auth.logout", "static"}


def needed(endpoint: str | None):
    """(known, permission) for an endpoint; unknown endpoints need an admin."""
    if endpoint in PAGE_PERMS:
        return True, PAGE_PERMS[endpoint]
    bp = (endpoint or "").split(".")[0]
    if bp in PAGE_PERMS:
        return True, PAGE_PERMS[bp]
    return False, "users:manage"


def current_user() -> dict | None:
    return g.get("web_user") if has_request_context() else None


def can_open(endpoint: str) -> bool:
    """Whether the signed-in user may open a page (True when sign-in is off)."""
    u = current_user()
    if u is None:
        return True
    _known, perm = needed(endpoint)
    return perm is None or accounts.can(u, perm)


def _scope(incidents):
    u = current_user()
    if u is None or u["role"] == "admin":
        return incidents
    cazas = _HELPERS["regions_of"](incidents)
    return [i for i in incidents if cazas.get(i.incident_id) in u["regions"]]


def _secret(app) -> str:
    key = os.environ.get("SIRENS_SECRET")
    if key:
        return key
    f = pathlib.Path(app.root_path) / "data" / "secret.key"
    try:
        return f.read_text().strip()
    except OSError:
        key = secrets.token_hex(32)
        try:
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(key)
            f.chmod(0o600)
        except OSError:
            pass
        return key


def register(app, *, regions_of):
    """regions_of(incidents) -> {incident id: caza or None}."""
    _HELPERS.update(regions_of=regions_of)
    app.secret_key = _secret(app)
    app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax",
                      SESSION_COOKIE_SECURE=os.environ.get("SIRENS_HTTPS") == "1",
                      SESSION_COOKIE_NAME="sirens_session")
    store.scope = _scope
    app.register_blueprint(auth_bp)
    app.before_request(_guard)
    app.jinja_env.globals["web_user"] = current_user
    app.jinja_env.globals["can_open"] = can_open


def _same_site() -> bool:
    src = request.headers.get("Origin") or request.headers.get("Referer")
    if not src:
        return True                      # non-browser clients send neither; the cookie is SameSite anyway
    return urlparse(src).netloc == request.host


def _guard():
    from flask import current_app
    g.web_user = None
    if current_app.config.get("LOGIN_DISABLED"):
        return None
    path = request.path
    if path.startswith(("/api/", "/gw/", "/static/")):
        return None
    if request.method not in ("GET", "HEAD", "OPTIONS") and not _same_site():
        abort(403)
    if request.endpoint in OPEN:
        return None
    user = accounts.user_for_token(session.get("tok", ""))
    if not user:
        session.pop("tok", None)
        if request.method == "GET" and not request.headers.get("HX-Request"):
            return redirect(url_for("auth.login", next=path if path != "/" else None))
        resp = redirect(url_for("auth.login"))
        resp.status_code = 401
        resp.headers["HX-Redirect"] = url_for("auth.login")
        return resp
    g.web_user = user
    # A password chosen by somebody else must be replaced before anything else.
    if user.get("must_change") and request.endpoint != "auth.password_page":
        if request.method == "GET" and not request.headers.get("HX-Request"):
            return redirect(url_for("auth.password_page"))
        abort(403)
    _known, perm = needed(request.endpoint)
    if perm and not accounts.can(user, perm):
        return _show("Not available for your account", _DENIED, "denied"), 403
    return None


def _show(title: str, body: str, page: str, **ctx):
    """Render a body template inside the page shell."""
    inner = Markup(render_template_string(body, **ctx))
    return render_template_string(_PAGE, title=title, page=page, body_html=inner)


def _safe_next(target: str | None) -> str:
    """Only local paths, never another site."""
    if target and target.startswith("/") and not target.startswith("//") and "\\" not in target:
        return target
    return url_for("home.home_page")


def _local() -> bool:
    return request.remote_addr in ("127.0.0.1", "::1")


# ------------------------------------------------------------------ sign in
@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    error = None
    first_run = not accounts.list_users()
    if request.method == "POST" and not first_run:
        try:
            token, _user, _exp = accounts.login(request.form.get("username", ""),
                                                request.form.get("password", ""))
        except accounts.AccountError as e:
            error = str(e).capitalize() + "."
        else:
            session.clear()
            session["tok"] = token
            session.permanent = False
            return redirect(_safe_next(request.form.get("next")))
    return _show("Sign in", _LOGIN, "login", error=error,
                                  first_run=first_run, local=_local(), next=request.values.get("next", ""),
                                  username=request.form.get("username", ""), min_pw=accounts.MIN_PASSWORD), \
        (401 if error else 200)


@auth_bp.route("/setup", methods=["POST"])
def setup():
    """Create the first administrator. Only while no account exists, and only
    from this computer."""
    if accounts.list_users() or not _local():
        abort(403)
    f = request.form
    error = None
    if f.get("password") != f.get("password2"):
        error = "The two passwords are different."
    else:
        try:
            accounts.create_user(f.get("username", ""), f.get("password", ""), "admin",
                                 display_name=f.get("display_name", ""), actor="first-run")
            token, _u, _e = accounts.login(f.get("username", ""), f.get("password", ""))
        except accounts.AccountError as e:
            error = str(e).capitalize() + "."
        else:
            session.clear()
            session["tok"] = token
            return redirect(url_for("home.home_page"))
    return _show("Sign in", _LOGIN, "login", error=error,
                                  first_run=True, local=True, next="", username=f.get("username", ""),
                                  min_pw=accounts.MIN_PASSWORD), 400


@auth_bp.route("/logout", methods=["POST"])
def logout():
    accounts.logout(session.get("tok", ""))
    session.clear()
    return redirect(url_for("auth.login"))


@auth_bp.route("/password", methods=["GET", "POST"])
def password_page():
    u = current_user()
    error = done = None
    if request.method == "POST" and u:
        f = request.form
        if f.get("new") != f.get("new2"):
            error = "The two new passwords are different."
        else:
            try:
                accounts.change_password(u["id"], f.get("current", ""), f.get("new", ""))
                if u.get("must_change"):
                    return redirect(url_for("home.home_page"))
                done = "Password changed."
            except accounts.AccountError as e:
                error = str(e).capitalize() + "."
    return _show("Change my password", _PASSWORD, "password", must=bool(u and u.get("must_change")),
                                  error=error, done=done, min_pw=accounts.MIN_PASSWORD), (400 if error else 200)


# ------------------------------------------------------------------ accounts
def _form_user(f):
    return {"level": f.get("level") or None, "regions": f.getlist("regions"),
            "display_name": f.get("display_name", "")}


@auth_bp.route("/accounts")
def accounts_page():
    return _show("Accounts", _ACCOUNTS, "accounts",
                                  users=accounts.list_users(), audit=accounts.audit_entries(40),
                                  made=request.args.get("made"), pw=session.pop("new_pw", None))


@auth_bp.route("/accounts/new", methods=["GET", "POST"])
def account_new():
    error = None
    f = request.form
    if request.method == "POST":
        pw = secrets.token_urlsafe(10)
        role = "admin" if f.get("role") == "admin" else "military"
        try:
            u = accounts.create_user(f.get("username", ""), pw, role, actor=_actor(), must_change=True,
                                     known_regions=set(regions.names()), **_form_user(f))
        except accounts.AccountError as e:
            error = str(e).capitalize() + "."
        else:
            session["new_pw"] = pw
            return redirect(url_for("auth.accounts_page", made=u["username"]))
    return _show("New account", _EDIT, "accounts", error=error,
                                  user=None, f=f, all_regions=regions.names(), levels=accounts.LEVELS), \
        (400 if error else 200)


@auth_bp.route("/accounts/<int:user_id>", methods=["GET", "POST"])
def account_edit(user_id):
    user = accounts.get_user(user_id)
    if not user:
        abort(404)
    error = None
    f = request.form
    me = current_user()
    if request.method == "POST":
        changes = _form_user(f)
        changes["active"] = f.get("active") == "on"
        pw = None
        if f.get("action") == "reset":
            pw = secrets.token_urlsafe(10)
            changes = {"password": pw}
        if me and me["id"] == user_id and changes.get("active") is False:
            error = "You cannot disable your own account."
        else:
            try:
                accounts.update_user(user_id, actor=_actor(), known_regions=set(regions.names()), **changes)
            except accounts.AccountError as e:
                error = str(e).capitalize() + "."
            else:
                if pw:
                    session["new_pw"] = pw
                return redirect(url_for("auth.accounts_page", made=user["username"]))
    return _show(user["username"], _EDIT, "accounts", error=error,
                                  user=user, f=f, all_regions=regions.names(), levels=accounts.LEVELS,
                                  is_me=bool(me and me["id"] == user_id)), (400 if error else 200)


def _actor() -> str:
    u = current_user()
    return u["username"] if u else "console"


# ------------------------------------------------------------------ templates
_PAGE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sirens — {{ title }}</title>
<link rel="stylesheet" href="{{ url_for('static', filename='sirens.css') }}">
<link rel="stylesheet" href="{{ url_for('static', filename='auth.css') }}">
</head>
<body class="au au-{{ page }}">
<div class="bar">
  <a class="brand" href="{{ url_for('home.home_page') }}">Sirens<small>C-IED Incident Link Console</small></a>
  {% if page not in ('login',) %}{{ sirens_menu('accounts' if page == 'accounts' else '') }}{% endif %}
</div>
<main class="wrap">""" + "{{ body_html }}" + r"""</main>
</body>
</html>
"""

_DENIED = r"""
<div class="box">
  <h1>This page is not available for your account</h1>
  <p>Your account level does not include this page. Ask an administrator if you need it.</p>
  <p><a class="btn" href="{{ url_for('home.home_page') }}">Back to Home</a></p>
</div>"""

_LOGIN = r"""
<div class="box">
  {% if first_run %}
    <h1>Create the first administrator</h1>
    {% if local %}
    <p class="lead">No account exists yet. This account manages all the others. It can only be created from this computer.</p>
    {% if error %}<p class="err" role="alert">{{ error }}</p>{% endif %}
    <form method="post" action="{{ url_for('auth.setup') }}" autocomplete="off">
      <label for="username">Username</label><input id="username" name="username" value="{{ username }}" required autofocus>
      <label for="display_name">Full name and rank</label><input id="display_name" name="display_name">
      <label for="password">Password (at least {{ min_pw }} characters)</label><input id="password" name="password" type="password" minlength="{{ min_pw }}" required>
      <label for="password2">Repeat the password</label><input id="password2" name="password2" type="password" required>
      <button class="btn" type="submit">Create administrator</button>
    </form>
    {% else %}
    <p class="lead">No account exists yet. Open Sirens on the computer it runs on to create the first administrator.</p>
    {% endif %}
  {% else %}
    <h1>Sign in</h1>
    <p class="lead">Use the account an administrator gave you.</p>
    {% if error %}<p class="err" role="alert">{{ error }}</p>{% endif %}
    <form method="post" action="{{ url_for('auth.login') }}">
      <input type="hidden" name="next" value="{{ next }}">
      <label for="username">Username</label><input id="username" name="username" value="{{ username }}" autocomplete="username" required autofocus>
      <label for="password">Password</label><input id="password" name="password" type="password" autocomplete="current-password" required>
      <button class="btn" type="submit">Sign in</button>
    </form>
  {% endif %}
</div>"""

_PASSWORD = r"""
<div class="box">
  <h1>{{ 'Choose your own password' if must else 'Change my password' }}</h1>
  {% if must %}<p class="lead">Your password was set by an administrator. Choose your own before you continue.</p>{% endif %}
  {% if done %}<p class="ok" role="status">{{ done }}</p>{% endif %}
  {% if error %}<p class="err" role="alert">{{ error }}</p>{% endif %}
  <form method="post" autocomplete="off">
    <label for="current">Current password</label><input id="current" name="current" type="password" autocomplete="current-password" required>
    <label for="new">New password (at least {{ min_pw }} characters)</label><input id="new" name="new" type="password" minlength="{{ min_pw }}" autocomplete="new-password" required>
    <label for="new2">Repeat the new password</label><input id="new2" name="new2" type="password" autocomplete="new-password" required>
    <button class="btn" type="submit">Change password</button>
  </form>
</div>"""

_ACCOUNTS = r"""
<div class="ahead"><h1>Accounts</h1><a class="btn" href="{{ url_for('auth.account_new') }}">New account</a></div>
{% if made and pw %}
<div class="newpw" role="status"><strong>Temporary password for {{ made }}</strong>
  <code>{{ pw }}</code>
  <span>Shown once. Hand it over in person. They must choose their own password the first time they sign in.</span></div>
{% elif made %}<p class="ok" role="status">Saved {{ made }}.</p>{% endif %}
<div class="tablewrap"><table class="users">
  <thead><tr><th>Username</th><th>Name</th><th>Role</th><th>Regions</th><th>Status</th><th></th></tr></thead>
  <tbody>{% for u in users %}
  <tr><td class="mono">{{ u.username }}</td><td>{{ u.display_name }}</td>
    <td>{{ 'Administrator' if u.role == 'admin' else u.level|capitalize }}</td>
    <td>{{ 'All' if u.role == 'admin' else u.regions|join(', ') }}</td>
    <td>{% if u.active %}Active{% else %}<span class="off">Disabled</span>{% endif %}</td>
    <td><a href="{{ url_for('auth.account_edit', user_id=u.id) }}">Edit</a></td></tr>
  {% endfor %}</tbody>
</table></div>
<h2>Recent activity</h2>
<div class="tablewrap"><table class="users audit">
  <thead><tr><th>When</th><th>Who</th><th>What</th><th>Details</th></tr></thead>
  <tbody>{% for e in audit %}<tr><td class="nowrap">{{ e.at[:16].replace('T', ' ') }}</td><td class="mono">{{ e.actor }}</td>
    <td>{{ e.action }}</td><td>{% for k, v in e.detail.items() %}{{ k }}: {{ v if v is string else v|tojson }}{{ ', ' if not loop.last }}{% endfor %}</td></tr>
  {% else %}<tr><td colspan="4">Nothing recorded yet.</td></tr>{% endfor %}</tbody>
</table></div>"""

_EDIT = r"""
<div class="box wide">
  <h1>{{ 'New account' if not user else user.username }}</h1>
  {% if error %}<p class="err" role="alert">{{ error }}</p>{% endif %}
  {% set role = (f.get('role') or (user.role if user else 'military')) %}
  {% set level = (f.get('level') or (user.level if user else 'field')) %}
  {% set chosen = (f.getlist('regions') if f else []) or (user.regions if user else []) %}
  <form method="post" autocomplete="off">
    {% if not user %}
      <label for="username">Username</label><input id="username" name="username" value="{{ f.get('username', '') }}" required autofocus>
      <fieldset><legend>Role</legend>
        <label class="pick"><input type="radio" name="role" value="military" {{ 'checked' if role != 'admin' }}> Military (level and regions)</label>
        <label class="pick"><input type="radio" name="role" value="admin" {{ 'checked' if role == 'admin' }}> Administrator (everything, all regions)</label>
      </fieldset>
    {% endif %}
    <label for="display_name">Full name and rank</label>
    <input id="display_name" name="display_name" value="{{ f.get('display_name') if f else (user.display_name if user else '') }}">
    {% if not user or user.role == 'military' %}
    <div class="mil">
      <fieldset><legend>Level</legend>
        {% for lv, what in [('field', 'file reports, brief, map'), ('analyst', 'adds review links and dashboard'), ('commander', 'adds civilian reports and warnings (mobile app)')] %}
        <label class="pick"><input type="radio" name="level" value="{{ lv }}" {{ 'checked' if level == lv }}> {{ lv|capitalize }} <span>{{ what }}</span></label>
        {% endfor %}
      </fieldset>
      <fieldset><legend>Regions (at least one caza)</legend>
        <div class="cz">{% for r in all_regions %}<label class="pick"><input type="checkbox" name="regions" value="{{ r }}" {{ 'checked' if r in chosen }}> {{ r }}</label>{% endfor %}</div>
      </fieldset>
    </div>
    {% endif %}
    {% if user %}
      <label class="pick"><input type="checkbox" name="active" {{ 'checked' if user.active }} {{ 'disabled' if is_me }}> Account active{% if is_me %} <span>(you cannot disable your own account)</span>{% endif %}</label>
      {% if is_me %}<input type="hidden" name="active" value="on">{% endif %}
    {% else %}
      <p class="lead">A temporary password is generated when you save. It is shown once on the next page.</p>
    {% endif %}
    <div class="row">
      <button class="btn" type="submit" name="action" value="save">Save</button>
      {% if user %}<button class="btn ghost" type="submit" name="action" value="reset">Reset password</button>{% endif %}
      <a href="{{ url_for('auth.accounts_page') }}">Cancel</a>
    </div>
  </form>
</div>"""
