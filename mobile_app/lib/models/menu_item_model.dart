class MenuItemModel {
  final int id;
  final int restaurantId;
  final int? categoryId;
  final String name;
  final String description;
  final double price;
  final String? image;
  final bool isAvailable;
  final bool isVegetarian;
  final int stockQuantity;

  MenuItemModel({
    required this.id,
    required this.restaurantId,
    this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    this.image,
    required this.isAvailable,
    required this.isVegetarian,
    required this.stockQuantity,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id'],
      restaurantId: json['restaurant'],
      categoryId: json['category'],
      name: json['name'],
      description: json['description'] ?? '',
      price: double.parse(json['price'].toString()),
      image: json['image'],
      isAvailable: json['is_available'] ?? true,
      isVegetarian: json['is_vegetarian'] ?? false,
      stockQuantity: json['stock_quantity'] ?? 0,
    );
  }
}