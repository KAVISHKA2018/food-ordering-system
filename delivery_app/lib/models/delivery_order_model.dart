class DeliveryOrderItem {
  final String itemName;
  final String variantName;
  final int quantity;

  DeliveryOrderItem({required this.itemName, required this.variantName, required this.quantity});

  factory DeliveryOrderItem.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderItem(
      itemName: json['item_name'] ?? '',
      variantName: json['variant_name'] ?? '',
      quantity: json['quantity'] ?? 1,
    );
  }

  String get displayName => variantName.isNotEmpty ? '$itemName ($variantName)' : itemName;
}

class DeliveryOrderModel {
  final int id;
  final String restaurantName;
  final String status;
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String contactPhone;
  final String alternativePhone;
  final String customerUsername;
  final double totalAmount;
  final String paymentMethod;
  final List<DeliveryOrderItem> items;
  final String createdAt;
  final String? deliveryStartedAt;

  DeliveryOrderModel({
    required this.id,
    required this.restaurantName,
    required this.status,
    required this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    required this.contactPhone,
    required this.alternativePhone,
    required this.customerUsername,
    required this.totalAmount,
    required this.paymentMethod,
    required this.items,
    required this.createdAt,
    this.deliveryStartedAt,
  });

  bool get tripStarted => deliveryStartedAt != null;

  factory DeliveryOrderModel.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderModel(
      id: json['id'],
      restaurantName: json['restaurant_name'] ?? '',
      status: json['status'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      deliveryLatitude: json['delivery_latitude']?.toDouble(),
      deliveryLongitude: json['delivery_longitude']?.toDouble(),
      contactPhone: json['contact_phone'] ?? '',
      alternativePhone: json['alternative_phone'] ?? '',
      customerUsername: json['customer_username'] ?? '',
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      paymentMethod: json['payment_method'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => DeliveryOrderItem.fromJson(i))
          .toList(),
      createdAt: json['created_at'] ?? '',
      deliveryStartedAt: json['delivery_started_at'],
    );
  }
}