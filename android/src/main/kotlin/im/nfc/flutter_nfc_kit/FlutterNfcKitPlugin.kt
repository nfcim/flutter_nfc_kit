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
                    result.error("405", "Transceive not supported", null)
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
                    result.error("500", "Communication error", null)
                } catch (ex: IllegalArgumentException) {
                    Log.e(TAG, "APDU Error: $req", ex)
                    result.error("400", "APDU format error", null)
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

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    override fun onDetachedFromActivityForConfigChanges() {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

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

            val type: String
            val id = tag.id.toHexString()
            val standard: String
            var atqa = ""
            var sak = ""
            var historicalBytes = ""
            var protocolInfo = ""
            var applicationData = ""
            var hiLayerResponse = ""

            if (tag.techList.contains(NfcA::class.java.name)) {
                val aTag = NfcA.get(tag)
                atqa = aTag.atqa.toHexString()
                sak = byteArrayOf(aTag.sak.toByte()).toHexString()
                when {
                    tag.techList.contains(IsoDep::class.java.name) -> {
                        type = "iso7816"
                        standard = "ISO 14443-4 (Type A)"
                        val isoDep = IsoDep.get(tag)
                        historicalBytes = isoDep.historicalBytes.toHexString()
                    }
                    tag.techList.contains(MifareClassic::class.java.name) -> {
                        type = "mifare_classic"
                        standard = "ISO 14443-3 (Type A)"
                    }
                    tag.techList.contains(MifareUltralight::class.java.name) -> {
                        type = "mifare_ultralight"
                        standard = "ISO 14443-3 (Type A)"
                    }
                    else -> {
                        type = "unknown"
                        standard = "ISO 14443-3 (Type A)"
                    }
                }
            } else if (tag.techList.contains(NfcB::class.java.name)) {
                val bTag = NfcB.get(tag)
                protocolInfo = bTag.protocolInfo.toHexString()
                applicationData = bTag.applicationData.toHexString()
                if (tag.techList.contains(IsoDep::class.java.name)) {
                    type = "iso7816"
                    standard = "ISO 14443-4 (Type B)"
                    val isoDep = IsoDep.get(tag)
                    hiLayerResponse = isoDep.hiLayerResponse.toHexString()
                } else {
                    type = "unknown"
                    standard = "ISO 14443-3 (Type B)"
                }
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
                        "hiLayerResponse" to hiLayerResponse
                ))
            }
        }, FLAG_READER_SKIP_NDEF_CHECK or FLAG_READER_NFC_A or FLAG_READER_NFC_B or FLAG_READER_NFC_V or FLAG_READER_NFC_F, null)
    }
}
