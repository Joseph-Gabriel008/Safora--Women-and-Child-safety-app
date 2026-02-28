import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:provider/provider.dart';
import 'package:torch_light/torch_light.dart';

import '../../models/app_settings.dart';
import '../../models/emergency_contact_info.dart';
import '../../models/guide_models.dart';
import '../../services/emergency_engine.dart';
import '../../services/guide_content_formatter.dart';
import '../../services/guide_recommendation_service.dart';
import '../../services/guide_tts_service.dart';
import '../../services/survival_guide_repository.dart';

class SurvivalGuideScreen extends StatefulWidget {
  const SurvivalGuideScreen({super.key});

  @override
  State<SurvivalGuideScreen> createState() => _SurvivalGuideScreenState();
}

class _SurvivalGuideScreenState extends State<SurvivalGuideScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GuideContentFormatter _formatter = GuideContentFormatter();
  late GuideTtsService _ttsService;
  bool _servicesBound = false;

  bool _sirenOn = false;
  bool _flashlightOn = false;
  bool _panicSimplifiedMode = false;
  bool _loading = true;

  List<ScenarioGuide> _guides = <ScenarioGuide>[];
  List<ScenarioGuide> _filteredGuides = <ScenarioGuide>[];
  List<EmergencyContactInfo> _contacts = <EmergencyContactInfo>[];

  ScenarioGuide? _selectedGuide;
  List<EmergencyChecklistItem> _checklist = <EmergencyChecklistItem>[];
  EmergencyScenario? _recommendedScenario;
  int _currentStepIndex = 0;

  StreamSubscription<EmergencyScenario?>? _recommendationSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servicesBound) {
      return;
    }

    _ttsService = context.read<GuideTtsService>();
    _servicesBound = true;
  }

  @override
  void dispose() {
    _recommendationSub?.cancel();
    _searchController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final repo = context.read<SurvivalGuideRepository>();
    final recommendationService = context.read<GuideRecommendationService>();

    try {
      final guides = await repo.loadGuides();
      final contacts = await repo.loadEmergencyContacts();
      _recommendationSub = recommendationService.stream.listen((scenario) {
        if (!mounted) {
          return;
        }
        setState(() {
          _recommendedScenario = scenario;
        });
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _guides = guides;
        _filteredGuides = guides;
        _contacts = contacts;
        _recommendedScenario = recommendationService.latestRecommendation;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<EmergencyEngine>().settings.mode;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedGuide == null ? 'Offline Survival Guide' : _selectedGuide!.shortTitle),
        actions: [
          if (_selectedGuide != null)
            IconButton(
              icon: Icon(_panicSimplifiedMode ? Icons.view_agenda : Icons.format_size),
              tooltip: _panicSimplifiedMode
                  ? 'Exit Panic Simplified Mode'
                  : 'Enter Panic Simplified Mode',
              onPressed: () {
                setState(() {
                  _panicSimplifiedMode = !_panicSimplifiedMode;
                  _currentStepIndex = 0;
                });
              },
            ),
          if (_selectedGuide != null)
            IconButton(
              icon: const Icon(Icons.record_voice_over),
              tooltip: 'Read Instructions',
              onPressed: _readCurrentStep,
            ),
          if (_selectedGuide != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to scenarios',
              onPressed: () async {
    await _ttsService.stop();
                if (!mounted) {
                  return;
                }
                setState(() {
                  _selectedGuide = null;
                  _panicSimplifiedMode = false;
                  _currentStepIndex = 0;
                  _checklist = <EmergencyChecklistItem>[];
                });
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _selectedGuide == null
              ? _buildScenarioList(mode)
              : _buildScenarioDetail(mode),
    );
  }

  Widget _buildScenarioList(UserMode mode) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_recommendedScenario != null)
          _recommendationBanner(_recommendedScenario!),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Search offline guide',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        ..._filteredGuides.map((guide) {
          final formatted = _formatter.formatForMode(source: guide, mode: mode);
          final isRecommended = guide.scenario == _recommendedScenario;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(
                isRecommended ? Icons.recommend : Icons.menu_book,
                color: isRecommended ? Colors.orange : null,
              ),
              title: Text(formatted.shortTitle),
              subtitle: Text('${formatted.immediateSteps.length} immediate steps'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openScenario(formatted),
            ),
          );
        }),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Local Emergency Numbers',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ..._contacts.map(
                  (contact) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${contact.country}: Police ${contact.police}, Women ${contact.womenHelpline}, '
                      'Child ${contact.childHelpline}, Emergency ${contact.generalEmergency}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _triggerFakeCall,
              icon: const Icon(Icons.call),
              label: const Text('Fake Call'),
            ),
            FilledButton.icon(
              onPressed: _toggleSiren,
              icon: Icon(_sirenOn ? Icons.volume_off : Icons.campaign),
              label: Text(_sirenOn ? 'Stop Siren' : 'Siren Mode'),
            ),
            FilledButton.icon(
              onPressed: _toggleFlashlight,
              icon: Icon(_flashlightOn ? Icons.flashlight_off : Icons.flashlight_on),
              label: Text(_flashlightOn ? 'Flashlight Off' : 'Flashlight Mode'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScenarioDetail(UserMode mode) {
    final guide = _formatter.formatForMode(source: _selectedGuide!, mode: mode);

    if (_panicSimplifiedMode) {
      return _panicModeView(guide);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard('Immediate Steps', guide.immediateSteps),
        _sectionCard('What Not To Do', guide.whatNotToDo),
        _sectionCard('Recommended Actions', guide.recommendedActions),
        const SizedBox(height: 10),
        const Text('Checklist', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ..._checklist.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return CheckboxListTile(
            title: Text(item.text),
            value: item.isCompleted,
            onChanged: (value) => _toggleChecklist(index, value ?? false),
          );
        }),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: guide.relatedQuickActions
              .map((action) => FilledButton.icon(
                    onPressed: () => _executeQuickAction(action),
                    icon: Icon(_iconForQuickAction(action)),
                    label: Text(_labelForQuickAction(action)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _panicModeView(ScenarioGuide guide) {
    final steps = guide.immediateSteps;

    return Container(
      color: Colors.black,
      child: PageView.builder(
        itemCount: steps.length,
        onPageChanged: (index) {
          setState(() {
            _currentStepIndex = index;
          });
        },
        itemBuilder: (_, index) {
          final step = steps[index];
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                step,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionCard(String title, List<String> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('• $item'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _recommendationBanner(EmergencyScenario scenario) {
    final guide = _guides.where((item) => item.scenario == scenario).toList();
    if (guide.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.orange.withValues(alpha: 0.12),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.tips_and_updates, color: Colors.orange),
        title: const Text('Suggested for current risk'),
        subtitle: Text(guide.first.shortTitle),
        trailing: TextButton(
          onPressed: () => _openScenario(guide.first),
          child: const Text('Open'),
        ),
      ),
    );
  }

  Future<void> _openScenario(ScenarioGuide guide) async {
    final checklist = await context.read<SurvivalGuideRepository>().loadChecklist(guide);
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedGuide = guide;
      _checklist = checklist;
      _panicSimplifiedMode = false;
      _currentStepIndex = 0;
    });
  }

  Future<void> _toggleChecklist(int index, bool checked) async {
    final updated = List<EmergencyChecklistItem>.from(_checklist);
    updated[index] = updated[index].copyWith(isCompleted: checked);

    setState(() {
      _checklist = updated;
    });

    await context.read<SurvivalGuideRepository>().saveChecklist(
          _selectedGuide!.scenario,
          updated,
        );
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredGuides = _guides.where((guide) {
        final text = <String>[
          guide.shortTitle,
          ...guide.immediateSteps,
          ...guide.whatNotToDo,
          ...guide.recommendedActions,
        ].join(' ').toLowerCase();
        return text.contains(q);
      }).toList();
    });
  }

  Future<void> _executeQuickAction(QuickActionType action) async {
    final success =
        await context.read<EmergencyEngine>().executeGuideQuickAction(action);

    if (action == QuickActionType.fakeCall) {
      await _triggerFakeCall();
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${_labelForQuickAction(action)} action completed.'
              : '${_labelForQuickAction(action)} could not run on this device.',
        ),
      ),
    );
  }

  Future<void> _readCurrentStep() async {
    if (_selectedGuide == null) {
      return;
    }

    final mode = context.read<EmergencyEngine>().settings.mode;
    final guide = _formatter.formatForMode(source: _selectedGuide!, mode: mode);
    final steps = guide.immediateSteps;
    if (steps.isEmpty) {
      return;
    }

    final index = _panicSimplifiedMode ? _currentStepIndex : 0;
    final step = steps[index.clamp(0, steps.length - 1)];
    await _ttsService.speak(step);
  }

  Future<void> _triggerFakeCall() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }

    await showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return _FakeIncomingCallView(
          callerName: 'Mom',
          onDecline: () => Navigator.of(context).pop('declined'),
          onAccept: () => Navigator.of(context).pop('accepted'),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  Future<void> _toggleSiren() async {
    if (_sirenOn) {
      FlutterRingtonePlayer().stop();
    } else {
      FlutterRingtonePlayer().playAlarm(looping: true, asAlarm: true, volume: 1);
    }

    setState(() {
      _sirenOn = !_sirenOn;
    });
  }

  Future<void> _toggleFlashlight() async {
    try {
      if (_flashlightOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      setState(() {
        _flashlightOn = !_flashlightOn;
      });
    } catch (_) {}
  }

  IconData _iconForQuickAction(QuickActionType type) {
    switch (type) {
      case QuickActionType.activateStealth:
        return Icons.visibility_off;
      case QuickActionType.startSilentRecording:
        return Icons.mic_none;
      case QuickActionType.flashlightOn:
        return Icons.flashlight_on;
      case QuickActionType.fakeCall:
        return Icons.call;
      case QuickActionType.triggerSOS:
        return Icons.sos;
    }
  }

  String _labelForQuickAction(QuickActionType type) {
    switch (type) {
      case QuickActionType.activateStealth:
        return 'Stealth';
      case QuickActionType.startSilentRecording:
        return 'Record';
      case QuickActionType.flashlightOn:
        return 'Flashlight';
      case QuickActionType.fakeCall:
        return 'Fake Call';
      case QuickActionType.triggerSOS:
        return 'SOS';
    }
  }
}

class _FakeIncomingCallView extends StatelessWidget {
  const _FakeIncomingCallView({
    required this.callerName,
    required this.onDecline,
    required this.onAccept,
  });

  final String callerName;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final timeLabel = now.format(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2A), Color(0xFF0D0E14)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Column(
              children: [
                Text(
                  timeLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Incoming call',
                  style: TextStyle(color: Colors.white70, fontSize: 20),
                ),
                const Spacer(),
                CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.white12,
                  child: Text(
                    callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mobile',
                  style: TextStyle(color: Colors.white60, fontSize: 18),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _callButton(
                      color: const Color(0xFFCF3F5A),
                      icon: Icons.call_end,
                      label: 'Decline',
                      onTap: onDecline,
                    ),
                    _callButton(
                      color: const Color(0xFF33B56C),
                      icon: Icons.call,
                      label: 'Accept',
                      onTap: onAccept,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _callButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(34),
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }
}
