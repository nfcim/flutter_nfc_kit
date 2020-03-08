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