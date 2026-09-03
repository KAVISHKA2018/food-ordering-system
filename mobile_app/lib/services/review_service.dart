import 'dart:convert';
import '../config/api_config.dart';
import '../models/review_model.dart';
import 'api_service.dart';

class ReviewService {
  static Future<Map<String, dynamic>> submitReview({
    required int orderId,
    required int rating,
    String comment = '',
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.baseUrl}/reviews/',
      {
        'order': orderId,
        'rating': rating,
        'comment': comment,
      },
      auth: true,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return {'success': true, 'review': ReviewModel.fromJson(data)};
    }
    String message = 'Failed to submit review.';
    if (data is Map && data.isNotEmpty) {
      message = data.values.first.toString();
    }
    return {'success': false, 'error': message};
  }

  static Future<List<ReviewModel>> getMyReviews() async {
    final response = await ApiService.get('${ApiConfig.baseUrl}/reviews/?mine=1', auth: true);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load reviews');
  }
}