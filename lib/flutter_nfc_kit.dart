import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:json_annotation/json_annotation.dart';

part 'flutter_nfc_kit.g.dart';

/// Availability of the NFC reader.
enum NFCAvailability {
  not_supported,
  disabled,
  available,
}

/// Type of NFC tag.
enum NFCTagType {
  iso7816,
  iso15693,
  mifare_classic,
  mifare_ultralight,
  mifare_desfire,
  mifare_plus,
  felica,
  unknown
}

/// Metadata of the polled NFC tag.
///
/// All fields except `type` and `standard` are in the format of hex string.
/// Fields that cannot be read will be empty.
@JsonSerializable()
class NFCTag {
  /// Tag Type
  final NFCTagType type;

  /// The standard that the tag complies with (can be `unknown`)
  final String standard;

  /// Tag ID
  final String id;

  /// ATQA (Type A only, Android only)
  final String atqa;

  /// SAK (Type A only, Android only)
  final String sak;

  /// Historical bytes (ISO 7816 only)
  final String historicalBytes;

  /// Higher layer response (ISO 7816 only, Android only)
  final String hiLayerResponse;

  /// Protocol information (Type B only， Android only)
  final String protocolInfo;

  /// Application data (Type B only)
  final String applicationData;

  /// Manufacturer (Type F & V only)
  final String manufacturer;

  /// System code (Type F only)
  final String systemCode;

  /// DSF ID (Type V only, Android only)
  final String dsfId;

  NFCTag(
      this.type,
      this.id,
      this.standard,
      this.atqa,
      this.sak,
      this.historicalBytes,
      this.protocolInfo,
      this.applicationData,
      this.hiLayerResponse,
      this.manufacturer,
      this.systemCode,
      this.dsfId);

  factory NFCTag.fromJson(Map<String, dynamic> json) => _$NFCTagFromJson(json);
  Map<String, dynamic> toJson() => _$NFCTagToJson(this);
}

/// Main class of NFC Kit
class FlutterNfcKit {
  static const MethodChannel _channel = const MethodChannel('flutter_nfc_kit');

  /// get the availablility of NFC reader on this device
  static Future<NFCAvailability> get nfcAvailability async {
    final String availability =
        await _channel.invokeMethod('getNFCAvailability');
    return NFCAvailability.values
        .firstWhere((it) => it.toString() == "NFCAvailability.$availability");
  }

  /// Try to poll a NFC tag from reader.
  ///
  /// If tag is successfully polled, a session is started.
  /// The default timeout for polling is 20 seconds.
  /// 
  /// On iOS, use [iosAlertMessage] to display NFC reader session alert message.
  static Future<NFCTag> poll({ String iosAlertMessage = "Hold your iPhone near the card" }) async {
    final String data = await _channel.invokeMethod('poll', {
      'iosAlertMessage': iosAlertMessage
    });
    return NFCTag.fromJson(jsonDecode(data));
  }

  /// Transceive data with the card / tag in the format of APDU (iso7816) or raw commands (other technologies).
  ///
  /// Note that iOS only supports APDU.
  /// There must be a valid session when invoking.
  static Future<String> transceive(String capdu) async {
    return await _channel.invokeMethod('transceive', capdu);
  }

  /// Finish current session.
  ///
  /// You must invoke `finish` before start a new session.
  /// 
  /// On iOS, use [iosAlertMessage] to indicate success or [iosErrorMessage] to indicate failure.
  /// If both parameters are set, [iosErrorMessage] will be used.
  static Future<void> finish({ String iosAlertMessage, String iosErrorMessage }) async {
    return await _channel.invokeMethod('finish', {
      'iosErrorMessage': iosErrorMessage,
      'iosAlertMessage': iosAlertMessage,
    });
  }

  /// iOS only, change currently displayed NFC reader session alert message with [message].
  /// There must be a valid session when invoking.
  /// On android, call to this function does nothing.
  static Future<void> setIosAlertMessage(String message) async {
    if(Platform.isIOS) {
      return await _channel.invokeMethod('setIosAlertMessage', message);
    }
  }
}
