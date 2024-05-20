# Flutter NFC Kit

[![pub version](https://img.shields.io/pub/v/flutter_nfc_kit)](https://pub.dev/packages/flutter_nfc_kit)
![Build Example App](https://github.com/nfcim/flutter_nfc_kit/workflows/Build%20Example%20App/badge.svg)

Yet another plugin to provide NFC functionality on Android, iOS and browsers (by WebUSB, see below).

This plugin's functionalities include:

* read metadata and read & write NDEF records of tags / cards complying with:
  * ISO 14443 Type A & Type B (NFC-A / NFC-B / MIFARE Classic / MIFARE Plus / MIFARE Ultralight / MIFARE DESFire)
  * ISO 18092 (NFC-F / FeliCa)
  * ISO 15963 (NFC-V)
* R/W block / page / sector level data of tags complying with:
  * MIFARE Classic / Ultralight (Android only)
  * ISO 15693 (iOS only)
* transceive raw commands with tags / cards complying with:
  * ISO 7816 Smart Cards (layer 4, in APDUs)
  * other device-supported technologies (layer 3, in raw commands, see documentation for platform-specific supportability)

Note that due to API limitations, not all operations are supported on all platforms.
**You are welcome to submit PRs to add support for any standard-specific operations.**

This library uses [ndef](https://pub.dev/packages/ndef) for NDEF record encoding & decoding.

## Dependency issue of `js` package

Since v3.5.0, `flutter_nfc_kit` depends on `js: ^0.7.1`. This might lead to a conflict with other packages that depend on `js: ^0.6.4`. If you do not use this plugin in a web environment, you can safely add the following to your `pubspec.yaml` to resolve the conflict:

```yaml
dependency_overrides:
  js: "^0.6.4"
```

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

We provide [simple code example](example/example.md) and a [example application](example/lib).

Refer to the [documentation](https://pub.dev/documentation/flutter_nfc_kit/) for more information.

### Error codes

We use error codes with similar meaning as HTTP status code. Brief explanation and error cause in string (if available) will also be returned when an error occurs.
