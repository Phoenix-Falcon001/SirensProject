# Sirens Mobile: server side

The mobile app (in `mobile/`) talks to two separate services, both run by
the Lebanese Army:

```
Civilian phones ──internet──► PUBLIC GATEWAY          gateway/app.py
                                - civilian sign-up by SMS code
                                - takes in civilian reports
                                - shows approved warnings + safety page
                                - keeps no report content once collected
                                     ▲
                                     │ sync_gateway.py connects OUT to the
                                     │ gateway; the gateway never connects in
                                     │
Military phones ──Army VPN──► INTERNAL SERVER         app.py + api_bp.py
                                - full Sirens database and analysis
                                - military/admin accounts (level + regions)
```

## Internal server: `/api/v1`

Part of the existing Flask app (`python app.py`), in `api_bp.py`.

### Accounts and access (`linker/accounts.py`)

| Role / level | Can |
|---|---|
| military **field** | read incidents, file reports, brief, map |
| military **analyst** | field + review links, dashboard |
| military **commander** | analyst + civilian reports, publish warnings |
| **admin** | everything, all regions, manage accounts, read audit log |

* Military accounts are created **only by an admin**, with a level and at
  least one assigned caza.
* Military users only ever see incidents, civilian reports and warnings in
  their own cazas. A record outside them answers `404`, the same as a missing
  one.
* Passwords: at least 10 characters, stored hashed. Five wrong passwords lock
  the account for 15 minutes.
* Sign-in gives a token valid for 12 hours. Only its SHA-256 is stored.
  Disabling an account or resetting its password ends its sessions.
* Every sign-in, account change, report filed, status change and warning is
  written to the audit log (`GET /api/v1/admin/audit`).

Create the first admin on the server:

```bash
python -m linker.accounts create-admin <username> --name "Full name"
```

### Endpoints

| Method | Path | Needs |
|---|---|---|
| POST | `/auth/login` `{username, password}` | – |
| POST | `/auth/logout` | signed in |
| GET | `/me` (includes `permissions`) | signed in |
| POST | `/me/password` `{current, new}` | signed in |
| GET | `/meta` (cazas, levels, munition types) | signed in |
| GET | `/incidents[?caza=]` | field |
| GET | `/incidents/<id>` | field |
| POST | `/incidents` `{narrative, caza, street?, date?, munition?, lat?, lon?}` | field |
| GET | `/civil-reports[?status=]`, `/civil-reports/<id>`, `/civil-reports/<id>/photo` | commander |
| PATCH | `/civil-reports/<id>` `{status, note?}` | commander |
| GET | `/warnings[?active=1]` | signed in |
| POST | `/warnings` `{caza, severity, title, body, expires_at}` | commander |
| POST | `/warnings/<id>/withdraw` | commander |
| GET/POST | `/admin/users` | admin |
| PATCH | `/admin/users/<id>` `{level?, regions?, active?, display_name?, password?}` | admin |
| GET | `/admin/audit[?limit=]` | admin |

`title` and `body` of a warning are `{"ar": …, "en": …, "fr": …}` (at
least one language).

## Public gateway: `/gw/v1`

A separate small Flask app with its own database (`data/gateway.db`). See the
docstring of `gateway/app.py` for every endpoint.

* **Sign-up / sign-in**: phone number + 6-digit SMS code (valid 5 minutes,
  5 tries, at most 3 codes per number and 10 per network address every 30
  minutes). Codes are stored only as keyed hashes. Sessions last 90 days.
* **Reports**: category, description (≤ 2000 characters), optional GPS
  position (must be in Lebanon), optional JPEG/PNG photo (≤ 5 MB). At most
  10 per person per day.
* **Once the internal server has collected a report**, the gateway wipes its
  description, position, photo and phone number, and keeps only its id and
  status, so the civilian can still follow it.
* **Account deletion** (`DELETE /me`): reports already collected stay with
  the Army; reports not yet collected are still delivered, without the phone
  number.
* **Warnings and the safety page** can be read without signing in.

### Settings (environment variables)

| Variable | Meaning |
|---|---|
| `SIRENS_GW_SYNC_KEY` | shared key the internal server's sync job presents (≥ 16 chars) |
| `SIRENS_GW_SECRET` | secret for SMS-code hashes (≥ 32 chars, same on every process) |
| `SIRENS_GW_SYNC_IPS` | optional: comma-separated addresses allowed to sync |
| `SIRENS_GW_DB` | database path (default `data/gateway.db`) |
| `SIRENS_GW_DEV=1` | development only: SMS codes are written to the log |

Outside development the gateway refuses to start without a sync key, a
secret, and a real SMS provider (`gateway/sms.py`, to be filled in once the
Army chooses one).

Development run:

```bash
SIRENS_GW_DEV=1 SIRENS_GW_SYNC_KEY=dev-sync-key-123456 python -m gateway.app   # port 5100
```

### Push notifications (`gateway/push.py`)

Switched **off** until the Army approves Google/Apple push. When on, a push
only says "warnings changed, open the app"; it never carries details.

## Sync job

On the internal server, every minute or so:

```bash
SIRENS_GW_URL=https://<gateway> SIRENS_GW_SYNC_KEY=<key> python sync_gateway.py
```

1. Collects new civilian reports (with photo) and stores them; each gets its
   caza from its GPS point (`linker/regions.py`) and an MGRS reference.
2. Tells the gateway they are collected (it then wipes them).
3. Sends back status changes made by commanders.
4. Sends the list of active warnings.

## Still to do before real use

* The Army's SMS provider, and their decision on push.
* The approved safety text and hotline numbers (`gateway/safety.json` is a
  marked placeholder; the Army number is left as `TO-BE-CONFIRMED`).
* HTTPS in front of both services (reverse proxy), and a production WSGI
  server instead of Flask's development server.
* The existing web console pages (`/`, `/review`, …) have no sign-in yet; they
  must stay reachable only from the Army network until they do.
* Precision is 0.63 on synthetic data, and the place-name bug ("Meiss") is
  still open. Links remain leads for analysts; civilians never see them.
