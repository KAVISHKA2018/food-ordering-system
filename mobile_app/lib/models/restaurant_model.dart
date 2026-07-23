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
  final List<CategoryModel> categories;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.phoneNumber,
    this.logo,
    this.coverImage,
    required this.isActive,
    this.categories = const [],
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
      categories: json['categories'] != null
          ? (json['categories'] as List<dynamic>)
              .map((cat) => CategoryModel.fromJson(cat))
              .toList()
          : [],
    );
  }
}