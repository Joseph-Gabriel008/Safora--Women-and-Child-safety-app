import 'risk_assessment.dart';

class RiskEventLog {
  RiskEventLog({
    required this.timestamp,
    required this.level,
    required this.score,
    required this.vulnerabilityPercentage,
  });

  final DateTime timestamp;
  final RiskLevel level;
  final int score;
  final double vulnerabilityPercentage;

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'score': score,
      'vulnerabilityPercentage': vulnerabilityPercentage,
    };
  }

  factory RiskEventLog.fromMap(Map<dynamic, dynamic> map) {
    final levelName = map['level'] as String? ?? RiskLevel.safe.name;
    return RiskEventLog(
      timestamp: DateTime.parse(map['timestamp'] as String),
      level: RiskLevel.values.firstWhere(
        (item) => item.name == levelName,
        orElse: () => RiskLevel.safe,
      ),
      score: map['score'] as int? ?? 0,
      vulnerabilityPercentage:
          (map['vulnerabilityPercentage'] as num?)?.toDouble() ?? 0,
    );
  }
}
