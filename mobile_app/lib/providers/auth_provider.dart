import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get errorMessage => _errorMessage;

  Future<bool> updateProfile({String? email, String? phoneNumber}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await AuthService.updateProfile(
      email: email,
      phoneNumber: phoneNumber,
    );

    if (result['success']) {
      _user = result['user'];
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = _extractError(result['error']);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await AuthService.login(username: username, password: password);

    if (result['success']) {
      _user = await AuthService.getCurrentUser();
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = _extractError(result['error']);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String role,
    String phoneNumber = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await AuthService.register(
      username: username,
      email: email,
      password: password,
      role: role,
      phoneNumber: phoneNumber,
    );

    if (result['success']) {
      _user = result['user'];
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = _extractError(result['error']);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> tryAutoLogin() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      _user = user;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    notifyListeners();
  }

  String _extractError(dynamic error) {
    if (error is Map) {
      final firstKey = error.keys.first;
      final firstValue = error[firstKey];
      if (firstValue is List) return firstValue.first.toString();
      return firstValue.toString();
    }
    return 'Something went wrong. Please try again.';
  }
}