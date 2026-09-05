class ApiConfig {
  static const String baseUrl = 'http://172.20.10.11:8000/api';

  static const String register = '$baseUrl/accounts/register/';
  static const String login = '$baseUrl/accounts/login/';
  static const String me = '$baseUrl/accounts/me/';
  static const String restaurants = '$baseUrl/restaurants/';
  static const String menuItems = '$baseUrl/menu-items/';
  static const String orders = '$baseUrl/orders/';
  static const String reservations = '$baseUrl/reservations/';
  static const String registerDevice = '$baseUrl/notifications/register-device/';
  static const String unregisterDevice = '$baseUrl/notifications/unregister-device/';

  // Phone OTP (registration verification only)
  static const String requestOtp = '$baseUrl/accounts/request-otp/';
  static const String verifyOtp = '$baseUrl/accounts/verify-otp/';

  // Registration and default login
  static const String registerWithDetails = '$baseUrl/accounts/register-with-details/';
  static const String loginWithPassword = '$baseUrl/accounts/login-with-password/';

  // Optional PIN login (opt-in from Profile/Settings)
  static const String enablePin = '$baseUrl/accounts/enable-pin/';
  static const String disablePin = '$baseUrl/accounts/disable-pin/';
  static const String loginWithPin = '$baseUrl/accounts/login-with-pin/';

  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = baseUrl.replaceAll('/api', '');
    return '$base$path';
  }
}