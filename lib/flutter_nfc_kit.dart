import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:json_annotation/json_annotation.dart';

part 'flutter_nfc_kit.g.dart';

enum NFCAvailability {
  not_supported,
  disabled,
  available,
}

enum NFCTagType { iso7816, iso15693, mifare_classic, mifare_ultralight, mifare_desfire, mifare_plus, felica, unknown }

@JsonSerializable()
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

  factory NFCTag.fromJson(Map<String, dynamic> json) => _$NFCTagFromJson(json);
  Map<String, dynamic> toJson() => _$NFCTagToJson(this);

}

class FlutterNfcKit {
  static const MethodChannel _channel = const MethodChannel('flutter_nfc_kit');

  static Future<NFCAvailability> get nfcAvailability async {
    final String availability = await _channel.invokeMethod('getNFCAvailability');
    return NFCAvailability.values.firstWhere((it) => it.toString() == "NFCAvailability.$availability");
  }

  static Future<NFCTag> poll() async {
    final String data = await _channel.invokeMethod('poll');
    return NFCTag.fromJson(jsonDecode(data));
  }

  static Future<String> transceive(String capdu) async {
    return await _channel.invokeMethod('transceive', capdu);
  }

  static Future<void> finish() async {
    return await _channel.invokeMethod('finish');
  }
}
