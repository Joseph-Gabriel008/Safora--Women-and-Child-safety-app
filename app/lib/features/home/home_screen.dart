import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/emergency_log.dart';
import '../../services/emergency_engine.dart';
import '../../services/voice_trigger_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<EmergencyEngine>();
    final logs = engine.getLogs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safora SOS'),
        actions: [
          IconButton(
            tooltip: engine.isListeningForVoiceTrigger
                ? 'Stop voice keyword'
                : 'Start voice keyword',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final voice = context.read<VoiceTriggerService>();
              if (engine.isListeningForVoiceTrigger) {
                await voice.stopListening();
                if (!context.mounted) {
                  return;
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('Voice keyword listening stopped.')),
                );
              } else {
                final started = await voice.startListening();
                if (!context.mounted) {
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      started
                          ? 'Voice keyword listening started.'
                          : 'Unable to start voice listening. Check microphone permission.',
                    ),
                  ),
                );
              }
            },
            icon: Icon(
              engine.isListeningForVoiceTrigger ? Icons.mic : Icons.mic_none,
              color: engine.isListeningForVoiceTrigger
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusCard(isEmergencyActive: engine.isEmergencyActive),
              const SizedBox(height: 20),
              Center(
                child: Hero(
                  tag: 'sos_hero',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(90),
                      onTap: () => context
                          .read<EmergencyEngine>()
                          .triggerEmergency(trigger: EmergencyTrigger.sosButton),
                      child: Ink(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE91E63), Color(0xFF8E24AA), Color(0xFF5E35B1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD81B60).withValues(alpha: 0.35),
                              blurRadius: 26,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 156,
                              height: 156,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.24),
                                  width: 2,
                                ),
                              ),
                            ),
                            const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_rounded, color: Colors.white, size: 48),
                                SizedBox(height: 8),
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tap to alert',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap mic to listen for: "Help me"\nPanic gesture: Triple tap anywhere',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text('Recent Emergency Logs', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              if (logs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No logs yet. Trigger a test emergency to verify offline flow.'),
                  ),
                )
              else
                ...logs.take(5).map((log) => _LogTile(log: log)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.isEmergencyActive});

  final bool isEmergencyActive;

  @override
  Widget build(BuildContext context) {
    final color = isEmergencyActive ? Colors.red : Colors.green;
    final text = isEmergencyActive ? 'Emergency running' : 'System ready';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final EmergencyLog log;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        '${log.timestamp.toLocal()}\nLat: ${log.latitude?.toStringAsFixed(4) ?? '--'} | Lng: ${log.longitude?.toStringAsFixed(4) ?? '--'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.warning_rounded, color: Color(0xFFD81B60)),
        title: Text('Trigger: ${log.trigger} (${log.type})'),
        subtitle: Text(subtitle),
      ),
    );
  }
}
