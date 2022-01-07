@JS()
library usb;

import 'dart:convert';
import 'dart:js_util';

import 'package:convert/convert.dart';
import 'package:js/js.dart';
import 'package:logging/logging.dart';

final log = Logger('FlutterNFCKit:WebUSB');

@JS('navigator.usb')
class _USB {
  external static dynamic requestDevice(_USBDeviceRequestOptions options);

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
  external factory _USBControlTransferParameters({String requestType, String recipient, int request, int value, int index});
}

class WebUSB {
  static dynamic device;

  static Future<String> poll() async {
    if (device == null || getProperty(device, 'opened')) {
      var devicePromise = _USB.requestDevice(new _USBDeviceRequestOptions(filters: [new _USBDeviceFilter(classCode: 0xFF)]));
      device = await promiseToFuture(devicePromise);
      await promiseToFuture(callMethod(device, 'open', List.empty()));
      await promiseToFuture(callMethod(device, 'claimInterface', [1]));
      _USB.ondisconnect = allowInterop(onDisconnect);
    }
    int vendorId = getProperty(device, 'vendorId');
    int productId = getProperty(device, 'productId');
    String id = '${vendorId.toRadixString(16).padLeft(4, '0')}:${productId.toRadixString(16).padLeft(4, '0')}';
    return json.encode({'type': 'webusb', 'id': id, 'standard': 'unknown'});
  }

  static Future<String> transceive(String capdu) async {
    log.config('capdu: $capdu');
    var rapdu = '';
    do {
      if (rapdu.length >= 4) {
        var remain = rapdu.substring(rapdu.length - 2);
        if (remain != '') {
          capdu = '00C00000$remain';
          rapdu = rapdu.substring(rapdu.length - 4);
        }
      }
      rapdu += await _transceive(capdu);
    } while (rapdu.substring(rapdu.length - 4, rapdu.length - 2) == '61');
    log.config('rapdu: $rapdu');
    return rapdu;
  }

  static void onDisconnect(event) {
    device = null;
    log.info('device is disconnected');
  }

  static Future<String> _transceive(String capdu) async {
    // send a command
    var promise = callMethod(device, 'controlTransferOut', [
      new _USBControlTransferParameters(requestType: 'vendor', recipient: 'interface', request: 0, value: 0, index: 1),
      hex.decode(capdu)
    ]);
    await promiseToFuture(promise);
    // wait for execution
    while (true) {
      promise = callMethod(device, 'controlTransferIn',
          [new _USBControlTransferParameters(requestType: 'vendor', recipient: 'interface', request: 2, value: 0, index: 1), 1]);
      var resp = await promiseToFuture(promise);
      if (getProperty(resp, 'status') == 'stalled') {
        throw Exception('device error');
      }
      var code = getProperty(resp, 'data').buffer.asUint8List()[0];
      if (code == 0) {
        break;
      } else if (code == 1) {
        await await Future.delayed(const Duration(microseconds: 100));
      } else {
        throw Exception('device error');
      }
    }
    // get the response
    promise = callMethod(device, 'controlTransferIn',
        [new _USBControlTransferParameters(requestType: 'vendor', recipient: 'interface', request: 1, value: 0, index: 1), 1500]);
    var resp = await promiseToFuture(promise);
    if (getProperty(resp, 'status') != 'ok') {
      throw Exception('device error');
    }
    return hex.encode(getProperty(resp, 'data').buffer.asUint8List());
  }
}
