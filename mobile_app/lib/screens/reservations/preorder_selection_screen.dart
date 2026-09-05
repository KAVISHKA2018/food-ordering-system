import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../models/menu_item_model.dart';
import 'preorder_food_detail_sheet.dart';

class SelectedPreOrderItem {
  final MenuItemModel menuItem;
  final MenuItemVariantModel? variant;
  int quantity;

  SelectedPreOrderItem({required this.menuItem, this.variant, this.quantity = 1});

  double get unitPrice => variant?.price ?? menuItem.price;
  double get subtotal => unitPrice * quantity;
  String get displayName =>
      variant != null ? '${menuItem.name} (${variant!.name})' : menuItem.name;
}

class PreOrderSelectionScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  final List<SelectedPreOrderItem> initialSelection;

  const PreOrderSelectionScreen({
    super.key,
    required this.restaurant,
    this.initialSelection = const [],
  });

  @override
  State<PreOrderSelectionScreen> createState() => _PreOrderSelectionScreenState();
}

class _PreOrderSelectionScreenState extends State<PreOrderSelectionScreen> {
  // Key: "itemId" for no-variant items, "itemId_vVariantId" for sized items.
  late Map<String, int> _quantities;

  @override
  void initState() {
    super.initState();
    _quantities = {
      for (final item in widget.initialSelection) _keyFor(item.menuItem, item.variant): item.quantity,
    };
  }

  String _keyFor(MenuItemModel item, MenuItemVariantModel? variant) {
    return variant != null ? '${item.id}_v${variant.id}' : '${item.id}';
  }

  int _quantityFor(MenuItemModel item, MenuItemVariantModel? variant) {
    return _quantities[_keyFor(item, variant)] ?? 0;
  }

  int _totalQuantityFor(MenuItemModel item) {
    if (!item.hasVariants) return _quantityFor(item, null);
    return item.variants.fold(0, (sum, v) => sum + _quantityFor(item, v));
  }

  double get _total {
    double sum = 0;
    for (final category in widget.restaurant.categories) {
      for (final item in category.menuItems) {
        if (item.hasVariants) {
          for (final v in item.variants) {
            sum += v.price * _quantityFor(item, v);
          }
        } else {
          sum += item.price * _quantityFor(item, null);
        }
      }
    }
    return sum;
  }

  int get _itemCount => _quantities.values.fold(0, (sum, q) => sum + q);

  void _openItemSheet(MenuItemModel item) {
    showPreOrderItemSheet(
      context: context,
      item: item,
      onAdd: (item, variant, quantity) {
        setState(() {
          final key = _keyFor(item, variant);
          _quantities[key] = (_quantities[key] ?? 0) + quantity;
        });
      },
    );
  }

  void _done() {
    final result = <SelectedPreOrderItem>[];
    for (final category in widget.restaurant.categories) {
      for (final item in category.menuItems) {
        if (item.hasVariants) {
          for (final v in item.variants) {
            final qty = _quantityFor(item, v);
            if (qty > 0) {
              result.add(SelectedPreOrderItem(menuItem: item, variant: v, quantity: qty));
            }
          }
        } else {
          final qty = _quantityFor(item, null);
          if (qty > 0) {
            result.add(SelectedPreOrderItem(menuItem: item, quantity: qty));
          }
        }
      }
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final coverUrl = ApiConfig.imageUrl(restaurant.coverImage);
    final logoUrl = ApiConfig.imageUrl(restaurant.logo);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: AppColors.primary,
            title: const Text('Add Foods / Pre-Order'),
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: logoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: logoUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 52,
                              height: 52,
                              color: AppColors.primary.withValues(alpha: 0.15),
                              child: const Icon(Icons.restaurant, color: AppColors.primary),
                            ),
                          )
                        : Container(
                            width: 52,
                            height: 52,
                            color: AppColors.primary.withValues(alpha: 0.15),
                            child: const Icon(Icons.restaurant, color: AppColors.primary),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(restaurant.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          if (restaurant.categories.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No menu items available.'),
              ),
            )
          else
            ...restaurant.categories.map((category) {
              final availableItems =
                  category.menuItems.where((item) => item.isAvailable).toList();
              if (availableItems.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

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
                        final item = availableItems[index];
                        final itemImageUrl = ApiConfig.imageUrl(item.image);
                        final cartQty = _totalQuantityFor(item);

                        return InkWell(
                          onTap: () => _openItemSheet(item),
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
                      childCount: availableItems.length,
                    ),
                  ),
                ],
              );
            }),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _done,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(
              _itemCount > 0
                  ? 'Done · $_itemCount item${_itemCount > 1 ? 's' : ''} · Rs. ${_total.toStringAsFixed(0)}'
                  : 'Done (no items selected)',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}