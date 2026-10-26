import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../api/api_client.dart';
import '../api/gateway_api.dart';
import '../api/staff_api.dart';
import '../config.dart';
import '../services/device.dart';
import '../services/map_files.dart';
import 'civilian.dart';
import 'drafts.dart';
import 'outbox.dart';
import 'session.dart';
import 'staff.dart';
import 'storage.dart';

const supportedLanguages = ['ar', 'en', 'fr'];

/// App-wide state: chosen language and who is signed in.
class AppState extends ChangeNotifier {
  AppState({
    required this.config,
    required this.secure,
    required this.prefs,
    OutboxStore? outbox,
    DeviceServices? device,
    DraftStore? drafts,
    MapFiles? maps,
    ApiClient? gatewayClient,
    ApiClient? internalClient,
  }) : outbox = outbox ?? FileOutboxStore(),
       device = device ?? RealDeviceServices(),
       drafts = drafts ?? FileDraftStore(),
       maps = maps ?? FileMapFiles(),
       gatewayClient = gatewayClient ?? ApiClient(config.gatewayUrl),
       internalClient = internalClient ?? ApiClient(config.internalUrl) {
    this.gatewayClient.onUnauthorized = _expired;
    this.internalClient.onUnauthorized = _expired;
  }

  static const _sessionKey = 'session';
  static const _langKey = 'lang';

  final AppConfig config;
  final KeyValueStore secure;
  final KeyValueStore prefs;
  final OutboxStore outbox;

  /// Camera, GPS and dialer.
  final DeviceServices device;

  /// Military reports waiting for the VPN, and the offline street map.
  final DraftStore drafts;
  final MapFiles maps;
  final ApiClient gatewayClient;
  final ApiClient internalClient;

  late final gateway = GatewayApi(gatewayClient);
  late final staff = StaffApi(internalClient);

  bool ready = false;
  Locale? locale;
  Session? session;

  /// Set while a civilian is signed in.
  CivilianService? civilian;

  /// Set while a military or admin user is signed in.
  StaffService? staffService;

  /// Set when the server ended the session; the sign-in screen shows a note.
  bool sessionExpired = false;

  String get lang => locale?.languageCode ?? 'ar';

  Future<void> init() async {
    final l = await prefs.read(_langKey);
    if (l != null && supportedLanguages.contains(l)) locale = Locale(l);
    final raw = await secure.read(_sessionKey);
    if (raw != null) {
      try {
        final s = Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (!s.isExpired) _use(s);
      } on Object {
        await secure.delete(_sessionKey);
      }
    }
    ready = true;
    notifyListeners();
    if (session?.kind == AccountKind.staff) await refreshStaff();
    await _startCivilian();
    await _startStaff();
  }

  Future<void> setLanguage(String code) async {
    locale = Locale(code);
    await prefs.write(_langKey, code);
    notifyListeners();
  }

  void _use(Session? s) {
    if (s?.kind != AccountKind.civilian || s?.phone != session?.phone) civilian = null;
    if (s?.kind != AccountKind.staff || s?.username != session?.username) staffService = null;
    session = s;
    if (s?.kind == AccountKind.staff) {
      staffService ??= StaffService(
        api: staff,
        drafts: drafts,
        maps: maps,
        username: s!.username!,
        internalUrl: config.internalUrl,
        tokenOf: () => internalClient.token,
      );
    }
    if (s?.kind == AccountKind.civilian) {
      civilian ??= CivilianService(api: gateway, outbox: outbox, cache: prefs, phone: s!.phone!);
    }
    gatewayClient.token = s?.kind == AccountKind.civilian ? s!.token : null;
    internalClient.token = s?.kind == AccountKind.staff ? s!.token : null;
  }

  Future<void> _save(Session? s) async {
    _use(s);
    if (s == null) {
      await secure.delete(_sessionKey);
    } else {
      await secure.write(_sessionKey, jsonEncode(s.toJson()));
    }
    notifyListeners();
  }

  void _expired() {
    if (session == null) return;
    sessionExpired = true;
    _save(null);
  }

  // -- civilians --------------------------------------------------------------
  /// Returns the number as the gateway normalised it (shown on the code screen).
  Future<String> requestCode(String phone) => gateway.requestCode(phone, lang);

  Future<void> signInCivilian(String phone, String code) async {
    final r = await gateway.verify(phone, code, lang);
    sessionExpired = false;
    await _save(Session.civilian(r));
    await _startCivilian();
  }

  /// Shows queued reports and sends any that were waiting for a connection.
  Future<void> _startCivilian() async {
    final c = civilian;
    if (c == null) return;
    try {
      await c.loadPending();
      await c.flush();
    } on Object {
      // Never block start-up on sending; the queue is retried later.
    }
  }

  Future<void> deleteCivilianAccount() async {
    await gateway.deleteAccount();
    await civilian?.clearPending();
    await _save(null);
  }

  // -- military / admin -------------------------------------------------------
  Future<void> signInStaff(String username, String password) async {
    final r = await staff.login(username.trim(), password);
    sessionExpired = false;
    await _save(
      Session.staff(
        r['token'] as String,
        r['expires_at'] as String,
        r['user'] as Map<String, dynamic>,
      ),
    );
    await _startStaff();
  }

  /// Loads form lists and sends reports drafted without the VPN.
  Future<void> _startStaff() async {
    final st = staffService;
    if (st == null) return;
    try {
      await st.loadPending();
      await st.loadMeta();
      await st.flush();
    } on Object {
      // Offline: the drafts wait; the forms fall back to the user's own regions.
    }
  }

  /// Picks up level or region changes an admin made since sign-in. Offline is
  /// fine: the saved details stay until the server can be reached.
  Future<void> refreshStaff() async {
    final s = session;
    if (s == null || s.kind != AccountKind.staff) return;
    try {
      await _save(s.withStaffUser(await staff.me()));
    } on ApiException {
      // 401 already signed out through onUnauthorized; network errors keep the session.
    }
  }

  Future<void> changePassword(String current, String newPassword) =>
      staff.changePassword(current, newPassword);

  // -- both -------------------------------------------------------------------
  Future<void> signOut() async {
    final s = session;
    if (s != null) {
      try {
        s.kind == AccountKind.civilian ? await gateway.logout() : await staff.logout();
      } on ApiException {
        // Signing out on the phone must work even offline.
      }
    }
    await _save(null);
  }
}
