import 'order_model.dart';

class TableSessionModel {
  final int id;
  final int restaurantId;
  final String restaurantName;
  final String tableNumber;
  final String status;
  final double totalAmount;
  final List<OrderModel> orders;
  final String createdAt;

  TableSessionModel({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.tableNumber,
    required this.status,
    required this.totalAmount,
    required this.orders,
    required this.createdAt,
  });

  factory TableSessionModel.fromJson(Map<String, dynamic> json) {
    return TableSessionModel(
      id: json['id'],
      restaurantId: json['restaurant'],
      restaurantName: json['restaurant_name'] ?? '',
      tableNumber: json['table_number'] ?? '',
      status: json['status'] ?? 'OPEN',
      totalAmount: double.parse(json['total_amount'].toString()),
      orders: (json['orders'] as List<dynamic>? ?? [])
          .map((o) => OrderModel.fromJson(o))
          .toList(),
      createdAt: json['created_at'] ?? '',
    );
  }
}
