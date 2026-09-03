class PromotionModel {
  final int id;
  final int restaurantId;
  final String restaurantName;
  final String title;
  final String description;
  final String? image;
  final String code;
  final String discountType; // PERCENTAGE or FIXED
  final double discountValue;
  final double minOrderAmount;
  final String startDate;
  final String endDate;

  PromotionModel({
    required this.id,
    required this.restaurantId,
    this.restaurantName = '',
    required this.title,
    required this.description,
    this.image,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    required this.startDate,
    required this.endDate,
  });

  String get discountLabel => discountType == 'PERCENTAGE'
      ? '${discountValue.toStringAsFixed(0)}% OFF'
      : 'Rs. ${discountValue.toStringAsFixed(0)} OFF';

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: json['id'],
      restaurantId: json['restaurant'],
      restaurantName: json['restaurant_name'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      image: json['image'],
      code: json['code'] ?? '',
      discountType: json['discount_type'] ?? 'PERCENTAGE',
      discountValue: double.parse(json['discount_value'].toString()),
      minOrderAmount: double.parse(json['min_order_amount'].toString()),
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
    );
  }
}