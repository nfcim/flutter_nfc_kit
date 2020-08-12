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
