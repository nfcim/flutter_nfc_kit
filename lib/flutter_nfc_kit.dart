import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:ndef/ndef.dart' show TypeNameFormat; // for generated file
import 'package:ndef/utilities.dart';
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
  iso18092,
  mifare_classic,
  mifare_ultralight,
  mifare_desfire,
  mifare_plus,
  webusb,
  unknown,
}

/// Metadata of a MIFARE-compatible tag
@JsonSerializable()
class MifareInfo {
  /// MIFARE type
  final String type;

  /// Size in bytes
  final int size;

  /// Size of a block (Classic) / page (Ultralight) in bytes
  final int blockSize;

  /// Number of blocks (Classic) / pages (Ultralight), -1 if type is unknown
  final int blockCount;

  /// Number of sectors (Classic only)
  final int? sectorCount;

  MifareInfo(
      this.type, this.size, this.blockSize, this.blockCount, this.sectorCount);

  factory MifareInfo.fromJson(Map<String, dynamic> json) =>
      _$MifareInfoFromJson(json);
  Map<String, dynamic> toJson() => _$MifareInfoToJson(this);
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

  /// Tag ID (can be `unknown`)
  final String id;

  /// ATQA (Type A only, Android only)
  final String? atqa;

  /// SAK (Type A only, Android only)
  final String? sak;

  /// Historical bytes (ISO 14443-4A only)
  final String? historicalBytes;

  /// Higher layer response (ISO 14443-4B only, Android only)
  final String? hiLayerResponse;

  /// Protocol information (Type B only， Android only)
  final String? protocolInfo;

  /// Application data (Type B only)
  final String? applicationData;

  /// Manufacturer (ISO 18092 only)
  final String? manufacturer;

  /// System code (ISO 18092 only)
  final String? systemCode;

  /// DSF ID (ISO 15693 only, Android only)
  final String? dsfId;

  /// NDEF availability
  final bool? ndefAvailable;

  /// NDEF tag type (Android only)
  final String? ndefType;

  /// Maximum NDEF message size in bytes (only meaningful when ndef available)
  final int? ndefCapacity;

  /// NDEF writebility
  final bool? ndefWritable;

  /// Indicates whether this NDEF tag can be made read-only (only works on Android, always false on iOS)
  final bool? ndefCanMakeReadOnly;

  /// Custom probe data returned by WebUSB device (see [FlutterNfcKitWeb] for detail, only on Web)
  final String? webUSBCustomProbeData;

  /// Mifare-related information (if available)
  final MifareInfo? mifareInfo;

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
      this.ndefWritable,
      this.ndefCanMakeReadOnly,
      this.webUSBCustomProbeData,
      this.mifareInfo);

  factory NFCTag.fromJson(Map<String, dynamic> json) => _$NFCTagFromJson(json);
  Map<String, dynamic> toJson() => _$NFCTagToJson(this);
}

/// Raw data of a NDEF record.
///
/// All [String] fields are in hex format.
@JsonSerializable()
class NDEFRawRecord {
  /// identifier of the payload (empty if not existed)
  final String identifier;

  /// payload
  final String payload;

  /// type of the payload
  final String type;

  /// type name format (see [ndef](https://pub.dev/packages/ndef) package for detail)
  final TypeNameFormat typeNameFormat;

  NDEFRawRecord(this.identifier, this.payload, this.type, this.typeNameFormat);

  factory NDEFRawRecord.fromJson(Map<String, dynamic> json) =>
      _$NDEFRawRecordFromJson(json);
  Map<String, dynamic> toJson() => _$NDEFRawRecordToJson(this);
}

/// Extension for conversion between [NDEFRawRecord] and [ndef.NDEFRecord]
extension NDEFRecordConvert on ndef.NDEFRecord {
  /// Convert an [ndef.NDEFRecord] to encoded [NDEFRawRecord]
  NDEFRawRecord toRaw() {
    return NDEFRawRecord(id?.toHexString() ?? '', payload?.toHexString() ?? '',
        type?.toHexString() ?? '', tnf);
  }

  /// Convert an [NDEFRawRecord] to decoded [ndef.NDEFRecord].
  /// Use `NDEFRecordConvert.fromRaw` to invoke.
  static ndef.NDEFRecord fromRaw(NDEFRawRecord raw) {
    return ndef.decodePartialNdefMessage(
        raw.typeNameFormat, raw.type.toBytes(), raw.payload.toBytes(),
        id: raw.identifier == "" ? null : raw.identifier.toBytes());
  }
}

