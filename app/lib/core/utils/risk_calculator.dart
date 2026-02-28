import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../../models/risk_assessment.dart';
import '../../models/risk_factors.dart';

class RiskCalculator {
  static const int nightWeight = 3;
  static const int isolatedRoadWeight = 3;
  static const int aloneWeight = 2;
  static const int lowBatteryWeight = 1;
  static const int noNetworkWeight = 2;
  static const int highSpeedWeight = 2;
  static const int farFromSafeZoneWeight = 2;

  RiskAssessment calculateRiskScore(RiskFactors factors) {
    var score = 0;
    final checklist = <String>[];

    if (factors.isNight) {
      score += nightWeight;
      checklist.add('Prefer well-lit routes and share live status.');
    }
    if (factors.areaType == AreaType.isolatedRoad) {
      score += isolatedRoadWeight;
      checklist.add('Avoid isolated stretches when possible.');
    }
    if (factors.isAlone) {
      score += aloneWeight;
      checklist.add('Keep a trusted contact informed.');
    }
    if (factors.batteryLevel < 20) {
      score += lowBatteryWeight;
      checklist.add('Battery low: enable power save and reduce screen usage.');
    }
    if (!factors.networkAvailable) {
      score += noNetworkWeight;
      checklist.add('Network unavailable: keep SMS fallback ready.');
    }
    if (factors.currentSpeed > 60) {
      score += highSpeedWeight;
      checklist.add('High movement speed detected: verify travel details.');
    }
    if (factors.distanceFromSafeZone > 5) {
      score += farFromSafeZoneWeight;
      checklist.add('Far from safe zone: stay in populated areas.');
      if (factors.isNight) {
        // Additional nighttime penalty for being far from known safe zone.
        score += 1;
      }
    }

    if (checklist.isEmpty) {
      checklist.add('Continue routine awareness and keep emergency tools ready.');
    }

    final level = _mapLevel(score);
    final vulnerabilityPercentage = min(score * 8.5, 100).toDouble();
    final confidenceScore =
        (factors.activeFactors / factors.totalFactors) * 100;

    return RiskAssessment(
      score: score,
      level: level,
      vulnerabilityPercentage: vulnerabilityPercentage,
      confidenceScore: confidenceScore,
      factors: factors,
      checklist: checklist,
    );
  }

  double calculateDistanceFromSafeZoneKm({
    required double currentLat,
    required double currentLng,
    required double safeLat,
    required double safeLng,
  }) {
    final distanceMeters = Geolocator.distanceBetween(
      currentLat,
      currentLng,
      safeLat,
      safeLng,
    );
    return distanceMeters / 1000;
  }

  RiskLevel _mapLevel(int score) {
    if (score <= 3) {
      return RiskLevel.safe;
    }
    if (score <= 7) {
      return RiskLevel.alert;
    }
    if (score <= 11) {
      return RiskLevel.caution;
    }
    return RiskLevel.danger;
  }
}
