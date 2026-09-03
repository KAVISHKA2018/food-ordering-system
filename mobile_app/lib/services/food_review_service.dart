import 'dart:convert';
import '../config/api_config.dart';
import '../models/food_review_model.dart';
import 'api_service.dart';

class FoodReviewService {
  static Future<Map<String, dynamic>> submitReview({
    required int orderItemId,
    required int rating,
    String comment = '',
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.baseUrl}/food-reviews/',
      {
        'order_item': orderItemId,
        'rating': rating,
        'comment': comment,
      },
      auth: true,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return {'success': true, 'review': FoodReviewModel.fromJson(data)};
    }
    String message = 'Failed to submit review.';
    if (data is Map && data.isNotEmpty) {
      message = data.values.first.toString();
    }
    return {'success': false, 'error': message};
  }
}