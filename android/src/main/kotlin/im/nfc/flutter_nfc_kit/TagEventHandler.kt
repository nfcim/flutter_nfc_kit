package im.nfc.flutter_nfc_kit

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.NfcAdapter.getDefaultAdapter
import android.nfc.tech.IsoDep
import android.nfc.tech.MifareClassic
import android.nfc.tech.MifareUltralight
import android.nfc.tech.Ndef
import android.nfc.tech.NfcA
import android.nfc.tech.NfcB
import android.nfc.tech.NfcF
import android.nfc.tech.NfcV
import android.os.Handler
import android.os.Looper
import im.nfc.flutter_nfc_kit.ByteUtils.toHexString
import im.nfc.flutter_nfc_kit.FlutterNfcKitPlugin.Companion.mifareInfo
import im.nfc.flutter_nfc_kit.FlutterNfcKitPlugin.Companion.ndefTechnology
import im.nfc.flutter_nfc_kit.FlutterNfcKitPlugin.Companion.tagTechnology
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import java.lang.ref.WeakReference


class TagEventHandler(activity: WeakReference<Activity>) : EventChannel.StreamHandler {
    private var _activity: WeakReference<Activity> = activity
    private val nfcAdapter: NfcAdapter = getDefaultAdapter(_activity.get())

    private val uiThreadHandler: Handler = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        val argsMap = arguments as? Map<*, *>
        val technologies = argsMap!!["technologies"] as Int

        val pollHandler = NfcAdapter.ReaderCallback { tag ->

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
            // NDEF
            var ndefAvailable = false
            var ndefWritable = false
            var ndefCanMakeReadOnly = false
            var ndefCapacity = 0
            var ndefType = ""

            if (tag.techList.contains(NfcA::class.java.name)) {
                val aTag = NfcA.get(tag)
                atqa = aTag.atqa.toHexString()
                sak = byteArrayOf(aTag.sak.toByte()).toHexString()
                tagTechnology = aTag
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
                        with(MifareClassic.get(tag)) {
                            tagTechnology = this
                            mifareInfo = MifareInfo(
                                this.type,
                                size,
                                MifareClassic.BLOCK_SIZE,
                                blockCount,
                                sectorCount
                            )
                        }
                    }

                    tag.techList.contains(MifareUltralight::class.java.name) -> {
                        standard = "ISO 14443-3 (Type A)"
                        type = "mifare_ultralight"
                        with(MifareUltralight.get(tag)) {
                            tagTechnology = this
                            mifareInfo = MifareInfo.fromUltralight(this.type)
                        }
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
                standard = "ISO 18092 (FeliCa)"
                type = "iso18092"
                val fTag = NfcF.get(tag)
                manufacturer = fTag.manufacturer.toHexString()
                systemCode = fTag.systemCode.toHexString()
                tagTechnology = fTag
            } else if (tag.techList.contains(NfcV::class.java.name)) {
                standard = "ISO 15693"
                type = "iso15693"
                val vTag = NfcV.get(tag)
                dsfId = vTag.dsfId.toHexString()
                tagTechnology = vTag
            } else {
                type = "unknown"
                standard = "unknown"
            }

            // detect ndef
            if (tag.techList.contains(Ndef::class.java.name)) {
                val ndefTag = Ndef.get(tag)
                ndefTechnology = ndefTag
                ndefAvailable = true
                ndefType = ndefTag.type
                ndefWritable = ndefTag.isWritable
                ndefCanMakeReadOnly = ndefTag.canMakeReadOnly()
                ndefCapacity = ndefTag.maxSize
            }

            val jsonResult = JSONObject(
                mapOf(
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
                    "dsfId" to dsfId,
                    "ndefAvailable" to ndefAvailable,
                    "ndefType" to ndefType,
                    "ndefWritable" to ndefWritable,
                    "ndefCanMakeReadOnly" to ndefCanMakeReadOnly,
                    "ndefCapacity" to ndefCapacity,
                )
            )

            if (mifareInfo != null) {
                with(mifareInfo!!) {
                    jsonResult.put(
                        "mifareInfo", JSONObject(
                            mapOf(
                                "type" to typeStr,
                                "size" to size,
                                "blockSize" to blockSize,
                                "blockCount" to blockCount,
                                "sectorCount" to sectorCount
                            )
                        )
                    )
                }
            }

            uiThreadHandler.post {
                events?.success(jsonResult.toString())
            }
        }

        nfcAdapter.enableReaderMode(_activity.get(), pollHandler, technologies, null)
    }

    override fun onCancel(p0: Any?) {
        nfcAdapter.disableReaderMode(_activity.get())
    }

}