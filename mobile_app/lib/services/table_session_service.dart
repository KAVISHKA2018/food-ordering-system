import 'dart:convert';
import '../config/api_config.dart';
import '../models/table_session_model.dart';
import 'api_service.dart';

class TableSessionService {
  static Future<List<TableSessionModel>> getActiveSessions() async {
    final response = await ApiService.get('${ApiConfig.baseUrl}/table-sessions/active/', auth: true);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => TableSessionModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load active table sessions');
  }

  static Future<Map<String, dynamic>> paySession(int sessionId) async {
    final response = await ApiService.post(
      '${ApiConfig.baseUrl}/table-sessions/$sessionId/pay/',
      {},
      auth: true,
    );
    if (response.statusCode == 200) {
      return {'success': true, 'session': TableSessionModel.fromJson(jsonDecode(response.body))};
    }
    return {'success': false, 'error': jsonDecode(response.body)};
  }
}