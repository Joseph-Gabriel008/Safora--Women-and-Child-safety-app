import 'emergency_level.dart';

class MovementPoint {
  MovementPoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.levelTriggered,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final EmergencyLevel levelTriggered;

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'levelTriggered': levelTriggered.name,
    };
  }

  factory MovementPoint.fromMap(Map<dynamic, dynamic> map) {
    final level = EmergencyLevel.values.firstWhere(
      (value) => value.name == map['levelTriggered'],
      orElse: () => EmergencyLevel.level1,
    );

    return MovementPoint(
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      levelTriggered: level,
    );
  }
}
