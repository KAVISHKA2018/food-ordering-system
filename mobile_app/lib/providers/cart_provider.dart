import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const _storage = FlutterSecureStorage();
  static const _kCartStorageKey = 'cart_snapshot_v1';
  static const _kAwaitingOrdersKey = 'cart_awaiting_orders_v1';

  final Map<int, RestaurantCartData> _restaurantCarts = {};

  /// restaurantId -> orderId of an order that was created but never
  /// successfully paid (e.g. a Card checkout that was abandoned). While
  /// this exists for a restaurant, the customer must Pay Now or Cancel it
  /// before a new order can be placed for that restaurant — this is what
  /// prevents duplicate orders.
  final Map<int, int> _awaitingOrderId = {};

  String? pendingTableNumber;
  bool isQRFlow = false;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final raw = await _storage.read(key: _kCartStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        for (final entry in decoded) {
          final restaurantId = entry['restaurantId'] as int;
          final restaurantName = entry['restaurantName'] as String;
          final menuItemId = entry['menuItemId'] as int;
          final menuItemName = entry['menuItemName'] as String;
          final menuItemPrice = (entry['menuItemPrice'] as num).toDouble();
          final menuItemImage = entry['menuItemImage'] as String?;
          final variantId = entry['variantId'] as int?;
          final variantName = entry['variantName'] as String?;
          final variantPrice = entry['variantPrice'] != null
              ? (entry['variantPrice'] as num).toDouble()
              : null;
          final quantity = entry['quantity'] as int;
          final note = entry['note'] as String? ?? '';

          MenuItemVariantModel? variant;
          List<MenuItemVariantModel> variants = [];
          if (variantId != null) {
            variant = MenuItemVariantModel(
              id: variantId,
              menuItemId: menuItemId,
              name: variantName ?? '',
              price: variantPrice ?? menuItemPrice,
            );
            variants = [variant];
          }

          final menuItem = MenuItemModel(
            id: menuItemId,
            restaurantId: restaurantId,
            name: menuItemName,
            description: '',
            price: menuItemPrice,
            image: menuItemImage,
            isAvailable: true,
            isVegetarian: false,
            stockQuantity: 9999,
            variants: variants,
          );

          final cart = _restaurantCarts.putIfAbsent(
            restaurantId,
            () => RestaurantCartData(restaurantId: restaurantId, restaurantName: restaurantName),
          );
          final key = _keyFor(menuItem, variant);
          cart.items[key] = CartItem(menuItem: menuItem, variant: variant, quantity: quantity, note: note);
        }
      }

      final rawAwaiting = await _storage.read(key: _kAwaitingOrdersKey);
      if (rawAwaiting != null && rawAwaiting.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(rawAwaiting);
        decoded.forEach((key, value) {
          _awaitingOrderId[int.parse(key)] = value as int;
        });
      }

      notifyListeners();
    } catch (_) {
      // Corrupted or incompatible saved data — start fresh rather than crash.
    }
  }

  Future<void> _persistCart() async {
    final entries = <Map<String, dynamic>>[];
    for (final cart in _restaurantCarts.values) {
      for (final item in cart.items.values) {
        entries.add({
          'restaurantId': cart.restaurantId,
          'restaurantName': cart.restaurantName,
          'menuItemId': item.menuItem.id,
          'menuItemName': item.menuItem.name,
          'menuItemPrice': item.menuItem.price,
          'menuItemImage': item.menuItem.image,
          'variantId': item.variant?.id,
          'variantName': item.variant?.name,
          'variantPrice': item.variant?.price,
          'quantity': item.quantity,
          'note': item.note,
        });
      }
    }
    try {
      await _storage.write(key: _kCartStorageKey, value: jsonEncode(entries));
    } catch (_) {}
  }

  Future<void> _persistAwaiting() async {
    try {
      final map = _awaitingOrderId.map((k, v) => MapEntry(k.toString(), v));
      await _storage.write(key: _kAwaitingOrdersKey, value: jsonEncode(map));
    } catch (_) {}
  }

  void _notifyAndPersist() {
    notifyListeners();
    _persistCart();
  }

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
    _notifyAndPersist();
  }

  void incrementByKey(int restaurantId, String key) {
    final cart = _restaurantCarts[restaurantId];
    if (cart == null || !cart.items.containsKey(key)) return;
    cart.items[key]!.quantity += 1;
    _notifyAndPersist();
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
    _notifyAndPersist();
  }

  void increment(int restaurantId, MenuItemModel menuItem, MenuItemVariantModel? variant) {
    incrementByKey(restaurantId, _keyFor(menuItem, variant));
  }

  void decrement(int restaurantId, MenuItemModel menuItem, MenuItemVariantModel? variant) {
    decrementByKey(restaurantId, _keyFor(menuItem, variant));
  }

  void clearRestaurant(int restaurantId) {
    _restaurantCarts.remove(restaurantId);
    _notifyAndPersist();
  }

  void clearAll() {
    _restaurantCarts.clear();
    pendingTableNumber = null;
    isQRFlow = false;
    _notifyAndPersist();
  }

  // --- In-flight order tracking (prevents duplicate orders) ---

  int? awaitingOrderIdFor(int restaurantId) => _awaitingOrderId[restaurantId];

  void setAwaitingOrder(int restaurantId, int orderId) {
    _awaitingOrderId[restaurantId] = orderId;
    notifyListeners();
    _persistAwaiting();
  }

  void clearAwaitingOrder(int restaurantId) {
    _awaitingOrderId.remove(restaurantId);
    notifyListeners();
    _persistAwaiting();
  }
}