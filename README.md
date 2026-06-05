# Flutter NFC Kit

[![pub version](https://img.shields.io/pub/v/flutter_nfc_kit)](https://pub.dev/packages/flutter_nfc_kit)
[![Test](https://github.com/nfcim/flutter_nfc_kit/actions/workflows/test.yml/badge.svg)](https://github.com/nfcim/flutter_nfc_kit/actions/workflows/test.yml)
[![Build Example App](https://github.com/nfcim/flutter_nfc_kit/actions/workflows/example-app.yml/badge.svg)](https://github.com/nfcim/flutter_nfc_kit/actions/workflows/example-app.yml)

Yet another plugin to provide NFC functionality on Android, iOS and browsers (by WebUSB, see below).

This plugin's functionalities include:

* read metadata and read & write NDEF records of tags / cards complying with:
  * ISO 14443 Type A & Type B (NFC-A / NFC-B / MIFARE Classic / MIFARE Plus / MIFARE Ultralight / MIFARE DESFire)
  * ISO 18092 (NFC-F / FeliCa)
  * ISO 15693 (NFC-V)
* R/W block / page / sector level data of tags complying with:
  * MIFARE Classic / Ultralight (Android only, MIFARE Classic Read & Write block for iOS)
  * ISO 15693 (iOS only)
* transceive raw commands with tags / cards complying with:
  * ISO 7816 Smart Cards (layer 4, in APDUs)
  * other device-supported technologies (layer 3, in raw commands, see documentation for platform-specific supportability)

Note that due to API limitations, not all operations are supported on all platforms.
**You are welcome to submit PRs to add support for any standard-specific operations.**

This library uses [ndef](https://pub.dev/packages/ndef) for NDEF record encoding & decoding.

## Contributing

Please refer to [CONTRIBUTING.md](CONTRIBUTING.md) for more information.

## Setup

### Android

We have the following minimum version requirements for Android plugin:

* Java 17
* Gradle 8.9
* Android SDK 24 (you must set corresponding `jvmTarget` in you app's `build.gradle`)
* Android Gradle Plugin 8.7

To use this plugin on Android, you also need to:

* Add [android.permission.NFC](https://developer.android.com/reference/android/Manifest.permission.html#NFC) to your `AndroidManifest.xml`.

### iOS

This plugin now supports Swift package manager, and requires iOS 13+.

* Add [Near Field Communication Tag Reader Session Formats Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_nfc_readersession_formats) to your entitlements.
* Add [NFCReaderUsageDescription](https://developer.apple.com/documentation/bundleresources/information_property_list/nfcreaderusagedescription) to your `Info.plist`.
* Add [com.apple.developer.nfc.readersession.felica.systemcodes](https://developer.apple.com/documentation/bundleresources/information_property_list/systemcodes) and [com.apple.developer.nfc.readersession.iso7816.select-identifiers](https://developer.apple.com/documentation/bundleresources/information_property_list/select-identifiers) to your `Info.plist` as needed. WARNING: for iOS 14.5 and earlier versions, you **MUST** add them before invoking `poll` with `readIso18092` or `readIso15693` enabled, or your NFC **WILL BE TOTALLY UNAVAILABLE BEFORE REBOOT** due to a [CoreNFC bug](https://github.com/nfcim/flutter_nfc_kit/issues/23).
* Open Runner.xcworkspace with Xcode and navigate to project settings then the tab _Signing & Capabilities._
* Select the Runner in targets in left sidebar then press the "+ Capability" in the left upper corner and choose _Near Field Communication Tag Reading._

### Web

The web version of this plugin **does not actually support NFC** in browsers, but uses a specific [WebUSB protocol](https://github.com/nfcim/flutter_nfc_kit/blob/master/WebUSB.md), so that Flutter programs can communicate with dual-interface (NFC / USB) devices in a platform-independent way.

Make sure you understand the statement above and the protocol before using this plugin.

## Usage

We provide [simple code example](example/example.md) and a [example application](example/lib).

Refer to the [documentation](https://pub.dev/documentation/flutter_nfc_kit/) for more information.

### Error codes

We use error codes with similar meaning as HTTP status code. Brief explanation and error cause in string (if available) will also be returned when an error occurs.

On iOS, session-invalidation errors are surfaced as a `PlatformException` whose `code` follows the same convention and whose `message` is the CoreNFC reason:

| Code | Message | Cause (CoreNFC) |
|------|---------|-----------------|
| `408` | `SessionTimeOut` | `readerSessionInvalidationErrorSessionTimeout` |
| `409` | `UserCanceled` | `readerSessionInvalidationErrorUserCanceled` (user tapped Cancel) |
| `502` | `SessionTerminatedUnexpectedly` | `readerSessionInvalidationErrorSessionTerminatedUnexpectedly` |
| `503` | `SystemIsBusy` | `readerSessionInvalidationErrorSystemIsBusy` |

These are iOS-only (CoreNFC concepts); Android and Web do not produce them. They are delivered to whichever call is pending when the session is invalidated — including a `transceive`/`readNDEF`/`writeNDEF` in progress after a tag was polled.

### Operation Mode

We provide two operation modes: polling (default) and event streaming. Both can give the same `NFCTag` object. Please see [example](example/example.md) for more details.

### Performance Optimization (Android)

For Android applications, you can optimize NFC tag detection performance using the `androidReaderModeFlags` parameter:

```dart
// Skip automatic NDEF discovery for ~500ms faster detection
// and disable platform sounds for custom feedback
const flags = 0x80 | 0x100; // FLAG_READER_SKIP_NDEF_CHECK | FLAG_READER_NO_PLATFORM_SOUNDS

final tag = await FlutterNfcKit.poll(
  androidReaderModeFlags: flags,
);
```

Common flags from [`NfcAdapter`](https://developer.android.com/reference/android/nfc/NfcAdapter#enableReaderMode(android.app.Activity,%20android.nfc.NfcAdapter.ReaderCallback,%20int,%20android.os.Bundle)):
- `0x80` - `FLAG_READER_SKIP_NDEF_CHECK`: Skip automatic NDEF discovery, improving detection speed by ~500ms
- `0x100` - `FLAG_READER_NO_PLATFORM_SOUNDS`: Disable system beep/vibration for custom audio/haptic feedback

These flags are particularly useful for applications that:
- Need fast tag detection (e.g., access control, fast payments)
- Implement custom user feedback instead of system sounds
- Use custom NDEF reading logic instead of automatic discovery
