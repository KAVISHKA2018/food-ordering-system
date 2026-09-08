import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../models/menu_item_model.dart';
import '../../services/restaurant_service.dart';
import '../restaurant/restaurant_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<RestaurantModel> _restaurantResults = [];
  List<MenuItemModel> _foodResults = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _restaurantResults = [];
        _foodResults = [];
        _searched = false;
        _loading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        RestaurantService.searchRestaurants(query),
        RestaurantService.searchMenuItems(query),
      ]);
      if (!mounted) return;
      setState(() {
        _restaurantResults = results[0] as List<RestaurantModel>;
        _foodResults = results[1] as List<MenuItemModel>;
        _searched = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searched = true;
      });
    }
  }

  Widget _restaurantTile(RestaurantModel restaurant) {
    final logoUrl = ApiConfig.imageUrl(restaurant.logo);
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: logoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: logoUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.restaurant, color: AppColors.primary),
                ),
              )
            : Container(
                width: 48,
                height: 48,
                color: AppColors.primary.withValues(alpha: 0.15),
                child: const Icon(Icons.restaurant, color: AppColors.primary),
              ),
      ),
      title: Text(restaurant.name),
      subtitle: Text(restaurant.address, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurantId: restaurant.id)),
        );
      },
    );
  }

  Widget _foodTile(MenuItemModel item) {
    final imgUrl = ApiConfig.imageUrl(item.image);
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imgUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imgUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.fastfood, color: AppColors.primary, size: 20),
                ),
              )
            : Container(
                width: 48,
                height: 48,
                color: AppColors.primary.withValues(alpha: 0.15),
                child: const Icon(Icons.fastfood, color: AppColors.primary, size: 20),
              ),
      ),
      title: Text(item.name),
      subtitle: Text(
        item.hasVariants
            ? 'From Rs. ${item.variants.map((v) => v.price).reduce((a, b) => a < b ? a : b).toStringAsFixed(0)}'
            : 'Rs. ${item.price.toStringAsFixed(0)}',
      ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final noResults = _searched &&
        !_loading &&
        _restaurantResults.isEmpty &&
        _foodResults.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Search restaurants or food',
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : noResults
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No results found.',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                  ),
                )
              : ListView(
                  children: [
                    if (_restaurantResults.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text('Restaurants',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      ..._restaurantResults.map(_restaurantTile),
                    ],
                    if (_foodResults.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text('Food Items',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      ..._foodResults.map(_foodTile),
                    ],
                  ],
                ),
    );
  }
}