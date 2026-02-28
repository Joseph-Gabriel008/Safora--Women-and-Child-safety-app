import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import '../models/emergency_level.dart';
import '../models/movement_point.dart';
import '../storage/hive_storage.dart';
import 'sms_dispatcher_service.dart';

class LocationService {
  LocationService(this._storage);

  final HiveStorage _storage;
  Timer? _trackingTimer;
  bool _isTracking = false;
  EmergencyLevel _trackingLevel = EmergencyLevel.level1;

  bool get isTracking => _isTracking;

  Future<void> startTracking(EmergencyLevel level) async {
    _trackingLevel = level;
    if (_isTracking) {
      return;
    }

    _isTracking = true;
    await _capturePoint();
    _trackingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _capturePoint();
    });
  }

  Future<void> stopTracking() async {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _isTracking = false;
  }

  List<MovementPoint> getHistory() => _storage.getMovementPoints();

  Future<String?> persistMovementHistory() async {
    final points = getHistory();
    if (points.isEmpty) {
      return null;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/movement_history_${DateTime.now().millisecondsSinceEpoch}.csv');
    final rows = <String>['timestamp,latitude,longitude,levelTriggered'];
    for (final point in points) {
      rows.add(
        '${point.timestamp.toIso8601String()},${point.latitude},${point.longitude},${point.levelTriggered.name}',
      );
    }

    await file.writeAsString(rows.join('\n'));
    return file.path;
  }

  Future<void> flushHistoryIfNetworkAvailable({
    required List<String> recipients,
    required SmsDispatcherService smsDispatcher,
    required String messagePrefix,
  }) async {
    if (recipients.isEmpty) {
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return;
    }

    final history = getHistory();
    if (history.isEmpty) {
      return;
    }

    final mapsLink = _buildGoogleMapsTrail(history);
    final message = '$messagePrefix Movement history: $mapsLink';
    for (final recipient in recipients.toSet()) {
      await smsDispatcher.send(phone: recipient, message: message);
    }
  }

  Future<void> clearHistory() => _storage.clearMovementPoints();

  Future<void> _capturePoint() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _storage.addMovementPoint(
        MovementPoint(
          timestamp: DateTime.now(),
          latitude: current.latitude,
          longitude: current.longitude,
          levelTriggered: _trackingLevel,
        ),
      );
    } catch (_) {}
  }

  String _buildGoogleMapsTrail(List<MovementPoint> points) {
    final waypoints = points
        .map((point) => '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}')
        .join('/');
    return 'https://www.google.com/maps/dir/$waypoints';
  }
}
