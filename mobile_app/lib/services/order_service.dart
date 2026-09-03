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
    String contactPhone = '',
    String tableNumber = '',
    String notes = '',
    String promoCode = '',
  }) async {
    final body = {
      'restaurant': restaurantId,
      'order_type': orderType,
      'delivery_address': deliveryAddress,
      'contact_phone': contactPhone,
      'notes': notes,
      'items': items,
    };
    if (orderType == 'DINE_IN') {
      body['table_number'] = tableNumber;
    }
    if (promoCode.trim().isNotEmpty) {
      body['promo_code'] = promoCode.trim();
    }

    final response = await ApiService.post(
      ApiConfig.orders,
      body,
      auth: true,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return {'success': true, 'order': OrderModel.fromJson(data)};
    } else {
      return {'success': false, 'error': data};
    }
  }

  static Future<Map<String, dynamic>> payOrder(int orderId) async {
    final response = await ApiService.post(
      '${ApiConfig.orders}$orderId/pay/',
      {},
      auth: true,
    );
    if (response.statusCode == 200) {
      return {'success': true, 'order': OrderModel.fromJson(jsonDecode(response.body))};
    }
    return {'success': false, 'error': jsonDecode(response.body)};
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