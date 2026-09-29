// ─── Location Helper ──────────────────────────────────────────────────────────
// Utility for fetching the user's current location and converting it
// into a human-readable address (city + street).
//
// On Web/Desktop where geocoding may not be fully supported, falls back
// to returning just GPS coordinates as the address.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationResult {
  final String city;          // locality, e.g. "Haifa"
  final String streetNumber;  // street + number, e.g. "Allenby 12"
  final String fullAddress;   // combined for display

  const LocationResult({
    required this.city,
    required this.streetNumber,
    required this.fullAddress,
  });
}

class LocationHelper {
  /// Request location permission, get current GPS position, and reverse-geocode it.
  /// Returns a [LocationResult] or throws a descriptive error message.
  static Future<LocationResult> getCurrentAddress() async {
    // 1) Make sure location services are enabled on the device
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      throw 'Location services are not available on this device.';
    }
    if (!serviceEnabled) {
      throw 'Location services are disabled. Please enable GPS in your device settings.';
    }

    // 2) Check / request permission
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission denied.';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permission permanently denied. Please enable it from app settings.';
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Could not request location permission. Please try again.';
    }

    // 3) Get current position
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
    } catch (e) {
      throw 'Could not get your location. Make sure GPS is on and try again.';
    }

    // 4) Reverse geocode — may fail on Web or unsupported platforms
    String city = '';
    String streetNumber = '';
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // Handle every field as nullable — some platforms return mostly nulls
        final locality   = p.locality ?? '';
        final subAdmin   = p.subAdministrativeArea ?? '';
        final admin      = p.administrativeArea ?? '';
        final street     = p.thoroughfare ?? p.street ?? '';
        final subThor    = p.subThoroughfare ?? '';

        city = locality.isNotEmpty
            ? locality
            : (subAdmin.isNotEmpty ? subAdmin : admin);

        streetNumber = [street, subThor]
            .where((s) => s.trim().isNotEmpty)
            .join(' ')
            .trim();
      }
    } catch (_) {
      // Geocoding failed (common on Web/some desktop builds) — keep going with coords
    }

    // 5) Build a human-readable address; fall back to coordinates if needed
    final parts = <String>[
      if (streetNumber.isNotEmpty) streetNumber,
      if (city.isNotEmpty) city,
    ];
    final fullAddress = parts.isEmpty
        ? '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'
        : parts.join(', ');

    // If geocoding gave nothing, use coordinates as the "city" placeholder
    if (city.isEmpty && streetNumber.isEmpty) {
      city = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    }

    return LocationResult(
      city: city,
      streetNumber: streetNumber,
      fullAddress: fullAddress,
    );
  }

  /// True if running on a platform where GPS may not work reliably.
  static bool get isLimitedPlatform => kIsWeb;
}