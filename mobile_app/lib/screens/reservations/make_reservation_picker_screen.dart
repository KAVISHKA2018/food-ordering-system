import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/restaurant_model.dart';
import '../../services/restaurant_service.dart';
import 'reservation_screen.dart';

class MakeReservationPickerScreen extends StatefulWidget {
  const MakeReservationPickerScreen({super.key});

  @override
  State<MakeReservationPickerScreen> createState() => _MakeReservationPickerScreenState();
}

class _MakeReservationPickerScreenState extends State<MakeReservationPickerScreen> {
  late Future<List<RestaurantModel>> _restaurantsFuture;
  int? _loadingId;

  @override
  void initState() {
    super.initState();
    _restaurantsFuture = RestaurantService.getRestaurants();
  }

  Future<void> _selectRestaurant(RestaurantModel restaurant) async {
    setState(() => _loadingId = restaurant.id);
    try {
      final fullRestaurant = await RestaurantService.getRestaurantDetail(restaurant.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReservationScreen(restaurant: fullRestaurant)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open reservation form: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Make a Reservation')),
      body: FutureBuilder<List<RestaurantModel>>(
        future: _restaurantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load restaurants: ${snapshot.error}'));
          }

          final restaurants = (snapshot.data ?? [])
              .where((r) => r.supportsReservations)
              .toList();

          if (restaurants.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No restaurants currently accept table reservations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGrey),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: restaurants.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];
              final logoUrl = ApiConfig.imageUrl(restaurant.logo);
              final isLoading = _loadingId == restaurant.id;

              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: logoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: logoUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 50,
                              height: 50,
                              color: AppColors.primary.withValues(alpha: 0.15),
                              child: const Icon(Icons.restaurant, color: AppColors.primary),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            color: AppColors.primary.withValues(alpha: 0.15),
                            child: const Icon(Icons.restaurant, color: AppColors.primary),
                          ),
                  ),
                  title: Text(restaurant.name),
                  subtitle: Text(restaurant.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: isLoading ? null : () => _selectRestaurant(restaurant),
                ),
              );
            },
          );
        },
      ),
    );
  }
}