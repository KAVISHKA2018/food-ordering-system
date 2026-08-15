class ApiConfig {
  static const String baseUrl = 'http://10.50.113.81:8000/api';

  static const String register = '$baseUrl/accounts/register/';
  static const String login = '$baseUrl/accounts/login/';
  static const String me = '$baseUrl/accounts/me/';
  static const String restaurants = '$baseUrl/restaurants/';
  static const String menuItems = '$baseUrl/menu-items/';
  static const String orders = '$baseUrl/orders/';
  static const String reservations = '$baseUrl/reservations/';

  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = baseUrl.replaceAll('/api', '');
    return '$base$path';
  }
}