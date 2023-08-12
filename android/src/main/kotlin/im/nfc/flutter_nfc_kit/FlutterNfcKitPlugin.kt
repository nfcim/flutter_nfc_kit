package im.nfc.flutter_nfc_kit

import android.app.Activity
import android.nfc.FormatException
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.NfcAdapter.*
import android.nfc.Tag
import android.nfc.tech.*
import android.os.Handler
import android.os.Looper
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
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.lang.reflect.InvocationTargetException
import java.util.*
import kotlin.concurrent.schedule
import kotlin.concurrent.thread


class FlutterNfcKitPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    companion object {
        private val TAG = FlutterNfcKitPlugin::class.java.name
        private var activity: Activity? = null
        private var pollingTimeoutTask: TimerTask? = null
        private var tagTechnology: TagTechnology? = null
        private var ndefTechnology: Ndef? = null
        private var isMifareClassic: Boolean = false;
        private var isMifareUltralight: Boolean = false;

        private fun TagTechnology.transceive(data: ByteArray, timeout: Int?): ByteArray {
            if (timeout != null) {
                try {
                    val timeoutMethod = this.javaClass.getMethod("setTimeout", Int::class.java)
                    timeoutMethod.invoke(this, timeout)
                } catch (ex: Throwable) {
                }
            }
            val transceiveMethod = this.javaClass.getMethod("transceive", ByteArray::class.java)
            return transceiveMethod.invoke(this, data) as ByteArray
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_nfc_kit")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        handleMethodCall(call, MethodResultWrapper(result))
    }

