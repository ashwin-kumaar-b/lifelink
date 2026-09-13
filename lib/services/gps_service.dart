import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GpsService {
  static final GpsService _instance = GpsService._internal();
  factory GpsService() => _instance;
  GpsService._internal();

  Position? _lastKnownPosition;

  Position? get lastKnownPosition => _lastKnownPosition;

  /// Default fallback coordinates (Chennai, India) if GPS hardware is initializing
  double get currentLatitude => _lastKnownPosition?.latitude ?? 13.0827;
  double get currentLongitude => _lastKnownPosition?.longitude ?? 80.2707;

  /// Initializes GPS hardware, requests permission, and fetches initial position.
  Future<Position?> initialize() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) {
        print('GpsService: Location services are disabled on device.');
      }
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print('GpsService: Location permissions are denied.');
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        print('GpsService: Location permissions are permanently denied.');
      }
      return null;
    }

    try {
      // Fetch immediate last known position first for quick response
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        _lastKnownPosition = lastPos;
      }

      // Fetch high accuracy fresh hardware GPS position
      final currentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      _lastKnownPosition = currentPos;
      return currentPos;
    } catch (e) {
      if (kDebugMode) {
        print('GpsService: Error fetching current GPS position: $e');
      }
      return _lastKnownPosition;
    }
  }

  /// Fetches an immediate high-precision fresh hardware GPS fix right before sending a message.
  Future<Position?> getFreshBestPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 3),
      );
      _lastKnownPosition = pos;
      return pos;
    } catch (e) {
      if (kDebugMode) {
        print('GpsService: Failed fresh position fetch, using cached: $e');
      }
      return _lastKnownPosition;
    }
  }

  /// Listen to live hardware GPS position updates as the user moves
  Stream<Position> getPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 1, // Trigger update every 1 meter movement
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings).map((pos) {
      _lastKnownPosition = pos;
      return pos;
    });
  }
}
