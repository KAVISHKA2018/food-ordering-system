import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../services/restaurant_service.dart';
import '../restaurant/restaurant_detail_screen.dart';
import '../activity/activity_hub_screen.dart';
import '../profile/profile_screen.dart';
import '../scan/qr_scanner_screen.dart';

import '../../models/promotion_model.dart';
import '../../services/promotion_service.dart';

import '../../models/menu_item_model.dart';
import '../../services/recommendation_service.dart';

import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../restaurant/food_detail_sheet.dart';
import '../../widgets/floating_cart_button.dart';
import '../activity/cart_tab.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<RestaurantModel>> _restaurantsFuture;
  late Future<List<PromotionModel>> _promotionsFuture;
  late Future<List<MenuItemModel>> _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _restaurantsFuture = RestaurantService.getRestaurants();
    _promotionsFuture = PromotionService.getActivePromotions();
    _recommendationsFuture = RecommendationService.getForMe();
  }

  Future<void> _refresh() async {
    setState(() {
      _restaurantsFuture = RestaurantService.getRestaurants();
      _promotionsFuture = PromotionService.getActivePromotions();
      _recommendationsFuture = RecommendationService.getForMe();
    });
  }

  Future<void> _openRecommendedItem(MenuItemModel item) async {
    try {
      final restaurant = await RestaurantService.getRestaurantDetail(item.restaurantId);
      if (!mounted) return;
      final cart = Provider.of<CartProvider>(context, listen: false);
      showFoodDetailSheet(context: context, item: item, restaurant: restaurant, cart: cart);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load this item: $e')),
      );
    }
  }

  void _openCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Your Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Expanded(child: CartTab()),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      SliverToBoxAdapter(child: _buildSearchBar()),
                      SliverToBoxAdapter(child: _buildScanBanner()),
                      SliverToBoxAdapter(child: _buildPromotionsBanner()),
                      SliverToBoxAdapter(child: _buildRecommendations()),
                      SliverToBoxAdapter(child: _buildSectionTitle('Restaurants')),
                      _buildRestaurantList(),
                    ],
                  ),
                ),
                FloatingCartButton(
                  areaSize: constraints.biggest,
                  onTap: _openCartSheet,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary),
          const SizedBox(width: 6),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deliver to',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                Text('Set your location',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long, color: AppColors.textDark),
            tooltip: 'My Activity',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActivityHubScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person, color: AppColors.textDark),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const TextField(
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Search restaurants or food',
            prefixIcon: Icon(Icons.search, color: AppColors.textGrey),
          ),
        ),
      ),
    );
  }

  Widget _buildScanBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QRScannerScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dining in?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Scan the table QR code to order',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

    Widget _buildPromotionsBanner() {
    return FutureBuilder<List<PromotionModel>>(
      future: _promotionsFuture,
      builder: (context, snapshot) {
        final promos = snapshot.data ?? [];
        if (promos.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: promos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final promo = promos[index];
                final imgUrl = ApiConfig.imageUrl(promo.image);
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailScreen(restaurantId: promo.restaurantId),
                      ),
                    );
                  },
                  child: Container(
                    width: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.primary,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imgUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(color: AppColors.primary),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  promo.discountLabel,
                                  style: const TextStyle(
                                      color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                promo.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              if (promo.restaurantName.isNotEmpty)
                                Text(
                                  promo.restaurantName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendations() {
    return FutureBuilder<List<MenuItemModel>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Recommended for You'),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final imgUrl = ApiConfig.imageUrl(item.image);
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestaurantDetailScreen(
                            restaurantId: item.restaurantId,
                            initialItemId: item.id,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 150,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1.4,
                            child: imgUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imgUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      child: const Icon(Icons.fastfood, color: AppColors.primary),
                                    ),
                                  )
                                : Container(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    child: const Icon(Icons.fastfood, color: AppColors.primary),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rs. ${item.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRestaurantList() {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<RestaurantModel>>(
        future: _restaurantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load restaurants: ${snapshot.error}'),
            );
          }
          final restaurants = snapshot.data ?? [];
          if (restaurants.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No restaurants available yet.'),
            );
          }
          return Column(
            children: restaurants.map((r) => _restaurantCard(r)).toList(),
          );
        },
      ),
    );
  }

  Widget _restaurantCard(RestaurantModel restaurant) {
    final logoUrl = ApiConfig.imageUrl(restaurant.logo);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RestaurantDetailScreen(restaurantId: restaurant.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: logoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 60,
                          height: 60,
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: AppColors.primary.withValues(alpha: 0.15),
                          child: const Icon(Icons.restaurant, color: AppColors.primary),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: AppColors.primary.withValues(alpha: 0.15),
                        child: const Icon(Icons.restaurant, color: AppColors.primary),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                    ),
                    if (restaurant.averageRating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            '${restaurant.averageRating!.toStringAsFixed(1)} (${restaurant.reviewCount})',
                            style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textGrey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin wrapper so home_screen.dart doesn't need to import the activity
/// tab's CartTab file directly — keeps this file's imports self-contained.
class _CartSheetContent extends StatelessWidget {
  const _CartSheetContent();

  @override
  Widget build(BuildContext context) {
    return const _InlineCartTab();
  }
}

class _InlineCartTab extends StatefulWidget {
  const _InlineCartTab();

  @override
  State<_InlineCartTab> createState() => _InlineCartTabState();
}

class _InlineCartTabState extends State<_InlineCartTab> {
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
              ],
            ),
          ),
        );
      },
    );
  }
}