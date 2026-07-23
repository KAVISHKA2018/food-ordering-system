class PreOrderItemModel {
  final int? id;
  final int menuItemId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  PreOrderItemModel({
    this.id,
    required this.menuItemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory PreOrderItemModel.fromJson(Map<String, dynamic> json) {
    return PreOrderItemModel(
      id: json['id'],
      menuItemId: json['menu_item'],
      itemName: json['item_name'] ?? '',
      quantity: json['quantity'],
      unitPrice: double.parse(json['unit_price'].toString()),
      subtotal: double.parse(json['subtotal'].toString()),
    );
  }
}

class ReservationModel {
  final int id;
  final int restaurantId;
  final String reservationDate;
  final String reservationTime;
  final int partySize;
  final String status;
  final String specialRequests;
  final double preOrderTotal;
  final List<PreOrderItemModel> preOrderItems;
  final String createdAt;

  ReservationModel({
    required this.id,
    required this.restaurantId,
    required this.reservationDate,
    required this.reservationTime,
    required this.partySize,
    required this.status,
    required this.specialRequests,
    required this.preOrderTotal,
    required this.preOrderItems,
    required this.createdAt,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: json['id'],
      restaurantId: json['restaurant'],
      reservationDate: json['reservation_date'],
      reservationTime: json['reservation_time'],
      partySize: json['party_size'],
      status: json['status'],
      specialRequests: json['special_requests'] ?? '',
      preOrderTotal: double.parse(json['pre_order_total'].toString()),
      preOrderItems: (json['pre_order_items'] as List<dynamic>? ?? [])
          .map((i) => PreOrderItemModel.fromJson(i))
          .toList(),
      createdAt: json['created_at'] ?? '',
    );
  }
}