import 'dart:io';

import 'package:flutter/services.dart';

class SmsDispatcherService {
  static const MethodChannel _channel = MethodChannel('safora/sms');

  Future<bool> send({
    required String phone,
    required String message,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final sent = await _channel.invokeMethod<bool>('sendSms', <String, dynamic>{
        'phone': phone,
        'message': message,
      });
      return sent ?? false;
    } on PlatformException {
      return false;
    }
  }
}
