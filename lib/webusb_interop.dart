@JS()

/// Library that inter-ops with JavaScript on WebUSB APIs.
///
/// Note: you should **NEVER use this library directly**, but instead use the [FlutterNfcKit] class in your project.
library webusb_interop;

import 'dart:convert';
import 'dart:js_util';
import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/services.dart';
import 'package:js/js.dart';
import 'package:logging/logging.dart';

final log = Logger('FlutterNFCKit:WebUSB');

/// The USB class code used to identify a WebUSB device that supports this protocol.
const int USB_CLASS_CODE_VENDOR_SPECIFIC = 0xFF;

@JS('navigator.usb')
class _USB {
  external static dynamic requestDevice(_USBDeviceRequestOptions options);
  // ignore: unused_field
  external static Function ondisconnect;
}

@JS()
@anonymous
class _USBDeviceRequestOptions {
  external factory _USBDeviceRequestOptions({List<_USBDeviceFilter> filters});
}

@JS()
@anonymous
class _USBDeviceFilter {
  external factory _USBDeviceFilter({int classCode});
}

@JS()
@anonymous
class _USBControlTransferParameters {
  external factory _USBControlTransferParameters(
      {String requestType,
      String recipient,
      int request,
      int value,
      int index});
}

/// Wraps around WebUSB APIs from browsers to provide low-level interfaces such as [poll] for [FlutterNfcKitWeb].
///
/// Note: you should **NEVER use this class directly**, but instead use the [FlutterNfcKit] class in your project.
class WebUSB {
  static dynamic _device;
  static String customProbeData = "";

  static bool _deviceAvailable() {
    return _device != null && getProperty(_device, 'opened');
  }

  static void _onDisconnect(event) {
    _device = null;
    log.info('device is disconnected from WebUSB API');
  }

  static const USB_PROBE_MAGIC = '_NFC_IM_';

  /// Try to poll a WebUSB device according to our protocol.
  static Future<String> poll(int timeout, bool probeMagic) async {
    // request WebUSB device with custom classcode
    if (!_deviceAvailable()) {
      var devicePromise = _USB.requestDevice(new _USBDeviceRequestOptions(
          filters: [
            new _USBDeviceFilter(classCode: USB_CLASS_CODE_VENDOR_SPECIFIC)
          ]));
      dynamic device = await promiseToFuture(devicePromise);
      try {
        await promiseToFuture(callMethod(device, 'open', List.empty()))
            .then((_) =>
                promiseToFuture(callMethod(device, 'claimInterface', [1])))
            .timeout(Duration(milliseconds: timeout));
        _device = device;
        _USB.ondisconnect = allowInterop(_onDisconnect);
        log.info("WebUSB device opened", _device);
      } on TimeoutException catch (_) {
        log.severe("Polling tag timeout");
        throw PlatformException(code: "408", message: "Polling tag timeout");
      } on Exception catch (e) {
        log.severe("Poll error", e);
        throw PlatformException(
            code: "500", message: "WebUSB API error", details: e);
      }

      if (probeMagic) {
        try {
          // PROBE request
          var promise = callMethod(_device, 'controlTransferIn', [
            new _USBControlTransferParameters(
                requestType: 'vendor',
                recipient: 'interface',
                request: 0xff,
                value: 0,
                index: 1),
            1
          ]);
          var resp = await promiseToFuture(promise);
          if (getProperty(resp, 'status') == 'stalled') {
            throw PlatformException(
                code: "500", message: "Device error: transfer stalled");
          }
          var result =
              (getProperty(resp, 'data').buffer as ByteBuffer).asUint8List();
          if (result.length < USB_PROBE_MAGIC.length ||
              result.sublist(0, USB_PROBE_MAGIC.length) !=
                  Uint8List.fromList(USB_PROBE_MAGIC.codeUnits)) {
            throw PlatformException(
                code: "500",
                message:
                    "Device error: invalid probe response: ${hex.encode(result)}, should begin with $USB_PROBE_MAGIC");
          }
          customProbeData = hex.encode(result.sublist(USB_PROBE_MAGIC.length));
        } on Exception catch (e) {
          log.severe("Probe error", e);
          throw PlatformException(
              code: "500", message: "WebUSB API error", details: e);
        }
      } else {
        customProbeData = "";
      }
    }
    // get VID & PID
    int vendorId = getProperty(_device, 'vendorId');
    int productId = getProperty(_device, 'productId');
    String id =
        '${vendorId.toRadixString(16).padLeft(4, '0')}:${productId.toRadixString(16).padLeft(4, '0')}';
    return json.encode({
      'type': 'webusb',
      'id': id,
      'standard': 'nfc-im-webusb-protocol',
      'customProbeData': customProbeData
    });
  }

