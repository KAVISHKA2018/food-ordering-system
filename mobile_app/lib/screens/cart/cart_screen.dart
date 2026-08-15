import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/cart_provider.dart';
import '../../services/order_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _orderType = 'TAKEAWAY';
  final _addressController = TextEditingController();
  final _tableNumberController = TextEditingController();
  final _notesController = TextEditingController();
  bool _placing = false;
  bool _initializedFromCart = false;

  final _orderTypes = const {
    'DINE_IN': 'Dine In',
    'TAKEAWAY': 'Takeaway',
    'DELIVERY': 'Delivery',
  };

  @override
  void dispose() {
    _addressController.dispose();
    _tableNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder(CartProvider cart) async {
    if (_orderType == 'DELIVERY' && _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a delivery address')),
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

    final result = await OrderService.createOrder(
      restaurantId: cart.restaurantId!,
      orderType: _orderType,
      items: items,
      deliveryAddress: _addressController.text.trim(),
      tableNumber: _tableNumberController.text.trim(),
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

    if (order.status == 'AWAITING_PAYMENT') {
      // Takeaway: payment is required before the order goes to the kitchen.
      _showTakeawayPaymentDialog(order);
    } else {
      // Dine-in (Pay Later by default) or Delivery — order already sent to kitchen.
      _showSuccessDialog(order, paid: false);
    }
  }

  Future<void> _showTakeawayPaymentDialog(dynamic order) async {
    bool paying = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Payment Required'),
              content: Text(
                'Your takeaway order total is Rs. ${order.totalAmount.toStringAsFixed(0)}.\n\n'
                'Please complete payment to send this order to the kitchen.',
              ),
              actions: [
                paying
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          setDialogState(() => paying = true);
                          final payResult = await OrderService.payOrder(order.id);
                          if (!mounted) return;
                          Navigator.pop(dialogContext);
                          if (payResult['success']) {
                            _showSuccessDialog(payResult['order'], paid: true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Payment failed. Please try again from My Orders.')),
                            );
                          }
                        },
                        child: Text('Pay Now (Rs. ${order.totalAmount.toStringAsFixed(0)})'),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(dynamic order, {required bool paid}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Order Placed!'),
        content: Text(
          order.orderType == 'DINE_IN'
              ? 'Your order #${order.id} has been sent to the kitchen. It has been added to your table\'s bill — pay anytime from "My Table".'
              : paid
                  ? 'Payment received. Your order #${order.id} has been sent to the kitchen.'
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
      }
      _initializedFromCart = true;
    }

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
                  children: _orderTypes.entries.map((e) {
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
                    decoration: const InputDecoration(
                      labelText: 'Table Number',
                      hintText: 'e.g. 05',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.table_bar),
                    ),
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
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Address',
                      border: OutlineInputBorder(),
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
                        onPressed: () => _placeOrder(cart),
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