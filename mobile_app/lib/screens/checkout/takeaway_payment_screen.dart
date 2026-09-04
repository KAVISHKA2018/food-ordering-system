import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/cart_provider.dart';
import '../../services/order_service.dart';

class TakeawayPaymentScreen extends StatefulWidget {
  final int restaurantId;
  final String restaurantName;
  final String notes;
  final String promoCode;
  final double discountAmount;

  const TakeawayPaymentScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    this.notes = '',
    this.promoCode = '',
    this.discountAmount = 0,
  });

  @override
  State<TakeawayPaymentScreen> createState() => _TakeawayPaymentScreenState();
}

class _TakeawayPaymentScreenState extends State<TakeawayPaymentScreen> {
  bool _paying = false;

  Future<void> _payNow(CartProvider cart) async {
    if (cart.isEmpty) return;

    setState(() => _paying = true);

    final items = cart.items.values
        .map((cartItem) => {
              'menu_item': cartItem.menuItem.id,
              if (cartItem.variant != null) 'variant': cartItem.variant!.id,
              'quantity': cartItem.quantity,
            })
        .toList();

    final result = await OrderService.createOrder(
      restaurantId: widget.restaurantId,
      orderType: 'TAKEAWAY',
      items: items,
      notes: [widget.notes, cart.buildItemNotesSummary()]
          .where((s) => s.isNotEmpty)
          .join('\n'),
      promoCode: widget.promoCode,
    );

    setState(() => _paying = false);

    if (!mounted) return;

    if (!result['success']) {
      final error = result['error'];
      String message = 'Payment failed. Please try again.';
      if (error is Map) {
        message = error.values.first.toString();
      } else if (error is List) {
        message = error.first.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return; // stay on this screen, cart untouched, customer can retry
    }

    final order = result['order'];
    cart.clear(); // only clear AFTER the order successfully exists

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Payment Requested'),
        content: Text(
          'Order #${order.id} has been created. Please pay at the counter — '
          'it will be sent to the kitchen once the restaurant confirms your payment.',
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

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: cart.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(widget.restaurantName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Takeaway Order',
                          style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      const Divider(height: 24),
                      ...cart.items.values.map((cartItem) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('${cartItem.quantity}x ${cartItem.displayName}'),
                                ),
                                Text('Rs. ${cartItem.subtotal.toStringAsFixed(0)}'),
                              ],
                            ),
                          )),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(fontSize: 14)),
                          Text('Rs. ${cart.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      if (widget.discountAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Discount', style: TextStyle(fontSize: 14, color: Colors.green)),
                            Text('-Rs. ${widget.discountAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 14, color: Colors.green)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total to Pay',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Rs. ${(cart.totalAmount - widget.discountAmount).toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Nothing is charged or created yet. Tap "Pay Now" below to '
                          'complete this order, or go back to keep editing your cart.',
                          style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _paying
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: () => _payNow(cart),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 0),
                            ),
                            child: Text(
                              'Pay Now (Rs. ${(cart.totalAmount - widget.discountAmount).toStringAsFixed(0)})',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}