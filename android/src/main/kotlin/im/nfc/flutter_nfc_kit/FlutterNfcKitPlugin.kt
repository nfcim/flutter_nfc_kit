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
    inner class MifareInfo(
        val mifareClassicType:Int?,
        val mifareClassSize: Int?,
        val mifareClassSectorCount: Int?,
        val mifareClassicBlockCount: Int?,
        val mifareMaxTransceiveLength: Int?
    ) {}

    companion object {
        private val TAG = FlutterNfcKitPlugin::class.java.name
        private var activity: Activity? = null
        private var pollingTimeoutTask: TimerTask? = null
        private var tagTechnology: TagTechnology? = null
        private var ndefTechnology: Ndef? = null
        private var tagType: String? = null
        private var mifareClassicKeyA: ByteArray? = null
        private var mifareClassicKeyB: ByteArray? = null

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
                    } catch (ex: SecurityException) {
                        Log.e(TAG, "Tag already removed", ex)
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
                val sendingBytes = when (req) {
                    is String -> req.hexToBytes()
                    else -> req as ByteArray
                }
                val sendingHex = when (req) {
                    is ByteArray -> req.toHexString()
                    else -> req
                }

                thread {
                    try {
                        switchTechnology(tagTech, ndefTechnology)
                        val timeout = call.argument<Int>("timeout")
                        val resp = tagTech.transceive(sendingBytes, timeout)
                        when (req) {
                            is String -> result.success(resp.toHexString())
                            else -> result.success(resp)
                        }
                    } catch (ex: SecurityException) {
                        Log.e(TAG, "Transceive Error: $sendingHex", ex)
                        result.error("503", "Tag already removed", ex.localizedMessage)
                    } catch (ex: IOException) {
                        Log.e(TAG, "Transceive Error: $sendingHex", ex)
                        result.error("500", "Communication error", ex.localizedMessage)
                    } catch (ex: InvocationTargetException) {
                        Log.e(TAG, "Transceive Error: $sendingHex", ex.cause ?: ex)
                        result.error("500", "Communication error", ex.cause?.localizedMessage)
                    } catch (ex: IllegalArgumentException) {
                        Log.e(TAG, "Command Error: $sendingHex", ex)
                        result.error("400", "Command format error", ex.localizedMessage)
                    } catch (ex: NoSuchMethodException) {
                        Log.e(TAG, "Transceive not supported: $sendingHex", ex)
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
                    } catch (ex: SecurityException) {
                        Log.e(TAG, "Read NDEF Error", ex)
                        result.error("503", "Tag already removed", ex.localizedMessage)
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
                    } catch (ex: SecurityException) {
                        Log.e(TAG, "Write NDEF Error", ex)
                        result.error("503", "Tag already removed", ex.localizedMessage)
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
                    } catch (ex: SecurityException) {
                        Log.e(TAG, "Lock NDEF Error", ex)
                        result.error("503", "Tag already removed", ex.localizedMessage)
                    } catch (ex: IOException) {
                        Log.e(TAG, "Lock NDEF Error", ex)
                        result.error("500", "Communication error", ex.localizedMessage)
                    }
                }
            }

            "readBlock" -> {
                val tagTech = tagTechnology
                if (tagTech == null) {
                    result.error("406", "No tag polled", null)
                    return
                }
                val blockIndex = call.argument<Int>("blockIndex")!!
                thread {
                    try {
                        switchTechnology(tagTech, ndefTechnology)
                        readBlock(result, blockIndex)
                    } catch (e: IOException) {
                        Log.e(TAG, "Read Mifare Tag In Block $blockIndex Error", e)
                    }
                }
            }

            "readAll" -> {
                val tagTech = tagTechnology
                if (tagTech == null) {
                    result.error("406", "No tag polled", null)
                    return
                }
                thread {
                    try {
                        switchTechnology(tagTech, ndefTechnology)
                        readAll(result)
                    } catch (e: Exception) {
                        Log.e(TAG, "Read Mifare Tag All Error", e)
                    }
                }
            }

            "readSector" -> {
                val tagTech = tagTechnology
                if (tagTech == null) {
                    result.error("406", "No tag polled", null)
                    return
                }
                val sectorIndex = call.argument<Int>("sectorIndex")!!
                thread {
                    try {
                        switchTechnology(tagTech, ndefTechnology)
                        readSector(result, sectorIndex)
                    } catch (e: Exception) {
                        Log.e(TAG, "Read Mifare In Sector $sectorIndex Error", e)
                    }
                }
            }


            "writeBlock" -> {
                val tagTech = tagTechnology
                if (tagTech == null) {
                    result.error("406", "No tag polled", null)
                    return
                }
                val blockIndex = call.argument<Int>("blockIndex")!!
                val message = call.argument<String>("data")!!
                thread {
                    try {
                        switchTechnology(tagTech, ndefTechnology)
                        writeBlock(result, blockIndex, message.toByteArray())
                    } catch (ex: IOException) {
                        Log.e(TAG, "Write Mifare Tag Error", ex)
                    }
                }
            }

            "setAuthenticateKey" -> {
                val authenticateKeyA = call.argument<String>("authenticateKeyA")!!
                val authenticateKeyB = call.argument<String>("authenticateKeyB")
                mifareClassicKeyA = if (authenticateKeyA.isEmpty()) {
                    MifareClassic.KEY_DEFAULT
                } else {
                    authenticateKeyA.hexToBytes()
                }
                if (authenticateKeyB != null) {
                    mifareClassicKeyB = if (authenticateKeyB.isEmpty()) {
                        MifareClassic.KEY_DEFAULT
                    } else {
                        authenticateKeyB.hexToBytes()
                    }
                }
            }
            else -> result.notImplemented()
        }
    }
    private fun authenticateSector(mifareClassic: MifareClassic, sectorIndex: Int) {
        if (mifareClassicKeyA?.isNotEmpty() == true) {
            mifareClassic.authenticateSectorWithKeyA(sectorIndex, mifareClassicKeyA)
        }
        if (mifareClassicKeyB?.isNotEmpty() == true) {
            mifareClassic.authenticateSectorWithKeyB(sectorIndex, mifareClassicKeyB)
        }
    }

    private fun readBlock(result: Result?, blockIndex: Int): ByteArray? {
        // MifareClassic
        var blockBytes: ByteArray?
        if (tagType == "mifare_classic") {
            val mifareClassic = MifareClassic.get(tagTechnology?.tag)
            try {
                mifareClassic.connect()
                val sectorIndex = mifareClassic.blockToSector(blockIndex)
                authenticateSector(mifareClassic, sectorIndex)
                blockBytes = mifareClassic.readBlock(blockIndex)
                if (blockBytes != null) {
                    if (blockBytes.size < 16) {
                        throw IOException("block bytes size error")
                    }
                }
                if (blockBytes != null) {
                    if (blockBytes.size > 16) {
                        blockBytes = blockBytes.copyOf(16)
                    }
                }
                if (result != null) {
                    Log.d(TAG, "readBlock: ${blockBytes?.toHexString()}")
                    result.success(result.success(blockBytes?.toHexString()))
                }
                return blockBytes
            } catch (ex: IOException) {
                Log.e(TAG, "Read Block Error", ex)
                result?.error("501", ex.localizedMessage, null)
            } finally {
                mifareClassic.close()
            }
        } else if (tagType == "mifare_ultralight") { // MifareUltralight
            val mifareUltralight = MifareUltralight.get(tagTechnology?.tag)
            try {
                mifareUltralight.connect()
                // For mifareUltralight block is page offset
                blockBytes = mifareUltralight.readPages(blockIndex)
                if (result != null) {
                    Log.d(TAG, "readBlock: ${blockBytes.toHexString()}")
                    result.success(blockBytes.toHexString())
                }
                return blockBytes
            } catch (ex: IOException) {
                Log.e(TAG, "error", ex)
                result?.error("501", ex.localizedMessage, null)
            } finally {
                mifareUltralight.close()
            }
        } else {
            Log.e(TAG, "read block function need tag type is mifare_classic or mifare_ultralight")
            result?.error("505", "read block function need tag type is mifare_classic or mifare_ultralight", null)
        }
        return null
    }

    private fun readSector(result: Result, sectorIndex: Int) {
        if (tagType == "mifare_classic") {
            val mifareClassic = MifareClassic.get(tagTechnology?.tag)
            try {
                mifareClassic.connect()
                authenticateSector(mifareClassic, sectorIndex)
                val sectorAsHex = arrayListOf<String>()
                val firstBlock: Int = mifareClassic.sectorToBlock(sectorIndex)
                val lastBlock = firstBlock + 4
                for (i in firstBlock until lastBlock) {
                    try {
                        val tempData = readBlock(null, i)
                        if (tempData != null) {
                            val blockBytes: ByteArray = tempData
                            val hex = blockBytes.toHexString()
                            sectorAsHex.add(hex)
                        }
                    } catch (e: Exception) {
                        print(e)
                    }
                }
                result.success(sectorAsHex)
            } catch (e: Exception) {
                Log.e(TAG, "read sector error", e)
                result.error("502", e.localizedMessage, null)
            } finally {
                mifareClassic.close()
            }
        } else {
            Log.e(TAG, "read sector function need tag type is mifare_classic")
            result.error("505", "read sector function need tag type is mifare_classic",null)
        }
    }

    private fun readAll(result: Result) {
        val response = mutableMapOf<Int, List<String>>()
        if (tagType == "mifare_classic") {
            val mifareClassic = MifareClassic.get(tagTechnology?.tag)
            try {
                mifareClassic.connect()
                for (i in 0 until mifareClassic.sectorCount) {
                    authenticateSector(mifareClassic, i)
                    val sectorAsHex = arrayListOf<String>()
                    val firstBlock: Int = i
                    val lastBlock = firstBlock + 4
                    for (j in firstBlock until lastBlock) {
                        try {
                            val tempData = readBlock(null, j)
                            if (tempData != null) {
                                val blockBytes: ByteArray = tempData
                                val hex = blockBytes.toHexString()
                                sectorAsHex.add(hex)
                            }
                        } catch (e: Exception) {
                            print(e)
                        }
                    }
                    response[i] = sectorAsHex
                }
                result.success(response)
            } catch (e:java.lang.Exception) {
                Log.e(TAG, "Read MifareClassic All Error: ", e)
                result.error("503", e.localizedMessage, null)
            } finally {
                mifareClassic.close()
            }
        } else if (tagType == "mifare_ultralight") {
            val  mifareUltralight = MifareUltralight.get(tagTechnology?.tag)
            try {
                mifareUltralight.connect()
                for (i in 0 until 16) {
                    val pageAsHex = arrayListOf<String>()
                    try {
                        val pageBytes = mifareUltralight.readPages(i)
                        val hex = pageBytes.toHexString()
                        pageAsHex.add(hex)
                    } catch (ex: Exception) {
                        print(ex)
                    }
                    response[i] = pageAsHex
                }
                result.success(response)
            } catch (ex: Exception) {
                Log.e(TAG, "Read MifareUltralight All Error: ", ex)
                result.error("503", ex.localizedMessage, null)
            } finally {
                mifareUltralight.close()
            }
        } else {
            Log.e(TAG, "read all function need tag type is mifare_classic or mifare_ultralight")
            result.error("505", "read all function need tag type is mifare_classic or mifare_ultralight",null)
        }
    }
    private fun writeBlock(result: Result, blockIndex: Int, message: ByteArray) {
        if (tagType == "mifare_classic") {
            val mifareClassic = MifareClassic.get(tagTechnology?.tag)
            var messageAsHex = message.toHexString()
            val diff = 32 - messageAsHex.length
            messageAsHex = "$messageAsHex${"0".repeat(diff)}"
            Log.d(TAG, "Write Block Of Sector: $messageAsHex")
            try {
                mifareClassic.connect()
                val sectorIndex = mifareClassic.blockToSector(blockIndex)
                authenticateSector(mifareClassic, sectorIndex)
                mifareClassic.writeBlock(
                    blockIndex,
                    messageAsHex.hexToBytes()
                )
            } catch (ex: IOException) {
                Log.e(TAG, "MifareClassic Write Error:", ex)
                result.error("504", ex.localizedMessage, null)
            } finally {
                mifareClassic.close()
            }
        } else if (tagType == "mifare_ultralight") { // MifareUltralight
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
                result.error("504", ex.localizedMessage, null)
            } finally {
                mifareUltralight.close()
            }
        } else {
            Log.e(TAG, "write block function need tag type is mifare_classic or mifare_ultralight")
            result.error("505", "write block function need tag type is mifare_classic or mifare_ultralight",null)
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
        ndefTechnology = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

    override fun onDetachedFromActivityForConfigChanges() {}

    private fun pollTag(nfcAdapter: NfcAdapter, result: Result, timeout: Int, technologies: Int) {
        val mifareClassicGetType  = {
            MifareClassic.get(tagTechnology?.tag).type
        }

        val mifareClassicGetSize = {
            MifareClassic.get(tagTechnology?.tag).size
        }

        val mifareClassicGetSectorCount = {
            MifareClassic.get(tagTechnology?.tag).sectorCount
        }

        val mifareClassGetBlockCount = {
            MifareClassic.get(tagTechnology?.tag).blockCount
        }

        val getMaxTransceiveLength = {
            if (tagType == "mifare_classic") {
                try {
                    val mifareClassic = MifareClassic.get(tagTechnology?.tag)
                    val maxTransceiveLen = mifareClassic.maxTransceiveLength
                    maxTransceiveLen
                } catch (ex: Exception) {
                    Log.e(TAG, "Get MifareClassic Max Transceive Length Error", ex)
                }
            } else if (tagType == "mifare_ultralight") {
                try {
                    val mifareUltralight = MifareUltralight.get(tagTechnology?.tag)
                    val maxTransceiveLen = mifareUltralight.maxTransceiveLength
                    maxTransceiveLen
                } catch (ex: Exception) {
                    Log.e(TAG, "Get MifareUltralight Max Transceive Length Error", ex)
                }
            }
            -1
        }

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
            var mifareInfo: MifareInfo? = null

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
                        mifareInfo = MifareInfo(
                            mifareClassicGetType(),
                            mifareClassicGetSize(),
                            mifareClassicGetSectorCount(),
                            mifareClassGetBlockCount(),
                            getMaxTransceiveLength())
                    }
                    tag.techList.contains(MifareUltralight::class.java.name) -> {
                        standard = "ISO 14443-3 (Type A)"
                        type = "mifare_ultralight"
                        mifareInfo = MifareInfo(null,null,null,null,mifareMaxTransceiveLength = getMaxTransceiveLength())
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

            tagType = type

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
                    "mifareClassType" to mifareInfo?.mifareClassicType,
                    "mifareClassSize" to mifareInfo?.mifareClassSize,
                    "mifareClassSectorCount" to mifareInfo?.mifareClassSectorCount,
                    "mifareClassicBlockCount" to mifareInfo?.mifareClassicBlockCount,
                    "mifareMaxTransceiveLength" to mifareInfo?.mifareMaxTransceiveLength,
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
