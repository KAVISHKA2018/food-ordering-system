import 'dart:convert';
import '../config/api_config.dart';
import '../models/menu_item_model.dart';
import 'api_service.dart';

class RecommendationService {
  static Future<List<MenuItemModel>> getForMe({int limit = 10}) async {
    final response = await ApiService.get(
      '${ApiConfig.baseUrl}/recommendations/for-me/?limit=$limit',
      auth: true,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => MenuItemModel.fromJson(json)).toList();
    }
    return [];
  }

  static Future<List<MenuItemModel>> getForRestaurant(int restaurantId, {int limit = 6}) async {
    final response = await ApiService.get(
      '${ApiConfig.baseUrl}/recommendations/restaurant/$restaurantId/?limit=$limit',
      auth: false,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => MenuItemModel.fromJson(json)).toList();
    }
    return [];
  }

  static Future<List<MenuItemModel>> getOrderAgain({int limit = 10}) async {
    final response = await ApiService.get(
      '${ApiConfig.baseUrl}/recommendations/order-again/?limit=$limit',
      auth: true,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => MenuItemModel.fromJson(json)).toList();
    }
    return [];
  }
}