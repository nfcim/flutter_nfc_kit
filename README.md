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

## Setup

### Android

We have the following minimum version requirements for Android plugin:

* Java 17
* Gradle 8.9
* Android SDK 26 (you must set corresponding `jvmTarget` in you app's `build.gradle`)
* Android Gradle Plugin 8.7

To use this plugin on Android, you also need to:

* Add [android.permission.NFC](https://developer.android.com/reference/android/Manifest.permission.html#NFC) to your `AndroidManifest.xml`.

To receive NFC tag events even when your app is in the foreground, you can set up tag event stream support:

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
        if (tag != null) {
            FlutterNfcKitPlugin.handleTag(tag)
        }
    }
}
```

2. Update your `AndroidManifest.xml` to use this activity instead of the default Flutter activity.

3. In your Flutter code, listen to the tag event stream:

```dart
@override
void initState() {
  super.initState();
  // Listen to NFC tag events
  FlutterNfcKit.tagStream.listen((tag) {
    print('Tag detected: ${tag.id}');
    // Process the tag
  });
}
```

This will allow your app to receive NFC tag events through a stream, which is useful for scenarios where you need continuous tag reading or want to handle tags even when your app is in the foreground but not actively polling.

### iOS

This plugin now supports Swift package manager, and requires iOS 13+.

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
