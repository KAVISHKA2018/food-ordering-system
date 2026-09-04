import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/menu_item_model.dart';
import '../../models/restaurant_model.dart';
import '../../providers/cart_provider.dart';

Future<void> showFoodDetailSheet({
  required BuildContext context,
  required MenuItemModel item,
  required RestaurantModel restaurant,
  required CartProvider cart,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.88,
        child: _FoodDetailSheetContent(item: item, restaurant: restaurant, cart: cart),
      );
    },
  );
}

class _FoodDetailSheetContent extends StatefulWidget {
  final MenuItemModel item;
  final RestaurantModel restaurant;
  final CartProvider cart;

  const _FoodDetailSheetContent({
    required this.item,
    required this.restaurant,
    required this.cart,
  });

  @override
  State<_FoodDetailSheetContent> createState() => _FoodDetailSheetContentState();
}

class _FoodDetailSheetContentState extends State<_FoodDetailSheetContent> {
  MenuItemVariantModel? _selectedVariant;
  int _quantity = 1;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item.hasVariants) {
      _selectedVariant = widget.item.variants.first;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  double get _unitPrice => _selectedVariant?.price ?? widget.item.price;
  double get _total => _unitPrice * _quantity;

  void _addToCart() {
    widget.cart.addItem(
      widget.item,
      widget.restaurant.id,
      widget.restaurant.name,
      variant: _selectedVariant,
      quantity: _quantity,
      note: _noteController.text,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${widget.item.name} to cart')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final imgUrl = ApiConfig.imageUrl(item.image);

    return Container(
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: imgUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imgUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    child: const Icon(Icons.fastfood, size: 40, color: AppColors.primary),
                                  ),
                                )
                              : Container(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.fastfood, size: 40, color: AppColors.primary),
                                ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Rs. ${_unitPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            if (item.averageRating != null) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                              const SizedBox(width: 3),
                              Text(
                                '${item.averageRating!.toStringAsFixed(1)} (${item.reviewCount})',
                                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                              ),
                            ],
                          ],
                        ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(item.description,
                              style: const TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.4)),
                        ],
                        if (item.hasVariants) ...[
                          const SizedBox(height: 22),
                          const Text('Portions',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          const Text('Select one',
                              style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                          const SizedBox(height: 10),
                          ...item.variants.map((variant) {
                            final selected = _selectedVariant?.id == variant.id;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedVariant = variant),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary.withValues(alpha: 0.08)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
                                    width: selected ? 1.6 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                      color: selected ? AppColors.primary : AppColors.textGrey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(variant.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    ),
                                    Text('Rs. ${variant.price.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 22),
                        const Text('Preparation Note',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'e.g. less spicy, no onions',
                            filled: true,
                            fillColor: AppColors.cardBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                      ),
                      Text('$_quantity', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                        onPressed: () => setState(() => _quantity++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addToCart,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Add to Cart · Rs. ${_total.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}