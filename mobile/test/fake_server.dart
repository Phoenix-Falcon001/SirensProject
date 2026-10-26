import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sirens/api/api_client.dart';
import 'package:sirens/config.dart';

import 'dart:typed_data';

import 'package:sirens/services/device.dart';
import 'package:sirens/state/app_state.dart';
import 'package:sirens/state/outbox.dart';
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

  // Gateway data
  final reports = <Map<String, dynamic>>[];
  final byRef = <String, String>{};
  final uploads = <String>[];
  int? reportStatus; // force an error answer for POST /reports
  String reportError = 'daily report limit reached';
  List<Map<String, dynamic>> warnings = [];
  Map<String, dynamic> safety = {
    'status': 'placeholder',
    'hotlines': [
      {
        'label': {'en': 'Lebanese Army', 'ar': 'الجيش اللبناني'},
        'number': 'TO-BE-CONFIRMED',
      },
      {
        'label': {'en': 'Internal Security Forces'},
        'number': '112',
      },
    ],
    'steps': {
      'en': ['Do not touch it.', 'Move away.'],
      'ar': ['لا تلمسه.', 'ابتعد.'],
    },
  };
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
    final isJson = req.headers['Content-Type']?.contains('json') ?? false;
    final body = !isJson || req.bodyBytes.isEmpty
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
    final civ = req.headers['Authorization'] == 'Bearer civ-token';
    switch ('${req.method} ${req.url.path}') {
      case 'POST /gw/v1/reports':
        if (!civ) return _json({'error': 'not signed in'}, 401);
        if (reportStatus != null) return _json({'error': reportError}, reportStatus!);
        final text = latin1.decode(req.bodyBytes, allowInvalid: true);
        final ref = RegExp(r'name="client_ref"\r\n\r\n(\w+)').firstMatch(text)?.group(1);
        uploads.add(text);
        final existing = ref == null ? null : byRef[ref];
        if (existing != null) return _json({'id': existing, 'status': 'received'});
        final id = 'CR-${(reports.length + 1).toString().padLeft(4, '0')}';
        if (ref != null) byRef[ref] = id;
        reports.insert(0, {
          'id': id,
          'submitted_at': DateTime.now().toUtc().toIso8601String(),
          'category': RegExp(r'name="category"\r\n\r\n(\w+)').firstMatch(text)!.group(1),
          'status': 'received',
          'status_at': null,
          'delivered': false,
        });
        return _json({'id': id, 'status': 'received'}, 201);
      case 'GET /gw/v1/reports':
        if (!civ) return _json({'error': 'not signed in'}, 401);
        return _json({'reports': reports});
      case 'GET /gw/v1/warnings':
        return _json({'warnings': warnings, 'push': 'disabled'});
      case 'GET /gw/v1/safety':
        return _json(safety);
    }
    return _json({'error': 'not found'}, 404);
  });

  final outbox = MemoryOutboxStore();
  final device = FakeDevice();

  AppState newState({MemoryStore? secure, MemoryStore? prefs}) => AppState(
    config: config,
    secure: secure ?? MemoryStore(),
    prefs: prefs ?? MemoryStore(),
    outbox: outbox,
    device: device,
    gatewayClient: ApiClient(config.gatewayUrl, client: client),
    internalClient: ApiClient(config.internalUrl, client: client),
  );
}

/// Camera / GPS / dialer stand-in.
class FakeDevice implements DeviceServices {
  GeoFix? fix = const GeoFix(33.27, 35.20, 8);
  LocationProblem? problem;
  PickedPhoto? photo = PickedPhoto(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4]));
  final dialed = <String>[];

  @override
  Future<GeoFix> currentPosition() async {
    if (problem != null) throw LocationException(problem!);
    return fix!;
  }

  @override
  Future<PickedPhoto?> pickPhoto({required bool camera}) async => photo;

  @override
  Future<bool> dial(String number) async {
    dialed.add(number);
    return true;
  }
}
