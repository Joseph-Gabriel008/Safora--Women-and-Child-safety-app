import 'package:flutter/services.dart';

class ForegroundExecutionService {
  static const MethodChannel _channel = MethodChannel('safora/system');

  Future<void> startStealthService() async {
    try {
      await _channel.invokeMethod<void>('startForegroundStealth');
    } catch (_) {}
  }

  Future<void> stopStealthService() async {
    try {
      await _channel.invokeMethod<void>('stopForegroundStealth');
    } catch (_) {}
  }
}
