import 'dart:async';
// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/webusb.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A web implementation of the FlutterNfcKit plugin.
class FlutterNfcKitWeb {
  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'flutter_nfc_kit',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = FlutterNfcKitWeb();
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getNFCAvailability':
        return 'available';

      case 'poll':
        return await WebUSB.poll();

      case 'transceive':
        return await WebUSB.transceive(call.arguments["data"]);

      case 'finish':
        return getPlatformVersion();

      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'flutter_nfc_kit for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  /// Returns a [String] containing the version of the platform.
  Future<String> getPlatformVersion() {
    final version = html.window.navigator.userAgent;
    return Future.value(version);
  }
}
