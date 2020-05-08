import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
/// All fields except [type] and [standard] are in the format of hex string.
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

  /// NDEF availability
  final bool ndefAvailable;

  /// NDEF tag type (Android only)
  final String ndefType;

  /// Maximum NDEF message size in bytes (only meaningful when ndef available)
  final int ndefCapacity;

  /// NDEF writebility
  final bool ndefWriteable;

  /// Indicates whether this NDEF tag can be made read-only (only works on Android, always false on iOS)
  final bool ndefCanMakeReadOnly;

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
      this.dsfId,
      this.ndefAvailable,
      this.ndefType,
      this.ndefCapacity,
      this.ndefWriteable,
      this.ndefCanMakeReadOnly);

  factory NFCTag.fromJson(Map<String, dynamic> json) => _$NFCTagFromJson(json);
  Map<String, dynamic> toJson() => _$NFCTagToJson(this);
}

/// Type of NFC tag.
enum NDEFTypeNameFormat {
  absoluteURI,
  empty,
  media,
  nfcExternal,
  nfcWellKnown,
  unchanged,
  unknown
}

/// Metadata of a NDEF record.
///
/// All fields are in the format of hex string.
@JsonSerializable()
class NDEFRecord {
  /// identifier of the payload
  final String identifier;

  /// payload
  final String payload;

  /// type of the payload
  final String type;

  /// type name format
  final NDEFTypeNameFormat typeNameFormat;

  NDEFRecord(this.identifier, this.payload, this.type, this.typeNameFormat);

  factory NDEFRecord.fromJson(Map<String, dynamic> json) =>
      _$NDEFRecordFromJson(json);
  Map<String, dynamic> toJson() => _$NDEFRecordToJson(this);
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
  ///
  /// The [timeout] parameter only works on Android (default to be 20 seconds). On iOS it is ignored and decided by the OS.
  ///
  /// On iOS, set [iosAlertMessage] to display a message when the session starts (to guide users to scan a tag),
  /// and set [iosMultipleTagMessage] to display a message when multiple tags are found.
  static Future<NFCTag> poll({
    Duration timeout,
    String iosAlertMessage = "Hold your iPhone near the card",
    String iosMultipleTagMessage =
        "More than one tags are detected, please leave only one tag and try again.",
  }) async {
    final String data = await _channel.invokeMethod('poll', {
      'timeout': timeout?.inMilliseconds ?? 20 * 1000,
      'iosAlertMessage': iosAlertMessage,
      'iosMultipleTagMessage': iosMultipleTagMessage
    });
    return NFCTag.fromJson(jsonDecode(data));
  }

  /// Transceive data with the card / tag in the format of APDU (iso7816) or raw commands (other technologies).
  /// The [capdu] can be either of type Uint8List or hex string.
  /// Return value will be in the same type of [capdu].
  ///
  /// There must be a valid session when invoking.
  ///
  /// On Android, [timeout] parameter will set transceive execution timeout that is persistent during a active session.
  /// Also, Ndef TagTechnology will be closed if active.
  /// On iOS, this parameter is ignored and is decided by the OS again.
  /// Timeout is reset to default value when [finish] is called, and could be changed by multiple calls to [transceive].
  static Future<T> transceive<T>(T capdu, {Duration timeout}) async {
    assert(capdu is String || capdu is Uint8List);
    return await _channel.invokeMethod(
        'transceive', {'data': capdu, 'timeout': timeout?.inMilliseconds});
  }

  /// Read NDEF records.
  ///
  /// There must be a valid session when invoking.
  /// [cached] only works on Android, allowing cached read (may obtain stale data)
  /// On Android, this would cause any other open TagTechnology to be closed
  static Future<List<NDEFRecord>> readNDEF({bool cached}) async {
    final String data = await _channel
        .invokeMethod('readNDEF', {'cached': cached ?? false});
    return (jsonDecode(data) as List<dynamic>)
        .map((json) => NDEFRecord.fromJson(json)).toList();
  }

  /// Finish current session.
  ///
  /// You must invoke it before start a new session.
  ///
  /// On iOS, use [iosAlertMessage] to indicate success or [iosErrorMessage] to indicate failure.
  /// If both parameters are set, [iosErrorMessage] will be used.
  static Future<void> finish(
      {String iosAlertMessage, String iosErrorMessage}) async {
    return await _channel.invokeMethod('finish', {
      'iosErrorMessage': iosErrorMessage,
      'iosAlertMessage': iosAlertMessage,
    });
  }

  /// iOS only, change currently displayed NFC reader session alert message with [message].
  /// There must be a valid session when invoking.
  /// On Android, call to this function does nothing.
  static Future<void> setIosAlertMessage(String message) async {
    if (Platform.isIOS) {
      return await _channel.invokeMethod('setIosAlertMessage', message);
    }
  }
}