    private fun handleMethodCall(call: MethodCall, result: Result) {

        if (activity == null) {
            result.error("500", "Cannot call method when not attached to activity", null)
            return
        }

        val nfcAdapter = getDefaultAdapter(activity)

        if (nfcAdapter?.isEnabled != true && call.method != "getNFCAvailability") {
            result.error("404", "NFC not available", null)
            return
        }

        val ensureNDEF = {
            if (ndefTechnology == null) {
                if (tagTechnology == null) {
                    result.error("406", "No tag polled", null)
                } else {
                    result.error("405", "NDEF not supported on current tag", null)
                }
                false
            } else true
        }

        val switchTechnology = { target: TagTechnology, other: TagTechnology? ->
            if (!target.isConnected) {
                // close previously connected technology
                if (other !== null && other.isConnected) {
                    other.close()
                }
                target.connect()
            }
        }

        val closeTechnology = {tagTech: TagTechnology? ->
            if (tagTech !==null && tagTech.isConnected) {
                tagTech.close()
            }
        }

        when (call.method) {

            "getNFCAvailability" -> {
                when {
                    nfcAdapter == null -> result.success("not_supported")
                    nfcAdapter.isEnabled -> result.success("available")
                    else -> result.success("disabled")
                }
            }

            "poll" -> {
                val timeout = call.argument<Int>("timeout")!!
                // technology and option bits are set in Dart code
                val technologies = call.argument<Int>("technologies")!!
                thread {
                    pollTag(nfcAdapter, result, timeout, technologies)
                }
            }

            "finish" -> {
                pollingTimeoutTask?.cancel()
                thread {
                    try {
                        val tagTech = tagTechnology
                        if (tagTech != null && tagTech.isConnected) {
                            tagTech.close()
                        }
                        val ndefTech = ndefTechnology
                        if (ndefTech != null && ndefTech.isConnected) {
                            ndefTech.close()
                        }
                    } catch (ex: IOException) {
                        Log.e(TAG, "Close tag error", ex)
                    }
                    if (activity != null) {
                        nfcAdapter.disableReaderMode(activity)
                    }
                    result.success("")
                }
            }

            "transceive" -> {
                val tagTech = tagTechnology
                val req = call.argument<Any>("data")
                if (req == null || (req !is String && req !is ByteArray)) {
                    result.error("400", "Bad argument", null)
                    return
                }
                if (tagTech == null) {
                    result.error("406", "No tag polled", null)
                    return
                }

                thread {
                    try {
                        switchTechnology(tagTech, ndefTechnology)
                        val sendingBytes = when (req) {
                            is String -> req.hexToBytes()
                            else -> req as ByteArray
                        }
                        val timeout = call.argument<Int>("timeout")
                        val resp = tagTech.transceive(sendingBytes, timeout)
                        when (req) {
                            is String -> result.success(resp.toHexString())
                            else -> result.success(resp)
                        }
                    } catch (ex: IOException) {
                        Log.e(TAG, "Transceive Error: $req", ex)
                        result.error("500", "Communication error", ex.localizedMessage)
                    } catch (ex: InvocationTargetException) {
                        Log.e(TAG, "Transceive Error: $req", ex.cause ?: ex)
                        result.error("500", "Communication error", ex.cause?.localizedMessage)
                    } catch (ex: IllegalArgumentException) {
                        Log.e(TAG, "Command Error: $req", ex)
                        result.error("400", "Command format error", ex.localizedMessage)
                    } catch (ex: NoSuchMethodException) {
                        Log.e(TAG, "Transceive not supported: $req", ex)
                        result.error("405", "Transceive not supported for this type of card", null)
                    }
                }
            }

            "readNDEF" -> {
                if (!ensureNDEF()) return
                val ndef = ndefTechnology!!
                thread {
                    try {
                        switchTechnology(ndef, tagTechnology)
                        // read NDEF message
                        val message: NdefMessage? = if (call.argument<Boolean>("cached")!!) {
                            ndef.cachedNdefMessage
                        } else {
                            ndef.ndefMessage
                        }
                        val parsedMessages = mutableListOf<Map<String, String>>()
                        if (message != null) {
                            for (record in message.records) {
                                parsedMessages.add(mapOf(
                                        "identifier" to record.id.toHexString(),
                                        "payload" to record.payload.toHexString(),
                                        "type" to record.type.toHexString(),
                                        "typeNameFormat" to when (record.tnf) {
                                            NdefRecord.TNF_ABSOLUTE_URI -> "absoluteURI"
                                            NdefRecord.TNF_EMPTY -> "empty"
                                            NdefRecord.TNF_EXTERNAL_TYPE -> "nfcExternal"
                                            NdefRecord.TNF_WELL_KNOWN -> "nfcWellKnown"
                                            NdefRecord.TNF_MIME_MEDIA -> "media"
                                            NdefRecord.TNF_UNCHANGED -> "unchanged"
                                            else -> "unknown"
                                        }
                                ))
                            }
                        }
                        result.success(JSONArray(parsedMessages).toString())
                    } catch (ex: IOException) {
                        Log.e(TAG, "Read NDEF Error", ex)
                        result.error("500", "Communication error", ex.localizedMessage)
                    } catch (ex: FormatException) {
                        Log.e(TAG, "NDEF Format Error", ex)
                        result.error("400", "NDEF format error", ex.localizedMessage)
                    }
                }
            }

            "writeNDEF" -> {
                if (!ensureNDEF()) return
                val ndef = ndefTechnology!!
                if (ndef.isWritable() == false) {
                    result.error("405", "Tag not writable", null)
                    return
                }
                thread {
                    try {
                        switchTechnology(ndef, tagTechnology)
                        // generate NDEF message
                        val jsonString = call.argument<String>("data")!!
                        val recordData = JSONArray(jsonString)
                        val records = Array<NdefRecord>(recordData.length(), init = { i: Int ->
                            val record: JSONObject = recordData.get(i) as JSONObject
                            NdefRecord(
                                    when (record.getString("typeNameFormat")) {
                                        "absoluteURI" -> NdefRecord.TNF_ABSOLUTE_URI
                                        "empty" -> NdefRecord.TNF_EMPTY
                                        "nfcExternal" -> NdefRecord.TNF_EXTERNAL_TYPE
                                        "nfcWellKnown" -> NdefRecord.TNF_WELL_KNOWN
                                        "media" -> NdefRecord.TNF_MIME_MEDIA
                                        "unchanged" -> NdefRecord.TNF_UNCHANGED
                                        else -> NdefRecord.TNF_UNKNOWN
                                    },
                                    record.getString("type").hexToBytes(),
                                    record.getString("identifier").hexToBytes(),
                                    record.getString("payload").hexToBytes()
                            )
                        })
                        // write NDEF message
                        val message: NdefMessage = NdefMessage(records)
                        ndef.writeNdefMessage(message)
                        result.success("")
                    } catch (ex: IOException) {
                        Log.e(TAG, "Write NDEF Error", ex)
                        result.error("500", "Communication error", ex.localizedMessage)
                    } catch (ex: FormatException) {
                        Log.e(TAG, "NDEF Format Error", ex)
                        result.error("400", "NDEF format error", ex.localizedMessage)
                    }
                }
            }

            "makeNdefReadOnly" -> {
                if (!ensureNDEF()) return
                val ndef = ndefTechnology!!
                if (ndef.isWritable() == false) {
                    result.error("405", "Tag not writable", null)
                    return
                }
                thread {
                    try {
                        switchTechnology(ndef, tagTechnology)
                        if (ndef.makeReadOnly()) {
                            result.success("")
                        } else {
                            result.error("500", "Failed to lock NDEF tag", null)
                        }
                    } catch (ex: IOException) {
                        Log.e(TAG, "Lock NDEF Error", ex)
                        result.error("500", "Communication error", ex.localizedMessage)
                    }
                }
            }

            "readBlock" -> {
                val blockIndex = call.argument<Int>("blockIndex")!!
                val authenticateKeyA = call.argument<String>("authenticateKeyA")
                var authenticateKey: ByteArray? = null
                if (!authenticateKeyA.isNullOrEmpty()) {
                    authenticateKey = authenticateKeyA.hexToBytes()
                }
                thread {
                    try {
                        closeTechnology(ndefTechnology)
                        closeTechnology(tagTechnology)
                        readBlock(result, blockIndex, authenticateKey)
                    } catch (e: IOException) {
                        Log.e(TAG, "Read Mifare Tag In Block $blockIndex Error", e)
                    }
                }
            }

            "readAll" -> {
                val authenticateKeyA = call.argument<String>("authenticateKeyA")
                var authenticateKey: ByteArray? = null
                if (!authenticateKeyA.isNullOrEmpty()) {
                    authenticateKey = authenticateKeyA.hexToBytes()
                }
                thread {
                    try {
                        closeTechnology(ndefTechnology)
                        closeTechnology(tagTechnology)
                        readAll(result,authenticateKey)
                    } catch (e: Exception) {
                        Log.e(TAG, "Read Mifare Tag All Error", e)
                    }
                }
            }

            "readSector" -> {
                val sectorIndex = call.argument<Int>("sectorIndex")!!
                val authenticateKeyA = call.argument<String>("authenticateKeyA")
                var authenticateKey: ByteArray? = null
                if (!authenticateKeyA.isNullOrEmpty()) {
                    authenticateKey = authenticateKeyA.hexToBytes()
                }
                thread {
                    try {
                        closeTechnology(ndefTechnology)
                        closeTechnology(tagTechnology)
                        readSector(result, sectorIndex, authenticateKey)
                    } catch (e: Exception) {
                        Log.e(TAG, "Read Mifare In Sector $sectorIndex Error", e)
                    }
                }
            }


            "writeBlock" -> {
                val blockIndex = call.argument<Int>("blockIndex")!!
                val authenticateKeyA = call.argument<String>("authenticateKeyA")
                val message = call.argument<String>("message")!!
                var authenticateKey: ByteArray? = null
                if (!authenticateKeyA.isNullOrEmpty()) {
                    authenticateKey = authenticateKeyA.hexToBytes()
                }
                thread {
                    try {
                        closeTechnology(ndefTechnology)
                        closeTechnology(tagTechnology)
                        writeBlock(result, blockIndex, authenticateKey, message.hexToBytes())
                    } catch (ex: IOException) {
                        Log.e(TAG, "Write Mifare Tag Error", ex)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun readBlock(result: Result, blockIndex: Int, authenticateKeyA: ByteArray?) {
        // MifareClassic
        if (isMifareClassic) {
            val sectorAuthenticateKeyA: ByteArray? = if (authenticateKeyA?.isEmpty() == null) {
                MifareClassic.KEY_DEFAULT
            } else {
                authenticateKeyA
            }
            val mifareClassic = MifareClassic.get(tagTechnology?.tag)
            try {
                mifareClassic.connect()
                val sectorIndex = mifareClassic.blockToSector(blockIndex)
                mifareClassic.authenticateSectorWithKeyA(sectorIndex, sectorAuthenticateKeyA)
                var blockBytes = mifareClassic.readBlock(blockIndex)
                if (blockBytes != null) {
                    if (blockBytes.size < 16) {
                        throw IOException()
                    }
                }
                if (blockBytes != null) {
                    if (blockBytes.size > 16) {
                        blockBytes = blockBytes.copyOf(16)
                    }
                }
                Log.d(TAG, "readBlock: ${blockBytes.toHexString()}")
                activity?.runOnUiThread { result.success(blockBytes.toHexString()) }
            } catch (ex: IOException) {
                Log.e(TAG, "Read Block Error", ex)
                activity?.runOnUiThread { result.error("501", ex.localizedMessage, null) }
            } finally {
                mifareClassic.close()
            }
        } else if (isMifareUltralight) { // MifareUltralight
            val mifareUltralight = MifareUltralight.get(tagTechnology?.tag)
            try {
                mifareUltralight.connect()
                // For mifareUltralight block is page offset
                var blockBytes = mifareUltralight.readPages(blockIndex)
                Log.d(TAG, "readBlock: ${blockBytes.toHexString()}")
                activity?.runOnUiThread { result.success(blockBytes.toHexString()) }
            } catch (ex: IOException) {
                Log.e(TAG, "error", ex)
                activity?.runOnUiThread { result.error("501", ex.localizedMessage, null) }
            } finally {
                mifareUltralight.close()
            }
        }
    }

    private fun readSector(result: Result, sectorIndex: Int, authenticateKeyA: ByteArray?) {
        if (isMifareClassic) {
            val mifareClassic = MifareClassic.get(tagTechnology?.tag)
            try {
                val sectorAuthenticateKeyA: ByteArray? = if (authenticateKeyA?.isEmpty() == null) {
                    MifareClassic.KEY_DEFAULT
                } else {
                    authenticateKeyA
                }
                mifareClassic.connect()
                mifareClassic.authenticateSectorWithKeyA(sectorIndex,sectorAuthenticateKeyA)
                val sector = ByteUtils.mifareClassPrintEntireBlock(mifareClassic, sectorIndex)
                activity?.runOnUiThread { result.success(sector) }
            } catch (e: Exception) {
                Log.e(TAG, "read sector error", e)
                activity?.runOnUiThread { result.error("502", e.localizedMessage, null) }
            } finally {
                mifareClassic.close()
            }
        }
    }

    private fun readAll(result: Result, authenticateKeyA: ByteArray?) {
        val response = mutableMapOf<Int, List<String>>()
        if (isMifareClassic) {
            val mifareClassic = MifareClassic.get(tagTechnology?.tag)
            try {
                val sectorAuthenticateKeyA: ByteArray? = if (authenticateKeyA?.isEmpty() == null) {
                    MifareClassic.KEY_DEFAULT
                } else {
                    authenticateKeyA
                }
                mifareClassic.connect()
                for (i in 0 until mifareClassic.sectorCount) {
                    mifareClassic.authenticateSectorWithKeyA(i, sectorAuthenticateKeyA)
                    response[i] = ByteUtils.mifareClassPrintEntireBlock(mifareClassic, i)
                }
                activity?.runOnUiThread { result.success(response) }
            } catch (e:java.lang.Exception) {
                Log.e(TAG, "Read MifareClassic All Error: ", e)
                activity?.runOnUiThread { result.error("503", e.localizedMessage, null) }
            } finally {
                mifareClassic.close()
            }
        } else if (isMifareUltralight) {
            val  mifareUltralight = MifareUltralight.get(tagTechnology?.tag)
            try {
                mifareUltralight.connect()
                for (i in 0 until 16) {
                    response[i] = ByteUtils.mifareUltralightPrintEntireBlock(mifareUltralight, i)
                }
                activity?.runOnUiThread { result.success(response) }
            } catch (ex: Exception) {
                Log.e(TAG, "Read MifareUltralight All Error: ", ex)
                activity?.runOnUiThread { result.error("503", ex.localizedMessage, null) }
            } finally {
                mifareUltralight.close()
            }
        }
    }
    private fun writeBlock(result: Result, blockIndex: Int, authenticateKeyA: ByteArray?, message: ByteArray) {
        if (isMifareClassic) {
            val sectorAuthenticateKeyA: ByteArray? = if (authenticateKeyA?.isEmpty() == null) {
                MifareClassic.KEY_DEFAULT
            } else {
                authenticateKeyA
            }
            val mifareClassic = MifareClassic.get(tagTechnology?.tag)
            Log.d(TAG, "Write Block Of Sector: $message")
            try {
                mifareClassic.connect()
                val sectorIndex = mifareClassic.blockToSector(blockIndex)
                mifareClassic.authenticateSectorWithKeyA(sectorIndex, sectorAuthenticateKeyA)
                mifareClassic.writeBlock(
                    blockIndex,
                    message
                )
            } catch (ex: IOException) {
                Log.e(TAG, "MifareClassic Write Error:", ex)
                activity?.runOnUiThread { result.error("504", ex.localizedMessage, null) }
            } finally {
                mifareClassic.close()
            }
        } else if (isMifareUltralight) { // MifareUltralight
            val mifareUltralight = MifareUltralight.get(tagTechnology?.tag)
            try {
                mifareUltralight.connect()
                if (blockIndex < 4) {
                    // block index in mifareUltralight must be more than 4
                    throw IOException("Error block index in mifareUltralight must be more than 4")
                }
                mifareUltralight.writePage(
                    blockIndex,
                    message
                )
            } catch (ex: IOException) {
                Log.e(TAG, "MifareUltralight Write Error:", ex)
                activity?.runOnUiThread { result.error("504", ex.localizedMessage, null) }
            } finally {
                mifareUltralight.close()
            }
        }
    }
    private fun getMaxTransceiveLength(): Int {
        if (isMifareClassic) {
            try {
                val mifareClassic = MifareClassic.get(tagTechnology?.tag)
                val maxTransceiveLen = mifareClassic.maxTransceiveLength
                return maxTransceiveLen
            } catch (ex: Exception) {
                Log.e(TAG, "Get MifareClassic Max Transceive Length Error", ex)
            }
        } else if (isMifareUltralight) {
            try {
                val mifareUltralight = MifareUltralight.get(tagTechnology?.tag)
                val maxTransceiveLen = mifareUltralight.maxTransceiveLength
                return maxTransceiveLen
            } catch (ex: Exception) {
                Log.e(TAG, "Get MifareUltralight Max Transceive Length Error", ex)
            }
        }
        return -1
    }
    /// Return the type of this MIFARE Classic compatible tag.
    /// One of TYPE_UNKNOWN, TYPE_CLASSIC, TYPE_PLUS or TYPE_PRO.
    private fun mifareClassicGetType(): Int {
        return MifareClassic.get(tagTechnology?.tag).type
    }
    /// Return the size of the tag in bytes
    /// One of SIZE_MINI, SIZE_1K, SIZE_2K, SIZE_4K. These constants are equal to their respective size in bytes.
    private fun mifareClassicGetSize(): Int {
        return MifareClassic.get(tagTechnology?.tag).size
    }
    /// Return the number of MIFARE Classic sectors.
    private fun mifareClassicGetSectorCount(): Int {
        return MifareClassic.get(tagTechnology?.tag).sectorCount;
    }
    /// Return the total number of MIFARE Classic blocks.
    private fun mifareClassGetBlockCount(): Int {
        return MifareClassic.get(tagTechnology?.tag).blockCount;
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
        ndefTechnology = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

    override fun onDetachedFromActivityForConfigChanges() {}

    private fun pollTag(nfcAdapter: NfcAdapter, result: Result, timeout: Int, technologies: Int) {

        pollingTimeoutTask = Timer().schedule(timeout.toLong()) {
            if (activity != null) {
                nfcAdapter.disableReaderMode(activity)
            }
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
            // NDEF
            var ndefAvailable = false
            var ndefWritable = false
            var ndefCanMakeReadOnly = false
            var ndefCapacity = 0
            var ndefType = ""
            // Mifare
            var mifareClassType: Int? = null
            var mifareClassSize: Int? = null
            var mifareClassSectorCount: Int? = null
            var mifareClassicBlockCount: Int? = null
            var mifareMaxTransceiveLength: Int? = null

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
                        isMifareClassic = true
                        mifareClassType = mifareClassicGetType()
                        mifareClassSize = mifareClassicGetSize()
                        mifareClassSectorCount = mifareClassicGetSectorCount()
                        mifareClassicBlockCount = mifareClassGetBlockCount()
                        mifareMaxTransceiveLength = getMaxTransceiveLength()
                    }
                    tag.techList.contains(MifareUltralight::class.java.name) -> {
                        standard = "ISO 14443-3 (Type A)"
                        type = "mifare_ultralight"
                        isMifareUltralight = true
                        mifareMaxTransceiveLength = getMaxTransceiveLength()
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
                    "dsfId" to dsfId,
                    "ndefAvailable" to ndefAvailable,
                    "ndefType" to ndefType,
                    "ndefWritable" to ndefWritable,
                    "ndefCanMakeReadOnly" to ndefCanMakeReadOnly,
                    "ndefCapacity" to ndefCapacity,
                    "mifareClassType" to mifareClassType,
                    "mifareClassSize" to mifareClassSize,
                    "mifareClassSectorCount" to mifareClassSectorCount,
                    "mifareClassicBlockCount" to mifareClassicBlockCount,
                    "mifareMaxTransceiveLength" to mifareMaxTransceiveLength,
            )).toString())

        }, technologies, null)
    }

    private class MethodResultWrapper internal constructor(result: Result) : Result {

        private val methodResult: Result = result
        private var hasError: Boolean = false;

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

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
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
