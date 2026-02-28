import '../models/app_settings.dart';
import '../models/guide_models.dart';

class GuideContentFormatter {
  ScenarioGuide formatForMode({
    required ScenarioGuide source,
    required UserMode mode,
  }) {
    if (mode != UserMode.child) {
      return source;
    }

    return ScenarioGuide(
      scenario: source.scenario,
      shortTitle: _simplify(source.shortTitle),
      immediateSteps: _simplifyList(source.immediateSteps, limit: 3),
      whatNotToDo: _simplifyList(source.whatNotToDo, limit: 2),
      recommendedActions: _simplifyList(source.recommendedActions, limit: 3),
      relatedQuickActions: source.relatedQuickActions,
    );
  }

  List<String> _simplifyList(List<String> items, {required int limit}) {
    return items
        .take(limit)
        .map(_simplify)
        .toList();
  }

  String _simplify(String text) {
    return text
        .replaceAll('immediately', 'now')
        .replaceAll('authorities', 'police')
        .replaceAll('maintain', 'keep')
        .replaceAll('surroundings', 'around you')
        .replaceAll('evidence', 'proof')
        .replaceAll('incident', 'event');
  }
}
