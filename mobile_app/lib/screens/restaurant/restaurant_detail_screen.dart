import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../models/menu_item_model.dart';
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

  void _openVariantPicker(MenuItemModel item, RestaurantModel restaurant, CartProvider cart) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<CartProvider>(
          builder: (context, cartValue, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Choose a size',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    const SizedBox(height: 16),
                    ...item.variants.map((variant) {
                      final qty = cartValue.quantityFor(item, variant);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(variant.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('Rs. ${variant.price.toStringAsFixed(0)}',
                                      style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                                ],
                              ),
                            ),
                            if (qty == 0)
                              OutlinedButton(
                                onPressed: () => cartValue.addItem(
                                  item,
                                  restaurant.id,
                                  restaurant.name,
                                  variant: variant,
                                ),
                                child: const Text('Add'),
                              )
                            else
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: AppColors.primary),
                                    onPressed: () => cartValue.decrement(item, variant),
                                  ),
                                  Text('$qty', style: const TextStyle(fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: AppColors.primary),
                                    onPressed: () => cartValue.increment(item, variant),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
          final coverUrl = ApiConfig.imageUrl(restaurant.coverImage);
          final logoUrl = ApiConfig.imageUrl(restaurant.logo);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: AppColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  background: coverUrl.isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(color: AppColors.primary),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.55),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(color: AppColors.primary),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: logoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: logoUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 64,
                                  height: 64,
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  child: const Icon(Icons.restaurant, color: AppColors.primary),
                                ),
                              )
                            : Container(
                                width: 64,
                                height: 64,
                                color: AppColors.primary.withValues(alpha: 0.15),
                                child: const Icon(Icons.restaurant, color: AppColors.primary),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                            final itemImageUrl = ApiConfig.imageUrl(item.image);

                            // For items without variants, keep the simple inline stepper.
                            final inCart = !item.hasVariants ? cart.items['${item.id}'] : null;

                            // For items with variants, sum quantities across all their variant lines.
                            final totalVariantQty = item.hasVariants
                                ? item.variants.fold<int>(
                                    0, (sum, v) => sum + cart.quantityFor(item, v))
                                : 0;

                            return ListTile(
                              onTap: item.hasVariants
                                  ? () => _openVariantPicker(item, restaurant, cart)
                                  : null,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: itemImageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: itemImageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          width: 50,
                                          height: 50,
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          width: 50,
                                          height: 50,
                                          color: AppColors.primary.withValues(alpha: 0.15),
                                          child: const Icon(Icons.fastfood,
                                              color: AppColors.primary, size: 20),
                                        ),
                                      )
                                    : Container(
                                        width: 50,
                                        height: 50,
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        child: const Icon(Icons.fastfood,
                                            color: AppColors.primary, size: 20),
                                      ),
                              ),
                              title: Text(item.name),
                              subtitle: Text(
                                item.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: SizedBox(
                                width: 120,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (item.hasVariants)
                                      Text(
                                        'From Rs. ${item.variants.map((v) => v.price).reduce((a, b) => a < b ? a : b).toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      )
                                    else
                                      Text('Rs. ${item.price.toStringAsFixed(0)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    if (!item.isAvailable)
                                      const Text('Unavailable',
                                          style: TextStyle(color: Colors.red, fontSize: 11))
                                    else if (item.hasVariants)
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          minimumSize: const Size(0, 32),
                                        ),
                                        onPressed: () => _openVariantPicker(item, restaurant, cart),
                                        child: Text(
                                          totalVariantQty > 0 ? 'In cart ($totalVariantQty)' : 'Select size',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      )
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
                                            onPressed: () => cart.decrement(item, null),
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
                                            onPressed: () => cart.increment(item, null),
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