class ApiConfig {
  // Same backend, same IP as your customer app — update this whenever
  // your computer's WiFi IP changes, exactly like in mobile_app.
  static const String baseUrl = 'http://192.168.158.81:8000/api';

  static const String loginWithPassword = '$baseUrl/accounts/login-with-password/';
  static const String me = '$baseUrl/accounts/me/';
  static const String orders = '$baseUrl/orders/';
  static const String tokenRefresh = '$baseUrl/accounts/token/refresh/';

  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = baseUrl.replaceAll('/api', '');
    return '$base$path';
  }
}