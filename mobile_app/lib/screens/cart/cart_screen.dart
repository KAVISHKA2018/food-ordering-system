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
  final _notesController = TextEditingController();
  bool _placing = false;

  final _orderTypes = const {
    'DINE_IN': 'Dine In',
    'TAKEAWAY': 'Takeaway',
    'DELIVERY': 'Delivery',
  };

  @override
  void dispose() {
    _addressController.dispose();
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

    setState(() => _placing = true);

    final items = cart.items.values
        .map((cartItem) => {
              'menu_item': cartItem.menuItem.id,
              'quantity': cartItem.quantity,
            })
        .toList();

    final result = await OrderService.createOrder(
      restaurantId: cart.restaurantId!,
      orderType: _orderType,
      items: items,
      deliveryAddress: _addressController.text.trim(),
      notes: _notesController.text.trim(),
    );

    setState(() => _placing = false);

    if (result['success'] && mounted) {
      cart.clear();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Order Placed!'),
          content: Text(
              'Your order #${result['order'].id} has been placed successfully.'),
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
    } else if (mounted) {
      final error = result['error'];
      String message = 'Failed to place order';
      if (error is Map) {
        message = error.values.first.toString();
      } else if (error is List) {
        message = error.first.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(cart.restaurantName ?? 'Your Cart')),
      body: cart.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...cart.items.values.map((cartItem) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(cartItem.menuItem.name),
                        subtitle: Text('Rs. ${cartItem.menuItem.price.toStringAsFixed(0)} x ${cartItem.quantity}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => cart.decrement(cartItem.menuItem.id),
                            ),
                            Text('${cartItem.quantity}'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => cart.increment(cartItem.menuItem.id),
                            ),
                          ],
                        ),
                      ),
                    )),
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
                        child: const Text('Place Order', style: TextStyle(fontSize: 16)),
                      ),
              ],
            ),
    );
  }
}