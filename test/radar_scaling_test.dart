import 'package:flutter_test/flutter_test.dart';
import 'package:jeevalink/utils/gps_calculator.dart';

void main() {
  group('Dynamic Radar Auto-Scaling & Target Tracking Math Tests', () {
    test('Calculates distance scaling factor for near and multi-hop far nodes correctly', () {
      final nearNodeDist = 50.0; // 50 meters
      final farNodeDist = 500.0; // 500 meters (5 hops away)
      final maxScaleRange = 500.0;

      final nearFactor = (nearNodeDist / maxScaleRange).clamp(0.15, 0.95);
      final farFactor = (farNodeDist / maxScaleRange).clamp(0.15, 0.95);

      expect(nearFactor, equals(0.15)); // Close to center
      expect(farFactor, equals(0.95));  // Outer edge ring
    });

    test('Bearing calculation correctly computes compass direction angle', () {
      // Direct north (lat increases)
      final bearingNorth = GpsCalculator.calculateBearingRadians(13.0, 80.0, 14.0, 80.0);
      expect(bearingNorth, closeTo(0.0, 0.05));
    });
  });
}
