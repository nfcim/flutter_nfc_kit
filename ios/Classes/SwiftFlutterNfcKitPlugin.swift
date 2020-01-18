import CoreNFC
import Flutter
import UIKit

// taken from StackOverflow
extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}

public class SwiftFlutterNfcKitPlugin: NSObject, FlutterPlugin, NFCTagReaderSessionDelegate {
    var session: NFCTagReaderSession?
    var result: FlutterResult?

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
        } else if call.method == "poll" {
            session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self)

            session?.alertMessage = "Hold your iPhone near the card"
            session?.begin()
            self.result = result
        } else {
            result("iOS " + UIDevice.current.systemVersion)
        }
    }

    public func tagReaderSessionDidBecomeActive(_: NFCTagReaderSession) {}

    public func tagReaderSession(_: NFCTagReaderSession, didInvalidateWithError _: Error) {
        result?([:])
        result = nil
    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        if tags.count > 1 {
            // Restart polling in 500ms
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected, please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval) {
                session.restartPolling()
            }
            return
        }

        let firstTag = tags.first!

        var result: [String: String] = [:]

        switch firstTag {
        case let .iso7816(tag):
            result["type"] = "iso7816"
            result["id"] = tag.identifier.hexEncodedString()
            result["historicalBytes"] = tag.historicalBytes?.hexEncodedString()
            result["applicationData"] = tag.applicationData?.hexEncodedString()
            result["aid"] = tag.initialSelectedAID
        default:
            result["type"] = "unknown"
        }

        self.result?(result)
        self.result = nil

        session.invalidate()
    }
}
