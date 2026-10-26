import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A failed call. [status] is the HTTP status, or null when the server could
/// not be reached at all.
class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int? status;
  final String message;

  bool get isNetwork => status == null;
  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiException($status, $message)';
}

/// Small JSON client shared by the gateway and the internal server.
class ApiClient {
  ApiClient(this.baseUrl, {http.Client? client, this.timeout = const Duration(seconds: 20)})
    : _http = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _http;

  /// Bearer token sent with every call once signed in.
  String? token;

  /// Called when the server says the session is no longer valid.
  void Function()? onUnauthorized;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> get(String path) =>
      _send(() => _http.get(_uri(path), headers: _headers));

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _send(() => _http.patch(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<Map<String, dynamic>> delete(String path) =>
      _send(() => _http.delete(_uri(path), headers: _headers));

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    final http.Response resp;
    try {
      resp = await call().timeout(timeout);
    } on TimeoutException {
      throw ApiException(null, 'timeout');
    } on SocketException catch (e) {
      throw ApiException(null, e.message);
    } on http.ClientException catch (e) {
      throw ApiException(null, e.message);
    }
    Map<String, dynamic> data = const {};
    if (resp.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic>) data = decoded;
      } on FormatException {
        // Not JSON (e.g. a proxy error page): fall through with an empty body.
      }
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) return data;
    final message = (data['error'] as String?) ?? 'HTTP ${resp.statusCode}';
    // A 401 on the sign-in call itself is a wrong password, not an expired session.
    if (resp.statusCode == 401 && token != null) onUnauthorized?.call();
    throw ApiException(resp.statusCode, message);
  }
}
