import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get errorMessage => _errorMessage;

  Future<Map<String, dynamic>> requestOtp(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await AuthService.requestOtp(phoneNumber);

    _isLoading = false;
    if (!result['success']) _errorMessage = result['error'];
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await AuthService.verifyOtp(phoneNumber, code);

    _isLoading = false;
    if (!result['success']) _errorMessage = result['error'];
    notifyListeners();
    return result;
  }

  Future<bool> completeRegistration(Map<String, String> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await AuthService.registerWithDetails(data);

    if (result['success']) {
      _user = result['user'];
      NotificationService.registerCurrentDevice();
      _isLoading = false;
      notifyListeners();
      return true;
    }
    _errorMessage = result['error'];
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> loginWithPassword(String identifier, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await AuthService.loginWithPassword(identifier, password);

    if (result['success']) {
      _user = result['user'];
      NotificationService.registerCurrentDevice();
      _isLoading = false;
      notifyListeners();
      return true;
    }
    _errorMessage = result['error'];
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> loginWithPin(String phoneNumber, String pin) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await AuthService.loginWithPin(phoneNumber, pin);

    if (result['success']) {
      _user = result['user'];
      NotificationService.registerCurrentDevice();
      _isLoading = false;
      notifyListeners();
      return true;
    }
    _errorMessage = result['error'];
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> enablePin(String pin) async {
    final result = await AuthService.enablePin(pin);
    if (result['success']) {
      _user = result['user'];
      notifyListeners();
      return true;
    }
    _errorMessage = result['error'];
    notifyListeners();
    return false;
  }

  Future<bool> disablePin() async {
    final result = await AuthService.disablePin();
    if (result['success']) {
      _user = result['user'];
      notifyListeners();
      return true;
    }
    _errorMessage = result['error'];
    notifyListeners();
    return false;
  }

  Future<bool> updateProfile({String? email, String? phoneNumber}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await AuthService.updateProfile(email: email, phoneNumber: phoneNumber);

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
    await NotificationService.unregisterCurrentDevice();
    await AuthService.logout();
    _user = null;
    notifyListeners();
  }
}