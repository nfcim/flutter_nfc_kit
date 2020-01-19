import 'dart:async';

import 'package:flutter/services.dart';

enum NFCAvailability {
  not_supported,
  disabled,
  available,
}

enum NFCTagType { iso7816, iso15693, mifare_classic, mifare_ultralight, mifare_desfire, mifare_plus, felica, vicinity_card, unknown }

class NFCTag {
  final NFCTagType type;
  final String id;
  final String standard;
  final String atqa;
  final String sak;
  final String historicalBytes;
  final String protocolInfo;
  final String applicationData;
  final String hiLayerResponse;
  final String manufacturer;
  final String systemCode;
  final String dsfId;

  NFCTag(this.type, this.id, this.standard, this.atqa, this.sak, this.historicalBytes, this.protocolInfo,
      this.applicationData, this.hiLayerResponse, this.manufacturer, this.systemCode, this.dsfId);

  factory NFCTag.fromMap(Map data) {
    final typeStr = data.containsKey('type') ? data['type'] : 'unknown';
    final type = NFCTagType.values.firstWhere((it) => it.toString() == "NFCTagType.$typeStr");
    return NFCTag(
      type,
      data.containsKey('id') ? data['id'] : '',
      data.containsKey('standard') ? data['standard'] : '',
      data.containsKey('atqa') ? data['atqa'] : '',
      data.containsKey('sak') ? data['sak'] : '',
      data.containsKey('historicalBytes') ? data['historicalBytes'] : '',
      data.containsKey('protocolInfo') ? data['protocolInfo'] : '',
      data.containsKey('applicationData') ? data['applicationData'] : '',
      data.containsKey('hiLayerResponse') ? data['hiLayerResponse'] : '',
      data.containsKey('manufacturer') ? data['manufacturer'] : '',
      data.containsKey('systemCode') ? data['systemCode'] : '',
      data.containsKey('dsfId') ? data['dsfId'] : ''
    );
  }
}

class FlutterNfcKit {
  static const MethodChannel _channel = const MethodChannel('flutter_nfc_kit');

  static Future<NFCAvailability> get nfcAvailability async {
    final String availability = await _channel.invokeMethod('getNFCAvailability');
    return NFCAvailability.values.firstWhere((it) => it.toString() == "NFCAvailability.$availability");
  }

  static Future<NFCTag> poll() async {
    final Map data = await _channel.invokeMethod('poll');
    return NFCTag.fromMap(data);
  }

  static Future<String> transceive(String capdu) async {
    return await _channel.invokeMethod('transceive', capdu);
  }

  static Future<void> finish() async {
    return await _channel.invokeMethod('finish');
  }
}
