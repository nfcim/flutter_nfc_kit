import CoreNFC
import Flutter
import UIKit

// taken from StackOverflow
extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = [.upperCase]) -> String {
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
        var ch: UInt64 = 0
        Scanner(string: c).scanHexInt64(&ch)
        var char = UInt8(ch)
        data.append(&char, count: 1)
    }
    return data
}

public class SwiftFlutterNfcKitPlugin: NSObject, FlutterPlugin, NFCTagReaderSessionDelegate {
    var session: NFCTagReaderSession?
    var result: FlutterResult?
    var tag: NFCTag?
    var multipleTagMessage: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_nfc_kit", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterNfcKitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // from FlutterPlugin
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getNFCAvailability" {
            if NFCReaderSession.readingAvailable {
                result("available")
            } else {
                result("not_supported")
            }
        } else if call.method == "poll" {
            if session != nil {
                result(FlutterError(code: "406", message: "Cannot invoke poll in a active session", details: nil))
            } else {
                let arguments = call.arguments as! [String: Any?]
                let technologies = arguments["technologies"] as! Int
                // TODO: derive pollingOption from technology flags
                var pollingOption: NFCTagReaderSession.PollingOption = []
                if (technologies & 0x3) != 0 {
                    pollingOption.insert(.iso14443)
                }
                if (technologies & 0x4) != 0 {
                    pollingOption.insert(.iso18092)
                }
                if (technologies & 0x8) != 0 {
                    pollingOption.insert(.iso15693)
                }
                session = NFCTagReaderSession(pollingOption: pollingOption, delegate: self)
                if let alertMessage = arguments["iosAlertMessage"] as? String {
                    session?.alertMessage = alertMessage
                }
                if let multipleTagMessage = arguments["iosMultipleTagMessage"] as? String {
                    self.multipleTagMessage = multipleTagMessage
                }
                self.result = result
                session?.begin()
            }
        } else if call.method == "transceive" {
            if tag != nil {
                let req = (call.arguments as? [String: Any?])?["data"]
                if req != nil, req is String || req is FlutterStandardTypedData {
                    var data: Data?
                    switch req {
                    case let hexReq as String:
                        data = dataWithHexString(hex: hexReq)
                    case let binReq as FlutterStandardTypedData:
                        data = binReq.data
                    default:
                        data = nil
                    }

                    switch tag {
                    case let .iso7816(tag):
                        var apdu: NFCISO7816APDU?
                        if data != nil {
                            apdu = NFCISO7816APDU(data: data!)
                        }

                        if apdu != nil {
                            tag.sendCommand(apdu: apdu!, completionHandler: { (response: Data, sw1: UInt8, sw2: UInt8, error: Error?) in
                                if let error = error {
                                    result(FlutterError(code: "500", message: "Communication error", details: error.localizedDescription))
                                } else {
                                    var response = response
                                    response.append(contentsOf: [sw1, sw2])
                                    if req is String {
                                        result(response.hexEncodedString())
                                    } else {
                                        result(response)
                                    }
                                }
                            })
                        } else {
                            result(FlutterError(code: "400", message: "Command format error", details: nil))
                        }
                    case let .feliCa(tag):
                        if data != nil {
                            // the first byte in data is length
                            // and iOS will add it for us
                            // so skip it
                            tag.sendFeliCaCommand(commandPacket: data!.advanced(by: 1), completionHandler: { (response: Data, error: Error?) in
                                if let error = error {
                                    result(FlutterError(code: "500", message: "Communication error", details: error.localizedDescription))
                                } else {
                                    if req is String {
                                        result(response.hexEncodedString())
                                    } else {
                                        result(response)
                                    }
                                }
                            })
                        } else {
                            result(FlutterError(code: "400", message: "No felica command specified", details: nil))
                        }
                    case let .miFare(tag):
                        if data != nil {
                            tag.sendMiFareCommand(commandPacket: data!, completionHandler: { (response: Data, error: Error?) in
                                if let error = error {
                                    result(FlutterError(code: "500", message: "Communication error", details: error.localizedDescription))
                                } else {
                                    if req is String {
                                        result(response.hexEncodedString())
                                    } else {
                                        result(response)
                                    }
                                }
                            })
                        } else {
                            result(FlutterError(code: "400", message: "No mifare command specified", details: nil))
                        }
                    default:
                        result(FlutterError(code: "405", message: "Transceive not supported on this type of card", details: nil))
                    }
                } else {
                    result(FlutterError(code: "400", message: "Bad argument", details: nil))
                }
            } else {
                result(FlutterError(code: "406", message: "No tag polled", details: nil))
            }
        } else if call.method == "readNDEF" {
            if tag != nil {
                var ndefTag: NFCNDEFTag?
                switch tag {
                case let .iso7816(tag):
                    ndefTag = tag
                case let .miFare(tag):
                    ndefTag = tag
                case let .feliCa(tag):
                    ndefTag = tag
                case let .iso15693(tag):
                    ndefTag = tag
                default:
                    ndefTag = nil
                }
                if ndefTag != nil {
                    ndefTag!.readNDEF(completionHandler: { (msg: NFCNDEFMessage?, error: Error?) in
                        if let nfcError = error as? NFCReaderError, nfcError.errorCode == 403  {
                            // NDEF tag does not contain any NDEF message
                            result("[]")
                        } else if let error = error {
                            result(FlutterError(code: "500", message: "Read NDEF error", details: error.localizedDescription))
                        } else if let msg = msg {
                            var records: [[String: Any]] = []

                            for record in msg.records {
                                var entry: [String: Any] = [:]

                                entry["identifier"] = record.identifier.hexEncodedString()
                                entry["payload"] = record.payload.hexEncodedString()
                                entry["type"] = record.type.hexEncodedString()
                                switch record.typeNameFormat {
                                case NFCTypeNameFormat.absoluteURI:
                                    entry["typeNameFormat"] = "absoluteURI"
                                case NFCTypeNameFormat.empty:
                                    entry["typeNameFormat"] = "empty"
                                case NFCTypeNameFormat.media:
                                    entry["typeNameFormat"] = "media"
                                case NFCTypeNameFormat.nfcExternal:
                                    entry["typeNameFormat"] = "nfcExternal"
                                case NFCTypeNameFormat.nfcWellKnown:
                                    entry["typeNameFormat"] = "nfcWellKnown"
                                case NFCTypeNameFormat.unchanged:
                                    entry["typeNameFormat"] = "unchanged"
                                default:
                                    entry["typeNameFormat"] = "unknown"
                                }

                                records.append(entry)
                            }

                            let jsonData = try! JSONSerialization.data(withJSONObject: records)
                            let jsonString = String(data: jsonData, encoding: .utf8)
                            result(jsonString)
                        } else {
                            result(FlutterError(code: "500", message: "Impossible branch reached", details: nil))
                        }
                    })
                } else {
                    result(FlutterError(code: "405", message: "NDEF not supported on this type of card", details: nil))
                }
            } else {
                result(FlutterError(code: "406", message: "No tag polled", details: nil))
            }
        } else if call.method == "writeNDEF" {
            if tag != nil {
                var ndefTag: NFCNDEFTag?
                switch tag {
                case let .iso7816(tag):
                    ndefTag = tag
                case let .miFare(tag):
                    ndefTag = tag
                case let .feliCa(tag):
                    ndefTag = tag
                case let .iso15693(tag):
                    ndefTag = tag
                default:
                    ndefTag = nil
                }
                if ndefTag != nil {
                    let jsonString = (call.arguments as? [String: Any?])?["data"] as? String
                    let json = try? JSONSerialization.jsonObject(with: jsonString!.data(using: .utf8)!)
                    let recordList = json as? [[String: Any]]
                    if recordList != nil {
                        var records: [NFCNDEFPayload] = []
                        for record in recordList! {
                            let format: NFCTypeNameFormat?
                            switch record["typeNameFormat"] as! String {
                            case "absoluteURI":
                                format = NFCTypeNameFormat.absoluteURI
                            case "empty":
                                format = NFCTypeNameFormat.empty
                            case "nfcExternal":
                                format = NFCTypeNameFormat.nfcExternal
                            case "nfcWellKnown":
                                format = NFCTypeNameFormat.nfcWellKnown
                            case "media":
                                format = NFCTypeNameFormat.media
                            case "unchanged":
                                format = NFCTypeNameFormat.unchanged
                            default:
                                format = NFCTypeNameFormat.unknown
                            }
                            records.append(NFCNDEFPayload(
                                format: format!,
                                type: dataWithHexString(hex: record["type"] as! String),
                                identifier: dataWithHexString(hex: record["identifier"] as! String),
                                payload: dataWithHexString(hex: record["payload"] as! String)
                            ))
                        }

                        ndefTag!.writeNDEF(NFCNDEFMessage(records: records), completionHandler: { (error: Error?) in
                            if let error = error {
                                result(FlutterError(code: "500", message: "Write NDEF error", details: error.localizedDescription))
                            } else {
                                result(nil)
                            }
                        })
                    } else {
                        result(FlutterError(code: "400", message: "Bad argument", details: nil))
                    }
                } else {
                    result(FlutterError(code: "405", message: "NDEF not supported on this type of card", details: nil))
                }
            } else {
                result(FlutterError(code: "406", message: "No tag polled", details: nil))
            }
        } else if call.method == "finish" {
            self.result?(FlutterError(code: "406", message: "Session not active", details: nil))
            self.result = nil

            if let session = session {
                let arguments = call.arguments as! [String: Any?]
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
                result(nil)
            } else {
                result(FlutterError(code: "406", message: "Session not active", details: nil))
            }
        } else if call.method == "makeNdefReadOnly" {
            if tag != nil {
                var ndefTag: NFCNDEFTag?
                switch tag {
                case let .iso7816(tag):
                    ndefTag = tag
                case let .miFare(tag):
                    ndefTag = tag
                case let .feliCa(tag):
                    ndefTag = tag
                case let .iso15693(tag):
                    ndefTag = tag
                default:
                    ndefTag = nil
                }
                if ndefTag != nil {
                    ndefTag!.writeLock(completionHandler: { (error: Error?) in
                        if let error = error {
                            result(FlutterError(code: "500", message: "Lock NDEF error", details: error.localizedDescription))
                        } else {
                            result(nil)
                        }
                    })
                } else {
                    result(FlutterError(code: "405", message: "NDEF not supported on this type of card", details: nil))
                }
            } else {
                result(FlutterError(code: "406", message: "No tag polled", details: nil))
            }
        }
        else {
            result(FlutterMethodNotImplemented)
        }
    }

    // from NFCTagReaderSessionDelegate
    public func tagReaderSessionDidBecomeActive(_: NFCTagReaderSession) {}

    // from NFCTagReaderSessionDelegate
    public func tagReaderSession(_: NFCTagReaderSession, didInvalidateWithError error: Error) {
        guard result != nil else { return; }
        
        if let nfcError = error as? NFCReaderError {
            NSLog("Got NFCError when reading NFC: %@", nfcError.localizedDescription)
            switch nfcError.errorCode {
            case NFCReaderError.Code.readerSessionInvalidationErrorUserCanceled.rawValue:
                result?(FlutterError(code: "409", message: "SessionCanceled", details: error.localizedDescription))
            case NFCReaderError.Code.readerSessionInvalidationErrorSessionTimeout.rawValue:
                result?(FlutterError(code: "408", message: "SessionTimeOut", details: error.localizedDescription))
            default:
                result?(FlutterError(code: "500", message: "Generic NFC Error", details: error.localizedDescription))
            }
        } else {
            NSLog("Got unknown when reading NFC: %@", error.localizedDescription)
            result?(FlutterError(code: "500", message: "Invalidate session with error", details: error.localizedDescription))
        }
        
        result = nil
        session = nil
        tag = nil
    }

    // from NFCTagReaderSessionDelegate
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        if tags.count > 1 {
            // Restart polling in 500ms
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            if multipleTagMessage != nil {
                session.alertMessage = multipleTagMessage!
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval) {
                session.restartPolling()
            }
            return
        }

        let firstTag = tags.first!

        var result: [String: Any] = [:]
        // default NDEF status
        result["ndefAvailable"] = false
        result["ndefWritable"] = false
        result["ndefCapacity"] = 0
        // fake NDEF results
        result["ndefType"] = ""
        result["ndefCanMakeReadOnly"] = false

        switch firstTag {
        case let .iso7816(tag):
            result["type"] = "iso7816"
            result["id"] = tag.identifier.hexEncodedString()
            if let historicalBytes = tag.historicalBytes {
                result["historicalBytes"] = historicalBytes.hexEncodedString()
                result["standard"] = "ISO 14443-4 (Type A)"
            } else if let applicationData = tag.applicationData {
                result["applicationData"] = applicationData.hexEncodedString()
                result["standard"] = "ISO 14443-4 (Type B)"
            } else {
                result["standard"] = "ISO 14443"
            }
            result["aid"] = tag.initialSelectedAID
        case let .miFare(tag):
            switch tag.mifareFamily {
            case .plus:
                result["type"] = "mifare_plus"
                result["standard"] = "ISO 14443-4 (Type A)"
            case .ultralight:
                result["type"] = "mifare_ultralight"
                result["standard"] = "ISO 14443-3 (Type A)"
            case .desfire:
                result["type"] = "mifare_desfire"
                result["standard"] = "ISO 14443-4 (Type A)"
            default:
                result["type"] = "unknown"
                result["standard"] = "ISO 14443 (Type A)"
            }
            result["id"] = tag.identifier.hexEncodedString()
            result["historicalBytes"] = tag.historicalBytes?.hexEncodedString()
        case let .feliCa(tag):
            result["type"] = "iso18092"
            result["standard"] = "ISO 18092 (FeliCa)"
            result["systemCode"] = tag.currentSystemCode.hexEncodedString()
            result["manufacturer"] = tag.currentIDm.hexEncodedString()
        case let .iso15693(tag):
            result["type"] = "iso15693"
            result["standard"] = "ISO 15693"
            result["id"] = tag.identifier.hexEncodedString()
            result["manufacturer"] = String(format: "%d", tag.icManufacturerCode)
        default:
            result["type"] = "unknown"
            result["standard"] = "unknown"
        }

        session.connect(to: firstTag, completionHandler: { (error: Error?) in
            if let error = error {
                self.result?(FlutterError(code: "500", message: "Error connecting to card", details: error.localizedDescription))
                self.result = nil
                return
            }
            self.tag = firstTag

            var ndefTag: NFCNDEFTag?
            switch self.tag {
            case let .iso7816(tag):
                ndefTag = tag
            case let .miFare(tag):
                ndefTag = tag
            case let .feliCa(tag):
                ndefTag = tag
            case let .iso15693(tag):
                ndefTag = tag
            default:
                ndefTag = nil
            }

            if ndefTag != nil {
                ndefTag!.queryNDEFStatus(completionHandler: { (status: NFCNDEFStatus, capacity: Int, error: Error?) in
                    if error == nil {
                        if status != NFCNDEFStatus.notSupported {
                            result["ndefAvailable"] = true
                        }
                        if status == NFCNDEFStatus.readWrite {
                            result["ndefWritable"] = true
                            result["ndefCanMakeReadOnly"] = true
                        }
                        result["ndefCapacity"] = capacity
                    }
                    // ignore error, just return with ndef disabled
                    let jsonData = try! JSONSerialization.data(withJSONObject: result)
                    let jsonString = String(data: jsonData, encoding: .utf8)
                    self.result?(jsonString)
                    self.result = nil
                })
            } else {
                let jsonData = try! JSONSerialization.data(withJSONObject: result)
                let jsonString = String(data: jsonData, encoding: .utf8)
                self.result?(jsonString)
                self.result = nil
            }
        })
    }
}
