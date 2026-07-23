import 'dart:convert';
import '../config/api_config.dart';
import '../models/reservation_model.dart';
import 'api_service.dart';

class ReservationService {
  static Future<Map<String, dynamic>> createReservation({
    required int restaurantId,
    required String reservationDate, // 'YYYY-MM-DD'
    required String reservationTime, // 'HH:MM:SS'
    required int partySize,
    List<Map<String, dynamic>> preOrderItems = const [],
    String specialRequests = '',
  }) async {
    final response = await ApiService.post(
      ApiConfig.reservations,
      {
        'restaurant': restaurantId,
        'reservation_date': reservationDate,
        'reservation_time': reservationTime,
        'party_size': partySize,
        'special_requests': specialRequests,
        'pre_order_items': preOrderItems,
      },
      auth: true,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return {'success': true, 'reservation': ReservationModel.fromJson(data)};
    } else {
      return {'success': false, 'error': data};
    }
  }

  static Future<List<ReservationModel>> getMyReservations() async {
    final response = await ApiService.get(ApiConfig.reservations, auth: true);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ReservationModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load reservations');
  }
}