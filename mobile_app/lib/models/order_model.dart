class OrderItemModel {
  final int? id;
  final int menuItemId;
  final int? variantId;
  final String itemName;
  final String variantName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  OrderItemModel({
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

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
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

class OrderModel {
  final int id;
  final int restaurantId;
  final String restaurantName;
  final String orderType;
  final String status;
  final String deliveryAddress;
  final String contactPhone;
  final String? tableNumber;
  final String paymentStatus;
  final double totalAmount;
  final String notes;
  final List<OrderItemModel> items;
  final String createdAt;

  OrderModel({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.orderType,
    required this.status,
    required this.deliveryAddress,
    this.contactPhone = '',
    this.tableNumber,
    this.paymentStatus = 'N/A',
    required this.totalAmount,
    required this.notes,
    required this.items,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      restaurantId: json['restaurant'],
      restaurantName: json['restaurant_name'] ?? '',
      orderType: json['order_type'],
      status: json['status'],
      deliveryAddress: json['delivery_address'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      tableNumber: json['table_number'],
      paymentStatus: json['payment_status'] ?? 'N/A',
      totalAmount: double.parse(json['total_amount'].toString()),
      notes: json['notes'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => OrderItemModel.fromJson(i))
          .toList(),
      createdAt: json['created_at'] ?? '',
    );
  }
}