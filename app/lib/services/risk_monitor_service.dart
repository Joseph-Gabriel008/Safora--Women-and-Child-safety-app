import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';

import '../core/utils/risk_calculator.dart';
import '../models/risk_assessment.dart';
import '../models/risk_event_log.dart';
import '../models/risk_factors.dart';
import '../storage/hive_storage.dart';
import 'emergency_engine.dart';
import 'voice_trigger_service.dart';

class RiskMonitorService {
  RiskMonitorService({
    required HiveStorage storage,
    required EmergencyEngine emergencyEngine,
    required VoiceTriggerService voiceTriggerService,
    RiskCalculator? calculator,
    Battery? battery,
  })  : _storage = storage,
        _emergencyEngine = emergencyEngine,
        _voiceTriggerService = voiceTriggerService,
        _calculator = calculator ?? RiskCalculator(),
        _battery = battery ?? Battery();

  final HiveStorage _storage;
  final EmergencyEngine _emergencyEngine;
  final VoiceTriggerService _voiceTriggerService;
  final RiskCalculator _calculator;
  final Battery _battery;

  final StreamController<RiskAssessment> _riskController =
      StreamController<RiskAssessment>.broadcast();
  final StreamController<String> _warningController =
      StreamController<String>.broadcast();

  Timer? _timer;
  RiskAssessment? _lastAssessment;

  Stream<RiskAssessment> get stream => _riskController.stream;
  Stream<String> get warnings => _warningController.stream;

  Future<void> start() async {
    if (_timer != null) {
      return;
    }

    await _tick();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _tick();
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    await stop();
    await _riskController.close();
    await _warningController.close();
  }

  Future<void> runManualEvaluation(RiskFactors factors) async {
    final assessment = _calculator.calculateRiskScore(factors);
    _riskController.add(assessment);
    await _storage.saveRiskEvent(
      RiskEventLog(
        timestamp: DateTime.now(),
        level: assessment.level,
        score: assessment.score,
        vulnerabilityPercentage: assessment.vulnerabilityPercentage,
      ),
    );
  }

  Future<void> _tick() async {
    try {
      final now = DateTime.now();
      final isNight = now.hour < 6 || now.hour >= 19;
      final batteryLevel = await _battery.batteryLevel;
      final networkState = await Connectivity().checkConnectivity();
      final networkAvailable = !networkState.contains(ConnectivityResult.none);
      final position = await _tryGetPosition();

      final currentSpeed = (position?.speed ?? 0) * 3.6;
      final areaType = _inferAreaType(currentSpeed);

      var distanceFromSafeZone = 0.0;
      if (position != null && _emergencyEngine.hasSafeZone) {
        final safeLat = _emergencyEngine.settings.safeZoneLatitude!;
        final safeLng = _emergencyEngine.settings.safeZoneLongitude!;
        distanceFromSafeZone = _calculator.calculateDistanceFromSafeZoneKm(
          currentLat: position.latitude,
          currentLng: position.longitude,
          safeLat: safeLat,
          safeLng: safeLng,
        );
      }

      final factors = RiskFactors(
        isNight: isNight,
        areaType: areaType,
        isAlone: isNight,
        batteryLevel: batteryLevel,
        networkAvailable: networkAvailable,
        currentSpeed: currentSpeed,
        distanceFromSafeZone: distanceFromSafeZone,
      );

      final assessment = _calculator.calculateRiskScore(factors);
      _riskController.add(assessment);

      await _storage.saveRiskEvent(
        RiskEventLog(
          timestamp: DateTime.now(),
          level: assessment.level,
          score: assessment.score,
          vulnerabilityPercentage: assessment.vulnerabilityPercentage,
        ),
      );

      await _applyRiskAutomation(assessment);
      await _handleSuddenIncrease(assessment);
      _lastAssessment = assessment;
    } catch (_) {
      // Keep monitor resilient; next tick will retry.
    }
  }

  Future<void> _applyRiskAutomation(RiskAssessment assessment) async {
    if (assessment.level != RiskLevel.danger) {
      return;
    }

    await _emergencyEngine.enableEmergencyReadyFromRisk();
    await _emergencyEngine.startPassiveLocationLogging();
    await _voiceTriggerService.startListening();
  }

  Future<void> _handleSuddenIncrease(RiskAssessment assessment) async {
    final previous = _lastAssessment;
    if (previous == null) {
      return;
    }

    final jumped = assessment.score - previous.score >= 3 ||
        assessment.level.index > previous.level.index;
    if (!jumped) {
      return;
    }

    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 260);
    }

    _warningController.add(
      'Risk increased to ${assessment.level.name.toUpperCase()} (${assessment.score}).',
    );

    await _storage.saveRiskEvent(
      RiskEventLog(
        timestamp: DateTime.now(),
        level: assessment.level,
        score: assessment.score,
        vulnerabilityPercentage: assessment.vulnerabilityPercentage,
      ),
    );
  }

  Future<Position?> _tryGetPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (_) {
      return null;
    }
  }

  AreaType _inferAreaType(double speedKmh) {
    if (speedKmh > 40) {
      return AreaType.cabRide;
    }
    if (speedKmh < 2) {
      return AreaType.busStop;
    }
    return AreaType.publicPlace;
  }
}
