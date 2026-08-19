import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/cart_provider.dart';
import '../../services/order_service.dart';
import '../../utils/table_number_utils.dart';
import '../checkout/delivery_details_screen.dart';
import '../checkout/takeaway_payment_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _orderType = 'TAKEAWAY';
  String _deliveryAddress = '';
  String _contactPhone = '';
  final _tableNumberController = TextEditingController();
  final _notesController = TextEditingController();
  bool _placing = false;
  bool _initializedFromCart = false;

  // True when this cart session started from a QR scan / "Add More Food" —
  // in that case the customer is physically at the restaurant, so Delivery
  // should not be offered as an option.
  bool _isTableFlow = false;

  @override
  void dispose() {
    _tableNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Map<String, String> get _availableOrderTypes {
    if (_isTableFlow) {
      return const {'DINE_IN': 'Dine In', 'TAKEAWAY': 'Takeaway'};
    }
    return const {'DINE_IN': 'Dine In', 'TAKEAWAY': 'Takeaway', 'DELIVERY': 'Delivery'};
  }

  Future<void> _handleSelectOrderType(String type) async {
    if (type == 'DELIVERY') {
      final result = await Navigator.push<DeliveryDetailsResult>(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryDetailsScreen(
            initialAddress: _deliveryAddress,
            initialPhone: _contactPhone,
          ),
        ),
      );
      if (result == null) return; // cancelled — keep previous selection
      setState(() {
        _orderType = 'DELIVERY';
        _deliveryAddress = result.address;
        _contactPhone = result.phone;
      });
    } else {
      setState(() => _orderType = type);
    }
  }

  Future<void> _placeOrder(CartProvider cart) async {
    if (_orderType == 'DELIVERY' && _deliveryAddress.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide delivery details')),
      );
      return;
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
      deliveryAddress: _deliveryAddress,
      contactPhone: _contactPhone,
      tableNumber: normalizedTable,
      notes: _notesController.text.trim(),
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
        ),
      ),
    );
    // The payment screen handles everything itself (create + clear cart on
    // success, or nothing at all if cancelled). Just refresh this screen's
    // state on return in case the cart was cleared.
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
        // Came from "Add More Food" — table number already known.
        _orderType = 'DINE_IN';
        _tableNumberController.text = cart.pendingTableNumber!;
        _isTableFlow = true;
      } else if (cart.isQRFlow) {
        // Came from QR scan — Dine In confirmed, but table number is
        // entered here at checkout instead of during scanning.
        _orderType = 'DINE_IN';
        _isTableFlow = true;
      }
      _initializedFromCart = true;
    }

    final orderTypes = _availableOrderTypes;

    return Scaffold(
      appBar: AppBar(title: Text(cart.restaurantName ?? 'Your Cart')),
      body: cart.isEmpty
          ? const Center(child: Text('Your cart is empty'))
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
                      onSelected: (_) => _handleSelectOrderType(e.key),
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
                      hintText: 'e.g. 3 or 03',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.table_bar),
                    ),
                    onEditingComplete: () {
                      _tableNumberController.text = normalizeTableNumber(_tableNumberController.text);
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textGrey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _deliveryAddress.isEmpty ? 'No address set' : _deliveryAddress,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 18, color: AppColors.textGrey),
                            const SizedBox(width: 6),
                            Text(_contactPhone.isEmpty ? 'No phone set' : _contactPhone,
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _handleSelectOrderType('DELIVERY'),
                            child: const Text('Edit'),
                          ),
                        ),
                      ],
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
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Rs. ${cart.totalAmount.toStringAsFixed(0)}',
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