import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _kRememberedPhone = 'remembered_phone';
  static const _kRememberedName = 'remembered_first_name';
  static const _kRememberedPinEnabled = 'remembered_pin_enabled';

  // --- OTP: used to verify a phone number, both during registration AND
  // when a customer wants to change their phone number from Profile ---

  static Future<Map<String, dynamic>> requestOtp(String phoneNumber) async {
    try {
      final response = await ApiService.post(
        ApiConfig.requestOtp,
        {'phone_number': phoneNumber},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'debugOtp': data['debug_otp']};
      }
      return {'success': false, 'error': data['detail'] ?? 'Failed to request OTP.'};
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to server: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String code) async {
    try {
      final response = await ApiService.post(
        ApiConfig.verifyOtp,
        {'phone_number': phoneNumber, 'code': code},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'error': data['detail'] ?? 'Invalid OTP.'};
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to server: $e'};
    }
  }

  // --- Registration: full details form, phone already verified above ---

  static Future<Map<String, dynamic>> registerWithDetails(Map<String, String> data) async {
    try {
      final response = await ApiService.post(
        ApiConfig.registerWithDetails,
        data,
      ).timeout(const Duration(seconds: 10));
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 201) {
        await ApiService.saveTokens(responseData['access'], responseData['refresh']);
        await _saveRememberedUser(responseData['user']);
        return {'success': true, 'user': responseData['user']};
      }
      String message = 'Registration failed.';
      if (responseData is Map && responseData.isNotEmpty) {
        message = responseData.values.first.toString();
      }
      return {'success': false, 'error': message};
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to server: $e'};
    }
  }

  // --- Default login: username OR phone number + password ---

  static Future<Map<String, dynamic>> loginWithPassword(String identifier, String password) async {
    try {
      final response = await ApiService.post(
        ApiConfig.loginWithPassword,
        {'identifier': identifier, 'password': password},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await ApiService.saveTokens(data['access'], data['refresh']);
        await _saveRememberedUser(data['user']);
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'error': data['detail'] ?? 'Incorrect username/phone number or password.'};
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to server: $e'};
    }
  }

  // --- Optional PIN login, enabled by the customer from Profile/Settings ---

  static Future<Map<String, dynamic>> loginWithPin(String phoneNumber, String pin) async {
    try {
      final response = await ApiService.post(
        ApiConfig.loginWithPin,
        {'phone_number': phoneNumber, 'pin': pin},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await ApiService.saveTokens(data['access'], data['refresh']);
        await _saveRememberedUser(data['user']);
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'error': data['detail'] ?? 'Incorrect PIN.'};
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to server: $e'};
    }
  }

  static Future<Map<String, dynamic>> enablePin(String pin) async {
    try {
      final response = await ApiService.post(
        ApiConfig.enablePin,
        {'pin': pin},
        auth: true,
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await _saveRememberedUser(data);
        return {'success': true, 'user': data};
      }
      return {'success': false, 'error': data['detail'] ?? 'Failed to enable PIN.'};
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to server: $e'};
    }
  }

  static Future<Map<String, dynamic>> disablePin() async {
    try {
      final response = await ApiService.post(
        ApiConfig.disablePin,
        {},
        auth: true,
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await _saveRememberedUser(data);
        return {'success': true, 'user': data};
      }
      return {'success': false, 'error': data['detail'] ?? 'Failed to disable PIN.'};
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to server: $e'};
    }
  }

  // --- Profile update: name / email / address / profile picture.
  // NOTE: phone_number is deliberately NOT handled here — the backend
  // ignores it on this endpoint. See changePhoneNumber() below, which is
  // the only way to actually change it (requires a verified OTP). ---

  static Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? address,
    File? profilePicture,
  }) async {
    try {
      if (profilePicture != null) {
        final token = await ApiService.getAccessToken();
        final uri = Uri.parse(ApiConfig.me);
        final request = http.MultipartRequest('PATCH', uri);
        request.headers['Authorization'] = 'Bearer $token';
        if (firstName != null) request.fields['first_name'] = firstName;
        if (lastName != null) request.fields['last_name'] = lastName;
        if (email != null) request.fields['email'] = email;
        if (address != null) request.fields['address'] = address;
        request.files.add(await http.MultipartFile.fromPath('profile_picture', profilePicture.path));

        final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
        final response = await http.Response.fromStream(streamedResponse);
        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          return {'success': true, 'user': data};
        }
        return {'success': false, 'error': 'Update failed.'};
      } else {
        final body = <String, dynamic>{};
        if (firstName != null) body['first_name'] = firstName;
        if (lastName != null) body['last_name'] = lastName;
        if (email != null) body['email'] = email;
        if (address != null) body['address'] = address;

        final response = await ApiService.patch(ApiConfig.me, body)
            .timeout(const Duration(seconds: 10));
        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          return {'success': true, 'user': data};
        }
        return {'success': false, 'error': 'Update failed.'};
      }
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to server: $e'};
    }
  }

  // --- Change phone number: requires a recently-verified OTP for the new
  // number (obtained via requestOtp/verifyOtp above, same as registration) ---

  static Future<Map<String, dynamic>> changePhoneNumber(String newPhoneNumber) async {
    try {
      final response = await ApiService.post(
        ApiConfig.changePhoneNumber,
        {'phone_number': newPhoneNumber},
        auth: true,
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Keep the device-remembered phone number in sync — otherwise
        // PIN/password-only quick-login would look up the OLD number
        // next time and silently fail.
        await _saveRememberedUser(data);
        return {'success': true, 'user': data};
      }
      return {'success': false, 'error': data['detail'] ?? 'Could not change phone number.'};
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not connect to server: $e'};
    }
  }

  // --- Device-remembered identity — lets the Login screen know whether to
  // offer PIN mode ("Welcome back, X") or default to the password form ---

  static Future<void> _saveRememberedUser(Map<String, dynamic>? user) async {
    if (user == null) return;
    final phone = user['phone_number']?.toString() ?? '';
    final firstName = (user['first_name'] as String?)?.trim().isNotEmpty == true
        ? user['first_name']
        : (user['username'] ?? 'there');
    final pinEnabled = user['pin_enabled'] == true;

    await _storage.write(key: _kRememberedPhone, value: phone);
    await _storage.write(key: _kRememberedName, value: firstName);
    await _storage.write(key: _kRememberedPinEnabled, value: pinEnabled.toString());
  }

  static Future<Map<String, dynamic>?> getRememberedUser() async {
    final phone = await _storage.read(key: _kRememberedPhone);
    final name = await _storage.read(key: _kRememberedName);
    final pinEnabledStr = await _storage.read(key: _kRememberedPinEnabled);
    if (phone == null || phone.isEmpty) return null;
    return {
      'phone': phone,
      'name': name ?? 'there',
      'pinEnabled': pinEnabledStr == 'true',
    };
  }

  static Future<void> clearRememberedUser() async {
    await _storage.delete(key: _kRememberedPhone);
    await _storage.delete(key: _kRememberedName);
    await _storage.delete(key: _kRememberedPinEnabled);
  }

  // --- Session ---

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final response = await ApiService.get(ApiConfig.me, auth: true)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> logout() async {
    await ApiService.clearTokens();
  }
}