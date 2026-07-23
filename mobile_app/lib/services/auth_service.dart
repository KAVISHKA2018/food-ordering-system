import 'dart:convert';
import 'dart:async';
import '../config/api_config.dart';
import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String role,
    String phoneNumber = '',
  }) async {
    final response = await ApiService.post(ApiConfig.register, {
      'username': username,
      'email': email,
      'password': password,
      'role': role,
      'phone_number': phoneNumber,
    });

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      await ApiService.saveTokens(data['access'], data['refresh']);
      return {'success': true, 'user': data['user']};
    } else {
      return {'success': false, 'error': data};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await ApiService.post(ApiConfig.login, {
      'username': username,
      'password': password,
    });

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await ApiService.saveTokens(data['access'], data['refresh']);
      return {'success': true};
    } else {
      return {'success': false, 'error': data};
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final response = await ApiService.get(ApiConfig.me, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  static Future<void> logout() async {
    await ApiService.clearTokens();
  }
  
  static Future<Map<String, dynamic>> updateProfile({
    String? email,
    String? phoneNumber,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (email != null) body['email'] = email;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;

      final response = await ApiService.patch(ApiConfig.me, body)
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'user': data};
      } else {
        return {'success': false, 'error': data};
      }
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to server: $e'};
    }
  }
}