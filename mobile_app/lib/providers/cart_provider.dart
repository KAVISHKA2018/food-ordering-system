import 'package:flutter/foundation.dart';
import '../models/menu_item_model.dart';

class CartItem {
  final MenuItemModel menuItem;
  final MenuItemVariantModel? variant;
  int quantity;
  String note;

  CartItem({
    required this.menuItem,
    this.variant,
    this.quantity = 1,
    this.note = '',
  });

  double get unitPrice => variant?.price ?? menuItem.price;
  double get subtotal => unitPrice * quantity;
  String get displayName =>
      variant != null ? '${menuItem.name} (${variant!.name})' : menuItem.name;
}

/// One restaurant's cart. Multiple of these can exist at once — items from
/// different restaurants are never mixed together.
class RestaurantCartData {
  final int restaurantId;
  final String restaurantName;
  final Map<String, CartItem> items = {};

  RestaurantCartData({required this.restaurantId, required this.restaurantName});

  double get totalAmount => items.values.fold(0.0, (sum, i) => sum + i.subtotal);
  int get itemCount => items.values.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => items.isEmpty;

  String buildItemNotesSummary() {
    final lines = <String>[];
    for (final item in items.values) {
      if (item.note.trim().isNotEmpty) {
        lines.add('${item.displayName}: ${item.note.trim()}');
      }
    }
    return lines.join('\n');
  }
}

class CartProvider extends ChangeNotifier {
  final Map<int, RestaurantCartData> _restaurantCarts = {};

  // Set only right after a QR scan / "Add More Food" — consumed by the
  // Cart screen for whichever restaurant the customer checks out next.
  String? pendingTableNumber;
  bool isQRFlow = false;

  /// All restaurants that currently have at least one item in their cart.
  /// Empty carts are never included, matching "empty restaurants should
  /// not be displayed."
  List<RestaurantCartData> get restaurantCarts =>
      _restaurantCarts.values.where((c) => !c.isEmpty).toList();

  bool get hasAnyItems => restaurantCarts.isNotEmpty;

  RestaurantCartData? cartFor(int restaurantId) => _restaurantCarts[restaurantId];

  String _keyFor(MenuItemModel menuItem, MenuItemVariantModel? variant) {
    return variant != null ? '${menuItem.id}_v${variant.id}' : '${menuItem.id}';
  }

  int quantityFor(int restaurantId, MenuItemModel menuItem, MenuItemVariantModel? variant) {
    final cart = _restaurantCarts[restaurantId];
    if (cart == null) return 0;
    return cart.items[_keyFor(menuItem, variant)]?.quantity ?? 0;
  }

  void setPendingTableNumber(int restaurantId, String restaurantName, String tableNumber) {
    pendingTableNumber = tableNumber;
    isQRFlow = false;
    notifyListeners();
  }

  void setQRFlow(int restaurantId, String restaurantName) {
    isQRFlow = true;
    pendingTableNumber = null;
    notifyListeners();
  }

  void clearPendingTableNumber() {
    pendingTableNumber = null;
    isQRFlow = false;
    notifyListeners();
  }

  void addItem(
    MenuItemModel menuItem,
    int restaurantId,
    String restaurantName, {
    MenuItemVariantModel? variant,
    int quantity = 1,
    String? note,
  }) {
    final cart = _restaurantCarts.putIfAbsent(
      restaurantId,
      () => RestaurantCartData(restaurantId: restaurantId, restaurantName: restaurantName),
    );

    final key = _keyFor(menuItem, variant);
    if (cart.items.containsKey(key)) {
      cart.items[key]!.quantity += quantity;
      if (note != null && note.trim().isNotEmpty) {
        cart.items[key]!.note = note.trim();
      }
    } else {
      cart.items[key] = CartItem(
        menuItem: menuItem,
        variant: variant,
        quantity: quantity,
        note: note?.trim() ?? '',
      );
    }
    notifyListeners();
  }

  void incrementByKey(int restaurantId, String key) {
    final cart = _restaurantCarts[restaurantId];
    if (cart == null || !cart.items.containsKey(key)) return;
    cart.items[key]!.quantity += 1;
    notifyListeners();
  }

  void decrementByKey(int restaurantId, String key) {
    final cart = _restaurantCarts[restaurantId];
    if (cart == null || !cart.items.containsKey(key)) return;

    if (cart.items[key]!.quantity > 1) {
      cart.items[key]!.quantity -= 1;
    } else {
      cart.items.remove(key);
    }
    if (cart.isEmpty) {
      _restaurantCarts.remove(restaurantId);
    }
    notifyListeners();
  }

  void increment(int restaurantId, MenuItemModel menuItem, MenuItemVariantModel? variant) {
    incrementByKey(restaurantId, _keyFor(menuItem, variant));
  }

  void decrement(int restaurantId, MenuItemModel menuItem, MenuItemVariantModel? variant) {
    decrementByKey(restaurantId, _keyFor(menuItem, variant));
  }

  /// Clears just one restaurant's cart (e.g. after that restaurant's order
  /// is placed) — other restaurants' carts are untouched.
  void clearRestaurant(int restaurantId) {
    _restaurantCarts.remove(restaurantId);
    notifyListeners();
  }

  /// Clears everything — used on logout, not during normal checkout.
  void clearAll() {
    _restaurantCarts.clear();
    pendingTableNumber = null;
    isQRFlow = false;
    notifyListeners();
  }
}