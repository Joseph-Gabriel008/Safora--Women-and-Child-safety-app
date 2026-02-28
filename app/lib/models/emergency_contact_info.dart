class EmergencyContactInfo {
  EmergencyContactInfo({
    required this.country,
    required this.police,
    required this.womenHelpline,
    required this.childHelpline,
    required this.generalEmergency,
  });

  final String country;
  final String police;
  final String womenHelpline;
  final String childHelpline;
  final String generalEmergency;

  factory EmergencyContactInfo.fromMap(Map<String, dynamic> map) {
    return EmergencyContactInfo(
      country: map['country'] as String,
      police: map['police'] as String,
      womenHelpline: map['womenHelpline'] as String,
      childHelpline: map['childHelpline'] as String,
      generalEmergency: map['generalEmergency'] as String,
    );
  }
}
