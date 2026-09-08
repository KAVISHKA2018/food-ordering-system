import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocationResult {
  final String label;
  final double latitude;
  final double longitude;
  LocationResult({required this.label, required this.latitude, required this.longitude});
}

class LocationService {
  static const _storage = FlutterSecureStorage();
  static const _kLocationKey = 'saved_location_label';

  /// Requests permission (if needed), fetches the device's current GPS
  /// position, and reverse-geocodes it into a short, human-readable
  /// address like "Dehiwala, Western Province".
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return {'success': false, 'error': 'Please turn on Location Services and try again.'};
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return {'success': false, 'error': 'Location permission was denied.'};
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return {
        'success': false,
        'error': 'Location permission is permanently denied. Please enable it from Settings.',
      };
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      String label = 'Current Location';
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [p.subLocality, p.locality, p.administrativeArea]
              .where((s) => s != null && s.isNotEmpty)
              .toList();
          if (parts.isNotEmpty) label = parts.join(', ');
        }
      } catch (_) {
        // Reverse geocoding can fail (no network, no results) — fall back
        // to raw coordinates rather than blocking the whole feature.
        label = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      await _storage.write(key: _kLocationKey, value: label);

      return {
        'success': true,
        'result': LocationResult(label: label, latitude: position.latitude, longitude: position.longitude),
      };
    } catch (e) {
      return {'success': false, 'error': 'Could not get your location: $e'};
    }
  }

  static Future<String?> getSavedLocationLabel() async {
    return _storage.read(key: _kLocationKey);
  }
}