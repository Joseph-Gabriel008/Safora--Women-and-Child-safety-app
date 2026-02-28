import 'emergency_level.dart';

class EmergencyLog {
  EmergencyLog({
    required this.id,
    required this.type,
    required this.trigger,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.audioPath,
    this.notes,
    this.emergencyLevel = EmergencyLevel.level1,
    this.escalationStage = 1,
    this.movementHistoryPath,
    this.encryptedRecordingPath,
    this.codeWordUsed = false,
    this.delayedTriggerUsed = false,
  });

  final String id;
  final String type;
  final String trigger;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? audioPath;
  final String? notes;
  final EmergencyLevel emergencyLevel;
  final int escalationStage;
  final String? movementHistoryPath;
  final String? encryptedRecordingPath;
  final bool codeWordUsed;
  final bool delayedTriggerUsed;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'trigger': trigger,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'audioPath': audioPath,
      'notes': notes,
      'emergencyLevel': emergencyLevel.name,
      'escalationStage': escalationStage,
      'movementHistoryPath': movementHistoryPath,
      'encryptedRecordingPath': encryptedRecordingPath,
      'codeWordUsed': codeWordUsed,
      'delayedTriggerUsed': delayedTriggerUsed,
    };
  }

  factory EmergencyLog.fromMap(Map<dynamic, dynamic> map) {
    final emergencyLevelName = map['emergencyLevel'] as String? ?? EmergencyLevel.level1.name;

    return EmergencyLog(
      id: map['id'] as String,
      type: map['type'] as String,
      trigger: map['trigger'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      audioPath: map['audioPath'] as String?,
      notes: map['notes'] as String?,
      emergencyLevel: EmergencyLevel.values.firstWhere(
        (value) => value.name == emergencyLevelName,
        orElse: () => EmergencyLevel.level1,
      ),
      escalationStage: map['escalationStage'] as int? ?? 1,
      movementHistoryPath: map['movementHistoryPath'] as String?,
      encryptedRecordingPath: map['encryptedRecordingPath'] as String?,
      codeWordUsed: map['codeWordUsed'] as bool? ?? false,
      delayedTriggerUsed: map['delayedTriggerUsed'] as bool? ?? false,
    );
  }
}
