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

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  int? _restaurantId;
  String? _restaurantName;

  String? pendingTableNumber;
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

  /// Adds an item to the cart. [quantity] and [note] let the Food Detail
  /// Sheet add a fully-configured line (size + qty + prep note) in one call.
  void addItem(
    MenuItemModel menuItem,
    int restaurantId,
    String restaurantName, {
    MenuItemVariantModel? variant,
    int quantity = 1,
    String? note,
  }) {
    if (_restaurantId != null && _restaurantId != restaurantId) {
      clear();
    }
    _restaurantId = restaurantId;
    _restaurantName = restaurantName;

    final key = _keyFor(menuItem, variant);
    if (_items.containsKey(key)) {
      _items[key]!.quantity += quantity;
      if (note != null && note.trim().isNotEmpty) {
        _items[key]!.note = note.trim();
      }
    } else {
      _items[key] = CartItem(
        menuItem: menuItem,
        variant: variant,
        quantity: quantity,
        note: note?.trim() ?? '',
      );
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

  /// One line per cart item that has a preparation note, formatted for
  /// inclusion in the order's general Notes field (no backend schema
  /// change needed — this is a display/formatting convenience only).
  String buildItemNotesSummary() {
    final lines = <String>[];
    for (final item in _items.values) {
      if (item.note.trim().isNotEmpty) {
        lines.add('${item.displayName}: ${item.note.trim()}');
      }
    }
    return lines.join('\n');
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