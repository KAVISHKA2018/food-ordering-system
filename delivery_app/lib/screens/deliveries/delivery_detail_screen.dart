import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../config/app_theme.dart';
import '../../config/secrets.dart';
import '../../models/delivery_order_model.dart';
import '../../services/order_service.dart';
import 'dart:async';

class DeliveryDetailScreen extends StatefulWidget {
  final DeliveryOrderModel order;
  const DeliveryDetailScreen({super.key, required this.order});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  bool _marking = false;
  bool _startingTrip = false;
  late DeliveryOrderModel _order;
  late bool _tripStarted;
  final MapController _mapController = MapController();
  bool _mapReady = false;

  LatLng? _riderPosition;
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  int? _routeDurationMin;
  bool _loadingRoute = false;
  String? _routeError;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _tripStarted = _order.tripStarted;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _mapReady = true);
      if (_hasLocation) {
        await _loadRouteToCustomer();
      }
      if (_tripStarted) {
        _beginLocationBroadcast();
      }
    });
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  bool get _hasLocation => _order.deliveryLatitude != null && _order.deliveryLongitude != null;

  Future<void> _loadRouteToCustomer() async {
    setState(() {
      _loadingRoute = true;
      _routeError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Please turn on Location Services.');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Enable it in Settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final rider = LatLng(position.latitude, position.longitude);
      final customer = LatLng(_order.deliveryLatitude!, _order.deliveryLongitude!);

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${rider.longitude},${rider.latitude};${customer.longitude},${customer.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 12));

      List<LatLng> points = [];
      double? distanceKm;
      int? durationMin;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final coords = route['geometry']['coordinates'] as List;
          points = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
          distanceKm = (route['distance'] as num) / 1000;
          durationMin = ((route['duration'] as num) / 60).round();
        }
      }

      if (!mounted) return;
      setState(() {
        _riderPosition = rider;
        _routePoints = points;
        _routeDistanceKm = distanceKm;
        _routeDurationMin = durationMin;
        _loadingRoute = false;
      });

      final bounds = LatLngBounds.fromPoints([rider, customer]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRoute = false;
        _routeError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _callNumber(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  Future<void> _openExternalNavigation() async {
    if (!_hasLocation) return;
    final lat = _order.deliveryLatitude;
    final lng = _order.deliveryLongitude;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// "Start" — opens external turn-by-turn navigation AND tells the
  /// backend the trip has begun, which notifies the customer.
  Future<void> _startTrip() async {
    setState(() => _startingTrip = true);
    final result = await OrderService.startTrip(_order.id);
    setState(() => _startingTrip = false);

    if (!mounted) return;

    if (result['success']) {
      setState(() => _tripStarted = true);
      _openExternalNavigation();
      _beginLocationBroadcast();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'].toString())),
      );
    }
  }

  /// Sends the rider's current position to the backend every 15 seconds
  /// while the trip is active, so the customer app can show it moving on
  /// their tracking map. Stops automatically once the screen closes or
  /// the delivery is marked complete.
  void _beginLocationBroadcast() {
    _sendLocationPing(); // one immediately, don't wait for the first timer tick
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendLocationPing();
    });
  }

  Future<void> _sendLocationPing() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await OrderService.updateRiderLocation(_order.id, position.latitude, position.longitude);
      if (mounted) {
        setState(() => _riderPosition = LatLng(position.latitude, position.longitude));
      }
    } catch (_) {
      // Best-effort — a single failed GPS read shouldn't crash anything.
    }
  }

  /// "End" — shows a payment-aware completion sheet before actually
  /// marking the order delivered.
  Future<void> _showEndTripSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final isCash = _order.paymentMethod != 'CARD';
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCash ? 'Collect Payment' : 'Card Payment',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (isCash) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('Ask the customer for', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(
                        'Rs. ${_order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _completeDelivery();
                    },
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Cash Collected', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.credit_card, size: 32, color: Colors.blue),
                      SizedBox(height: 10),
                      Text(
                        'This is a Card Payment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Already paid online — no cash needed.',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _completeDelivery();
                    },
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Finish Trip', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Not yet — go back'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _completeDelivery() async {
    _locationUpdateTimer?.cancel();
    setState(() => _marking = true);
    final result = await OrderService.markDelivered(_order.id);
    setState(() => _marking = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery marked complete!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'].toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _order.status == 'OUT_FOR_DELIVERY';

    return Scaffold(
      appBar: AppBar(title: Text('Order #${_order.id}')),
      body: ListView(
        children: [
          if (_hasLocation)
            SizedBox(
              height: 260,
              child: _mapReady
                  ? Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: LatLng(_order.deliveryLatitude!, _order.deliveryLongitude!),
                            initialZoom: 16,
                            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png?key=${Secrets.mapTilerApiKey}',
                              userAgentPackageName: 'com.kavishka.foodordering.delivery_app',
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
                                  point: LatLng(_order.deliveryLatitude!, _order.deliveryLongitude!),
                                  width: 44,
                                  height: 44,
                                  child: const Icon(Icons.location_on, size: 40, color: AppColors.primary),
                                ),
                                if (_riderPosition != null)
                                  Marker(
                                    point: _riderPosition!,
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
                        if (_loadingRoute)
                          Positioned(
                            top: 10, left: 10, right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white, borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 10),
                                  Text('Finding route...', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        if (!_loadingRoute && _routeDistanceKm != null)
                          Positioned(
                            top: 10, left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white, borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.route, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text('${_routeDistanceKm!.toStringAsFixed(1)} km · $_routeDurationMin min',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        if (!_loadingRoute && _routeError != null)
                          Positioned(
                            top: 10, left: 10, right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white, borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: AppColors.textGrey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(_routeError!, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: AppColors.cardBackground,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
            )
          else
            Container(
              height: 100,
              color: AppColors.cardBackground,
              child: const Center(
                child: Text('No exact location pinned for this order', style: TextStyle(color: AppColors.textGrey)),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_order.restaurantName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Customer: ${_order.customerUsername}', style: const TextStyle(color: AppColors.textGrey)),
                const SizedBox(height: 16),

                const Text('DELIVERY ADDRESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGrey, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(_order.deliveryAddress, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _callNumber(_order.contactPhone),
                        icon: const Icon(Icons.call, size: 18),
                        label: Text(_order.contactPhone.isEmpty ? 'No phone' : _order.contactPhone),
                      ),
                    ),
                    if (_order.alternativePhone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _callNumber(_order.alternativePhone),
                        icon: const Icon(Icons.phone_forwarded_outlined),
                        tooltip: 'Alternative: ${_order.alternativePhone}',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // --- Start / End trip control ---
                if (isActive)
                  !_tripStarted
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _startingTrip ? null : _startTrip,
                            icon: _startingTrip
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.play_arrow),
                            label: Text(_startingTrip ? 'Starting...' : 'Start', style: const TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _marking ? null : _showEndTripSheet,
                                icon: _marking
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.flag),
                                label: Text(_marking ? 'Finishing...' : 'End', style: const TextStyle(fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openExternalNavigation,
                                icon: const Icon(Icons.navigation),
                                label: const Text('Navigate', style: TextStyle(fontSize: 16)),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                              ),
                            ),
                          ],
                        ),
                if (isActive && _tripStarted) ...[
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.green),
                      SizedBox(width: 6),
                      Text('Customer has been notified you\'re on the way',
                          style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ],
                  ),
                ],

                const Divider(height: 32),

                const Text('ORDER ITEMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGrey, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                ..._order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${item.quantity}x ${item.displayName}', style: const TextStyle(fontSize: 14)),
                    )),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Rs. ${_order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                if (_order.paymentMethod.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _order.paymentMethod == 'CARD' ? '💳 Already paid by card' : '💵 Collect cash on delivery',
                    style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}