enum EmergencyScenario {
  unsafeCab,
  nightTravelAlone,
  domesticThreat,
  childLost,
  followedByStranger,
  kidnappingRisk,
  medicalEmergency,
  cpr,
  bleedingControl,
  postIncidentProtection,
}

enum QuickActionType {
  activateStealth,
  startSilentRecording,
  flashlightOn,
  fakeCall,
  triggerSOS,
}

class ScenarioGuide {
  ScenarioGuide({
    required this.scenario,
    required this.shortTitle,
    required this.immediateSteps,
    required this.whatNotToDo,
    required this.recommendedActions,
    required this.relatedQuickActions,
  });

  final EmergencyScenario scenario;
  final String shortTitle;
  final List<String> immediateSteps;
  final List<String> whatNotToDo;
  final List<String> recommendedActions;
  final List<QuickActionType> relatedQuickActions;
}

class EmergencyChecklistItem {
  EmergencyChecklistItem({
    required this.text,
    this.isCompleted = false,
  });

  final String text;
  final bool isCompleted;

  EmergencyChecklistItem copyWith({
    String? text,
    bool? isCompleted,
  }) {
    return EmergencyChecklistItem(
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isCompleted': isCompleted,
    };
  }

  factory EmergencyChecklistItem.fromMap(Map<dynamic, dynamic> map) {
    return EmergencyChecklistItem(
      text: map['text'] as String,
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }
}
