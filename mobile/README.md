# Sirens mobile app (Android and iPhone)

One Flutter app for three kinds of user, operated by the Lebanese Army:

| User | Signs in with | Talks to |
|---|---|---|
| Civilian | mobile number + SMS code (first sign-in creates the account) | public gateway (`gateway/`) |
| Military (field / analyst / commander) | username + password from an admin | internal server `/api/v1`, over the Army VPN |
| Admin | username + password | internal server `/api/v1`, over the Army VPN |

What each account may do, and which regions it sees, is decided by the
server. The app only shows the tiles for the permissions the server
returns. See [../docs/MOBILE_SERVER.md](../docs/MOBILE_SERVER.md).

Languages: Arabic (right-to-left), English, French. The first screen asks
which one; it can be changed later in Settings.

## Status

| Step | |
|---|---|
| 1. Server: accounts, roles + regions, `/api/v1`, public gateway, sync | done |
| 2. App foundation: sign-in for all users, 3 languages + RTL, home per role, settings | done |
| 3. Civilian features: report, my reports, warnings, safety + hotline | done |
| 4. Military features: new report, incidents, brief, offline map + MGRS, review, dashboard | done |
| 5. Commander and admin features: civilian reports, warnings, accounts, audit log | done |
| 6. Android APK pilot, then iPhone through TestFlight | next (needs a laptop) |

## Civilian features

