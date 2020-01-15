#import "FlutterNfcKitPlugin.h"
#if __has_include(<flutter_nfc_kit/flutter_nfc_kit-Swift.h>)
#import <flutter_nfc_kit/flutter_nfc_kit-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_nfc_kit-Swift.h"
#endif

@implementation FlutterNfcKitPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterNfcKitPlugin registerWithRegistrar:registrar];
}
@end
