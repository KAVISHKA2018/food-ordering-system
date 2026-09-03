import 'dart:convert';
import '../config/api_config.dart';
import '../models/promotion_model.dart';
import 'api_service.dart';

class PromotionService {
  static Future<List<PromotionModel>> getActivePromotions({int? restaurantId}) async {
    String url = '${ApiConfig.baseUrl}/promotions/';
    if (restaurantId != null) {
      url += '?restaurant=$restaurantId';
    }
    final response = await ApiService.get(url, auth: false);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PromotionModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load promotions');
  }

  static Future<Map<String, dynamic>> validateCode({
    required int restaurantId,
    required String code,
    required double subtotal,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.baseUrl}/promotions/validate_code/',
      {
        'restaurant': restaurantId,
        'code': code,
        'subtotal': subtotal.toString(),
      },
      auth: true,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, ...data};
    }
    return {'success': false, 'error': data['detail'] ?? 'Invalid promo code.'};
  }
}