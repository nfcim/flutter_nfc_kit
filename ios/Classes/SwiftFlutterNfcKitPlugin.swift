import Flutter
import UIKit
import CoreNFC

public class SwiftFlutterNfcKitPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_nfc_kit", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterNfcKitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getNFCAvailability" {
      if NFCReaderSession.readingAvailable {
        result("available")
      } else {
        result("disabled")
      }
    } else {
      result("iOS " + UIDevice.current.systemVersion)
    }
  }
}
