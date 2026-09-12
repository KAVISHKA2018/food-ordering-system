import 'dart:convert';
import 'dart:async';
import '../config/api_config.dart';
import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> loginWithPassword(String identifier, String password) async {
    try {
      final response = await ApiService.post(
        ApiConfig.loginWithPassword,
        {'identifier': identifier, 'password': password},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['user']?['role'] != 'DELIVERY_STAFF') {
          return {'success': false, 'error': 'This account is not a delivery staff account.'};
        }
        await ApiService.saveTokens(data['access'], data['refresh']);
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'error': data['detail'] ?? 'Incorrect username or password.'};
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to server: $e'};
    }
  }

  static Future<void> logout() async {
    await ApiService.clearTokens();
  }
}