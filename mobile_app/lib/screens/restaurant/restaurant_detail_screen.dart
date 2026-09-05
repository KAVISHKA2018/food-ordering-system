import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../models/menu_item_model.dart';
import '../../services/restaurant_service.dart';
import '../../services/recommendation_service.dart';
import '../../providers/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../reservations/reservation_screen.dart';
import 'food_detail_sheet.dart';

const double _kChipBarHeight = 58;

class RestaurantDetailScreen extends StatefulWidget {
  final int restaurantId;
  final int? initialItemId;
  const RestaurantDetailScreen({super.key, required this.restaurantId, this.initialItemId});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  late Future<RestaurantModel> _restaurantFuture;
  late Future<List<MenuItemModel>> _recommendedFuture;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _chipBarKey = GlobalKey();
  final ScrollController _tabScrollController = ScrollController();

  List<GlobalKey> _categoryKeys = [];
  List<GlobalKey> _tabKeys = [];
  int _selectedCategoryIndex = 0;
  bool _isProgrammaticScroll = false;

  @override
  void initState() {
    super.initState();
    _restaurantFuture = RestaurantService.getRestaurantDetail(widget.restaurantId);
    _recommendedFuture = RecommendationService.getForRestaurant(widget.restaurantId);
    _scrollController.addListener(_onScroll);

    if (widget.initialItemId != null) {
      _restaurantFuture.then((restaurant) {
        if (!mounted) return;

        MenuItemModel? found;
        for (final category in restaurant.categories) {
          for (final item in category.menuItems) {
            if (item.id == widget.initialItemId) {
              found = item;
              break;
            }
          }
          if (found != null) break;
        }

        if (found != null) {
          final cart = Provider.of<CartProvider>(context, listen: false);
          final foundItem = found;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showFoodDetailSheet(context: context, item: foundItem!, restaurant: restaurant, cart: cart);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  void _ensureKeys(int categoryCount) {
    if (_categoryKeys.length != categoryCount) {
      _categoryKeys = List.generate(categoryCount, (_) => GlobalKey());
      _tabKeys = List.generate(categoryCount, (_) => GlobalKey());
    }
  }

  double? _chipBarBottomY() {
    final chipBox = _chipBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (chipBox == null || !chipBox.attached) return null;
    return chipBox.localToGlobal(Offset.zero).dy + chipBox.size.height;
  }

  void _onScroll() {
    if (_isProgrammaticScroll || _categoryKeys.isEmpty) return;

    final thresholdY = _chipBarBottomY();
    if (thresholdY == null) return;

    int newIndex = _selectedCategoryIndex;
    for (int i = 0; i < _categoryKeys.length; i++) {
      final box = _categoryKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y <= thresholdY + 2) {
        newIndex = i;
      }
    }

    if (newIndex != _selectedCategoryIndex) {
      setState(() => _selectedCategoryIndex = newIndex);
      _scrollTabIntoView(newIndex);
    }
  }

  Future<void> _scrollToCategory(int index) async {
    setState(() => _selectedCategoryIndex = index);
    _scrollTabIntoView(index);

    final headerBox = _categoryKeys[index].currentContext?.findRenderObject() as RenderBox?;
    final thresholdY = _chipBarBottomY();
    if (headerBox == null || !headerBox.attached || thresholdY == null) return;

    final currentY = headerBox.localToGlobal(Offset.zero).dy;
    final delta = currentY - thresholdY;

    if (delta.abs() < 2) return;

    final position = _scrollController.position;
    final targetOffset = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    _isProgrammaticScroll = true;
    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    await Future.delayed(const Duration(milliseconds: 50));
    _isProgrammaticScroll = false;
  }

  void _scrollTabIntoView(int index) {
    if (!_tabScrollController.hasClients) return;

    final tabBox = _tabKeys[index].currentContext?.findRenderObject() as RenderBox?;
    final barBox = _chipBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (tabBox == null || !tabBox.attached || barBox == null || !barBox.attached) {
      return;
    }

    const horizontalPadding = 16.0;
    final barWidth = barBox.size.width;
    final tabWidth = tabBox.size.width;

    final tabLeftInBar = tabBox.localToGlobal(Offset.zero, ancestor: barBox).dx;
    final tabRightInBar = tabLeftInBar + tabWidth;

    final position = _tabScrollController.position;
    double target = position.pixels;

    if (tabLeftInBar < horizontalPadding) {
      target = position.pixels + (tabLeftInBar - horizontalPadding);
    } else if (tabRightInBar > barWidth - horizontalPadding) {
      target = position.pixels + (tabRightInBar - (barWidth - horizontalPadding));
    } else {
      return;
    }

    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);

    _tabScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildCategoryChips(RestaurantModel restaurant) {
    return Container(
      key: _chipBarKey,
      height: _kChipBarHeight,
      color: Colors.white,
      child: ListView.separated(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: restaurant.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = restaurant.categories[index];
          final isSelected = index == _selectedCategoryIndex;
          return GestureDetector(
            key: _tabKeys[index],
            onTap: () => _scrollToCategory(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? Colors.black : const Color(0xFFDDDDDD),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                category.name.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF2B2B2B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendedSection(RestaurantModel restaurant, CartProvider cart) {
    return FutureBuilder<List<MenuItemModel>>(
      future: _recommendedFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('You Might Also Like',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final imgUrl = ApiConfig.imageUrl(item.image);

                    return GestureDetector(
                      onTap: () => showFoodDetailSheet(
                        context: context, item: item, restaurant: restaurant, cart: cart,
                      ),
                      child: Container(
                        width: 130,
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 1.3,
                              child: imgUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imgUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        child: const Icon(Icons.fastfood, size: 18, color: AppColors.primary),
                                      ),
                                    )
                                  : Container(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      child: const Icon(Icons.fastfood, size: 18, color: AppColors.primary),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text('Rs. ${item.price.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return FutureBuilder<RestaurantModel>(
      future: _restaurantFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        final restaurant = snapshot.data!;
        _ensureKeys(restaurant.categories.length);

        final coverUrl = ApiConfig.imageUrl(restaurant.coverImage);
        final logoUrl = ApiConfig.imageUrl(restaurant.logo);
        final myCart = cart.cartFor(restaurant.id);

        return Scaffold(
          body: CustomScrollView(
            controller: _scrollController,
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
                  if (restaurant.supportsReservations)
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restaurant.name,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            if (restaurant.averageRating != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${restaurant.averageRating!.toStringAsFixed(1)} (${restaurant.reviewCount} reviews)',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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

              SliverToBoxAdapter(child: _buildRecommendedSection(restaurant, cart)),

              if (restaurant.categories.isNotEmpty)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryTabBarDelegate(
                    height: _kChipBarHeight,
                    child: _buildCategoryChips(restaurant),
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
                ...restaurant.categories.asMap().entries.map((entry) {
                  final catIndex = entry.key;
                  final category = entry.value;

                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Container(
                          key: _categoryKeys[catIndex],
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
                            final cartQty = item.hasVariants
                                ? item.variants.fold<int>(
                                    0, (sum, v) => sum + cart.quantityFor(restaurant.id, item, v))
                                : cart.quantityFor(restaurant.id, item, null);

                            return InkWell(
                              onTap: item.isAvailable
                                  ? () => showFoodDetailSheet(
                                        context: context, item: item, restaurant: restaurant, cart: cart,
                                      )
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: itemImageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: itemImageUrl,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(
                                                width: 56,
                                                height: 56,
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                              ),
                                              errorWidget: (_, __, ___) => Container(
                                                width: 56,
                                                height: 56,
                                                color: AppColors.primary.withValues(alpha: 0.15),
                                                child: const Icon(Icons.fastfood,
                                                    color: AppColors.primary, size: 22),
                                              ),
                                            )
                                          : Container(
                                              width: 56,
                                              height: 56,
                                              color: AppColors.primary.withValues(alpha: 0.15),
                                              child: const Icon(Icons.fastfood,
                                                  color: AppColors.primary, size: 22),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(item.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                          if (item.description.isNotEmpty)
                                            Text(
                                              item.description,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                                            ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.hasVariants
                                                ? 'From Rs. ${item.variants.map((v) => v.price).reduce((a, b) => a < b ? a : b).toStringAsFixed(0)}'
                                                : 'Rs. ${item.price.toStringAsFixed(0)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!item.isAvailable)
                                      const Text('Unavailable',
                                          style: TextStyle(color: Colors.red, fontSize: 11))
                                    else
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.add, color: Colors.white, size: 20),
                                          ),
                                          if (cartQty > 0)
                                            Positioned(
                                              right: -4,
                                              top: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black,
                                                  shape: BoxShape.circle,
                                                ),
                                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                                child: Text(
                                                  '$cartQty',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
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
          ),
          floatingActionButton: (myCart == null || myCart.isEmpty)
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartScreen(restaurant: restaurant),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                  label: Text(
                    'Checkout (${myCart.itemCount}) · Rs. ${myCart.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
        );
      },
    );
  }
}

class _CategoryTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _CategoryTabBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _CategoryTabBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}