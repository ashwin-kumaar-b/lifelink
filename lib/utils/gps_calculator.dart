import 'dart:math';

class GpsCalculator {
  /// Calculates Haversine distance in meters between two GPS coordinates.
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371000; // Earth radius in meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Formats distance into a human-readable string (e.g. "120m" or "2.4 km").
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    } else {
      final double km = meters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Calculates initial bearing in radians from (lat1, lon1) to (lat2, lon2).
  static double calculateBearingRadians(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final double phi1 = _toRadians(lat1);
    final double phi2 = _toRadians(lat2);
    final double deltaLambda = _toRadians(lon2 - lon1);

    final double y = sin(deltaLambda) * cos(phi2);
    final double x =
        cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);

    final double theta = atan2(y, x);
    return (theta + 2 * pi) % (2 * pi); // Normalize to 0 .. 2*pi
  }

  static double _toRadians(double degree) {
    return degree * pi / 180.0;
  }
}
