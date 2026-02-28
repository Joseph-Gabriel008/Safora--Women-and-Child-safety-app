enum AreaType {
  isolatedRoad,
  busStop,
  cabRide,
  publicPlace,
}

class RiskFactors {
  const RiskFactors({
    required this.isNight,
    required this.areaType,
    required this.isAlone,
    required this.batteryLevel,
    required this.networkAvailable,
    required this.currentSpeed,
    required this.distanceFromSafeZone,
  });

  final bool isNight;
  final AreaType areaType;
  final bool isAlone;
  final int batteryLevel;
  final bool networkAvailable;
  final double currentSpeed;
  final double distanceFromSafeZone;

  int get totalFactors => 7;

  int get activeFactors {
    var count = 0;
    if (isNight) count++;
    if (areaType == AreaType.isolatedRoad) count++;
    if (isAlone) count++;
    if (batteryLevel < 20) count++;
    if (!networkAvailable) count++;
    if (currentSpeed > 60) count++;
    if (distanceFromSafeZone > 5) count++;
    return count;
  }
}
