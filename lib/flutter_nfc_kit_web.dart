import 'dart:async';
// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;
import 'dart:js_util';
import 'dart:typed_data';
import 'package:convert/convert.dart';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_nfc_kit/webusb_interop.dart';

/// A web implementation of the FlutterNfcKit plugin.
///
/// Note: you should **NEVER use this class directly**, but instead use the [FlutterNfcKit] class in your project.
///
/// You **need to implement our WebUSB protocol** on the device side for this to work.
/// See [WebUSB.md](https://github.com/nfcim/flutter_nfc_kit/blob/master/WebUSB.md) for protocol details.
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
        if (hasProperty(html.window.navigator, 'usb'))
          return 'available';
        else
          return 'not_supported';

      case 'poll':
        int timeout = call.arguments["timeout"];
        bool probe = call.arguments["probeWebUSBMagic"];
        return await WebUSB.poll(timeout, probe);

      case 'transceive':
        var data = call.arguments["data"];
        if (!(data is Uint8List || data is String)) {
          throw PlatformException(
              code: "400",
              message:
                  "Bad argument: data should be String or Uint8List, got $data");
        }
        // always pass hex string to [transceive]
        var encodedData = data;
        if (data is Uint8List) {
          encodedData = hex.encode(data);
        }
        var encodedResp = await WebUSB.transceive(encodedData);
        dynamic resp = encodedResp;
        // return type should be the same as [data]
        if (data is Uint8List) {
          resp = Uint8List.fromList(hex.decode(encodedResp));
        }
        return resp;

      case 'finish':
        bool closeWebUSB = call.arguments["closeWebUSB"];
        return await WebUSB.finish(closeWebUSB);

      default:
        throw PlatformException(
            code: "501",
            details:
                "flutter_nfc_kit for web does not support \"${call.method}\"");
    }
  }
}
