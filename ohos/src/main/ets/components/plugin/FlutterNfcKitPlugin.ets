import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { BusinessError } from '@kit.BasicServicesKit';
import { tag } from '@kit.ConnectivityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { abilityAccessCtrl, bundleManager, PermissionRequestResult } from '@kit.AbilityKit';

/** FlutterNfcKitPlugin **/
export default class FlutterNfcKitPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private tagInfo: tag.TagInfo | null = null;

  constructor() {
    hilog.info(0x0000, 'FlutterNfcKitPlugin', 'Plugin constructed');
  }

  getUniqueClassName(): string {
    return "FlutterNfcKitPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    hilog.info(0x0000, 'FlutterNfcKitPlugin', 'Plugin attached');
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_nfc_kit");
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    hilog.info(0x0000, 'FlutterNfcKitPlugin', 'Plugin detached');
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.info(0x0000, 'FlutterNfcKitPlugin', 'Plugin got method call: %{public}s', JSON.stringify(call));

    try {
      if (call.method == "getNFCAvailability") {
        // https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-nfccontroller-V5#nfccontrollerisnfcavailabledeprecated
        const isNFCAvailable = canIUse('SystemCapability.Communication.NFC.Core');
        if (isNFCAvailable) {
          result.success("available");
        } else {
          result.success("not_supported");
        }
      } else if (call.method == "poll") {
        const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
        atManager.requestPermissionsFromUser(getContext(), ['ohos.permission.NFC_TAG']).then((data: PermissionRequestResult) => {
          hilog.info(0x0000, 'FlutterNfcKitPlugin', 'Request nfc permission done: data=%{public}s', JSON.stringify(data));
          // poll for tag
          // https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-nfctag-V5#tagon11
          // TODO: compute discTech from args
          let discTech : number[] = [tag.NFC_A, tag.NFC_B];

          let elementName : bundleManager.ElementName = {
            bundleName: getContext().applicationInfo.name,
            abilityName: "EntryAbility" // TODO: do not hardcode
          };

          tag.on('readerMode', elementName, discTech, (err: BusinessError, tagInfo: tag.TagInfo) => {
            hilog.info(0x0000, 'FlutterNfcKitPlugin', 'Got tag: err=%{public}s, tagInfo=%{public}s', JSON.stringify(err), JSON.stringify(tagInfo));
            if (err) {
              result.error("500", "Failed to poll", err);
            } else {
              this.tagInfo = tagInfo;
              result.success(JSON.stringify({
                type: 'unknown',
                standard: 'TODO',
                id: 'TODO',
                atqa: 'TODO',
                sak: 'TODO',
                historicalBytes: 'TODO',
                hiLayerResponse: 'TODO',
                protocolInfo: 'TODO',
                applicationData: 'TODO',
                manufacturer: 'TODO',
                systemCode: 'TODO',
                dsfId: 'TODO',
                ndefAvailable: false,
                ndefCapacity: 0,
                ndefWritable: false,
                ndefCanMakeReadOnly: false
              }));
            }
          });
        }).catch((err: BusinessError) => {
          hilog.info(0x0000, 'FlutterNfcKitPlugin', 'Failed to request nfc permission: err=%{public}s', JSON.stringify(err));
          result.error("500", "Permission denied", err);
        });
      } else {
        result.notImplemented();
      }
    } catch (e) {
      hilog.info(0x0000, 'FlutterNfcKitPlugin', 'Got error: %{public}s', (e as BusinessError).message);
      result.error("500", "Got unexpected exception", e);
    }
  }
}