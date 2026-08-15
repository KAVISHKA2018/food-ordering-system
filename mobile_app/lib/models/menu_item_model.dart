class MenuItemVariantModel {
  final int id;
  final int menuItemId;
  final String name;
  final double price;

  MenuItemVariantModel({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
  });

  factory MenuItemVariantModel.fromJson(Map<String, dynamic> json) {
    return MenuItemVariantModel(
      id: json['id'],
      menuItemId: json['menu_item'],
      name: json['name'],
      price: double.parse(json['price'].toString()),
    );
  }
}

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
  final List<MenuItemVariantModel> variants;

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
    this.variants = const [],
  });

  bool get hasVariants => variants.isNotEmpty;

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
      variants: (json['variants'] as List<dynamic>? ?? [])
          .map((v) => MenuItemVariantModel.fromJson(v))
          .toList(),
    );
  }
}