  static Future<Uint8List> _doTransceive(Uint8List capdu) async {
    // send a command (CMD)
    var promise = callMethod(_device, 'controlTransferOut', [
      new _USBControlTransferParameters(
          requestType: 'vendor',
          recipient: 'interface',
          request: 0,
          value: 0,
          index: 1),
      capdu
    ]);
    await promiseToFuture(promise);
    // wait for execution to finish (STAT)
    while (true) {
      promise = callMethod(_device, 'controlTransferIn', [
        new _USBControlTransferParameters(
            requestType: 'vendor',
            recipient: 'interface',
            request: 2,
            value: 0,
            index: 1),
        1
      ]);
      var resp = await promiseToFuture(promise);
      if (getProperty(resp, 'status') == 'stalled') {
        throw PlatformException(
            code: "500", message: "Device error: transfer stalled");
      }
      var code = getProperty(resp, 'data').buffer.asUint8List()[0];
      if (code == 0) {
        break;
      } else if (code == 1) {
        await Future.delayed(const Duration(microseconds: 100));
      } else {
        throw PlatformException(
            code: "500", message: "Device error: unexpected RESP code $code");
      }
    }
    // get the response (RESP)
    promise = callMethod(_device, 'controlTransferIn', [
      new _USBControlTransferParameters(
          requestType: 'vendor',
          recipient: 'interface',
          request: 1,
          value: 0,
          index: 1),
      1500
    ]);
    var resp = await promiseToFuture(promise);
    var deviceStatus = getProperty(resp, 'status');
    if (deviceStatus != 'ok') {
      throw PlatformException(
          code: "500",
          message:
              "Device error: status should be \"ok\", got \"$deviceStatus\"");
    }
    return getProperty(resp, 'data').buffer.asUint8List();
  }

  /// Transceive data with polled WebUSB device according to our protocol.
  static Future<String> transceive(String capdu) async {
    log.config('CAPDU: $capdu');
    if (!_deviceAvailable()) {
      throw PlatformException(
          code: "406", message: "No tag polled or device already disconnected");
    }
    try {
      var rawCAPDU = Uint8List.fromList(hex.decode(capdu));
      var rawRAPDU = await _doTransceive(rawCAPDU);
      String rapdu = hex.encode(rawRAPDU);
      log.config('RAPDU: $rapdu');
      return rapdu;
    } on TimeoutException catch (_) {
      log.severe("Transceive timeout");
      throw PlatformException(code: "408", message: "Transceive timeout");
    } on PlatformException catch (e) {
      log.severe("Transceive error", e);
      throw e;
    } on Exception catch (e) {
      log.severe("Transceive error", e);
      throw PlatformException(
          code: "500", message: "WebUSB API error", details: e);
    }
  }

  /// Finish this session, also end WebUSB session if explicitly asked by user.
  static Future<void> finish(bool closeWebUSB) async {
    if (_deviceAvailable()) {
      if (closeWebUSB) {
        try {
          await promiseToFuture(callMethod(_device, "close", List.empty()));
        } on Exception catch (e) {
          log.severe("Finish error: ", e);
          throw PlatformException(
              code: "500", message: "WebUSB API error", details: e);
        }
        _device = null;
      }
    }
  }
}
