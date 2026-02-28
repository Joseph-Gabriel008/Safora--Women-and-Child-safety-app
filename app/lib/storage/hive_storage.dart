import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/app_constants.dart';
import '../models/app_settings.dart';
import '../models/emergency_log.dart';
import '../models/guide_models.dart';
import '../models/movement_point.dart';
import '../models/queued_guardian_message.dart';
import '../models/risk_event_log.dart';

class HiveStorage {
  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(AppConstants.logsBox);
    await Hive.openBox<Map>(AppConstants.queueBox);
    await Hive.openBox<Map>(AppConstants.settingsBox);
    await Hive.openBox<Map>(AppConstants.movementBox);
    await Hive.openBox<Map>(AppConstants.riskEventsBox);
    await Hive.openBox<Map>(AppConstants.checklistBox);
  }

  Box<Map> get _logs => Hive.box<Map>(AppConstants.logsBox);
  Box<Map> get _queue => Hive.box<Map>(AppConstants.queueBox);
  Box<Map> get _settings => Hive.box<Map>(AppConstants.settingsBox);
  Box<Map> get _movement => Hive.box<Map>(AppConstants.movementBox);
  Box<Map> get _riskEvents => Hive.box<Map>(AppConstants.riskEventsBox);
  Box<Map> get _checklist => Hive.box<Map>(AppConstants.checklistBox);

  Future<void> saveLog(EmergencyLog log) async {
    await _logs.put(log.id, log.toMap());
  }

  Future<void> updateLog(EmergencyLog log) async {
    await _logs.put(log.id, log.toMap());
  }

  List<EmergencyLog> getLogs() {
    return _logs.values
        .map(EmergencyLog.fromMap)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> enqueueGuardianMessage(QueuedGuardianMessage message) async {
    await _queue.put(message.id, message.toMap());
  }

  List<QueuedGuardianMessage> getQueuedMessages() {
    return _queue.values
        .map(QueuedGuardianMessage.fromMap)
        .where((message) => !message.isSent)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> markMessageSent(String id) async {
    final raw = _queue.get(id);
    if (raw == null) {
      return;
    }

    final updated = QueuedGuardianMessage.fromMap(raw).copyWith(
      isSent: true,
      sentAt: DateTime.now(),
    );
    await _queue.put(id, updated.toMap());
  }

  AppSettings getSettings() {
    final map = _settings.get(AppConstants.settingsKey);
    if (map == null) {
      return AppSettings();
    }
    return AppSettings.fromMap(map);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _settings.put(AppConstants.settingsKey, settings.toMap());
  }

  Future<void> addMovementPoint(MovementPoint point) async {
    final key = point.timestamp.microsecondsSinceEpoch.toString();
    await _movement.put(key, point.toMap());
  }

  List<MovementPoint> getMovementPoints() {
    return _movement.values
        .map(MovementPoint.fromMap)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> clearMovementPoints() async {
    await _movement.clear();
  }

  Future<void> saveRiskEvent(RiskEventLog event) async {
    final key = event.timestamp.microsecondsSinceEpoch.toString();
    await _riskEvents.put(key, event.toMap());
  }

  List<RiskEventLog> getRiskEvents() {
    return _riskEvents.values
        .map(RiskEventLog.fromMap)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> saveChecklist(
    String scenarioKey,
    List<EmergencyChecklistItem> checklist,
  ) async {
    await _checklist.put(
      scenarioKey,
      <String, dynamic>{
        'items': checklist.map((item) => item.toMap()).toList(),
      },
    );
  }

  List<EmergencyChecklistItem> getChecklist(String scenarioKey) {
    final raw = _checklist.get(scenarioKey);
    if (raw == null) {
      return <EmergencyChecklistItem>[];
    }

    final items = raw['items'] as List<dynamic>? ?? const <dynamic>[];
    return items
        .map((item) => EmergencyChecklistItem.fromMap(item as Map<dynamic, dynamic>))
        .toList();
  }
}
