import '../models/app_settings.dart';
import '../models/emergency_level.dart';

class CodeWordMessageBuilder {
  String build({
    required AppSettings settings,
    required EmergencyLevel level,
    required String fallbackMessage,
  }) {
    if (!settings.codeWordEnabled || settings.codeWordMessage.trim().isEmpty) {
      return fallbackMessage;
    }

    return '${settings.codeWordMessage.trim()} (${_levelHint(level)})';
  }

  String _levelHint(EmergencyLevel level) {
    switch (level) {
      case EmergencyLevel.level1:
        return 'A1';
      case EmergencyLevel.level2:
        return 'A2';
      case EmergencyLevel.level3:
        return 'A3';
    }
  }
}
