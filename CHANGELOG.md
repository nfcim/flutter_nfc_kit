## 0.0.1

* Initial release
* Support reading metadata of cards of standard ISO 14443-4 Type A & Type B (NFC-A / NFC-B / Mifare Classic / Mifare Ultralight)
* Support transceiving APDU with cards of standard ISO 7816

## 0.0.2

* Support reading metadata of cards of standard ISO 18092 / JIS 6319 (NFC-F / Felica)
* Support reading metadata of cards of standard ISO 15963 (NFC-V)
* Support reading GUID of China ID Card (which is non-standard)
* Add more documentation
* Release with MIT License

## 0.0.3

* Fix compilation errors of iOS plugin

## 0.0.4

* Fix IsoDep unintentionally closing of the Android plugin
* Fix incorrect standards description

## 0.0.5

* Fix finish method blocking error

## 0.0.6

* Avoid returning redundant result if user finish the read operation prematurely

## 0.0.7

* Allow data transceive on lower layer (Android only)

## 1.0.0

* Remove China ID Card support due to support of lower layer transceiving
* Fix some racing problem on iOS
* We are out-of beta and releasing on time!

## 1.0.1

* Fix IllegalStateException & Add MethodResultWrapper (Thanks to @smlu)

## 1.0.2

* Remove redundant code in Android plugin
* Format dart code

## 1.1.0

* Add NFC session alert/error message on iOS (Thanks to @smlu)
* Support execution timeout as optional parameter on Android for `poll` and `transceive` (Thanks to @smlu)
* Accept command in the type of hex string / `UInt8List` in `transceive` and return in the same type (Thanks to @smlu)

## 1.2.0

* Add support for NFC 18902 on iOS
* Add initial NDEF support (read only, no decoding)
* Allow disabling platform sound on Android when polling card

## 2.0.0

* Switch to [ndef](https://pub.dev/packages/ndef) for NDEF record encoding & decoding (breaking API change)
* Support writing NDEF records
* Add NDEF writing in example app

## 2.0.1

* Fix compiling problem on iOS

## 2.0.2

* Fix format of CHANGELOG.md
* Format source code to pass static analysis

## 2.1.0

* Update to latest version of `ndef` package
* Update example app on writing NDEF records

## 2.2.0

* Allow specifying needed NFC technologies in `poll` (fix [#15](https://github.com/nfcim/flutter_nfc_kit/issues/15))

## 2.2.1

* Disable ISO 18092 in `poll` by default due to iOS CoreNFC bug (see [#23](https://github.com/nfcim/flutter_nfc_kit/issues/23))
* Bump dependencies & fix some deprecation warnings

## 3.0.0

* Upgrade to Flutter 2.0, add null-safety support for APIs
* Bump dependencies (`ndef` to 0.3.1)

## 3.0.1

* Remove errorous non-null assertion in `ndef.NDEFRecord.toRaw()` extension method & fix example app (#38)

## 3.0.2

* Fix incorrect flags passed by `poll` method to Android NFC API (#42)

## 3.1.0

* Fix inappropriate non-null type in fields of `NFCTag` (#43)

## 3.2.0

* Add `makeNdefReadOnly` (#53, thanks to @timnew)
* Avoid NFC API calls to block the main thread on Android (#54, thanks to @cyberbobs)
* Bump dependencies of Android plugin and example App (esp. Kotlin 1.6.0)
* Exclude example app in published version to reduce package size

## 3.3.0

* Add Web support using own WebUSB protocol (see documentation for detail)
* Bump dependencies (esp. Kotlin 1.6.21 and SDK 31) of Android plugin and example App to fix build error (#55)
* Distinguish session canceled and session timeout (#58, #59, thanks to @timnew)
* Minor error fixes (#61, #63, #64, #65, #71, #72, many of them come from @timnew)

## 3.3.1

* Downgrade dependency `js` to 0.6.3 to maintain backward compatibility with Flutter 2 (#74)
