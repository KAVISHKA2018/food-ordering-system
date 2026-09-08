import 'dart:convert';
import '../config/api_config.dart';
import '../models/restaurant_model.dart';
import '../models/menu_item_model.dart';
import 'api_service.dart';

class RestaurantService {
  static Future<List<RestaurantModel>> getRestaurants() async {
    final response = await ApiService.get(ApiConfig.restaurants, auth: false);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => RestaurantModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load restaurants');
  }

  static Future<RestaurantModel> getRestaurantDetail(int id) async {
    final response = await ApiService.get('${ApiConfig.restaurants}$id/', auth: false);
    if (response.statusCode == 200) {
      return RestaurantModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load restaurant details');
  }

  static Future<List<MenuItemModel>> searchMenuItems(String query) async {
    final response = await ApiService.get(
      '${ApiConfig.menuItems}?search=$query',
      auth: false,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => MenuItemModel.fromJson(json)).toList();
    }
    throw Exception('Failed to search menu items');
  }

  static Future<List<RestaurantModel>> searchRestaurants(String query) async {
    final response = await ApiService.get(
      '${ApiConfig.restaurants}search/?q=${Uri.encodeQueryComponent(query)}',
      auth: false,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => RestaurantModel.fromJson(json)).toList();
    }
    throw Exception('Failed to search restaurants');
  }
}