/// Request flag for ISO 15693 Tags
class Iso15693RequestFlags {
  /// bit 1
  bool dualSubCarriers;

  /// bit 2
  bool highDataRate;

  /// bit 3
  bool inventory;

  /// bit 4
  bool protocolExtension;

  /// bit 5
  bool select;

  /// bit 6
  bool address;

  /// bit 7
  bool option;

  /// bit 8
  bool commandSpecificBit8;

  /// encode bits to one byte as specified in ISO15693-3
  int encode() {
    var result = 0;
    if (dualSubCarriers) {
      result |= 0x01;
    }
    if (highDataRate) {
      result |= 0x02;
    }
    if (inventory) {
      result |= 0x04;
    }
    if (protocolExtension) {
      result |= 0x08;
    }
    if (select) {
      result |= 0x10;
    }
    if (address) {
      result |= 0x20;
    }
    if (option) {
      result |= 0x40;
    }
    if (commandSpecificBit8) {
      result |= 0x80;
    }
    return result;
  }

  Iso15693RequestFlags(
      {this.dualSubCarriers = false,
      this.highDataRate = false,
      this.inventory = false,
      this.protocolExtension = false,
      this.select = false,
      this.address = false,
      this.option = false,
      this.commandSpecificBit8 = false});

  /// decode bits from one byte as specified in ISO15693-3
  factory Iso15693RequestFlags.fromRaw(int r) {
    assert(r >= 0 && r <= 0xFF, "raw flags must be in range [0, 255]");
    var f = Iso15693RequestFlags(
        dualSubCarriers: (r & 0x01) != 0,
        highDataRate: (r & 0x02) != 0,
        inventory: (r & 0x04) != 0,
        protocolExtension: (r & 0x08) != 0,
        select: (r & 0x10) != 0,
        address: (r & 0x20) != 0,
        option: (r & 0x40) != 0,
        commandSpecificBit8: (r & 0x80) != 0);
    return f;
  }
}

/// Main class of NFC Kit
class FlutterNfcKit {
  /// Default timeout for [transceive] (in milliseconds)
  static const int TRANSCEIVE_TIMEOUT = 5 * 1000;

  /// Default timeout for [poll] (in milliseconds)
  static const int POLL_TIMEOUT = 20 * 1000;

  static const MethodChannel _channel = MethodChannel('flutter_nfc_kit');

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
  /// The [timeout] parameter only works on Android & Web (default to be 20 seconds). On iOS it is ignored and decided by the OS.
  ///
  /// On iOS, set [iosAlertMessage] to display a message when the session starts (to guide users to scan a tag),
  /// and set [iosMultipleTagMessage] to display a message when multiple tags are found.
  ///
  /// On Android, set [androidPlatformSound] to control whether to play sound when a tag is polled,
  /// and set [androidCheckNDEF] to control whether check NDEF records on the tag.
  ///
  /// The four boolean flags [readIso14443A], [readIso14443B], [readIso18092], [readIso15693] control the NFC technology that would be tried.
  /// On iOS, setting any of [readIso14443A] and [readIso14443B] will enable `iso14443` in `pollingOption`.
  ///
  /// On Web, all parameters are ignored except [timeout] and [probeWebUSBMagic].
  /// If [probeWebUSBMagic] is set, the library will use the `PROBE` request to check whether the device supports our API (see [FlutterNfcKitWeb] for details).
  ///
  /// Note: Sometimes NDEF check [leads to error](https://github.com/nfcim/flutter_nfc_kit/issues/11), and disabling it might help.
  /// If disabled, you will not be able to use any NDEF-related methods in the current session.
  static Future<NFCTag> poll({
    Duration? timeout,
    bool androidPlatformSound = true,
    bool androidCheckNDEF = true,
    String iosAlertMessage = "Hold your iPhone near the card",
    String iosMultipleTagMessage =
        "More than one tags are detected, please leave only one tag and try again.",
    bool readIso14443A = true,
    bool readIso14443B = true,
    bool readIso18092 = false,
    bool readIso15693 = true,
    bool probeWebUSBMagic = false,
  }) async {
    // use a bitmask for compact representation
    int technologies = 0x0;
    // hardcoded bits, corresponding to flags in android.nfc.NfcAdapter
    if (readIso14443A) technologies |= 0x1;
    if (readIso14443B) technologies |= 0x2;
    if (readIso18092) technologies |= 0x4;
    if (readIso15693) technologies |= 0x8;
    // iOS can safely ignore these option bits
    if (!androidCheckNDEF) technologies |= 0x80;
    if (!androidPlatformSound) technologies |= 0x100;
    final String data = await _channel.invokeMethod('poll', {
      'timeout': timeout?.inMilliseconds ?? POLL_TIMEOUT,
      'iosAlertMessage': iosAlertMessage,
      'iosMultipleTagMessage': iosMultipleTagMessage,
      'technologies': technologies,
      'probeWebUSBMagic': probeWebUSBMagic,
    });
    return NFCTag.fromJson(jsonDecode(data));
  }

