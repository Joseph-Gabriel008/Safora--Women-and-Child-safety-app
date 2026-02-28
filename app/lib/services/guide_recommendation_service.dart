import 'dart:async';

import '../models/guide_models.dart';
import '../models/risk_assessment.dart';
import '../models/risk_factors.dart';

class GuideRecommendationService {
  GuideRecommendationService(Stream<RiskAssessment> riskStream) {
    _subscription = riskStream.listen(_onRiskUpdate);
  }

  final StreamController<EmergencyScenario?> _controller =
      StreamController<EmergencyScenario?>.broadcast();
  late final StreamSubscription<RiskAssessment> _subscription;

  EmergencyScenario? _latestRecommendation;

  Stream<EmergencyScenario?> get stream => _controller.stream;
  EmergencyScenario? get latestRecommendation => _latestRecommendation;

  static EmergencyScenario? recommend(RiskAssessment assessment) {
    if (assessment.level == RiskLevel.danger &&
        assessment.factors.areaType == AreaType.cabRide) {
      return EmergencyScenario.unsafeCab;
    }

    if (assessment.level == RiskLevel.caution && assessment.factors.isNight) {
      return EmergencyScenario.nightTravelAlone;
    }

    return null;
  }

  static EmergencyScenario? recommendFromNullable(RiskAssessment? assessment) {
    if (assessment == null) {
      return null;
    }
    return recommend(assessment);
  }

  void _onRiskUpdate(RiskAssessment assessment) {
    final recommendation = recommend(assessment);
    if (recommendation == _latestRecommendation) {
      return;
    }

    _latestRecommendation = recommendation;
    _controller.add(recommendation);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}
