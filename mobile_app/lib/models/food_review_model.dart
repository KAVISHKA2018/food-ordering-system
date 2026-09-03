class FoodReviewModel {
  final int id;
  final int orderItemId;
  final int? menuItemId;
  final String itemName;
  final int rating;
  final String comment;
  final String createdAt;

  FoodReviewModel({
    required this.id,
    required this.orderItemId,
    this.menuItemId,
    required this.itemName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory FoodReviewModel.fromJson(Map<String, dynamic> json) {
    return FoodReviewModel(
      id: json['id'],
      orderItemId: json['order_item'],
      menuItemId: json['menu_item'],
      itemName: json['item_name'] ?? '',
      rating: json['rating'],
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}