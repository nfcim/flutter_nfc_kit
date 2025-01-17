# Example of flutter_nfc_kit

## Polling

This is the default operation mode and is supported on all platforms.
We recommend using this method to read NFC tags to ensure the consistency of cross-platform interactions.


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

## Event Streaming

This is only supported on Android now. To receive NFC tag events even when your app is in the foreground, you can set up tag event stream support by:

1. Create a custom Activity that extends `FlutterActivity` in your Android project:

```kotlin
package your.package.name

import android.app.PendingIntent
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import io.flutter.embedding.android.FlutterActivity
import im.nfc.flutter_nfc_kit.FlutterNfcKitPlugin

class MainActivity : FlutterActivity() {
    override fun onResume() {
        super.onResume()
        val adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(this)
        val pendingIntent: PendingIntent = PendingIntent.getActivity(
            this, 0, Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_MUTABLE
        )
        // See https://developer.android.com/reference/android/nfc/NfcAdapter#enableForegroundDispatch(android.app.Activity,%20android.app.PendingIntent,%20android.content.IntentFilter[],%20java.lang.String[][]) for details 
        adapter?.enableForegroundDispatch(this, pendingIntent, null, null)
    }

    override fun onPause() {
        super.onPause()
        val adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(this)
        adapter?.disableForegroundDispatch(this)
    }

    override fun onNewIntent(intent: Intent) {
        val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        tag?.apply(FlutterNfcKitPlugin::handleTag)
    }
}
```

You may also invoke `enableForegroundDispatch` and `disableForegroundDispatch` in other places as needed.

2. Update your `AndroidManifest.xml` to use it as the main activity instead of the default Flutter activity.

3. In Flutter code, listen to the tag event stream and process events:

```dart
@override
void initState() {
  super.initState();
  // listen to NFC tag events
  FlutterNfcKit.tagStream.listen((tag) {
    print('Tag detected: ${tag.id}');
    // process the tag as in polling mode
    FlutterNfcKit.transceive("xxx", ...);
    // DO NOT call `FlutterNfcKit.finish` in this mode!
  });
}
```

This will allow your app to receive NFC tag events through a stream, which is useful for scenarios where you need continuous tag reading or want to handle tags even when your app is in the foreground but not actively polling.

## GUI Application

See `lib/main.dart` for a GUI application on Android / iOS / web. Skeleton code for specific platforms are not uploaded to <pub.dev>. Please refer to the [GitHub repository](https://github.com/nfcim/flutter_nfc_kit).
