import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../models/menu_item_model.dart';

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

  void _openVariantPicker(MenuItemModel item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                      final qty = _quantityFor(item, variant);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(variant.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('Rs. ${variant.price.toStringAsFixed(0)}',
                                      style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: qty > 0
                                  ? () => setState(() {
                                        setSheetState(() {
                                          _quantities[_keyFor(item, variant)] = qty - 1;
                                        });
                                      })
                                  : null,
                            ),
                            Text('$qty', style: const TextStyle(fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                              onPressed: () => setState(() {
                                setSheetState(() {
                                  _quantities[_keyFor(item, variant)] = qty + 1;
                                });
                              }),
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
                        final hasVariants = item.hasVariants;
                        final qty = hasVariants
                            ? _totalQuantityFor(item)
                            : _quantityFor(item, null);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                                width: 110,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      hasVariants
                                          ? 'From Rs. ${item.variants.map((v) => v.price).reduce((a, b) => a < b ? a : b).toStringAsFixed(0)}'
                                          : 'Rs. ${item.price.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    if (hasVariants)
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minimumSize: const Size(0, 32),
                                        ),
                                        onPressed: () => _openVariantPicker(item),
                                        child: Text(
                                          qty > 0 ? 'In cart ($qty)' : 'Select size',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      )
                                    else if (qty == 0)
                                      SizedBox(
                                        height: 32,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                          ),
                                          onPressed: () => setState(
                                              () => _quantities[_keyFor(item, null)] = 1),
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
                                            onPressed: () => setState(
                                                () => _quantities[_keyFor(item, null)] = qty - 1),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text('$qty'),
                                          ),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.add_circle,
                                                color: AppColors.primary, size: 22),
                                            onPressed: () => setState(
                                                () => _quantities[_keyFor(item, null)] = qty + 1),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
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