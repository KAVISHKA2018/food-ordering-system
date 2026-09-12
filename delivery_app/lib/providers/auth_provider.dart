import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'dart:convert';
import '../config/api_config.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _checkingSession = true;
  String? _errorMessage;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get checkingSession => _checkingSession;
  bool get isLoggedIn => _user != null;
  String? get errorMessage => _errorMessage;

  /// Called once at app startup — if a token is already stored (rider
  /// never logged out), silently restore their session instead of
  /// showing the login screen again.
  Future<void> tryRestoreSession() async {
    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) {
      _checkingSession = false;
      notifyListeners();
      return;
    }

    try {
      // ApiService.get() automatically attempts a token refresh internally
      // if the stored access token has expired — this is what makes
      // "log in once, then just tap the app icon" actually work long-term.
      final response = await ApiService.get(ApiConfig.me, auth: true);
      if (response.statusCode == 200) {
        _user = jsonDecode(response.body);
      } else {
        // Refresh token itself is invalid/expired too — genuinely needs
        // a fresh login this time.
        await ApiService.clearTokens();
      }
    } catch (_) {
      // Network hiccup on startup — fall back to login rather than hang.
    }

    _checkingSession = false;
    notifyListeners();
  }

  Future<bool> loginWithPassword(String identifier, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await AuthService.loginWithPassword(identifier, password);

    if (result['success']) {
      _user = result['user'];
      _isLoading = false;
      notifyListeners();
      return true;
    }
    _errorMessage = result['error'];
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    notifyListeners();
  }
}