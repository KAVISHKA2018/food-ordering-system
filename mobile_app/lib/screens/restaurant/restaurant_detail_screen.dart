import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../services/restaurant_service.dart';
import '../../providers/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../reservations/reservation_screen.dart';

const double _kChipBarHeight = 58;

class RestaurantDetailScreen extends StatefulWidget {
  final int restaurantId;
  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  late Future<RestaurantModel> _restaurantFuture;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _chipBarKey = GlobalKey();
  final ScrollController _tabScrollController = ScrollController();

  List<GlobalKey> _categoryKeys = [];
  List<GlobalKey> _tabKeys = [];
  // ValueNotifier instead of a plain int + setState: changing categories
  // (which happens on every scroll frame that crosses a category boundary)
  // must NOT rebuild the entire screen (all product tiles/images). Only the
  // small tab-chip row listens to this via ValueListenableBuilder below,
  // which is what eliminates the freeze/stutter on category change.
  final ValueNotifier<int> _selectedCategoryIndex = ValueNotifier<int>(0);
  bool _isProgrammaticScroll = false;

  @override
  void initState() {
    super.initState();
    _restaurantFuture = RestaurantService.getRestaurantDetail(widget.restaurantId);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabScrollController.dispose();
    _selectedCategoryIndex.dispose();
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

  // --- Vertical scroll -> update active tab ---
  void _onScroll() {
    if (_isProgrammaticScroll || _categoryKeys.isEmpty) return;

    final thresholdY = _chipBarBottomY();
    if (thresholdY == null) return;

    int newIndex = _selectedCategoryIndex.value;
    for (int i = 0; i < _categoryKeys.length; i++) {
      final box = _categoryKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y <= thresholdY + 2) {
        newIndex = i;
      }
    }

    if (newIndex != _selectedCategoryIndex.value) {
      _selectedCategoryIndex.value = newIndex;
      _scrollTabIntoView(newIndex);
    }
  }

  // --- Tap a tab -> scroll menu to that category (single pre-computed
  // target offset, avoids Scrollable.ensureVisible fighting with the
  // pinned app bar + pinned category bar and causing a jump/snap-back) ---
  Future<void> _scrollToCategory(int index) async {
    _selectedCategoryIndex.value = index;
    _scrollTabIntoView(index);

    final headerBox = _categoryKeys[index].currentContext?.findRenderObject() as RenderBox?;
    final thresholdY = _chipBarBottomY();
    if (headerBox == null || !headerBox.attached || thresholdY == null) return;

    final currentY = headerBox.localToGlobal(Offset.zero).dy;
    final delta = currentY - thresholdY;

    if (delta.abs() < 2) return; // already in position

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

  // --- FIX ---
  // Previously this used `Scrollable.ensureVisible(ctx)`, which walks up
  // *every* ancestor Scrollable of the tapped tab's context - not just the
  // horizontal tab ListView, but also the outer vertical CustomScrollView
  // that the tab bar is pinned inside of (via SliverPersistentHeader).
  //
  // Because the tab chip's RenderBox is painted inside a pinned persistent
  // header, the outer viewport's "reveal" calculation gets confused about
  // where that box actually sits in the scroll extent, and computes a
  // target offset that snaps the *vertical* scroll position back to 0.
  // That's exactly the "jumps back to top when a new category becomes
  // active" bug.
  //
  // Fix: scroll ONLY the horizontal `_tabScrollController` directly, using
  // a manually computed offset (same pattern already used correctly in
  // `_scrollToCategory` for the vertical list). This never touches the
  // outer vertical scrollable, so it can't cause a jump-to-top.
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

    // Position of the tab's left edge relative to the chip bar's left edge.
    final tabLeftInBar = tabBox.localToGlobal(Offset.zero, ancestor: barBox).dx;
    final tabRightInBar = tabLeftInBar + tabWidth;

    final position = _tabScrollController.position;
    double target = position.pixels;

    if (tabLeftInBar < horizontalPadding) {
      // Tab is (partially) hidden off the left edge.
      target = position.pixels + (tabLeftInBar - horizontalPadding);
    } else if (tabRightInBar > barWidth - horizontalPadding) {
      // Tab is (partially) hidden off the right edge.
      target = position.pixels + (tabRightInBar - (barWidth - horizontalPadding));
    } else {
      // Already fully visible, nothing to do.
      return;
    }

    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);

    _tabScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _openVariantPicker(RestaurantModel restaurant, item, CartProvider cart) {
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
                    ...item.variants.map<Widget>((variant) {
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

  Widget _buildCategoryChips(RestaurantModel restaurant) {
    return Container(
      key: _chipBarKey,
      height: _kChipBarHeight,
      color: Colors.white,
      // Only this small chip row listens for category-index changes, so a
      // category change during scroll repaints ~a dozen small chip widgets
      // instead of rebuilding the whole product list underneath it.
      child: ValueListenableBuilder<int>(
        valueListenable: _selectedCategoryIndex,
        builder: (context, selectedIndex, _) {
          return ListView.separated(
            controller: _tabScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: restaurant.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = restaurant.categories[index];
              final isSelected = index == selectedIndex;
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
          );
        },
      ),
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
                            final inCart = !item.hasVariants ? cart.items['${item.id}'] : null;
                            final itemImageUrl = ApiConfig.imageUrl(item.image);

                            final totalVariantQty = item.hasVariants
                                ? item.variants.fold<int>(
                                    0, (sum, v) => sum + cart.quantityFor(item, v))
                                : 0;

                            return InkWell(
                              onTap: item.hasVariants
                                  ? () => _openVariantPicker(restaurant, item, cart)
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
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 130,

                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (item.hasVariants)
                                            Text(
                                              'From Rs. ${item.variants.map((v) => v.price).reduce((a, b) => a < b ? a : b).toStringAsFixed(0)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            )
                                          else
                                            Text('Rs. ${item.price.toStringAsFixed(0)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 4),
                                          if (!item.isAvailable)
                                            const Text('Unavailable',
                                                style: TextStyle(color: Colors.red, fontSize: 11))
                                          else if (item.hasVariants)
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                minimumSize: const Size(0, 32),
                                              ),
                                              onPressed: () => _openVariantPicker(restaurant, item, cart),
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
          floatingActionButton: cart.isEmpty
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
                    'View Cart (${cart.itemCount}) · Rs. ${cart.totalAmount.toStringAsFixed(0)}',
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