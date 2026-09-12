import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';

  static Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _kAccessToken, value: access);
    await _storage.write(key: _kRefreshToken, value: refresh);
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _kAccessToken);
  }

  static Future<String?> _getRefreshToken() async {
    return _storage.read(key: _kRefreshToken);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }

  /// Uses the stored refresh token to get a new access token — this is
  /// what lets the rider stay logged in across app restarts long after
  /// their original access token has expired, without re-entering
  /// username/password. Returns true if it succeeded.
  static Future<bool> _tryRefreshAccessToken() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.tokenRefresh),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccess = data['access'];
        // Some SimpleJWT configs rotate the refresh token too — keep the
        // old one unless a new one was actually issued.
        final newRefresh = data['refresh'] ?? refreshToken;
        if (newAccess != null) {
          await saveTokens(newAccess, newRefresh);
          return true;
        }
      }
    } catch (_) {
      // Network hiccup — treat as failure, caller falls back to login.
    }
    return false;
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Runs [request] once; if it comes back 401 (expired access token) AND
  /// this was an authenticated call, silently refreshes and retries ONE
  /// more time with the new token before giving up. Completely invisible
  /// to callers — they just see the eventual real response.
  static Future<http.Response> _withAutoRefresh(
    bool auth,
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    final headers = await _headers(auth: auth);
    final response = await request(headers);

    if (auth && response.statusCode == 401) {
      final refreshed = await _tryRefreshAccessToken();
      if (refreshed) {
        final newHeaders = await _headers(auth: auth);
        return request(newHeaders);
      }
    }
    return response;
  }

  static Future<http.Response> get(String url, {bool auth = false}) async {
    return _withAutoRefresh(auth, (headers) => http.get(Uri.parse(url), headers: headers));
  }

  static Future<http.Response> post(String url, Map<String, dynamic> body, {bool auth = false}) async {
    return _withAutoRefresh(
      auth,
      (headers) => http.post(Uri.parse(url), headers: headers, body: jsonEncode(body)),
    );
  }
}