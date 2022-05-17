# Flutter NFC Kit

[![pub version](https://img.shields.io/pub/v/flutter_nfc_kit)](https://pub.dev/packages/flutter_nfc_kit)
![Build Example App](https://github.com/nfcim/flutter_nfc_kit/workflows/Build%20Example%20App/badge.svg)

Yet another plugin to provide NFC functionality on Android, iOS and browsers (by WebUSB, see below).

This plugin's functionalities include:

* read metadata and read & write NDEF records of tags / cards complying with:
  * ISO 14443 Type A & Type B (NFC-A / NFC-B / MIFARE Classic / MIFARE Plus / MIFARE Ultralight / MIFARE DESFire)
  * ISO 18092 (NFC-F / FeliCa)
  * ISO 15963 (NFC-V)
* transceive commands with tags / cards complying with:
  * ISO 7816 Smart Cards (layer 4, in APDUs)
  * other device-supported technologies (layer 3, in raw commands, see documentation for platform-specific supportability)

Note that due to API limitations not all operations are supported on both platforms.

This library uses [ndef](https://pub.dev/packages/ndef) for NDEF record encoding & decoding.

## Setup

Thank [nfc_manager](https://pub.dev/packages/nfc_manager) plugin for these instructions.

### Android

* Add [android.permission.NFC](https://developer.android.com/reference/android/Manifest.permission.html#NFC) to your `AndroidManifest.xml`.

### iOS

* Add [Near Field Communication Tag Reader Session Formats Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_nfc_readersession_formats) to your entitlements.
* Add [NFCReaderUsageDescription](https://developer.apple.com/documentation/bundleresources/information_property_list/nfcreaderusagedescription) to your `Info.plist`.
* Add [com.apple.developer.nfc.readersession.felica.systemcodes](https://developer.apple.com/documentation/bundleresources/information_property_list/systemcodes) and [com.apple.developer.nfc.readersession.iso7816.select-identifiers](https://developer.apple.com/documentation/bundleresources/information_property_list/select-identifiers) to your `Info.plist` as needed. WARNING: for iOS 14.5 and earlier versions, you **MUST** add them before invoking `poll` with `readIso18092` or `readIso15693` enabled, or your NFC **WILL BE TOTALLY UNAVAILABLE BEFORE REBOOT** due to a [CoreNFC bug](https://github.com/nfcim/flutter_nfc_kit/issues/23).
* Open Runner.xcworkspace with Xcode and navigate to project settings then the tab _Signing & Capabilities._
* Select the Runner in targets in left sidebar then press the "+ Capability" in the left upper corner and choose _Near Field Communication Tag Reading._

## Web

The web version of this plugin **does not actually support NFC** in browsers, but uses a specific [WebUSB protocol](https://github.com/nfcim/flutter_nfc_kit/blob/master/WebUSB.md), so that Flutter programs can communicate with dual-interface (NFC / USB) devices in a platform-independent way.

Make sure you understand the statement above and the protocol before using this plugin.

## Usage

Simple example:

```dart
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;

var availability = await FlutterNfcKit.nfcAvailability;
if (availability != NFCAvailability.available) {
    // oh-no
}

// timeout only works on Android, while the latter two messages are only for iOS
var tag = await FlutterNfcKit.poll(timeout: Duration(seconds: 10),
  iosMultipleTagMessage: "Multiple tags found!", iosAlertMessage: "Scan your tag");

print(jsonEncode(tag));
if (tag.type == NFCTagType.iso7816) {
    var result = await FlutterNfcKit.transceive("00B0950000", Duration(seconds: 5)); // timeout is still Android-only, persist until next change
    print(result);
}
// iOS only: set alert message on-the-fly
// this will persist until finish()
await FlutterNfcKit.setIosAlertMessage("hi there!");

// read NDEF records if available
if (tag.ndefAvailable){
  /// decoded NDEF records (see [ndef.NDEFRecord] for details)
  /// `UriRecord: id=(empty) typeNameFormat=TypeNameFormat.nfcWellKnown type=U uri=https://github.com/nfcim/ndef`
  for (var record in await FlutterNfcKit.readNDEFRecords(cached: false)) {
    print(record.toString());
  }
  /// raw NDEF records (data in hex string)
  /// `{identifier: "", payload: "00010203", type: "0001", typeNameFormat: "nfcWellKnown"}`
  for (var record in await FlutterNfcKit.readNDEFRawRecords(cached: false)) {
    print(jsonEncode(record).toString());
  }
}

// write NDEF records if applicable
if (tag.ndefWritable) {
  // decoded NDEF records
  await FlutterNfcKit.writeNDEFRecords([new ndef.UriRecord.fromUriString("https://github.com/nfcim/flutter_nfc_kit")]);
  // raw NDEF records
  await FlutterNfcKit.writeNDEFRawRecords([new NDEFRawRecord("00", "0001", "0002", "0003", ndef.TypeNameFormat.unknown)]);
}

// Call finish() only once
await FlutterNfcKit.finish();
// iOS only: show alert/error message on finish
await FlutterNfcKit.finish(iosAlertMessage: "Success");
// or
await FlutterNfcKit.finish(iosErrorMessage: "Failed");
```

A more complicated example can be seen in `example` dir.

Refer to the [documentation](https://pub.dev/documentation/flutter_nfc_kit/) for more information.

### Error codes

We use error codes with similar meaning as HTTP status code. Brief explanation and error cause in string (if available) will also be returned when an error occurs.
