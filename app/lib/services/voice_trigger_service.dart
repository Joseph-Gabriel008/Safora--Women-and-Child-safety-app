// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/constants/app_constants.dart';
import 'emergency_engine.dart';

class VoiceTriggerService {
  VoiceTriggerService(this._engine);

  final EmergencyEngine _engine;
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _triggerInFlight = false;

  Future<bool> startListening() async {
    if (!_isInitialized) {
      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: (_) {
          _engine.setVoiceListening(false);
        },
      );
    }

    if (!_isInitialized) {
      _engine.setVoiceListening(false);
      return false;
    }

    if (_speech.isListening) {
      _engine.setVoiceListening(true);
      return true;
    }

    try {
      _engine.setVoiceListening(true);
      await _speech.listen(
        listenMode: ListenMode.dictation,
        onResult: _onResult,
        cancelOnError: false,
        partialResults: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
      );
      return true;
    } catch (_) {
      _engine.setVoiceListening(false);
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    _engine.setVoiceListening(false);
  }

  Future<void> _onResult(SpeechRecognitionResult result) async {
    final words = result.recognizedWords.toLowerCase().trim();
    if (kDebugMode) {
      debugPrint('Voice heard: $words');
    }

    if (_triggerInFlight) {
      return;
    }

    if (_matchesHelpKeyword(words)) {
      _triggerInFlight = true;
      try {
        await stopListening();
        await _engine.triggerEmergency(trigger: EmergencyTrigger.voice);
      } finally {
        _triggerInFlight = false;
      }
    }
  }

  Future<void> _onStatus(String status) async {
    final normalized = status.toLowerCase();
    final isListening = normalized.contains('listening');
    _engine.setVoiceListening(isListening);
  }

  bool _matchesHelpKeyword(String input) {
    if (input.isEmpty) {
      return false;
    }

    final normalized = input
        .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();

    if (normalized.contains(AppConstants.helpKeyword)) {
      return true;
    }

    final tokens = normalized.split(' ');
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token != 'help') {
        continue;
      }

      final next = i + 1 < tokens.length ? tokens[i + 1] : '';
      if (next == 'me' || next == 'mi' || next == 'mee') {
        return true;
      }
    }

    return false;
  }
}
