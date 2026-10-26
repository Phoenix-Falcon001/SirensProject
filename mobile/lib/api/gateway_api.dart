import '../models/civilian.dart';
import '../state/outbox.dart';
import 'api_client.dart';

/// Calls a civilian makes to the public gateway (/gw/v1).
class GatewayApi {
  GatewayApi(this.client);

  final ApiClient client;

  /// Asks for an SMS code. Returns the number as the server normalised it.
  Future<String> requestCode(String phone, String lang) async {
    final r = await client.post('/gw/v1/auth/request-code', {'phone': phone, 'lang': lang});
    return r['phone'] as String;
  }

  /// Checks the code; the first successful check creates the account.
  Future<Map<String, dynamic>> verify(String phone, String code, String lang) =>
      client.post('/gw/v1/auth/verify', {'phone': phone, 'code': code, 'lang': lang});

  Future<Map<String, dynamic>> me() => client.get('/gw/v1/me');

  Future<void> logout() => client.post('/gw/v1/auth/logout');

  Future<void> deleteAccount() => client.delete('/gw/v1/me');

  Future<Map<String, dynamic>> submitReport(PendingReport r) => client.postMultipart(
    '/gw/v1/reports',
    {
      'client_ref': r.localId,
      'observed_at': r.observedAt.toUtc().toIso8601String(),
      'category': r.category,
      'description': r.description,
      if (r.lat != null) 'lat': r.lat!.toStringAsFixed(6),
      if (r.lon != null) 'lon': r.lon!.toStringAsFixed(6),
      if (r.accuracyM != null) 'accuracy_m': r.accuracyM!.toStringAsFixed(0),
    },
    fileField: r.photo == null ? null : 'photo',
    fileBytes: r.photo,
    fileName: 'photo.jpg',
  );

  Future<List<CivilReport>> myReports() async {
    final r = await client.get('/gw/v1/reports');
    return [
      for (final j in r['reports'] as List)
        CivilReport.fromJson(Map<String, dynamic>.from(j as Map)),
    ];
  }

  Future<List<dynamic>> warnings() async =>
      (await client.get('/gw/v1/warnings'))['warnings'] as List;

  Future<Map<String, dynamic>> safety() => client.get('/gw/v1/safety');
}
