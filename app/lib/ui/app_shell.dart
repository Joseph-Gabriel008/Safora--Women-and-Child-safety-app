import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'risk_screen.dart';

import '../core/widgets/panic_tap_wrapper.dart';
import '../features/child/child_mode_screen.dart';
import '../features/guide/survival_guide_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stealth/stealth_calculator_screen.dart';
import '../models/app_settings.dart';
import '../services/emergency_engine.dart';
import '../services/risk_monitor_service.dart';
import 'app_controller.dart';

class SaforaAppShell extends StatefulWidget {
  const SaforaAppShell({super.key});

  @override
  State<SaforaAppShell> createState() => _SaforaAppShellState();
}

class _SaforaAppShellState extends State<SaforaAppShell> {
  StreamSubscription<String>? _warningSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warningSub = context.read<RiskMonitorService>().warnings.listen((message) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentMaterialBanner()
          ..showMaterialBanner(
            MaterialBanner(
              content: Text(message),
              backgroundColor: Colors.orange.withValues(alpha: 0.12),
              leading: const Icon(Icons.warning_amber_rounded),
              actions: [
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          );
      });
    });
  }

  @override
  void dispose() {
    _warningSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppController, EmergencyEngine>(
      builder: (context, controller, engine, _) {
        final pages = <Widget>[
          engine.settings.mode == UserMode.child
              ? const ChildModeScreen()
              : const HomeScreen(),
          const StealthCalculatorScreen(),
          const RiskZoneScreen(),
          const SurvivalGuideScreen(),
          const SettingsScreen(),
        ];

        return PanicTapWrapper(
          onTripleTap: () => context.read<EmergencyEngine>().triggerEmergency(
                trigger: EmergencyTrigger.panicTap,
                customNote: 'Triggered with triple tap gesture',
              ),
          child: Scaffold(
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: KeyedSubtree(
                key: ValueKey<int>(controller.tabIndex),
                child: pages[controller.tabIndex],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: controller.tabIndex,
              onDestinationSelected: controller.setTab,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_filled), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.calculate), label: 'Stealth'),
                NavigationDestination(icon: Icon(Icons.security), label: 'Risk'),
                NavigationDestination(icon: Icon(Icons.menu_book), label: 'Guide'),
                NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
          ),
        );
      },
    );
  }
}
