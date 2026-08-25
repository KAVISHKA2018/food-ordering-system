class PreOrderItemModel {
  final int? id;
  final int menuItemId;
  final int? variantId;
  final String itemName;
  final String variantName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  PreOrderItemModel({
    this.id,
    required this.menuItemId,
    this.variantId,
    required this.itemName,
    this.variantName = '',
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  String get displayName =>
      variantName.isNotEmpty ? '$itemName ($variantName)' : itemName;

  factory PreOrderItemModel.fromJson(Map<String, dynamic> json) {
    return PreOrderItemModel(
      id: json['id'],
      menuItemId: json['menu_item'],
      variantId: json['variant'],
      itemName: json['item_name'] ?? '',
      variantName: json['variant_name'] ?? '',
      quantity: json['quantity'],
      unitPrice: double.parse(json['unit_price'].toString()),
      subtotal: double.parse(json['subtotal'].toString()),
    );
  }
}

class ReservationModel {
  final int id;
  final int restaurantId;
  final String restaurantName;
  final String reservationDate;
  final String reservationTime;
  final int partySize;
  final String status;
  final String tableNumber;
  final int? tableSession;
  final String paymentStatus;
  final String specialRequests;
  final double preOrderTotal;
  final double currentBillTotal;
  final List<PreOrderItemModel> preOrderItems;
  final String createdAt;

  ReservationModel({
    required this.id,
    required this.restaurantId,
    this.restaurantName = '',
    required this.reservationDate,
    required this.reservationTime,
    required this.partySize,
    required this.status,
    this.tableNumber = '',
    this.tableSession,
    this.paymentStatus = 'N/A',
    required this.specialRequests,
    required this.preOrderTotal,
    required this.currentBillTotal,
    required this.preOrderItems,
    required this.createdAt,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    final preOrderTotal = double.parse(json['pre_order_total'].toString());
    return ReservationModel(
      id: json['id'],
      restaurantId: json['restaurant'],
      restaurantName: json['restaurant_name'] ?? '',
      reservationDate: json['reservation_date'],
      reservationTime: json['reservation_time'],
      partySize: json['party_size'],
      status: json['status'],
      tableNumber: json['table_number'] ?? '',
      tableSession: json['table_session'],
      paymentStatus: json['payment_status'] ?? 'N/A',
      specialRequests: json['special_requests'] ?? '',
      preOrderTotal: preOrderTotal,
      currentBillTotal: json['current_bill_total'] != null
          ? double.parse(json['current_bill_total'].toString())
          : preOrderTotal,
      preOrderItems: (json['pre_order_items'] as List<dynamic>? ?? [])
          .map((i) => PreOrderItemModel.fromJson(i))
          .toList(),
      createdAt: json['created_at'] ?? '',
    );
  }
}