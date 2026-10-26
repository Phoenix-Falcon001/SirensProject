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
}
