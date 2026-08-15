import 'package:flutter/foundation.dart';
import '../models/menu_item_model.dart';

class CartItem {
  final MenuItemModel menuItem;
  final MenuItemVariantModel? variant;
  int quantity;

  CartItem({required this.menuItem, this.variant, this.quantity = 1});

  double get unitPrice => variant?.price ?? menuItem.price;
  double get subtotal => unitPrice * quantity;
  String get displayName =>
      variant != null ? '${menuItem.name} (${variant!.name})' : menuItem.name;
}

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  int? _restaurantId;
  String? _restaurantName;

  // Set when the customer scans a table QR code — carries the table number
  // through to the Cart/Checkout screen so it defaults to Dine In.
  String? pendingTableNumber;

  Map<String, CartItem> get items => _items;
  int? get restaurantId => _restaurantId;
  String? get restaurantName => _restaurantName;

  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.values.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

  String _keyFor(MenuItemModel menuItem, MenuItemVariantModel? variant) {
    return variant != null ? '${menuItem.id}_v${variant.id}' : '${menuItem.id}';
  }

  int quantityFor(MenuItemModel menuItem, MenuItemVariantModel? variant) {
    final key = _keyFor(menuItem, variant);
    return _items[key]?.quantity ?? 0;
  }

  void setPendingTableNumber(int restaurantId, String restaurantName, String tableNumber) {
    // Scanning a QR for a different restaurant than what's currently in cart
    // should start fresh, same rule as adding items from a different restaurant.
    if (_restaurantId != null && _restaurantId != restaurantId) {
      clear();
    }
    _restaurantId = restaurantId;
    _restaurantName = restaurantName;
    pendingTableNumber = tableNumber;
    notifyListeners();
  }

  void clearPendingTableNumber() {
    pendingTableNumber = null;
    notifyListeners();
  }

  void addItem(
    MenuItemModel menuItem,
    int restaurantId,
    String restaurantName, {
    MenuItemVariantModel? variant,
  }) {
    if (_restaurantId != null && _restaurantId != restaurantId) {
      clear();
    }
    _restaurantId = restaurantId;
    _restaurantName = restaurantName;

    final key = _keyFor(menuItem, variant);
    if (_items.containsKey(key)) {
      _items[key]!.quantity += 1;
    } else {
      _items[key] = CartItem(menuItem: menuItem, variant: variant);
    }
    notifyListeners();
  }

  void incrementByKey(String key) {
    if (_items.containsKey(key)) {
      _items[key]!.quantity += 1;
      notifyListeners();
    }
  }

  void decrementByKey(String key) {
    if (_items.containsKey(key)) {
      if (_items[key]!.quantity > 1) {
        _items[key]!.quantity -= 1;
      } else {
        _items.remove(key);
      }
      notifyListeners();
    }
    if (_items.isEmpty) {
      _restaurantId = null;
      _restaurantName = null;
    }
  }

  void increment(MenuItemModel menuItem, MenuItemVariantModel? variant) {
    incrementByKey(_keyFor(menuItem, variant));
  }

  void decrement(MenuItemModel menuItem, MenuItemVariantModel? variant) {
    decrementByKey(_keyFor(menuItem, variant));
  }

  void removeItem(String key) {
    _items.remove(key);
    if (_items.isEmpty) {
      _restaurantId = null;
      _restaurantName = null;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _restaurantId = null;
    _restaurantName = null;
    pendingTableNumber = null;
    notifyListeners();
  }
}