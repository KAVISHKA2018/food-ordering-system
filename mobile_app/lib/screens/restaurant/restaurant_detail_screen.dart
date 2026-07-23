import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../services/restaurant_service.dart';
import '../../providers/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../reservations/reservation_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final int restaurantId;
  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  late Future<RestaurantModel> _restaurantFuture;

  @override
  void initState() {
    super.initState();
    _restaurantFuture = RestaurantService.getRestaurantDetail(widget.restaurantId);
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      body: FutureBuilder<RestaurantModel>(
        future: _restaurantFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final restaurant = snapshot.data!;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 160,
                backgroundColor: AppColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(restaurant.name),
                  background: Container(color: AppColors.primary),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.event_seat, color: Colors.white),
                    tooltip: 'Reserve a Table',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReservationScreen(restaurant: restaurant),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restaurant.description,
                          style: const TextStyle(color: AppColors.textGrey)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: AppColors.textGrey),
                          const SizedBox(width: 4),
                          Expanded(child: Text(restaurant.address)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (restaurant.categories.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No menu items available yet.'),
                  ),
                )
              else
                ...restaurant.categories.map((category) {
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            category.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = category.menuItems[index];
                            final inCart = cart.items[item.id];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                child: const Icon(Icons.fastfood, color: AppColors.primary),
                              ),
                              title: Text(item.name),
                              subtitle: Text(
                                item.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: SizedBox(
                                width: 110,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Rs. ${item.price.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    if (!item.isAvailable)
                                      const Text('Unavailable',
                                          style: TextStyle(color: Colors.red, fontSize: 11))
                                    else if (inCart == null)
                                      SizedBox(
                                        height: 32,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                          ),
                                          onPressed: () => cart.addItem(
                                            item,
                                            restaurant.id,
                                            restaurant.name,
                                          ),
                                          child: const Text('Add', style: TextStyle(fontSize: 13)),
                                        ),
                                      )
                                    else
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.remove_circle,
                                                color: AppColors.primary, size: 22),
                                            onPressed: () => cart.decrement(item.id),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text('${inCart.quantity}'),
                                          ),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.add_circle,
                                                color: AppColors.primary, size: 22),
                                            onPressed: () => cart.addItem(
                                              item,
                                              restaurant.id,
                                              restaurant.name,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: category.menuItems.length,
                        ),
                      ),
                    ],
                  );
                }),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
      floatingActionButton: cart.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text(
                'View Cart (${cart.itemCount}) · Rs. ${cart.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
    );
  }
}