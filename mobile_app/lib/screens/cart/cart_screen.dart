import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/order_service.dart';
import '../../services/promotion_service.dart';
import '../../utils/table_number_utils.dart';
import '../checkout/takeaway_payment_screen.dart';

class CartScreen extends StatefulWidget {
  final RestaurantModel? restaurant;
  const CartScreen({super.key, this.restaurant});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _orderType = 'TAKEAWAY';
  final _tableNumberController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _promoCodeController = TextEditingController();

  bool _placing = false;
  bool _initializedFromCart = false;
  bool _isTableFlow = false;

  String? _appliedPromoCode;
  double _discountAmount = 0;
  String? _promoTitle;
  bool _validatingPromo = false;

  @override
  void dispose() {
    _tableNumberController.dispose();
    _deliveryAddressController.dispose();
    _contactPhoneController.dispose();
    _notesController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  Map<String, String> get _availableOrderTypes {
    final r = widget.restaurant;
    final types = <String, String>{};

    if (r?.supportsDineIn ?? true) types['DINE_IN'] = 'Dine In';
    if (r?.supportsTakeaway ?? true) types['TAKEAWAY'] = 'Takeaway';
    if (!_isTableFlow && (r?.supportsDelivery ?? true)) {
      types['DELIVERY'] = 'Delivery';
    }
    return types;
  }

  Future<void> _applyPromoCode(CartProvider cart) async {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _validatingPromo = true);
    final result = await PromotionService.validateCode(
      restaurantId: cart.restaurantId!,
      code: code,
      subtotal: cart.totalAmount,
    );
    setState(() => _validatingPromo = false);

    if (result['success']) {
      setState(() {
        _appliedPromoCode = code;
        _discountAmount = double.parse(result['discount_amount'].toString());
        _promoTitle = result['title'];
      });
    } else {
      setState(() {
        _appliedPromoCode = null;
        _discountAmount = 0;
        _promoTitle = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'].toString())),
        );
      }
    }
  }

  void _removePromoCode() {
    setState(() {
      _appliedPromoCode = null;
      _discountAmount = 0;
      _promoTitle = null;
      _promoCodeController.clear();
    });
  }

  Future<void> _placeOrder(CartProvider cart) async {
    if (_orderType == 'DELIVERY') {
      if (_deliveryAddressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a delivery address')),
        );
        return;
      }
      if (_contactPhoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a contact phone number')),
        );
        return;
      }
    }
    if (_orderType == 'DINE_IN' && _tableNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your table number')),
      );
      return;
    }

    setState(() => _placing = true);

    final items = cart.items.values
        .map((cartItem) => {
              'menu_item': cartItem.menuItem.id,
              if (cartItem.variant != null) 'variant': cartItem.variant!.id,
              'quantity': cartItem.quantity,
            })
        .toList();

    final normalizedTable = normalizeTableNumber(_tableNumberController.text);

    final result = await OrderService.createOrder(
      restaurantId: cart.restaurantId!,
      orderType: _orderType,
      items: items,
      deliveryAddress: _deliveryAddressController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      tableNumber: normalizedTable,
      notes: [_notesController.text.trim(), cart.buildItemNotesSummary()]
          .where((s) => s.isNotEmpty)
          .join('\n'),
      promoCode: _appliedPromoCode ?? '',
    );

    setState(() => _placing = false);

    if (!result['success']) {
      if (!mounted) return;
      final error = result['error'];
      String message = 'Failed to place order';
      if (error is Map) {
        message = error.values.first.toString();
      } else if (error is List) {
        message = error.first.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final order = result['order'];
    cart.clear();

    if (!mounted) return;
    _showSuccessDialog(order);
  }

  Future<void> _goToTakeawayPayment(CartProvider cart) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TakeawayPaymentScreen(
          restaurantId: cart.restaurantId!,
          restaurantName: cart.restaurantName ?? 'Restaurant',
          notes: _notesController.text.trim(),
          promoCode: _appliedPromoCode ?? '',
          discountAmount: _discountAmount,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _showSuccessDialog(dynamic order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Order Placed!'),
        content: Text(
          order.orderType == 'DINE_IN'
              ? 'Your order #${order.id} has been sent to the kitchen. It has been added to your table\'s bill — pay anytime from "My Table".'
              : 'Your order #${order.id} has been placed successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    if (!_initializedFromCart) {
      if (cart.pendingTableNumber != null) {
        _orderType = 'DINE_IN';
        _tableNumberController.text = cart.pendingTableNumber!;
        _isTableFlow = true;
      } else if (cart.isQRFlow) {
        _orderType = 'DINE_IN';
        _isTableFlow = true;
      }
      _initializedFromCart = true;
    }

    final orderTypes = _availableOrderTypes;
    if (orderTypes.isNotEmpty && !orderTypes.containsKey(_orderType)) {
      _orderType = orderTypes.keys.first;
    }

    return Scaffold(
      appBar: AppBar(title: Text(cart.restaurantName ?? 'Your Cart')),
      body: cart.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : orderTypes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'This restaurant is not currently accepting orders.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...cart.items.entries.map((entry) {
                      final key = entry.key;
                      final cartItem = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(cartItem.displayName),
                          subtitle: Text(
                              'Rs. ${cartItem.unitPrice.toStringAsFixed(0)} x ${cartItem.quantity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => cart.decrementByKey(key),
                              ),
                              Text('${cartItem.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => cart.incrementByKey(key),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const Divider(height: 32),
                    const Text('Order Type', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: orderTypes.entries.map((e) {
                        return ChoiceChip(
                          label: Text(e.value),
                          selected: _orderType == e.key,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _orderType == e.key ? Colors.white : AppColors.textDark,
                          ),
                          onSelected: (_) => setState(() => _orderType = e.key),
                        );
                      }).toList(),
                    ),
                    if (_orderType == 'DINE_IN') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tableNumberController,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'Table Number',
                          hintText: 'e.g. 3 or 05',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.table_bar),
                        ),
                        onEditingComplete: () {
                          _tableNumberController.text =
                              normalizeTableNumber(_tableNumberController.text);
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This order will be added to your table\'s bill. You can pay now or later from "My Table".',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                      ),
                    ],
                    if (_orderType == 'DELIVERY') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _deliveryAddressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Address',
                          hintText: 'House number, street, city',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contactPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone Number',
                          hintText: 'e.g. 0771234567',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ],
                    if (_orderType == 'TAKEAWAY') ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Payment is required immediately after placing a takeaway order.',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const Text('Promo Code', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_appliedPromoCode != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF7ED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_offer, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_promoTitle ?? _appliedPromoCode} applied (-Rs. ${_discountAmount.toStringAsFixed(0)})',
                                style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: _removePromoCode,
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _promoCodeController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                hintText: 'Enter promo code',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _validatingPromo
                              ? const SizedBox(
                                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : TextButton(
                                  onPressed: () => _applyPromoCode(cart),
                                  child: const Text('Apply'),
                                ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal', style: TextStyle(fontSize: 14)),
                        Text('Rs. ${cart.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    if (_discountAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount', style: TextStyle(fontSize: 14, color: Colors.green)),
                          Text('-Rs. ${_discountAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 14, color: Colors.green)),
                        ],
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Rs. ${(cart.totalAmount - _discountAmount).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _placing
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: () => _orderType == 'TAKEAWAY'
                                ? _goToTakeawayPayment(cart)
                                : _placeOrder(cart),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 0),
                            ),
                            child: Text(
                              _orderType == 'TAKEAWAY' ? 'Place Order & Pay' : 'Place Order',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                  ],
                ),
    );
  }
}