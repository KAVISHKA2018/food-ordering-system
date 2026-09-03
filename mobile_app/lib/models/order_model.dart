class OrderItemModel {
  final int? id;
  final int menuItemId;
  final int? variantId;
  final String itemName;
  final String variantName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final bool hasFoodReview;

  OrderItemModel({
    this.id,
    required this.menuItemId,
    this.variantId,
    required this.itemName,
    this.variantName = '',
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.hasFoodReview = false,
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
      hasFoodReview: json['has_food_review'] ?? false,
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
  final double subtotalAmount;
  final double discountAmount;
  final String? promotionTitle;
  final String notes;
  final List<OrderItemModel> items;
  final bool hasReview;
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
    required this.subtotalAmount,
    required this.discountAmount,
    this.promotionTitle,
    required this.totalAmount,
    required this.notes,
    required this.items,
    required this.hasReview,
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
      subtotalAmount: json['subtotal_amount'] != null
          ? double.parse(json['subtotal_amount'].toString())
          : double.parse(json['total_amount'].toString()),
      discountAmount: json['discount_amount'] != null
          ? double.parse(json['discount_amount'].toString())
          : 0,
      promotionTitle: json['promotion_title'],
      notes: json['notes'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => OrderItemModel.fromJson(i))
          .toList(),
      hasReview: json['has_review'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}