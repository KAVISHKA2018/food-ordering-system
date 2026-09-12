import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../../config/app_theme.dart';
import '../../services/location_service.dart';
import '../../config/secrets.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String address;
  LocationPickerResult({required this.latitude, required this.longitude, required this.address});
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({super.key, this.initialLatitude, this.initialLongitude});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _center = const LatLng(6.9271, 79.8612);
  bool _loadingInitialLocation = true;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _setInitialPosition();
  }

  Future<void> _setInitialPosition() async {
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      setState(() {
        _center = LatLng(widget.initialLatitude!, widget.initialLongitude!);
        _loadingInitialLocation = false;
      });
      return;
    }

    final result = await LocationService.getCurrentLocation();
    if (!mounted) return;
    if (result['success']) {
      final loc = result['result'] as LocationResult;
      setState(() {
        _center = LatLng(loc.latitude, loc.longitude);
        _loadingInitialLocation = false;
      });
      _mapController.move(_center, 16);
    } else {
      setState(() => _loadingInitialLocation = false);
    }
  }

  Future<void> _confirmLocation() async {
    setState(() => _confirming = true);

    String address = '';
    try {
      final placemarks = await placemarkFromCoordinates(_center.latitude, _center.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.street, p.subLocality, p.locality, p.administrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .toList();
        address = parts.join(', ');
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _confirming = false);

    Navigator.pop(
      context,
      LocationPickerResult(latitude: _center.latitude, longitude: _center.longitude, address: address),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Delivery Location')),
      body: _loadingInitialLocation
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 16,
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        setState(() => _center = position.center);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://api.maptiler.com/maps/bright-v2/{z}/{x}/{y}.png?key=${Secrets.mapTilerApiKey}',
                      userAgentPackageName: 'com.kavishka.foodordering.mobile_app',
                    ),
                  ],
                ),
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.location_on, size: 48, color: AppColors.primary),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: SafeArea(
                    top: false,
                    child: ElevatedButton(
                      onPressed: _confirming ? null : _confirmLocation,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _confirming
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Confirm This Location', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}