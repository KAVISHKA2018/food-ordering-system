import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/cart_provider.dart';
import '../../services/restaurant_service.dart';
import '../cart/cart_screen.dart';

class CartTab extends StatefulWidget {
  const CartTab({super.key});

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  int? _checkingOutRestaurantId;

  Future<void> _checkout(RestaurantCartData myCart) async {
    setState(() => _checkingOutRestaurantId = myCart.restaurantId);
    try {
      final restaurant = await RestaurantService.getRestaurantDetail(myCart.restaurantId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CartScreen(restaurant: restaurant)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open checkout: $e')),
      );
    } finally {
      if (mounted) setState(() => _checkingOutRestaurantId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final carts = cart.restaurantCarts;

    if (carts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 60, color: AppColors.textGrey),
              SizedBox(height: 12),
              Text('Your cart is empty', style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
              SizedBox(height: 4),
              Text('Browse restaurants to start ordering.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: carts.length,
      itemBuilder: (context, index) {
        final myCart = carts[index];
        final isCheckingOut = _checkingOutRestaurantId == myCart.restaurantId;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(myCart.restaurantName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 20),
                ...myCart.items.entries.map((entry) {
                  final key = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.displayName, style: const TextStyle(fontSize: 14)),
                              Text('Rs. ${item.unitPrice.toStringAsFixed(0)} each',
                                  style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => cart.decrementByKey(myCart.restaurantId, key),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('${item.quantity}'),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
                          onPressed: () => cart.incrementByKey(myCart.restaurantId, key),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            'Rs. ${item.subtotal.toStringAsFixed(0)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Rs. ${myCart.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: isCheckingOut
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: () => _checkout(myCart),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Checkout'),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}