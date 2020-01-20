# Flutter NFC Kit

Yet another plugin to provide NFC functionality on Android and iOS.

This plugin supports:

* read metadata of tags / cards complying with:
  * ISO 14443-4 Type A & Type B (NFC-A / NFC-B / Mifare Classic / Mifare Ultralight)
  * ISO 18092 (NFC-F / Felica)
  * ISO 15963 (NFC-V)
  * China ID Card (non-standard, GUID only)
* transceive APDU with smart cards complying with ISO 7816

Note that due to API limitations not all operations are supported on both platforms.

## Setup

Thank [nfc_manager](https://pub.dev/packages/nfc_manager) plugin to these instructions.

### Android

* Add [android.permission.NFC](https://developer.android.com/reference/android/Manifest.permission.html#NFC) to your `AndroidManifest.xml`.

### iOS

* Add [Near Field Communication Tag Reader Session Formats Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_nfc_readersession_formats) to your entitlements.

* Add [NFCReaderUsageDescription](https://developer.apple.com/documentation/bundleresources/information_property_list/nfcreaderusagedescription) to your `Info.plist`.

* Add [com.apple.developer.nfc.readersession.felica.systemcodes](https://developer.apple.com/documentation/bundleresources/information_property_list/systemcodes) and [com.apple.developer.nfc.readersession.iso7816.select-identifiers](https://developer.apple.com/documentation/bundleresources/information_property_list/select-identifiers) to your `Info.plist` as needed.

## Usage

Simple example:

```dart
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

var availability = await FlutterNfcKit.nfcAvailability;
if (availability != NFCAvailability.available) {
    // oh-no
}

var tag = await FlutterNfcKit.poll();
print(jsonEncode(tag));
if (tag.type == NFCTagType.iso7816) {
    var result = await FlutterNfcKit.transceive("00B0950000");
    print(result);
}
await FlutterNfcKit.finish();
```

A more complicated example can be seen in `example` dir.

Refer to the [documentation](https://pub.dev/documentation/flutter_nfc_kit/) for more information.

### Error codes

We use error codes with similar meaning as HTTP status code. Brief explanation and error cause in string (if available) will also be returned when an error occurs.