* **Report a suspicious object.** The person must first confirm they are at
  a safe distance. They then choose what they saw (5 categories), add a
  description, and optionally a photo (camera or gallery; "never go closer to
  take a photo"). The phone's position is added automatically when location
  is allowed; without it, the report can still be sent with a described place.
* **Offline queue.** Every report is saved on the phone before sending. With
  no connection (or a server error) it stays queued and is sent automatically
  at the next start or from *My reports → Send now*. The time it was seen
  travels with it, and the gateway recognises retries, so a report is never
  lost or duplicated. Reports the gateway refuses (e.g. outside Lebanon) are
  marked and can be discarded.
* **My reports.** Waiting-to-send reports, then sent ones with their status:
  received → under review → closed / not followed up, and "delivered to the
  Army" once collected. No investigation details.
* **Area warnings.** Active warnings, most serious first, in the user's
  language (falls back to English), filterable by area. Checked when opened
  and on pull-to-refresh; the last copy is shown offline.
* **Safety and hotlines.** Steps and numbers with a *Call* button. Works with
  no connection at all (copy bundled in the app). Shows a notice while the
  text is still the placeholder; numbers not yet confirmed have no button.

## Military features

Everything is limited to the user's assigned cazas (admins: all). A link
between two reports is shown only when the user may see both.

* **New report** (field+). Caza (own regions only), street/place, date, type
  (or "not sure"), report text, and the phone's position shown as MGRS.
  After filing, the report's **likely network** is shown, as on the web
  console. Without the VPN the report is kept on the phone and filed when the
  VPN is back (*Send now*, or automatically at sign-in); retries never file
  twice.
* **Incidents** (field+). Search and caza filter; each report shows its text,
  what Sirens read in it, and its network with strength and reasons.
* **Pre-arrival brief** (field+). Past reporting at a place: objects reported
  there, common features, the most similar reports. Record-based only; it
  never identifies an object and gives no handling guidance.
* **Map and MGRS** (field+).
  * Caza outlines and the MGRS grid always work offline (outlines are bundled).
  * The **street map** is the same OpenStreetMap file as the web map
    (`lebanon.pmtiles`), downloaded once from the internal server over the VPN:
    resumable, checked against its SHA-256, then fully offline.
  * Grid lines every 100 km / 10 km / 1 km depending on zoom; the grid jumps at
    36°E where UTM zones 36 and 37 meet.
  * The MGRS reference of the map centre (crosshair) is always shown and can
    be copied. MGRS is computed on the phone with a port of
    `linker/grid_ref.py`, tested to give identical references on 208 points.
  * Incident markers coloured by type; a thick white ring means a filed grid
    reference, a thin one "approx. — placed at caza centre".
* **Review links** (analyst+). Confirm / reject / unsure / undo and notes,
  recorded under the signed-in account; filters with counts.
* **Dashboard** (analyst+). Reports per month, by caza, by initiation method,
  link strength and review progress, candidate networks, data completeness;
  bars with the numbers written out. Counts only.

Analysis results are not stored on the phone; only reports waiting for the
VPN and the street map are.

## Commander and admin features

* **Civilian reports** (commander+, own regions; admins also see reports
  outside every caza). Filter by status; each report shows its text, photo,
  when it was seen, MGRS and caza, and the reporter's number with a *Call*
  button. *Set status* (received / under review / closed / not followed up)
  with an internal note; the civilian sees only the status, after the next
  sync. *File as military report* opens New report pre-filled with the
  text, caza and position.
* **Publish warnings** (commander+, own regions). Caza, level (information /
  caution / danger), how long it shows (6 h – 7 days), and title + text in
  Arabic, English and/or French (each language used needs both). A reminder
  says to state only what civilians should do. Active warnings can be
  withdrawn; past ones are listed with who wrote them.
* **Manage accounts** (admin). Create military accounts (level + at least
  one region) or admin accounts, with a generated 14-character temporary
  password to hand over in person. Change level, regions, name; disable
  (not your own account); reset a password (ends that person's sessions).
* **Audit log** (admin). Sign-ins (failed ones flagged), account changes,
  reports filed, link decisions, status changes, warnings.

## Layout

```
lib/
  config.dart          server addresses (set at build time)
  api/                 HTTP client, gateway calls, internal-server calls
  models/              data for civilians and for military users
  services/            camera, GPS, dialer; offline map download (faked in tests)
  geo/                 MGRS (port of linker/grid_ref.py), street map + caza outlines
  state/               session, secure storage, app state, civilian and military
                       services, offline queues (civilian reports, military drafts)
  ui/                  screens; menu.dart decides tiles from permissions
  l10n/app_*.arb       all text, in ar / en / fr
test/                  unit + widget tests against a fake server
```

## Run on a laptop (development)

Needs Flutter 3.47+ and Android Studio (for the Android SDK and an
emulator), or Xcode on a Mac for iPhone.

```bash
# 1. Internal server (from the repository root)
bash setup.sh && source .venv/bin/activate
python -m linker.accounts create-admin admin        # first admin account
python app.py                                       # http://127.0.0.1:5000

# 2. Public gateway, development mode (SMS codes are printed in its log)
SIRENS_GW_DEV=1 SIRENS_GW_SYNC_KEY=dev-sync-key-123456 python -m gateway.app   # :5100

# 3. Sync job, whenever you want civilian reports to move inward
SIRENS_GW_URL=http://127.0.0.1:5100 SIRENS_GW_SYNC_KEY=dev-sync-key-123456 python sync_gateway.py

# 4. The app, on an Android emulator (10.0.2.2 = this laptop)
cd mobile
flutter pub get
flutter run
```

On a real phone on the same Wi-Fi, pass the laptop's address:
`flutter run --dart-define=SIRENS_GATEWAY_URL=http://192.168.1.20:5100 --dart-define=SIRENS_INTERNAL_URL=http://192.168.1.20:5000`
and make both servers listen on the network: `flask --app app run --host 0.0.0.0`
for the internal server, and `SIRENS_GW_HOST=0.0.0.0` for the gateway. Only do
this on a private test network: the web console pages have no sign-in yet.

## Tests

```bash
cd mobile
flutter analyze     # expect: No issues found
flutter test        # expect: 69 tests pass (4 live tests skipped)
```

Live tests against running servers (skipped unless the variables are set):

```bash
SIRENS_LIVE_GATEWAY=http://127.0.0.1:5100 SIRENS_GW_LOG=<gateway log> flutter test test/live_gateway_test.dart
SIRENS_LIVE_INTERNAL=http://127.0.0.1:5000 SIRENS_LIVE_USER=<admin> SIRENS_LIVE_PASSWORD=<pw> \
  flutter test test/live_internal_test.dart test/live_map_download_test.dart test/live_admin_test.dart
```

## Build for direct install

```bash
flutter build apk --release \
  --dart-define=SIRENS_GATEWAY_URL=https://<public gateway> \
  --dart-define=SIRENS_INTERNAL_URL=https://<internal server>
# -> build/app/outputs/flutter-apk/app-release.apk
```

* Release builds refuse plain `http://`: both servers must be on HTTPS.
  Debug builds allow `http://` for development only.
* Before the pilot, create the Army's own signing key and set it in
  `android/app/build.gradle.kts` (it still signs with the debug key).
* iPhone: needs a Mac, Xcode and an Apple Developer account. Pilot through
  TestFlight; for lasting civilian use, unlisted App Store distribution.

## Permissions asked on the phone

* Location (only while the report screen is open), camera / photo library
  (only when adding a photo). Both are optional: a report can be sent
  without them.
* To do: translate the iPhone permission prompts (Info.plist) into Arabic and
  French in Xcode (`InfoPlist.strings`); they are English only for now.
* Warnings are fetched when the app is open. Background checks on Android,
  or push notifications, come once the Army decides on push.

## Security notes

* Sign-in tokens are kept in the Android Keystore / iOS Keychain
  (`flutter_secure_storage`), never in plain preferences.
* Android backups of app data are turned off (`allowBackup="false"`).
* Queued reports (with photos) are kept in the app's private folder until
  sent; deleting the account removes them.
* A civilian's token is only ever sent to the gateway, and a military
  token only to the internal server.
* When the server answers 401 (session ended, account disabled, password
  reset), the app signs out and says so.
