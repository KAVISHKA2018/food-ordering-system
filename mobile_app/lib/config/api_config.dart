class ApiConfig {
  // Use 10.0.2.2 for Android Emulator, or your PC's local IP for a physical device
  static const String baseUrl = 'http://192.168.1.8:8000/api';

  static const String register = '$baseUrl/accounts/register/';
  static const String login = '$baseUrl/accounts/login/';
  static const String me = '$baseUrl/accounts/me/';
  static const String restaurants = '$baseUrl/restaurants/';
  static const String menuItems = '$baseUrl/menu-items/';
  static const String orders = '$baseUrl/orders/';
  static const String reservations = '$baseUrl/reservations/';
}