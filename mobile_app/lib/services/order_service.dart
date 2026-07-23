import 'dart:convert';
import '../config/api_config.dart';
import '../models/order_model.dart';
import 'api_service.dart';

class OrderService {
  static Future<Map<String, dynamic>> createOrder({
    required int restaurantId,
    required String orderType,
    required List<Map<String, dynamic>> items,
    String deliveryAddress = '',
    String notes = '',
  }) async {
    final response = await ApiService.post(
      ApiConfig.orders,
      {
        'restaurant': restaurantId,
        'order_type': orderType,
        'delivery_address': deliveryAddress,
        'notes': notes,
        'items': items,
      },
      auth: true,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return {'success': true, 'order': OrderModel.fromJson(data)};
    } else {
      return {'success': false, 'error': data};
    }
  }

  static Future<List<OrderModel>> getMyOrders() async {
    final response = await ApiService.get(ApiConfig.orders, auth: true);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => OrderModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load orders');
  }
}