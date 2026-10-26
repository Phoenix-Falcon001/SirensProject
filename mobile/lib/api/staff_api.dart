import '../models/staff.dart';
import 'api_client.dart';

/// Calls military and admin users make to the internal server (/api/v1).
class StaffApi {
  StaffApi(this.client);

  final ApiClient client;

  Future<Map<String, dynamic>> login(String username, String password) =>
      client.post('/api/v1/auth/login', {'username': username, 'password': password});

  Future<Map<String, dynamic>> me() => client.get('/api/v1/me');

  Future<void> logout() => client.post('/api/v1/auth/logout');

  Future<void> changePassword(String current, String newPassword) =>
      client.post('/api/v1/me/password', {'current': current, 'new': newPassword});

  Future<Map<String, dynamic>> meta() => client.get('/api/v1/meta');

  Future<List<IncidentSummary>> incidents() async => [
    for (final j in (await client.get('/api/v1/incidents'))['incidents'] as List)
      IncidentSummary.fromJson(Map<String, dynamic>.from(j as Map)),
  ];

  Future<IncidentDetail> incident(String id) async =>
      IncidentDetail.fromJson(await client.get('/api/v1/incidents/${Uri.encodeComponent(id)}'));

  Future<NetworkInfo> network(String id) async => NetworkInfo.fromJson(
    await client.get('/api/v1/incidents/${Uri.encodeComponent(id)}/network'),
  );

  /// Files a report. The answer includes the new incident id and its network.
  Future<Map<String, dynamic>> fileIncident(Map<String, dynamic> body) =>
      client.post('/api/v1/incidents', body);

  Future<BriefResult> brief(String location, String? describe) async {
    final q = Uri(
      queryParameters: {
        'location': location,
        if (describe != null && describe.isNotEmpty) 'describe': describe,
      },
    ).query;
    return BriefResult.fromJson(await client.get('/api/v1/brief?$q'));
  }

  Future<(List<LinkRow>, Map<String, int>)> links(String show) async {
    final r = await client.get('/api/v1/links?show=$show');
    return (
      [for (final j in r['links'] as List) LinkRow.fromJson(Map<String, dynamic>.from(j as Map))],
      Map<String, int>.from(r['tally'] as Map),
    );
  }

  Future<LinkRow> decide(String a, String b, String decision) async => LinkRow.fromJson(
    await client.post('/api/v1/links/decision', {'a': a, 'b': b, 'decision': decision}),
  );

  Future<LinkRow> note(String a, String b, String note) async =>
      LinkRow.fromJson(await client.post('/api/v1/links/note', {'a': a, 'b': b, 'note': note}));

  Future<DashboardData> dashboard({String? caza, String? from, String? to}) async {
    final q = Uri(
      queryParameters: {
        if (caza != null && caza.isNotEmpty) 'caza': caza,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    ).query;
    return DashboardData.fromJson(await client.get('/api/v1/dashboard?$q'));
  }

  Future<List<MapMarker>> markers() async => [
    for (final j in (await client.get('/api/v1/map/markers'))['markers'] as List)
      MapMarker.fromJson(Map<String, dynamic>.from(j as Map)),
  ];

  Future<MapInfo> mapInfo() async {
    final j = await client.get('/api/v1/map/info');
    return MapInfo(
      available: j['available'] == true,
      size: (j['size'] as num).toInt(),
      sha256: j['sha256'] as String?,
    );
  }
}
