import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../core/utils/risk_calculator.dart';
import '../models/risk_assessment.dart';
import '../models/risk_factors.dart';
import '../services/emergency_engine.dart';
import '../services/risk_monitor_service.dart';

class RiskZoneScreen extends StatefulWidget {
  const RiskZoneScreen({super.key});

  @override
  State<RiskZoneScreen> createState() => _RiskZoneScreenState();
}

class _RiskZoneScreenState extends State<RiskZoneScreen> {
  final _calculator = RiskCalculator();

  bool _isNight = false;
  bool _isAlone = true;
  bool _networkAvailable = true;
  AreaType _areaType = AreaType.publicPlace;
  double _currentSpeed = 0;
  double _distanceFromSafeZone = 0;
  int _batteryLevel = 65;

  @override
  Widget build(BuildContext context) {
    final factors = RiskFactors(
      isNight: _isNight,
      areaType: _areaType,
      isAlone: _isAlone,
      batteryLevel: _batteryLevel,
      networkAvailable: _networkAvailable,
      currentSpeed: _currentSpeed,
      distanceFromSafeZone: _distanceFromSafeZone,
    );
    final assessment = _calculator.calculateRiskScore(factors);

    final levelColor = switch (assessment.level) {
      RiskLevel.safe => Colors.green,
      RiskLevel.alert => Colors.lightGreen,
      RiskLevel.caution => Colors.orange,
      RiskLevel.danger => Colors.red,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Risk Zone Predictor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Night Time'),
                    value: _isNight,
                    onChanged: (v) => setState(() => _isNight = v),
                  ),
                  SwitchListTile(
                    title: const Text('Alone'),
                    value: _isAlone,
                    onChanged: (v) => setState(() => _isAlone = v),
                  ),
                  SwitchListTile(
                    title: const Text('Network Available'),
                    value: _networkAvailable,
                    onChanged: (v) => setState(() => _networkAvailable = v),
                  ),
                  DropdownButtonFormField<AreaType>(
                    initialValue: _areaType,
                    decoration: const InputDecoration(labelText: 'Area Type'),
                    items: AreaType.values
                        .map(
                          (value) => DropdownMenuItem<AreaType>(
                            value: value,
                            child: Text(_areaTypeLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _areaType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _sliderRow(
                    label: 'Battery: $_batteryLevel%',
                    value: _batteryLevel.toDouble(),
                    max: 100,
                    onChanged: (value) => setState(() => _batteryLevel = value.toInt()),
                  ),
                  _sliderRow(
                    label: 'Speed: ${_currentSpeed.toStringAsFixed(1)} km/h',
                    value: _currentSpeed,
                    max: 140,
                    onChanged: (value) => setState(() => _currentSpeed = value),
                  ),
                  _sliderRow(
                    label: 'Distance from safe zone: ${_distanceFromSafeZone.toStringAsFixed(1)} km',
                    value: _distanceFromSafeZone,
                    max: 20,
                    onChanged: (value) => setState(() => _distanceFromSafeZone = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: levelColor.withValues(alpha: 0.16),
              border: Border.all(color: levelColor.withValues(alpha: 0.55), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk: ${assessment.level.name.toUpperCase()} (score ${assessment.score})',
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vulnerability: ${assessment.vulnerabilityPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Confidence: ${assessment.confidenceScore.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...assessment.checklist.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• $item',
                        style: const TextStyle(fontSize: 16, height: 1.35),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Consumer<EmergencyEngine>(
            builder: (context, engine, _) {
              final safeLat = engine.settings.safeZoneLatitude;
              final safeLng = engine.settings.safeZoneLongitude;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeLat == null || safeLng == null
                            ? 'Safe zone not configured'
                            : 'Safe zone: ${safeLat.toStringAsFixed(4)}, ${safeLng.toStringAsFixed(4)}',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _setSafeZoneFromCurrentLocation,
                            icon: const Icon(Icons.home),
                            label: const Text('Set Current as Safe Zone'),
                          ),
                          OutlinedButton(
                            onPressed: engine.clearSafeZone,
                            child: const Text('Clear Safe Zone'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_graph),
              title: const Text('Live Monitor Snapshot'),
              subtitle: StreamBuilder<RiskAssessment>(
                stream: context.read<RiskMonitorService>().stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('Waiting for monitor updates...');
                  }
                  final live = snapshot.data!;
                  return Text(
                    '${live.level.name.toUpperCase()} | Score ${live.score} | '
                    'Vulnerability ${live.vulnerabilityPercentage.toStringAsFixed(1)}%',
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Consumer<EmergencyEngine>(
            builder: (context, engine, _) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Emergency Ready Mode'),
                subtitle: const Text('Keeps safety engine primed for faster response.'),
                value: engine.settings.emergencyReadyMode,
                onChanged: (v) => engine.updateEmergencyReadyMode(v),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        Slider(value: value, max: max, onChanged: onChanged),
      ],
    );
  }

  String _areaTypeLabel(AreaType value) {
    switch (value) {
      case AreaType.isolatedRoad:
        return 'Isolated Road';
      case AreaType.busStop:
        return 'Bus Stop';
      case AreaType.cabRide:
        return 'Cab Ride';
      case AreaType.publicPlace:
        return 'Public Place';
    }
  }

  Future<void> _setSafeZoneFromCurrentLocation() async {
    final engine = context.read<EmergencyEngine>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(const SnackBar(content: Text('Location permission denied.')));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await engine.updateSafeZone(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('Safe zone updated.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Unable to set safe zone.')));
    }
  }
}
