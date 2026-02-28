import 'package:flutter_test/flutter_test.dart';

import 'package:safora/core/utils/risk_calculator.dart';
import 'package:safora/models/risk_factors.dart';

void main() {
  test('Risk calculator classifies danger for stacked high-risk factors', () {
    final calculator = RiskCalculator();
    final result = calculator.calculateRiskScore(
      const RiskFactors(
        isNight: true,
        areaType: AreaType.isolatedRoad,
        isAlone: true,
        batteryLevel: 10,
        networkAvailable: false,
        currentSpeed: 72,
        distanceFromSafeZone: 8,
      ),
    );

    expect(result.level.name, 'danger');
    expect(result.score, greaterThanOrEqualTo(12));
    expect(result.checklist, isNotEmpty);
  });
}
