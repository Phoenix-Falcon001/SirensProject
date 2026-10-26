import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../api/api_client.dart';
import '../api/gateway_api.dart';
import '../api/staff_api.dart';
import '../config.dart';
import 'session.dart';
import 'storage.dart';

const supportedLanguages = ['ar', 'en', 'fr'];

/// App-wide state: chosen language and who is signed in.
class AppState extends ChangeNotifier {
  AppState({
    required this.config,
    required this.secure,
    required this.prefs,
    ApiClient? gatewayClient,
    ApiClient? internalClient,
  }) : gatewayClient = gatewayClient ?? ApiClient(config.gatewayUrl),
       internalClient = internalClient ?? ApiClient(config.internalUrl) {
    this.gatewayClient.onUnauthorized = _expired;
    this.internalClient.onUnauthorized = _expired;
  }

  static const _sessionKey = 'session';
  static const _langKey = 'lang';

  final AppConfig config;
  final KeyValueStore secure;
  final KeyValueStore prefs;
  final ApiClient gatewayClient;
  final ApiClient internalClient;

  late final gateway = GatewayApi(gatewayClient);
  late final staff = StaffApi(internalClient);

  bool ready = false;
  Locale? locale;
  Session? session;

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
  }

  Future<void> setLanguage(String code) async {
    locale = Locale(code);
    await prefs.write(_langKey, code);
    notifyListeners();
  }

  void _use(Session? s) {
    session = s;
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
  }

  Future<void> deleteCivilianAccount() async {
    await gateway.deleteAccount();
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
