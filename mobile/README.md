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
| 3. Civilian features: report, my reports, warnings, safety + hotline | next (tiles show "coming in next version") |
| 4. Military features: new report, brief, offline map + MGRS, review, dashboard | to do |
| 5. Admin features: accounts, civilian report triage, warnings | to do (server side already done) |
| 6. Android APK pilot, then iPhone through TestFlight | to do |

## Layout

```
lib/
  config.dart          server addresses (set at build time)
  api/                 HTTP client, gateway calls, internal-server calls
  state/               session model, secure token storage, app state
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
flutter test        # expect: 18 tests pass
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

## Security notes

* Sign-in tokens are kept in the Android Keystore / iOS Keychain
  (`flutter_secure_storage`), never in plain preferences.
* Android backups of app data are turned off (`allowBackup="false"`).
* A civilian's token is only ever sent to the gateway, and a military
  token only to the internal server.
* When the server answers 401 (session ended, account disabled, password
  reset), the app signs out and says so.
