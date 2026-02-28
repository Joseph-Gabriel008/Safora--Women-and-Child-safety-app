import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/emergency_engine.dart';

class ChildModeScreen extends StatelessWidget {
  const ChildModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Child Guardian Mode')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFFE8F5E9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_rounded, size: 28, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'If you feel scared, tap the big SOS button once.\nThen move to a bright place with people.',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Hero(
                tag: 'sos_hero',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF5350), Color(0xFFD81B60)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD81B60).withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await context.read<EmergencyEngine>().triggerEmergency(
                              trigger: EmergencyTrigger.childMode,
                              customNote: 'Child mode one tap SOS',
                            );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Emergency action sent. Stay in a safe place.')),
                        );
                      } catch (_) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not trigger SOS. Try again.')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sos_rounded, size: 70),
                        SizedBox(height: 12),
                        Text(
                          'ONE-TAP SOS',
                          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap once to get help',
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFFFF8E1),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Emergency Steps',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 10),
                    _StepTile(icon: Icons.call, text: 'Call your trusted adult.'),
                    SizedBox(height: 8),
                    _StepTile(icon: Icons.family_restroom, text: 'Stay near families or police.'),
                    SizedBox(height: 8),
                    _StepTile(icon: Icons.visibility, text: 'Keep your phone visible and ready.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: const Color(0xFFF57C00)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
