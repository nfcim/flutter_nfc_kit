import 'dart:async';

import 'package:flutter/services.dart';

class FlutterNfcKit {
  static const MethodChannel _channel =
      const MethodChannel('flutter_nfc_kit');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
