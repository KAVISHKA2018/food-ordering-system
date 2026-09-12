import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../config/app_theme.dart';
import '../../config/secrets.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';

class TrackDeliveryScreen extends StatefulWidget {
  final int orderId;
  const TrackDeliveryScreen({super.key, required this.orderId});

  @override
  State<TrackDeliveryScreen> createState() => _TrackDeliveryScreenState();
}

class _TrackDeliveryScreenState extends State<TrackDeliveryScreen> {
  final MapController _mapController = MapController();
  Timer? _pollTimer;

  OrderModel? _order;
  bool _loading = true;
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  int? _routeDurationMin;
  bool _fittedOnce = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final order = await OrderService.getOrderDetail(widget.orderId);
    if (!mounted || order == null) return;

    setState(() {
      _order = order;
      _loading = false;
    });

    if (order.riderCurrentLatitude != null && order.deliveryLatitude != null) {
      await _fetchRoute(
        rider: LatLng(order.riderCurrentLatitude!, order.riderCurrentLongitude!),
        customer: LatLng(order.deliveryLatitude!, order.deliveryLongitude!),
      );
    }

    // Delivery finished — stop polling, nothing more to track.
    if (order.status == 'COMPLETED' || order.status == 'CANCELLED') {
      _pollTimer?.cancel();
    }
  }

  Future<void> _fetchRoute({required LatLng rider, required LatLng customer}) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${rider.longitude},${rider.latitude};${customer.longitude},${customer.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) return;

      final route = data['routes'][0];
      final coords = route['geometry']['coordinates'] as List;
      final points = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();

      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _routeDistanceKm = (route['distance'] as num) / 1000;
        _routeDurationMin = ((route['duration'] as num) / 60).round();
      });

      if (!_fittedOnce) {
        _fittedOnce = true;
        final bounds = LatLngBounds.fromPoints([rider, customer]);
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
      }
    } catch (_) {
      // Best-effort — the map still shows both pins even without a route line.
    }
  }

  String _statusMessage(String status, bool tripStarted) {
    switch (status) {
      case 'PENDING':
        return 'Your order has been placed';
      case 'CONFIRMED':
        return 'Restaurant confirmed your order';
      case 'PREPARING':
        return 'Your food is being prepared';
      case 'READY':
        return 'Your order is ready and waiting for pickup';
      case 'OUT_FOR_DELIVERY':
        return tripStarted ? 'Your rider is on the way!' : 'A rider has been assigned';
      case 'COMPLETED':
        return 'Delivered — enjoy your meal!';
      case 'CANCELLED':
        return 'This order was cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final order = _order!;
    final hasCustomerLocation = order.deliveryLatitude != null && order.deliveryLongitude != null;
    final hasRiderLocation = order.riderCurrentLatitude != null && order.riderCurrentLongitude != null;
    final isDone = order.status == 'COMPLETED' || order.status == 'CANCELLED';

    return Scaffold(
      appBar: AppBar(title: Text('Order #${order.id}')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isDone ? Colors.green.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle : Icons.delivery_dining,
                  color: isDone ? Colors.green : AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusMessage(order.status, order.tripStarted),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDone ? Colors.green : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (hasCustomerLocation)
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(order.deliveryLatitude!, order.deliveryLongitude!),
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png?key=${Secrets.mapTilerApiKey}',
                        userAgentPackageName: 'com.kavishka.foodordering.mobile_app',
                      ),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(points: _routePoints, strokeWidth: 5, color: AppColors.primary),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(order.deliveryLatitude!, order.deliveryLongitude!),
                            width: 44,
                            height: 44,
                            child: const Icon(Icons.home, size: 36, color: AppColors.primary),
                          ),
                          if (hasRiderLocation)
                            Marker(
                              point: LatLng(order.riderCurrentLatitude!, order.riderCurrentLongitude!),
                              width: 36,
                              height: 36,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                                ),
                                child: const Icon(Icons.two_wheeler, color: Colors.white, size: 18),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (!hasRiderLocation && !isDone)
                    Positioned(
                      top: 10, left: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                        ),
                        child: const Text(
                          'Waiting for your rider to start the trip...',
                          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                        ),
                      ),
                    ),
                  if (hasRiderLocation && _routeDistanceKm != null)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.route, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text('${_routeDistanceKm!.toStringAsFixed(1)} km · ~$_routeDurationMin min away',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No delivery location was set for this order.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}