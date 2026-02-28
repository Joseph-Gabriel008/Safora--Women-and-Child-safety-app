import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'services/emergency_engine.dart';
import 'services/guide_recommendation_service.dart';
import 'services/guide_tts_service.dart';
import 'services/risk_monitor_service.dart';
import 'services/survival_guide_repository.dart';
import 'services/voice_trigger_service.dart';
import 'storage/hive_storage.dart';
import 'ui/app_controller.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = HiveStorage();
  await storage.init();

  final emergencyEngine = EmergencyEngine(storage);
  await emergencyEngine.initialize();

  runApp(SaforaApp(
    emergencyEngine: emergencyEngine,
    storage: storage,
  ));
}

class SaforaApp extends StatelessWidget {
  const SaforaApp({
    required this.emergencyEngine,
    required this.storage,
    super.key,
  });

  final EmergencyEngine emergencyEngine;
  final HiveStorage storage;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EmergencyEngine>.value(value: emergencyEngine),
        ChangeNotifierProvider<AppController>(create: (_) => AppController()),
        Provider<VoiceTriggerService>(
          create: (_) => VoiceTriggerService(emergencyEngine),
          dispose: (_, service) => service.stopListening(),
        ),
        Provider<RiskMonitorService>(
          create: (context) => RiskMonitorService(
            storage: storage,
            emergencyEngine: emergencyEngine,
            voiceTriggerService: context.read<VoiceTriggerService>(),
          ),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<SurvivalGuideRepository>(
          create: (_) => SurvivalGuideRepository(storage),
        ),
        Provider<GuideTtsService>(
          create: (_) => GuideTtsService(),
          dispose: (_, service) => service.stop(),
        ),
        Provider<GuideRecommendationService>(
          create: (context) => GuideRecommendationService(
            context.read<RiskMonitorService>().stream,
          ),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Safora',
        theme: AppTheme.lightTheme(),
        home: const _LifecycleHost(),
      ),
    );
  }
}

class _LifecycleHost extends StatefulWidget {
  const _LifecycleHost();

  @override
  State<_LifecycleHost> createState() => _LifecycleHostState();
}

class _LifecycleHostState extends State<_LifecycleHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RiskMonitorService>().start();
    });
  }

  @override
  void dispose() {
    context.read<RiskMonitorService>().stop();
    context.read<EmergencyEngine>().disposeEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SaforaAppShell();
  }
}
