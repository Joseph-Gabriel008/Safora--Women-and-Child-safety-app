import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

class GuideTtsService {
  GuideTtsService() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      return;
    }

    try {
      await _configure();
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> _configure() async {
    if (_configured) {
      return;
    }

    try {
      await _tts.setSpeechRate(0.46);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.setSharedInstance(true);

      if (Platform.isAndroid) {
        await _tts.awaitSpeakCompletion(true);
      }

      _configured = true;
    } catch (_) {
      _configured = false;
    }
  }
}
