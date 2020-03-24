package im.nfc.flutter_nfc_kit

import java.util.*
import java.io.IOException
import org.json.JSONObject
import kotlin.concurrent.schedule

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.NfcAdapter.*
import android.nfc.Tag
import android.nfc.tech.*
import android.os.Handler
import android.os.Looper

import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import im.nfc.flutter_nfc_kit.ByteUtils.hexToBytes
import im.nfc.flutter_nfc_kit.ByteUtils.toHexString


class FlutterNfcKitPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    companion object {
        private val TAG = FlutterNfcKitPlugin::class.java.name
        private var activity: Activity? = null
        private var pollingTimeoutTask: TimerTask? = null
        private var tagTechnology: TagTechnology? = null
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_nfc_kit")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        handleMethodCall(call, MethodResultWrapper(result))
    }

    private fun handleMethodCall(call: MethodCall, result: Result) {

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
                try {
                    tagTechnology?.close()
                } catch (ex: IOException) {
                    Log.e(TAG, "Close tag error", ex)
                }
                nfcAdapter.disableReaderMode(activity)
                result.success("")
            }


            "transceive" -> {
                val tagTech = tagTechnology
                val req = call.arguments as? String
                if (req == null) {
                    results.error("400", "Bad argument", null)
                    return
                }
                if (tagTech == null) {
                    result.error("406", "No tag polled", null)
                    return
                }
                if (!tagTech.isConnected) {
                    try {
                        tagTech.connect()
                    } catch (ex: IOException) {
                        Log.e(TAG, "Transceive Error: $req", ex)
                        result.error("500", "Communication error", ex.localizedMessage)
                    }
                }
                try {
                    val sendingBytes = req!!.hexToBytes()
                    val recvingBytes: ByteArray
                    when (tagTech) {
                        is IsoDep -> recvingBytes = tagTech.transceive(sendingBytes)
                        is NfcA -> recvingBytes = tagTech.transceive(sendingBytes)
                        is NfcB -> recvingBytes = tagTech.transceive(sendingBytes)
                        is NfcF -> recvingBytes = tagTech.transceive(sendingBytes)
                        is NfcV -> recvingBytes = tagTech.transceive(sendingBytes)
                        is MifareClassic -> recvingBytes = tagTech.transceive(sendingBytes)
                        is MifareUltralight -> recvingBytes = tagTech.transceive(sendingBytes)
                        else -> {
                            result.error("405", "Transceive not supported on this type of card", null)
                            return
                        }
                    }
                    val resp = recvingBytes.toHexString()
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
        tagTechnology = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

    override fun onDetachedFromActivityForConfigChanges() {}

    private fun pollTag(nfcAdapter: NfcAdapter, result: Result) {

        pollingTimeoutTask = Timer().schedule(20000) {
            nfcAdapter.disableReaderMode(activity)
            result.error("408", "Polling tag timeout", null)
        }

        nfcAdapter.enableReaderMode(activity, { tag ->
            pollingTimeoutTask?.cancel()

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
                val aTag = NfcA.get(tag)
                atqa = aTag.atqa.toHexString()
                sak = byteArrayOf(aTag.sak.toByte()).toHexString()
                when {
                    tag.techList.contains(IsoDep::class.java.name) -> {
                        standard = "ISO 14443-4 (Type A)"
                        type = "iso7816"
                        val isoDep = IsoDep.get(tag)
                        tagTechnology = isoDep
                        historicalBytes = isoDep.historicalBytes.toHexString()
                    }
                    tag.techList.contains(MifareClassic::class.java.name) -> {
                        standard = "ISO 14443-3 (Type A)"
                        type = "mifare_classic"
                    }
                    tag.techList.contains(MifareUltralight::class.java.name) -> {
                        standard = "ISO 14443-3 (Type A)"
                        type = "mifare_ultralight"
                    }
                    else -> {
                        standard = "ISO 14443-3 (Type A)"
                        type = "unknown"
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
                    tagTechnology = isoDep
                    hiLayerResponse = isoDep.hiLayerResponse.toHexString()
                } else {
                    type = "unknown"
                    standard = "ISO 14443-3 (Type B)"
                    tagTechnology = bTag
                }
            } else if (tag.techList.contains(NfcF::class.java.name)) {
                standard = "ISO 18092"
                type = "felica"
                val fTag = NfcF.get(tag)
                manufacturer = fTag.manufacturer.toHexString()
                systemCode = fTag.systemCode.toHexString()
            } else if (tag.techList.contains(NfcV::class.java.name)) {
                standard = "ISO 15693"
                type = "iso15693"
                val vTag = NfcV.get(tag)
                dsfId = vTag.dsfId.toHexString()
            } else {
                type = "unknown"
                standard = "unknown"
            }

            result.success(JSONObject(mapOf(
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
            )).toString())

        }, FLAG_READER_SKIP_NDEF_CHECK or FLAG_READER_NFC_A or FLAG_READER_NFC_B or FLAG_READER_NFC_V or FLAG_READER_NFC_F, null)
    }

    private class MethodResultWrapper internal constructor(result: MethodChannel.Result) : MethodChannel.Result {

        private val methodResult: MethodChannel.Result
        private var hasError: Boolean = false;

        init {
            methodResult = result
        }

        companion object {
            // a Handler is always thread-safe, so use a singleton here
            private val handler: Handler by lazy {
                Handler(Looper.getMainLooper())
            }
        }

        override fun success(result: Any?) {
            handler.post {
                ignoreIllegalState {
                    methodResult.success(result)
                }
            }
        }

        override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
            handler.post {
                ignoreIllegalState {
                    methodResult.error(errorCode, errorMessage, errorDetails)
                }
            }
        }

        override fun notImplemented() {
            handler.post {
                ignoreIllegalState {
                    methodResult.notImplemented()
                }
            }
        }

        private fun ignoreIllegalState(fn: () -> Unit) {
            try {
                if (!hasError) fn()
            } catch (e: IllegalStateException) {
                hasError = true;
                Log.w(TAG, "Exception occurred when using MethodChannel.Result: $e")
                Log.w(TAG, "Will ignore all following usage of object: $methodResult")
            }
        }
    }
}
