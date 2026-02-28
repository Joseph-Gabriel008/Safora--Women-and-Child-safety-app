import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/emergency_contact_info.dart';
import '../models/guide_models.dart';
import '../storage/hive_storage.dart';

class SurvivalGuideRepository {
  SurvivalGuideRepository(this._storage);

  final HiveStorage _storage;

  Future<List<ScenarioGuide>> loadGuides() async {
    final raw = await rootBundle.loadString('assets/data/survival_guide.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final scenarios = data['scenarios'] as List<dynamic>? ?? const <dynamic>[];

    return scenarios
        .map((item) => _toScenarioGuide(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<EmergencyContactInfo>> loadEmergencyContacts() async {
    final raw = await rootBundle.loadString('assets/data/emergency_contacts.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final rows = data['contacts'] as List<dynamic>? ?? const <dynamic>[];

    return rows
        .map((item) => EmergencyContactInfo.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ScenarioGuide>> search(String query) async {
    final q = query.trim().toLowerCase();
    final guides = await loadGuides();
    if (q.isEmpty) {
      return guides;
    }

    return guides.where((guide) {
      final haystack = <String>[
        guide.shortTitle,
        ...guide.immediateSteps,
        ...guide.whatNotToDo,
        ...guide.recommendedActions,
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }).toList();
  }

  Future<List<EmergencyChecklistItem>> loadChecklist(ScenarioGuide guide) async {
    final saved = _storage.getChecklist(guide.scenario.name);
    if (saved.isNotEmpty) {
      return saved;
    }

    return guide.immediateSteps
        .map((step) => EmergencyChecklistItem(text: step))
        .toList();
  }

  Future<void> saveChecklist(
    EmergencyScenario scenario,
    List<EmergencyChecklistItem> checklist,
  ) async {
    await _storage.saveChecklist(scenario.name, checklist);
  }

  ScenarioGuide _toScenarioGuide(Map<String, dynamic> map) {
    final scenario = EmergencyScenario.values.firstWhere(
      (item) => item.name == map['scenario'],
      orElse: () => EmergencyScenario.medicalEmergency,
    );

    final quickActions = (map['relatedQuickActions'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => QuickActionType.values.firstWhere(
              (value) => value.name == item,
              orElse: () => QuickActionType.triggerSOS,
            ))
        .toList();

    return ScenarioGuide(
      scenario: scenario,
      shortTitle: map['shortTitle'] as String,
      immediateSteps: List<String>.from(map['immediateSteps'] as List<dynamic>),
      whatNotToDo: List<String>.from(map['whatNotToDo'] as List<dynamic>),
      recommendedActions: List<String>.from(map['recommendedActions'] as List<dynamic>),
      relatedQuickActions: quickActions,
    );
  }
}
