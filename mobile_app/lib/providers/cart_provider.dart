import 'package:flutter/foundation.dart';
import '../models/menu_item_model.dart';

class CartItem {
  final MenuItemModel menuItem;
  int quantity;

  CartItem({required this.menuItem, this.quantity = 1});

  double get subtotal => menuItem.price * quantity;
}

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _items = {};
  int? _restaurantId;
  String? _restaurantName;

  Map<int, CartItem> get items => _items;
  int? get restaurantId => _restaurantId;
  String? get restaurantName => _restaurantName;

  int get itemCount => _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.values.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

  void addItem(MenuItemModel menuItem, int restaurantId, String restaurantName) {
    // Enforce single-restaurant cart — matches how checkout/order creation works (one order = one restaurant)
    if (_restaurantId != null && _restaurantId != restaurantId) {
      clear();
    }
    _restaurantId = restaurantId;
    _restaurantName = restaurantName;

    if (_items.containsKey(menuItem.id)) {
      _items[menuItem.id]!.quantity += 1;
    } else {
      _items[menuItem.id] = CartItem(menuItem: menuItem);
    }
    notifyListeners();
  }

  void increment(int menuItemId) {
    if (_items.containsKey(menuItemId)) {
      _items[menuItemId]!.quantity += 1;
      notifyListeners();
    }
  }

  void decrement(int menuItemId) {
    if (_items.containsKey(menuItemId)) {
      if (_items[menuItemId]!.quantity > 1) {
        _items[menuItemId]!.quantity -= 1;
      } else {
        _items.remove(menuItemId);
      }
      notifyListeners();
    }
    if (_items.isEmpty) {
      _restaurantId = null;
      _restaurantName = null;
    }
  }

  void removeItem(int menuItemId) {
    _items.remove(menuItemId);
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
    notifyListeners();
  }
}