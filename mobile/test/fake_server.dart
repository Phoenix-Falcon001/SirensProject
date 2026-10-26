import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sirens/api/api_client.dart';
import 'package:sirens/config.dart';

import 'dart:typed_data';

import 'package:sirens/services/device.dart';
import 'package:sirens/state/app_state.dart';
import 'package:sirens/services/map_files.dart';
import 'package:sirens/state/drafts.dart';
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

  // Internal server data (military)
  final filed = <Map<String, dynamic>>[];
  final staffRefs = <String, String>{};
  int? fileStatus; // force an error answer for POST /api/v1/incidents
  final decisions = <String, String?>{'INC-001--INC-002': null};
  final linkNotes = <String, List<Map<String, dynamic>>>{};
  bool mapOnServer = true;

  Map<String, dynamic> _inc(String id, String loc) => {
    'id': id,
    'date': '2026-05-20',
    'location': loc,
    'caza': 'Sour',
    'summary': 'An IED with a tripwire near $loc.',
  };

  Map<String, dynamic> _linkRow(String key) {
    final ids = key.split('--');
    return {
      'a': _inc(ids[0], 'Qana'),
      'b': _inc(ids[1], 'Srifa'),
      'score': 0.71,
      'band': 'strong',
      'reasons': ['both: trigger=tripwire'],
      'below_threshold': false,
      'decision': decisions[key],
      'notes': linkNotes[key] ?? [],
    };
  }

  http.Response? _staff(http.Request req, Map<String, dynamic> body, bool authed) {
    final path = req.url.path;
    if (!path.startsWith('/api/v1/') || path.startsWith('/api/v1/auth') || path == '/api/v1/me') {
      return null;
    }
    if (offline) throw http.ClientException('offline');
    if (!authed) return _json({'error': 'not signed in'}, 401);
    final network = {
      'cluster': 'N1',
      'members': ['INC-001', 'INC-002'],
      'signature': ['trigger=tripwire'],
      'links': [
        {
          'other': _inc('INC-002', 'Srifa'),
          'score': 0.71,
          'band': 'strong',
          'reasons': ['both: trigger=tripwire'],
          'decision': null,
        },
      ],
      'tentative': false,
      'note': 'Leads for a human analyst, never conclusions.',
    };
    switch ('${req.method} $path') {
      case 'GET /api/v1/meta':
        return _json({
          'regions': ['Beirut', 'Saida', 'Sour'],
          'levels': ['field', 'analyst', 'commander'],
          'munitions': [
            {'key': 'ied', 'label': 'IED / roadside device'},
          ],
        });
      case 'GET /api/v1/incidents':
        return _json({
          'incidents': [_inc('INC-001', 'Qana'), _inc('INC-002', 'Srifa')],
        });
      case 'GET /api/v1/incidents/INC-001':
      case 'GET /api/v1/incidents/INC-002':
        final id = path.split('/').last;
        return _json({
          'incident_id': id,
          'date': '2026-05-20',
          'location': 'Qana',
          'caza': 'Sour',
          'narrative': 'On 20 an IED with a tripwire was found near Qana.',
          'features': ['trigger=tripwire'],
          'persons': [],
          'groups': [],
          'phones': [],
        });
      case 'GET /api/v1/incidents/INC-001/network':
      case 'GET /api/v1/incidents/INC-002/network':
        return _json(network);
      case 'POST /api/v1/incidents':
        if (fileStatus != null) {
          return _json({'error': 'that caza is outside your assigned regions'}, fileStatus!);
        }
        final ref = body['client_ref'] as String?;
        if (ref != null && staffRefs.containsKey(ref)) {
          return _json({'incident_id': staffRefs[ref], 'duplicate': true});
        }
        final id = 'INC-${(41 + filed.length).toString().padLeft(3, '0')}';
        filed.add(body);
        if (ref != null) staffRefs[ref] = id;
        return _json({'incident_id': id, 'caza': body['caza'], 'network': network}, 201);
      case 'GET /api/v1/brief':
        return _json({
          'n_in_area': 2,
          'object_profile': [
            {'type': 'unexploded_ordnance', 'count': 2, 'last_seen': '2026-05-20'},
          ],
          'area_signature': ['trigger=tripwire'],
          'matches': [
            {
              'incident_id': 'INC-001',
              'score': 0.5,
              'location': 'Qana',
              'date': '2026-05-20',
              'object_features': [],
              'shared': ['object_type=unexploded_ordnance'],
            },
          ],
          'area_incidents': [_inc('INC-001', 'Qana')],
        });
      case 'GET /api/v1/links':
        final show = req.url.queryParameters['show'] ?? 'all';
        final rows = [
          for (final k in decisions.keys)
            if (show == 'all' || (show == 'open' ? decisions[k] == null : decisions[k] == show))
              _linkRow(k),
        ];
        return _json({
          'links': rows,
          'tally': {
            'open': decisions.values.where((d) => d == null).length,
            for (final d in ['confirm', 'reject', 'unsure'])
              d: decisions.values.where((x) => x == d).length,
          },
        });
      case 'POST /api/v1/links/decision':
        final key = '${body['a']}--${body['b']}';
        if (!decisions.containsKey(key)) return _json({'error': 'not found'}, 404);
        decisions[key] = body['decision'] == 'undo' ? null : body['decision'] as String;
        return _json(_linkRow(key));
      case 'POST /api/v1/links/note':
        final key = '${body['a']}--${body['b']}';
        (linkNotes[key] ??= []).add({'note': body['note'], 'analyst': 'analyst1', 'at': ''});
        return _json(_linkRow(key));
      case 'GET /api/v1/dashboard':
        final caza = req.url.queryParameters['caza'];
        return _json({
          'total': caza == 'Saida' ? 1 : 3,
          'timeline': {
            'labels': ['May 2026'],
            'values': [3],
            'undated': 0,
          },
          'by_caza': [
            {'caza': 'Sour', 'n': 2},
            {'caza': 'Saida', 'n': 1},
          ],
          'by_initiation': {
            'labels': ['victim operated'],
            'values': [2],
          },
          'links': {
            'total': 1,
            'reviewed_pct': 0,
            'bands': [
              {'band': 'strong', 'n': 1},
              {'band': 'medium', 'n': 0},
              {'band': 'weak', 'n': 0},
            ],
            'review': [
              {'key': 'confirm', 'n': 0},
              {'key': 'reject', 'n': 0},
              {'key': 'unsure', 'n': 0},
              {'key': 'open', 'n': 1},
            ],
          },
          'networks': {
            'rows': [
              {'id': 'N1', 'in_view': 2, 'best_band': 'strong'},
            ],
            'unlinked': 1,
          },
          'quality': {
            'overall': 80,
            'fields': [
              {'label': 'Date', 'pct': 100},
            ],
          },
        });
      case 'GET /api/v1/map/markers':
        return _json({
          'markers': [
            {
              'id': 'INC-001',
              'lat': 33.27,
              'lon': 35.2,
              'exact': true,
              'caza': 'Sour',
              'date': '2026-05-20',
              'type': 'ied',
              'typelabel': 'IED / roadside device',
              'fill': '#c0663f',
              'mgrs': '36S YB 049 833',
              'snip': 'IED near Qana',
            },
          ],
          'legend': [],
          'unplaced': 0,
        });
      case 'GET /api/v1/map/info':
        return _json({
          'available': mapOnServer,
          'size': mapOnServer ? 52428800 : 0,
          'sha256': null,
        });
    }
    return _json({'error': 'not found'}, 404);
  }

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
    final staffResp = _staff(req, body, authed);
    if (staffResp != null) return staffResp;
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
  final drafts = MemoryDraftStore();
  final maps = FakeMapFiles();
  final device = FakeDevice();

  AppState newState({MemoryStore? secure, MemoryStore? prefs}) => AppState(
    config: config,
    secure: secure ?? MemoryStore(),
    prefs: prefs ?? MemoryStore(),
    outbox: outbox,
    device: device,
    drafts: drafts,
    maps: maps,
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

/// Offline map store stand-in: no file until [download] is called.
class FakeMapFiles implements MapFiles {
  String? path;
  final downloads = <String>[];
  bool fail = false;

  @override
  Future<String?> localMap() async => path;

  @override
  Future<void> download({
    required String url,
    required String token,
    required int size,
    String? sha256,
    void Function(int done, int total)? onProgress,
  }) async {
    downloads.add('$url $token');
    onProgress?.call(size ~/ 2, size);
    if (fail) throw const MapDownloadException('connection lost');
    onProgress?.call(size, size);
    // No real file in widget tests: the map stays on outlines.
  }

  @override
  Future<void> delete() async => path = null;
}
