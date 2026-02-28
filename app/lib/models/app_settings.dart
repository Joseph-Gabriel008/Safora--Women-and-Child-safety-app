enum UserMode { women, child }

const Object _notSet = Object();

class AppSettings {
  AppSettings({
    this.mode = UserMode.women,
    this.guardianPhone = '',
    this.trustedContacts = const <String>[],
    this.emergencyReadyMode = false,
    this.codeWordEnabled = false,
    this.codeWordMessage = '',
    this.emergencyNumber = '112',
    this.safeZoneLatitude,
    this.safeZoneLongitude,
  });

  final UserMode mode;
  final String guardianPhone;
  final List<String> trustedContacts;
  final bool emergencyReadyMode;
  final bool codeWordEnabled;
  final String codeWordMessage;
  final String emergencyNumber;
  final double? safeZoneLatitude;
  final double? safeZoneLongitude;

  AppSettings copyWith({
    UserMode? mode,
    String? guardianPhone,
    List<String>? trustedContacts,
    bool? emergencyReadyMode,
    bool? codeWordEnabled,
    String? codeWordMessage,
    String? emergencyNumber,
    Object? safeZoneLatitude = _notSet,
    Object? safeZoneLongitude = _notSet,
  }) {
    return AppSettings(
      mode: mode ?? this.mode,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      trustedContacts: trustedContacts ?? this.trustedContacts,
      emergencyReadyMode: emergencyReadyMode ?? this.emergencyReadyMode,
      codeWordEnabled: codeWordEnabled ?? this.codeWordEnabled,
      codeWordMessage: codeWordMessage ?? this.codeWordMessage,
      emergencyNumber: emergencyNumber ?? this.emergencyNumber,
      safeZoneLatitude: identical(safeZoneLatitude, _notSet)
          ? this.safeZoneLatitude
          : safeZoneLatitude as double?,
      safeZoneLongitude: identical(safeZoneLongitude, _notSet)
          ? this.safeZoneLongitude
          : safeZoneLongitude as double?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode.name,
      'guardianPhone': guardianPhone,
      'trustedContacts': trustedContacts,
      'emergencyReadyMode': emergencyReadyMode,
      'codeWordEnabled': codeWordEnabled,
      'codeWordMessage': codeWordMessage,
      'emergencyNumber': emergencyNumber,
      'safeZoneLatitude': safeZoneLatitude,
      'safeZoneLongitude': safeZoneLongitude,
    };
  }

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) {
    return AppSettings(
      mode: (map['mode'] as String?) == UserMode.child.name
          ? UserMode.child
          : UserMode.women,
      guardianPhone: map['guardianPhone'] as String? ?? '',
      trustedContacts: List<String>.from(
        (map['trustedContacts'] as List<dynamic>? ?? const <dynamic>[]),
      ).map((value) => value.trim()).where((value) => value.isNotEmpty).toList(),
      emergencyReadyMode: map['emergencyReadyMode'] as bool? ?? false,
      codeWordEnabled: map['codeWordEnabled'] as bool? ?? false,
      codeWordMessage: map['codeWordMessage'] as String? ?? '',
      emergencyNumber: map['emergencyNumber'] as String? ?? '112',
      safeZoneLatitude: (map['safeZoneLatitude'] as num?)?.toDouble(),
      safeZoneLongitude: (map['safeZoneLongitude'] as num?)?.toDouble(),
    );
  }
}
