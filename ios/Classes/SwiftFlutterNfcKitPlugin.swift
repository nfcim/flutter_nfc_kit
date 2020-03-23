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

func dataWithHexString(hex: String) -> Data {
    var hex = hex
    var data = Data()
    while hex.count > 0 {
        let subIndex = hex.index(hex.startIndex, offsetBy: 2)
        let c = String(hex[..<subIndex])
        hex = String(hex[subIndex...])
        var ch: UInt32 = 0
        Scanner(string: c).scanHexInt32(&ch)
        var char = UInt8(ch)
        data.append(&char, count: 1)
    }
    return data
}

public class SwiftFlutterNfcKitPlugin: NSObject, FlutterPlugin, NFCTagReaderSessionDelegate {
    var session: NFCTagReaderSession?
    var result: FlutterResult?
    var tag: NFCTag?

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
            if session != nil {
                result(FlutterError(code: "500", message: "called too early", details: nil))
            } else {
                let arguments = call.arguments as! [String:Any?]
                let alertMessage = arguments["iosAlertMessage"] as? String
                
                session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self)
                self.result = result
                if alertMessage != nil {
                    session?.alertMessage = alertMessage!
                }
                //session?.alertMessage = "Hold your iPhone near the nfc card"
                session?.begin()
            }
        } else if call.method == "transceive" {
            if tag != nil {
                if let input = call.arguments as? String {
                    let data = dataWithHexString(hex: input)
                    switch tag {
                    case let .iso7816(tag):
                        let apdu = NFCISO7816APDU(data: data)!
                        tag.sendCommand(apdu: apdu, completionHandler: { (response: Data, sw1: UInt8, sw2: UInt8, _: Error?) in
                            let sw = String(format: "%02X%02X", sw1, sw2)
                            result("\(response.hexEncodedString())\(sw)")
                        })
                    default:
                        result(FlutterError(code: "501", message: "not implemented", details: nil))
                    }
                } else {
                    result(FlutterError(code: "501", message: "not implemented", details: nil))
                }
            } else {
                result(FlutterError(code: "500", message: "no tag found", details: nil))
            }
        } else if call.method == "finish" {
            self.result?(FlutterError(code: "500", message: "session finished", details: nil))
            self.result = nil

            if let session = session {
                let arguments = call.arguments as! [String:Any?]
                let alertMessage = arguments["iosAlertMessage"] as? String
                let errorMessage = arguments["iosErrorMessage"] as? String

                if let errorMessage = errorMessage {
                    session.invalidate(errorMessage: errorMessage)
                } else {
                    if let alertMessage = alertMessage {
                        session.alertMessage = alertMessage
                    }
                    session.invalidate()
                }
                self.session = nil
            }
            
            tag = nil
            result(nil)
        } else if call.method == "setIosAlertMessage" {
            if let session = session {
                if let alertMessage = call.arguments as? String {
                    session.alertMessage = alertMessage
                }
                result(nil);
            } else {
                result(FlutterError(code: "500", message: "called too early", details: nil))
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    public func tagReaderSessionDidBecomeActive(_: NFCTagReaderSession) {}

    public func tagReaderSession(_: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if result != nil {
            NSLog("Got error when reading NFC: %@", error.localizedDescription)
            result?(FlutterError(code: "500", message: "invalidate with error", details: error.localizedDescription))
            result = nil
            session = nil
            tag = nil
        }
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
            if tag.historicalBytes != nil {
                result["historicalBytes"] = tag.historicalBytes!.hexEncodedString()
                result["standard"] = "ISO 14443-4 (Type A)"
            } else if tag.applicationData != nil {
                result["applicationData"] = tag.applicationData!.hexEncodedString()
                result["standard"] = "ISO 14443-4 (Type B)"
            } else {
                result["standard"] = "ISO 14443"
            }
            result["aid"] = tag.initialSelectedAID
        case let .miFare(tag):
            result["standard"] = "ISO 14443-4 (Type A)"
            switch tag.mifareFamily {
            case .plus:
                result["type"] = "mifare_plus"
            case .ultralight:
                result["type"] = "mifare_ultralight"
            case .desfire:
                result["type"] = "mifare_desfire"
            default:
                result["type"] = "unknown"
            }
            result["id"] = tag.identifier.hexEncodedString()
            result["historicalBytes"] = tag.historicalBytes?.hexEncodedString()
        case let .feliCa(tag):
            result["type"] = "felica"
            result["standard"] = "ISO 18092"
            result["systemCode"] = tag.currentSystemCode.hexEncodedString()
            result["manufacturer"] = tag.currentIDm.hexEncodedString()
        case let .iso15693(tag):
            result["type"] = "iso15693"
            result["standard"] = "ISO 15093"
            result["id"] = tag.identifier.hexEncodedString()
            result["manufacturer"] = String(format: "%d", tag.icManufacturerCode)
        default:
            result["type"] = "unknown"
            result["standard"] = "unknown"
        }

        session.connect(to: firstTag, completionHandler: { (_: Error?) in
            self.tag = firstTag
            let jsonData = try! JSONSerialization.data(withJSONObject: result)
            let jsonString = String(data: jsonData, encoding: .utf8)
            self.result?(jsonString)
            self.result = nil
        })
    }
}
