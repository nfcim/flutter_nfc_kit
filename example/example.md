# Example of flutter_nfc_kit

## Simple usage

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
if (tag.ndefAvailable) {
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

// read / write block / page / sector level data
// see documentation for platform-specific supportability
if (tag.type == NFCTagType.iso15693) {
  await await FlutterNfcKit.writeBlock(
    1, // index
    [0xde, 0xad, 0xbe, 0xff], // data
    iso15693RequestFlag: Iso15693RequestFlag(), // optional flags for ISO 15693
    iso15693ExtendedMode: false // use extended mode for ISO 15693
  );
}

if (tag.type == NFCType.mifare_classic) {
  await FlutterNfcKit.authenticateSector(0, keyA: "FFFFFFFFFFFF");
  var data = await FlutterNfcKit.readSector(0); // read one sector, or
  var data = await FlutterNfcKit.readBlock(0); // read one block
}

// Call finish() only once
await FlutterNfcKit.finish();
// iOS only: show alert/error message on finish
await FlutterNfcKit.finish(iosAlertMessage: "Success");
// or
await FlutterNfcKit.finish(iosErrorMessage: "Failed");
```

## GUI Application

See `lib/main.dart` for a GUI application on Android / iOS / web. Skeleton code for specific platforms are not uploaded to <pub.dev>. Please refer to the [GitHub repository](https://github.com/nfcim/flutter_nfc_kit).
