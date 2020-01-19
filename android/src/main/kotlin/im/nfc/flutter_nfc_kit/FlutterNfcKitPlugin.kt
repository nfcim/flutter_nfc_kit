package im.nfc.flutter_nfc_kit

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.NfcAdapter.*
import android.nfc.Tag
import android.nfc.tech.*
import im.nfc.flutter_nfc_kit.ByteUtils.hexToBytes
import im.nfc.flutter_nfc_kit.ByteUtils.toHexString
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException
import java.util.*
import kotlin.concurrent.schedule


class FlutterNfcKitPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    companion object {
        private val TAG = FlutterNfcKitPlugin::class.java.name
        private var activity: Activity? = null
        private var pollingTimeoutTask: TimerTask? = null
        private var tag: Tag? = null
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_nfc_kit")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val nfcAdapter = getDefaultAdapter(activity)

        if (nfcAdapter?.isEnabled != true && call.method != "getNFCAvailability") {
            result.error("404", "NFC not available", null)
            return
        }

        when (call.method) {

            "getNFCAvailability" -> {
                when {
                    nfcAdapter == null -> result.success("not_supported")
                    nfcAdapter.isEnabled -> result.success("available")
                    else -> result.success("disabled")
                }
            }

            "poll" -> pollTag(nfcAdapter, result)

            "finish" -> {
                pollingTimeoutTask?.cancel()
                nfcAdapter.disableReaderMode(activity)
            }


            "transceive" -> {
                if (tag == null) {
                    result.error("406", "No tag polled", null)
                    return
                }
                val isoDep = IsoDep.get(tag)
                if (isoDep == null) {
                    result.error("405", "Transceive not yet supported on this type of card", null)
                    return
                }
                val req = call.arguments as String
                try {
                    isoDep.connect()
                    val resp = isoDep.transceive(req.hexToBytes()).toHexString()
                    isoDep.close()
                    Log.d(TAG, "Transceive: $req, $resp")
                    result.success(resp)
                } catch (ex: IOException) {
                    Log.e(TAG, "Transceive Error: $req", ex)
                    result.error("500", "Communication error", ex.localizedMessage)
                } catch (ex: IllegalArgumentException) {
                    Log.e(TAG, "APDU Error: $req", ex)
                    result.error("400", "APDU format error", ex.localizedMessage)
                }
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        if (activity != null) return
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        pollingTimeoutTask?.cancel()
        pollingTimeoutTask = null
        tag = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

    override fun onDetachedFromActivityForConfigChanges() {}

    private fun pollTag(nfcAdapter: NfcAdapter, result: Result) {
        pollingTimeoutTask = Timer().schedule(20000) {
            nfcAdapter.disableReaderMode(activity)
            activity?.runOnUiThread {
                result.error("408", "Polling tag timeout", null)
            }
        }

        nfcAdapter.enableReaderMode(activity, { tag ->
            pollingTimeoutTask?.cancel()

            FlutterNfcKitPlugin.tag = tag

            // common fields
            val type: String
            val id = tag.id.toHexString()
            val standard: String
            // ISO 14443 Type A
            var atqa = ""
            var sak = ""
            // ISO 14443 Type B
            var protocolInfo = ""
            var applicationData = ""
            // ISO 7816
            var historicalBytes = ""
            var hiLayerResponse = ""
            // NFC-F / Felica
            var manufacturer = ""
            var systemCode = ""
            // NFC-V
            var dsfId = ""

            if (tag.techList.contains(NfcA::class.java.name)) {
                standard = "ISO 14443-4 (Type A)"
                val aTag = NfcA.get(tag)
                atqa = aTag.atqa.toHexString()
                sak = byteArrayOf(aTag.sak.toByte()).toHexString()
                when {
                    tag.techList.contains(IsoDep::class.java.name) -> {
                        type = "iso7816"
                        historicalBytes = IsoDep.get(tag).historicalBytes.toHexString()
                    }
                    tag.techList.contains(MifareClassic::class.java.name) -> {
                        type = "mifare_classic"
                    }
                    tag.techList.contains(MifareUltralight::class.java.name) -> {
                        type = "mifare_ultralight"
                    }
                    else -> {
                        type = "unknown"
                    }
                }
            } else if (tag.techList.contains(NfcB::class.java.name)) {
                standard = "ISO 14443-4 (Type B)"
                val bTag = NfcB.get(tag)
                protocolInfo = bTag.protocolInfo.toHexString()
                applicationData = bTag.applicationData.toHexString()
                if (tag.techList.contains(IsoDep::class.java.name)) {
                    type = "iso7816"
                    hiLayerResponse = IsoDep.get(tag).hiLayerResponse.toHexString()
                } else {
                    type = "unknown"
                }
            } else if (tag.techList.contains(NfcF::class.java.name)) {
                standard = "ISO 18092 (Felica)"
                type = "N/A"
                val fTag = NfcF.get(tag)
                manufacturer = fTag.manufacturer.toHexString()
                systemCode = fTag.systemCode.toHexString()
            } else if (tag.techList.contains(NfcF::class.java.name)) {
                standard = "ISO 15693"
                type = "N/A"
                val vTag = NfcV.get(tag)
                dsfId = vTag.dsfId.toHexString()
            } else {
                type = "unknown"
                standard = "unknown"
            }
            activity?.runOnUiThread {
                result.success(mapOf(
                        "type" to type,
                        "id" to id,
                        "standard" to standard,
                        "atqa" to atqa,
                        "sak" to sak,
                        "historicalBytes" to historicalBytes,
                        "protocolInfo" to protocolInfo,
                        "applicationData" to applicationData,
                        "hiLayerResponse" to hiLayerResponse,
                        "manufacturer" to manufacturer,
                        "systemCode" to systemCode,
                        "dsfId" to dsfId
                ))
            }
        }, FLAG_READER_SKIP_NDEF_CHECK or FLAG_READER_NFC_A or FLAG_READER_NFC_B or FLAG_READER_NFC_V or FLAG_READER_NFC_F, null)
    }
}
