#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_nfc_kit.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_nfc_kit'
  s.version          = '2.0.0'
  s.summary          = 'NFC support plugin of Flutter.'
  s.description      = <<-DESC
  Flutter plugin to provide NFC functionality on Android and iOS, including reading metadata, read & write NDEF records, and transceive layer 3 & 4 data with NFC tags / cards.
                       DESC
  s.homepage         = 'https://github.com/nfcim/flutter_nfc_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'nfc.im' => 'nfsee@nfc.im' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.weak_frameworks = ['CoreNFC']
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
end
