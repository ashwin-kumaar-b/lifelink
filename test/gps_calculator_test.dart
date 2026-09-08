import 'package:flutter_test/flutter_test.dart';
import 'package:jeevalink/utils/gps_calculator.dart';

void main() {
  group('GpsCalculator Tests', () {
    test('Calculates distance between two known GPS points accurately', () {
      // Chennai Central (13.0827, 80.2707) to Marina Beach (13.0500, 80.2824) ~ 3.8 km
      final distMeters = GpsCalculator.calculateDistanceMeters(
        13.0827,
        80.2707,
        13.0500,
        80.2824,
      );

      expect(distMeters, greaterThan(3500));
      expect(distMeters, lessThan(4200));

      final formatted = GpsCalculator.formatDistance(distMeters);
      expect(formatted.contains('km'), isTrue);
    });

    test('Formats short distances in meters correctly', () {
      expect(GpsCalculator.formatDistance(140.5), equals('141m'));
      expect(GpsCalculator.formatDistance(2450.0), equals('2.5 km'));
    });
  });
}
