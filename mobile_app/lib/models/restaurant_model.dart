import 'menu_item_model.dart';

class CategoryModel {
  final int id;
  final String name;
  final List<MenuItemModel> menuItems;

  CategoryModel({
    required this.id,
    required this.name,
    required this.menuItems,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      name: json['name'],
      menuItems: (json['menu_items'] as List<dynamic>? ?? [])
          .map((item) => MenuItemModel.fromJson(item))
          .toList(),
    );
  }
}

class RestaurantModel {
  final int id;
  final String name;
  final String description;
  final String address;
  final String phoneNumber;
  final String? logo;
  final String? coverImage;
  final bool isActive;
  final bool supportsDineIn;
  final bool supportsTakeaway;
  final bool supportsDelivery;
  final bool supportsReservations;
  final List<CategoryModel> categories;
  final double? averageRating;
  final int reviewCount;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.phoneNumber,
    this.logo,
    this.coverImage,
    required this.isActive,
    this.supportsDineIn = true,
    this.supportsTakeaway = true,
    this.supportsDelivery = true,
    this.supportsReservations = true,
    this.categories = const [],
    this.averageRating,
    this.reviewCount = 0,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    return RestaurantModel(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      logo: json['logo'],
      coverImage: json['cover_image'],
      isActive: json['is_active'] ?? true,
      supportsDineIn: json['supports_dine_in'] ?? true,
      supportsTakeaway: json['supports_takeaway'] ?? true,
      supportsDelivery: json['supports_delivery'] ?? true,
      supportsReservations: json['supports_reservations'] ?? true,
      categories: json['categories'] != null
          ? (json['categories'] as List<dynamic>)
              .map((cat) => CategoryModel.fromJson(cat))
              .toList()
          : [],
      averageRating: json['average_rating'] != null ? double.parse(json['average_rating'].toString()) : null,
      reviewCount: json['review_count'] ?? 0,
    );
  }
}