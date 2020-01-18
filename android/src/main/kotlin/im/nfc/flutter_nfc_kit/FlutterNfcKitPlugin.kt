package im.nfc.flutter_nfc_kit

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.NfcAdapter.*
import android.nfc.tech.*
import androidx.annotation.NonNull
import im.nfc.flutter_nfc_kit.ByteUtils.toHexString
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*
import kotlin.concurrent.schedule

/** FlutterNfcKitPlugin */
class FlutterNfcKitPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    companion object {
        private var activity: Activity? = null
        private var nfcAdapter: NfcAdapter? = null
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_nfc_kit")
        channel.setMethodCallHandler(FlutterNfcKitPlugin())
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (nfcAdapter?.isEnabled != true && call.method != "getNFCAvailability") {
            result.error("404", "NFC not available", null)
            return
        }

        when (call.method) {
            "getNFCAvailability" -> {
                when {
                    nfcAdapter == null -> result.success("not_supported")
                    nfcAdapter!!.isEnabled -> result.success("available")
                    else -> result.success("disabled")
                }
            }
            "poll" -> {
                Timer().schedule(20000) {
                    nfcAdapter!!.disableReaderMode(activity)
                    activity!!.runOnUiThread {
                        result.error("408", "Polling tag timeout.", null)
                    }
                }
                nfcAdapter!!.enableReaderMode(activity, { tag ->
                    val type: String
                    val id = tag.id.toHexString()
                    val standard: String
                    var atqa = ""
                    var sak = ""
                    var historicalBytes = ""
                    var protocolInfo = ""
                    var applicationData = ""

                    if (tag.techList.contains(NfcA::class.java.name)) {
                        val aTag = NfcA.get(tag)
                        atqa = aTag.atqa.toHexString()
                        sak = byteArrayOf(aTag.sak.toByte()).toHexString()
                        when {
                            tag.techList.contains(IsoDep::class.java.name) -> {
                                type = "iso7816"
                                standard = "ISO 14443-4 (Type A)"
                                historicalBytes = IsoDep.get(tag).historicalBytes.toHexString()
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
                        } else {
                            type = "unknown"
                            standard = "ISO 14443-3 (Type B)"
                        }
                    } else {
                        type = "unknown"
                        standard = "unknown"
                    }
                    activity!!.runOnUiThread {
                        result.success(mapOf(
                                "type" to type,
                                "id" to id,
                                "standard" to standard,
                                "atqa" to atqa,
                                "sak" to sak,
                                "historicalBytes" to historicalBytes,
                                "protocolInfo" to protocolInfo,
                                "applicationData" to applicationData
                        ))
                    }
                }, FLAG_READER_SKIP_NDEF_CHECK or FLAG_READER_NFC_A or FLAG_READER_NFC_B, null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    }

    override fun onDetachedFromActivity() {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        nfcAdapter = getDefaultAdapter(activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }
}
