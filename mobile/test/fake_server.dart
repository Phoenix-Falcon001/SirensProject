import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sirens/api/api_client.dart';
import 'package:sirens/config.dart';
import 'package:sirens/state/app_state.dart';
import 'package:sirens/state/storage.dart';

const config = AppConfig(gatewayUrl: 'https://gw.test', internalUrl: 'https://int.test');

/// Stand-in for both servers, following the real API in api_bp.py and
/// gateway/app.py.
class FakeServers {
  final users = <String, Map<String, dynamic>>{
    'field1': {
      'id': 2,
      'username': 'field1',
      'display_name': 'Sgt. Haddad',
      'role': 'military',
      'level': 'field',
      'regions': ['Sour'],
      'active': true,
      'all_regions': false,
      'permissions': ['brief', 'incidents:create', 'incidents:read', 'map'],
    },
    'admin': {
      'id': 1,
      'username': 'admin',
      'display_name': '',
      'role': 'admin',
      'level': null,
      'regions': [],
      'active': true,
      'all_regions': true,
      'permissions': [
        'audit:read',
        'brief',
        'civil_reports',
        'dashboard',
        'incidents:create',
        'incidents:read',
        'map',
        'review',
        'users:manage',
        'warnings:publish',
      ],
    },
  };
  final calls = <String>[];
  bool offline = false;
  bool expireSessions = false;
  String? lastCodeLang;

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  late final MockClient client = MockClient((req) async {
    calls.add('${req.method} ${req.url.path}');
    if (offline) throw http.ClientException('offline');
    final body = req.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(req.body) as Map<String, dynamic>;
    final authed = req.headers['Authorization']?.startsWith('Bearer ') ?? false;
    final exp = DateTime.now().add(const Duration(hours: 12)).toUtc().toIso8601String();
    switch ('${req.method} ${req.url.path}') {
      case 'POST /gw/v1/auth/request-code':
        lastCodeLang = body['lang'] as String?;
        return _json({'ok': true, 'phone': '+9613123456', 'expires_in': 300});
      case 'POST /gw/v1/auth/verify':
        if (body['code'] != '123456') return _json({'error': 'wrong code'}, 400);
        return _json({
          'token': 'civ-token',
          'expires_at': exp,
          'new_account': true,
          'citizen': {'id': 1, 'phone': '+9613123456', 'lang': 'ar'},
        });
      case 'DELETE /gw/v1/me':
      case 'POST /gw/v1/auth/logout':
      case 'POST /api/v1/auth/logout':
        return authed ? _json({'ok': true}) : _json({'error': 'not signed in'}, 401);
      case 'POST /api/v1/auth/login':
        final u = users[body['username']];
        if (u == null || body['password'] != 'correct-horse-1') {
          return _json({'error': 'wrong username or password'}, 401);
        }
        return _json({'token': 'tok-${u['username']}', 'expires_at': exp, 'user': u});
      case 'GET /api/v1/me':
        if (expireSessions || !authed) return _json({'error': 'not signed in'}, 401);
        final name = req.headers['Authorization']!.substring('Bearer tok-'.length);
        return _json(users[name]!);
    }
    return _json({'error': 'not found'}, 404);
  });

  AppState newState({MemoryStore? secure, MemoryStore? prefs}) => AppState(
    config: config,
    secure: secure ?? MemoryStore(),
    prefs: prefs ?? MemoryStore(),
    gatewayClient: ApiClient(config.gatewayUrl, client: client),
    internalClient: ApiClient(config.internalUrl, client: client),
  );
}
