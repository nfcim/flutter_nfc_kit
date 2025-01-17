import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from "@ohos/flutter_ohos";
import { BusinessError } from "@kit.BasicServicesKit";
import { tag } from "@kit.ConnectivityKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { abilityAccessCtrl, bundleManager, PermissionRequestResult } from "@kit.AbilityKit";

interface NFCTag {
  type: string;
  standard: string;
  id: string;
}

function toHexString(arr: number[]): string {
  let res = "";
  for (let num of arr) {
    let part = num.toString(16);
    if (part.length === 1) {
      part = "0" + part;
    }
    res += part;
  }
  return res;
}

function fromHexString(s: string): number[] {
  let res: number[] = [];
  for (let i = 0;i < s.length;i += 2) {
    res.push(parseInt(s.substring(i, i+2), 16));
  }
  return res;
}

/** FlutterNfcKitPlugin **/
export default class FlutterNfcKitPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private tagInfo: tag.TagInfo | null = null;
  private tag: tag.TagSession | null = null;

  constructor() {
    hilog.info(0x0000, "FlutterNfcKitPlugin", "Plugin constructed");
  }

  getUniqueClassName(): string {
    return "FlutterNfcKitPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    hilog.info(0x0000, "FlutterNfcKitPlugin", "Plugin attached");
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_nfc_kit/method");
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    hilog.info(0x0000, "FlutterNfcKitPlugin", "Plugin detached");
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.info(0x0000, "FlutterNfcKitPlugin", "Plugin got method call: %{public}s", JSON.stringify(call));
    try {
      let elementName: bundleManager.ElementName = {
        bundleName: getContext().applicationInfo.name,
        abilityName: "EntryAbility" // TODO: do not hardcode
      };

      if (call.method == "getNFCAvailability") {
        // https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-nfccontroller-V5#nfccontrollerisnfcavailabledeprecated
        const isNFCAvailable = canIUse("SystemCapability.Communication.NFC.Core");
        if (isNFCAvailable) {
          hilog.info(0x0000, "FlutterNfcKitPlugin", "NFC is available");
          result.success("available");
        } else {
          hilog.info(0x0000, "FlutterNfcKitPlugin", "NFC is not available");
          result.success("not_supported");
        }
      } else if (call.method == "poll") {
        const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
        atManager.requestPermissionsFromUser(getContext(), ["ohos.permission.NFC_TAG"]).then((data: PermissionRequestResult) => {
          hilog.info(0x0000, "FlutterNfcKitPlugin", "Request nfc permission done: data=%{public}s", JSON.stringify(data));
          // poll for tag
          // https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-nfctag-V5#tagon11
          // TODO: compute discTech from args
          let discTech : number[] = [tag.NFC_A, tag.NFC_B];

          tag.on("readerMode", elementName, discTech, (err: BusinessError, tagInfo: tag.TagInfo) => {
            hilog.info(0x0000, "FlutterNfcKitPlugin", "Got tag: err=%{public}s, tagInfo=%{public}s", JSON.stringify(err), JSON.stringify(tagInfo));
            if (err) {
              result.error("500", "Failed to poll", err);
            } else {
              this.tagInfo = tagInfo;

              let res: NFCTag = {
                type: "unknown",
                standard: "unknown",
                id: toHexString(tagInfo.uid),
              };

              if (tagInfo.technology.includes(tag.NFC_A)) {
                let aTag = tag.getNfcA(tagInfo);
                if (tagInfo.technology.includes(tag.ISO_DEP)) {
                  let isoDepTag = tag.getIsoDep(tagInfo);
                  this.tag = isoDepTag;
                  res.type = "iso7816";
                  res.standard = "ISO 14443-4 (Type A)";
                } else {
                  this.tag = aTag;
                  res.type = "unknown";
                  res.standard = "ISO 14443-3 (Type A)";
                }
              } else if (tagInfo.technology.includes(tag.NFC_B)) {
                let bTag = tag.getNfcB(tagInfo);
                if (tagInfo.technology.includes(tag.ISO_DEP)) {
                  let isoDepTag = tag.getIsoDep(tagInfo);
                  this.tag = isoDepTag;
                  res.type = "iso7816";
                  res.standard = "ISO 14443-4 (Type B)";
                } else {
                  this.tag = bTag;
                  res.type = "unknown";
                  res.standard = "ISO 14443-3 (Type B)";
                }
              } else {
                // TODO: more types
              }
              result.success(JSON.stringify(res));
            }
          });
        }).catch((err: BusinessError) => {
          hilog.info(0x0000, "FlutterNfcKitPlugin", "Failed to request nfc permission: err=%{public}s", JSON.stringify(err));
          result.error("500", "Permission denied", err);
        });
      } else if (call.method == "transceive") {
        let tx: string = call.argument("data");
        hilog.info(0x0000, "FlutterNfcKitPlugin", "transceive: tx=%{public}s", JSON.stringify(tx));
        if (this.tag !== null) {
          this.tag!.connect();
          this.tag!.transmit(fromHexString(tx)).then((rx) => {
            hilog.info(0x0000, "FlutterNfcKitPlugin", "transceive: rx=%{public}s", JSON.stringify(rx));
            result.success(toHexString(rx));
          }).catch((err: BusinessError) => {
            hilog.info(0x0000, "FlutterNfcKitPlugin", "Failed to transceive: err=%{public}s", JSON.stringify(err));
            result.error("500", "Transceive failed", err);
          });
        } else {
          result.error("406", "No tag polled", null);
        }
      } else if (call.method == "finish") {
        // turn off reader mode
        tag.off("readerMode", elementName, (err: BusinessError, tagInfo: tag.TagInfo) => {});
        this.tag = null;
        result.success("");
      } else if (call.method == "setIosAlertMessage") {
        // do nothing, just for compatibility
        result.success("");
      } else if (call.method == "readNDEF") {
        // TODO
        result.success("[]");
      } else {
        hilog.info(0x0000, "FlutterNfcKitPlugin", "Not implemented method: %{public}s", call.method);
        result.notImplemented();
      }
    } catch (e) {
      hilog.info(0x0000, "FlutterNfcKitPlugin", "Got error: %{public}s", (e as BusinessError).message);
      result.error("500", "Got unexpected exception", e);
    }
  }
}