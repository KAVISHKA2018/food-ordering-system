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

  // Set only when arriving via "Add More Food" from My Table — carries a
  // known table number through to Checkout so it's pre-filled.
  String? pendingTableNumber;

  // Set when arriving via QR scan — no table number known yet, but the
  // customer is confirmed to be physically at the restaurant, so Checkout
  // should default to Dine In and hide Delivery, while still asking for
  // the table number itself at checkout.
  bool isQRFlow = false;

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

  /// Used by "Add More Food" (My Table screen) — table number already known.
  void setPendingTableNumber(int restaurantId, String restaurantName, String tableNumber) {
    if (_restaurantId != null && _restaurantId != restaurantId) {
      clear();
    }
    _restaurantId = restaurantId;
    _restaurantName = restaurantName;
    pendingTableNumber = tableNumber;
    isQRFlow = false;
    notifyListeners();
  }

  /// Used by the QR scanner — table number not yet known, will be entered
  /// by the customer at checkout.
  void setQRFlow(int restaurantId, String restaurantName) {
    if (_restaurantId != null && _restaurantId != restaurantId) {
      clear();
    }
    _restaurantId = restaurantId;
    _restaurantName = restaurantName;
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
    isQRFlow = false;
    notifyListeners();
  }
}