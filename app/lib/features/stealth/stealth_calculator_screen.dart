import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/emergency_level.dart';
import '../../services/emergency_engine.dart';

class StealthCalculatorScreen extends StatefulWidget {
  const StealthCalculatorScreen({super.key});

  @override
  State<StealthCalculatorScreen> createState() => _StealthCalculatorScreenState();
}

class _StealthCalculatorScreenState extends State<StealthCalculatorScreen> {
  String _display = '0';
  double _left = 0;
  String _operator = '';
  final List<String> _secretBuffer = <String>[];

  final _countdownController = StealthCountdownController();
  StreamSubscription<int>? _safetyCheckSubscription;

  bool _isDispatching = false;
  bool _freezeUi = false;
  int _countdownRemaining = 10;
  bool _canCancel = true;

  static const Map<String, EmergencyLevel> _pinEscalationMap = <String, EmergencyLevel>{
    '1111=': EmergencyLevel.level1,
    '2222=': EmergencyLevel.level2,
    '9090=': EmergencyLevel.level3,
  };

  @override
  void initState() {
    super.initState();
    _safetyCheckSubscription = context.read<EmergencyEngine>().safetyCheckRequests.listen(
          _showSafetyConfirmation,
        );
  }

  @override
  void dispose() {
    _safetyCheckSubscription?.cancel();
    _countdownController.dispose();
    super.dispose();
  }

  void _onPressed(String value) {
    if (_freezeUi) {
      return;
    }

    setState(() {
      _pushSecret(value);

      if (value == 'C') {
        _display = '0';
        _left = 0;
        _operator = '';
        return;
      }

      if (<String>{'+', '-', 'x', '/'}.contains(value)) {
        _left = double.tryParse(_display) ?? 0;
        _operator = value;
        _display = '0';
        return;
      }

      if (value == '=') {
        final right = double.tryParse(_display) ?? 0;
        switch (_operator) {
          case '+':
            _display = (_left + right).toStringAsFixed(0);
            break;
          case '-':
            _display = (_left - right).toStringAsFixed(0);
            break;
          case 'x':
            _display = (_left * right).toStringAsFixed(0);
            break;
          case '/':
            _display = right == 0 ? '0' : (_left / right).toStringAsFixed(2);
            break;
          default:
            break;
        }
        _operator = '';
        return;
      }

      _display = _display == '0' ? value : '$_display$value';
    });
  }

  void _pushSecret(String value) {
    _secretBuffer.add(value);
    if (_secretBuffer.length > 6) {
      _secretBuffer.removeAt(0);
    }

    for (final entry in _pinEscalationMap.entries) {
      final pin = entry.key;
      if (_secretBuffer.length < pin.length) {
        continue;
      }

      final current = _secretBuffer.sublist(_secretBuffer.length - pin.length).join();
      if (current == pin) {
        _secretBuffer.clear();
        _triggerStealth(entry.value);
        break;
      }
    }
  }

  Future<void> _triggerStealth(EmergencyLevel level) async {
    if (_isDispatching) {
      return;
    }

    _isDispatching = true;
    final engine = context.read<EmergencyEngine>();
    final shouldProceed = await _startDelayedDispatch();
    if (!shouldProceed) {
      _isDispatching = false;
      return;
    }

    await engine.activateStealthLevel(
          level: level,
          delayedTriggerUsed: true,
          triggerSource: 'stealth_pin_l${level.stage}',
        );

    await _showFakeCrashCover();
    _isDispatching = false;
  }

  Future<bool> _startDelayedDispatch() async {
    setState(() {
      _countdownRemaining = 10;
      _canCancel = true;
    });

    if (!mounted) {
      return false;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    BuildContext? dialogContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return AlertDialog(
          title: const Text('Calculating...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Please wait ${_countdownRemaining}s'),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (10 - _countdownRemaining) / 10),
            ],
          ),
          actions: [
            if (_canCancel)
              TextButton(
                onPressed: () {
                  _countdownController.cancel();
                  if (dialogContext != null) {
                    Navigator.of(dialogContext!).pop();
                  }
                },
                child: const Text('Cancel'),
              ),
          ],
        );
      },
    );

    final shouldProceed = await _countdownController.start(
      totalSeconds: 10,
      cancelWindowSeconds: 5,
      onTick: (remaining, canCancel) {
        if (!mounted) {
          return;
        }

        setState(() {
          _countdownRemaining = remaining;
          _canCancel = canCancel;
        });

        if (remaining == 0 && dialogContext != null) {
          Navigator.of(dialogContext!).pop();
        }
      },
    );

    if (dialogContext != null && rootNavigator.canPop()) {
      rootNavigator.maybePop();
    }

    return shouldProceed;
  }

  Future<void> _showFakeCrashCover() async {
    if (!mounted) {
      return;
    }

    setState(() => _freezeUi = true);

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    BuildContext? dialogContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const AlertDialog(
          title: Text('Calculator Not Responding'),
          content: Text('Wait or close the app?'),
        );
      },
    );

    await Future<void>.delayed(const Duration(seconds: 6));

    if (mounted && dialogContext != null && rootNavigator.canPop()) {
      rootNavigator.maybePop();
    }

    if (mounted) {
      setState(() => _freezeUi = false);
    }
  }

  Future<void> _showSafetyConfirmation(int requestId) async {
    if (!mounted) {
      return;
    }

    final engine = context.read<EmergencyEngine>();
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    var responded = false;
    BuildContext? dialogContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return AlertDialog(
          title: const Text('Session Check'),
          content: const Text('Continue normal calculator activity?'),
          actions: [
            TextButton(
              onPressed: () {
                responded = true;
                engine.respondSafetyCheck(requestId, true);
                rootNavigator.maybePop();
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    await Future<void>.delayed(const Duration(seconds: 15));
    if (!mounted || responded) {
      return;
    }

    engine.respondSafetyCheck(requestId, false);
    if (dialogContext != null && rootNavigator.canPop()) {
      rootNavigator.maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    const keys = <String>[
      '7', '8', '9', '/',
      '4', '5', '6', 'x',
      '1', '2', '3', '-',
      'C', '0', '=', '+',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Calculator')),
      body: AbsorbPointer(
        absorbing: _freezeUi,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _display,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  itemCount: keys.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (_, index) {
                    final key = keys[index];
                    return ElevatedButton(
                      onPressed: () => _onPressed(key),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: <String>{'+', '-', 'x', '/', '='}.contains(key)
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.white,
                      ),
                      child: Text(key, style: const TextStyle(fontSize: 22)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StealthCountdownController {
  Timer? _timer;
  Completer<bool>? _completer;
  bool _canceled = false;

  Future<bool> start({
    required int totalSeconds,
    required int cancelWindowSeconds,
    required void Function(int remaining, bool canCancel) onTick,
  }) {
    _timer?.cancel();
    _completer = Completer<bool>();
    _canceled = false;

    var elapsed = 0;
    onTick(totalSeconds, true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsed += 1;
      final remaining = totalSeconds - elapsed;
      final canCancel = elapsed <= cancelWindowSeconds;
      onTick(remaining.clamp(0, totalSeconds), canCancel);

      if (_canceled) {
        timer.cancel();
        _complete(false);
        return;
      }

      if (remaining <= 0) {
        timer.cancel();
        _complete(true);
      }
    });

    return _completer!.future;
  }

  void cancel() {
    _canceled = true;
  }

  void _complete(bool value) {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(value);
    }
  }

  void dispose() {
    _timer?.cancel();
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(false);
    }
  }
}