  /// Works only on iOS
  /// Calls NFCTagReaderSession.restartPolling()
  /// Call this if you have received "Tag connection lost" exception
  /// This will allow to reconnect to tag without closing system popup
  static Future<void> iosRestartPolling() async =>
      await _channel.invokeMethod("restartPolling");

  /// Transceive data with the card / tag in the format of APDU (iso7816) or raw commands (other technologies).
  /// The [capdu] can be either of type Uint8List or hex string.
  /// Return value will be in the same type of [capdu].
  ///
  /// There must be a valid session when invoking.
  ///
  /// On Android, [timeout] parameter will set transceive execution timeout that is persistent during a active session.
  /// Also, Ndef TagTechnology will be closed if active.
  /// On iOS, this parameter is ignored and is decided by the OS.
  /// On Web, [timeout] is currently not
  /// Timeout is reset to default value when [finish] is called, and could be changed by multiple calls to [transceive].
  static Future<T> transceive<T>(T capdu, {Duration? timeout}) async {
    assert(capdu is String || capdu is Uint8List);
    return await _channel.invokeMethod('transceive', {
      'data': capdu,
      'timeout': timeout?.inMilliseconds ?? TRANSCEIVE_TIMEOUT
    });
  }

  /// Read NDEF records (in decoded format, Android & iOS only).
  ///
  /// There must be a valid session when invoking.
  /// [cached] only works on Android, allowing cached read (may obtain stale data).
  /// On Android, this would cause any other open TagTechnology to be closed.
  /// See [ndef](https://pub.dev/packages/ndef) for usage of [ndef.NDEFRecord].
  static Future<List<ndef.NDEFRecord>> readNDEFRecords({bool? cached}) async {
    return (await readNDEFRawRecords(cached: cached))
        .map((r) => NDEFRecordConvert.fromRaw(r))
        .toList();
  }

  /// Read NDEF records (in raw data, Android & iOS only).
  ///
  /// There must be a valid session when invoking.
  /// [cached] only works on Android, allowing cached read (may obtain stale data).
  /// On Android, this would cause any other open TagTechnology to be closed.
  /// Please use [readNDEFRecords] if you want decoded NDEF records
  static Future<List<NDEFRawRecord>> readNDEFRawRecords({bool? cached}) async {
    final String data =
        await _channel.invokeMethod('readNDEF', {'cached': cached ?? false});
    return (jsonDecode(data) as List<dynamic>)
        .map((object) => NDEFRawRecord.fromJson(object))
        .toList();
  }

  /// Write NDEF records (in decoded format, Android & iOS only).
  ///
  /// There must be a valid session when invoking.
  /// [cached] only works on Android, allowing cached read (may obtain stale data).
  /// On Android, this would cause any other open TagTechnology to be closed.
  /// See [ndef](https://pub.dev/packages/ndef) for usage of [ndef.NDEFRecord]
  static Future<void> writeNDEFRecords(List<ndef.NDEFRecord> message) async {
    return await writeNDEFRawRecords(message.map((r) => r.toRaw()).toList());
  }

  /// Write NDEF records (in raw data, Android & iOS only).
  ///
  /// There must be a valid session when invoking.
  /// [message] is a list of NDEFRawRecord.
  static Future<void> writeNDEFRawRecords(List<NDEFRawRecord> message) async {
    var data = jsonEncode(message);
    return await _channel.invokeMethod('writeNDEF', {'data': data});
  }

