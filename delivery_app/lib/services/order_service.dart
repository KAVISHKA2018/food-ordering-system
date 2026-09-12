import 'dart:convert';
import '../config/api_config.dart';
import '../models/delivery_order_model.dart';
import 'api_service.dart';

class OrderService {
  /// Backend already scopes this to only orders assigned to the logged-in
  /// delivery staff member (see OrderViewSet.get_queryset's DELIVERY_STAFF
  /// branch) — no extra filtering needed here.
  static Future<List<DeliveryOrderModel>> getMyDeliveries() async {
    final response = await ApiService.get(ApiConfig.orders, auth: true);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => DeliveryOrderModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load deliveries');
  }

  static Future<Map<String, dynamic>> markDelivered(int orderId) async {
    final response = await ApiService.post(
      '${ApiConfig.orders}$orderId/mark_delivered/',
      {},
      auth: true,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'order': DeliveryOrderModel.fromJson(data)};
    }
    return {'success': false, 'error': data['detail'] ?? 'Could not mark as delivered.'};
  }

  static Future<Map<String, dynamic>> startTrip(int orderId) async {
    final response = await ApiService.post(
      '${ApiConfig.orders}$orderId/start_trip/',
      {},
      auth: true,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'order': DeliveryOrderModel.fromJson(data)};
    }
    return {'success': false, 'error': data['detail'] ?? 'Could not start trip.'};
  }

  static Future<void> updateRiderLocation(int orderId, double lat, double lng) async {
    // Fire-and-forget by design — a single missed location ping isn't
    // worth interrupting the rider with an error; the next periodic
    // update will simply catch up.
    try {
      await ApiService.post(
        '${ApiConfig.orders}$orderId/update_rider_location/',
        {'latitude': lat, 'longitude': lng},
        auth: true,
      );
    } catch (_) {}
  }
}