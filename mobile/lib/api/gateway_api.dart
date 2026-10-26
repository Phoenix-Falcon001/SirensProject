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
}
