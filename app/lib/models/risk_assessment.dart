import 'risk_factors.dart';

enum RiskLevel { safe, alert, caution, danger }

class RiskAssessment {
  const RiskAssessment({
    required this.score,
    required this.level,
    required this.vulnerabilityPercentage,
    required this.confidenceScore,
    required this.factors,
    required this.checklist,
  });

  final int score;
  final RiskLevel level;
  final double vulnerabilityPercentage;
  final double confidenceScore;
  final RiskFactors factors;
  final List<String> checklist;
}
