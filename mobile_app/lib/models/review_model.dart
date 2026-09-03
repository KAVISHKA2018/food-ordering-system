class ReviewModel {
  final int id;
  final int restaurantId;
  final String restaurantName;
  final int orderId;
  final int rating;
  final String comment;
  final String restaurantReply;
  final String createdAt;

  ReviewModel({
    required this.id,
    required this.restaurantId,
    this.restaurantName = '',
    required this.orderId,
    required this.rating,
    required this.comment,
    this.restaurantReply = '',
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'],
      restaurantId: json['restaurant'],
      restaurantName: json['restaurant_name'] ?? '',
      orderId: json['order'],
      rating: json['rating'],
      comment: json['comment'] ?? '',
      restaurantReply: json['restaurant_reply'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}