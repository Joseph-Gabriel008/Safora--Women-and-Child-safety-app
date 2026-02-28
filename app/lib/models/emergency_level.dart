enum EmergencyLevel { level1, level2, level3 }

extension EmergencyLevelX on EmergencyLevel {
  int get stage {
    switch (this) {
      case EmergencyLevel.level1:
        return 1;
      case EmergencyLevel.level2:
        return 2;
      case EmergencyLevel.level3:
        return 3;
    }
  }

  EmergencyLevel next() {
    switch (this) {
      case EmergencyLevel.level1:
        return EmergencyLevel.level2;
      case EmergencyLevel.level2:
        return EmergencyLevel.level3;
      case EmergencyLevel.level3:
        return EmergencyLevel.level3;
    }
  }
}