  /// Finish current session.
  ///
  /// You must invoke it before start a new session.
  ///
  /// On iOS, use [iosAlertMessage] to indicate success or [iosErrorMessage] to indicate failure.
  /// If both parameters are set, [iosErrorMessage] will be used.
  /// On Web, set [closeWebUSB] to `true` to end the session, so that user can choose a different device in next [poll].
  static Future<void> finish(
      {String? iosAlertMessage,
      String? iosErrorMessage,
      bool? closeWebUSB}) async {
    return await _channel.invokeMethod('finish', {
      'iosErrorMessage': iosErrorMessage,
      'iosAlertMessage': iosAlertMessage,
      'closeWebUSB': closeWebUSB ?? false,
    });
  }

  /// iOS only, change currently displayed NFC reader session alert message with [message].
  ///
  /// There must be a valid session when invoking.
  /// On Android, call to this function does nothing.
  static Future<void> setIosAlertMessage(String message) async {
    if (!kIsWeb && Platform.isIOS) {
      return await _channel.invokeMethod('setIosAlertMessage', message);
    }
  }

  /// Make the NDEF tag readonly (i.e. lock the NDEF tag, Android & iOS only).
  ///
  /// **WARNING: IT CANNOT BE UNDONE!**
  static Future<void> makeNdefReadOnly() async {
    return await _channel.invokeMethod('makeNdefReadOnly');
  }

  /// Authenticate against a sector of MIFARE Classic tag (Android only).
  ///
  /// Either one of [keyA] or [keyB] must be provided.
  /// If both are provided, [keyA] will be used.
  /// Returns whether authentication succeeds.
  static Future<bool> authenticateSector<T>(int index,
      {T? keyA, T? keyB}) async {
    assert((keyA is String || keyA is Uint8List) ||
        (keyB is String || keyB is Uint8List));
    return await _channel.invokeMethod(
        'authenticateSector', {'index': index, 'keyA': keyA, 'keyB': keyB});
  }

  /// Read one unit of data (specified below) from:
  /// * MIFARE Classic / Ultralight tag: one 16B block / page (Android only)
  /// * ISO 15693 tag: one 4B block (iOS only)
  ///
  /// There must be a valid session when invoking.
  /// [index] refers to the block / page index.
  /// For MIFARE Classic tags, you must first authenticate against the corresponding sector.
  /// For MIFARE Ultralight tags, four consecutive pages will be read.
  /// Returns data in [Uint8List].
  static Future<Uint8List> readBlock(int index,
      {Iso15693RequestFlags? iso15693Flags,
      bool iso15693ExtendedMode = false}) async {
    var flags = iso15693Flags ?? Iso15693RequestFlags();
    return await _channel.invokeMethod('readBlock', {
      'index': index,
      'iso15693Flags': flags.encode(),
      'iso15693ExtendedMode': iso15693ExtendedMode,
    });
  }

  /// Write one unit of data (specified below) to:
  /// * MIFARE Classic tag: one 16B block (Android only)
  /// * MIFARE Ultralight tag: one 4B page (Android only)
  /// * ISO 15693 tag: one 4B block (iOS only)
  ///
  /// There must be a valid session when invoking.
  /// [index] refers to the block / page index.
  /// For MIFARE Classic tags, you must first authenticate against the corresponding sector.
  static Future<void> writeBlock<T>(int index, T data,
      {Iso15693RequestFlags? iso15693Flags,
      bool iso15693ExtendedMode = false}) async {
    assert(data is String || data is Uint8List);
    var flags = iso15693Flags ?? Iso15693RequestFlags();
    await _channel.invokeMethod('writeBlock', {
      'index': index,
      'data': data,
      'iso15693Flags': flags.encode(),
      'iso15693ExtendedMode': iso15693ExtendedMode,
    });
  }

  /// Read one sector from MIFARE Classic tag (Android Only)
  ///
  /// There must be a valid session when invoking.
  /// [index] refers to the sector index.
  /// You must first authenticate against the corresponding sector.
  /// Note: not all sectors are 64B long, some tags might have 256B sectors.
  /// Returns data in [Uint8List].
  static Future<Uint8List> readSector(int index) async {
    return await _channel.invokeMethod('readSector', {'index': index});
  }
}
