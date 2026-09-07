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
    String paymentMethod = 'CASH',
  }) async {
    final body = {
      'restaurant': restaurantId,
      'order_type': orderType,
      'delivery_address': deliveryAddress,
      'contact_phone': contactPhone,
      'notes': notes,
      'items': items,
      'payment_method': paymentMethod,
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

  /// Creates a Stripe Checkout session for a pending payment and returns
  /// the hosted checkout URL to load in a WebView.
  static Future<Map<String, dynamic>> createCheckoutSession(int paymentId) async {
    final response = await ApiService.post(
      '${ApiConfig.baseUrl}/payments/$paymentId/create-checkout-session/',
      {},
      auth: true,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'checkoutUrl': data['checkout_url']};
    }
    return {'success': false, 'error': data['detail'] ?? 'Could not start payment.'};
  }

  /// Polled after the customer returns from the Stripe checkout page —
  /// only this (backed by the webhook) is trusted to confirm payment,
  /// never the browser redirect alone.
  static Future<String?> getPaymentStatus(int paymentId) async {
    final response = await ApiService.get(
      '${ApiConfig.baseUrl}/payments/$paymentId/status/',
      auth: true,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['status'];
    }
    return null;
  }

  static Future<Map<String, dynamic>> cancelOrder(int orderId) async {
    final response = await ApiService.post(
      '${ApiConfig.orders}$orderId/cancel/',
      {},
      auth: true,
    );
    if (response.statusCode == 200) {
      return {'success': true, 'order': OrderModel.fromJson(jsonDecode(response.body))};
    }
    final data = jsonDecode(response.body);
    return {'success': false, 'error': data['detail'] ?? 'Could not cancel order.'};
  }

  static Future<Map<String, dynamic>> requestCashForOrder(int orderId) async {
    final response = await ApiService.post(
      '${ApiConfig.orders}$orderId/request_cash/',
      {},
      auth: true,
    );
    if (response.statusCode == 200) {
      return {'success': true, 'order': OrderModel.fromJson(jsonDecode(response.body))};
    }
    final data = jsonDecode(response.body);
    return {'success': false, 'error': data['detail'] ?? 'Could not switch to cash.'};
  }
}