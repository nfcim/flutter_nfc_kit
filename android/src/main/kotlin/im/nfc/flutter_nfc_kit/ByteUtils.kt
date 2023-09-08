package im.nfc.flutter_nfc_kit

import im.nfc.flutter_nfc_kit.ByteUtils.hexToBytes
import im.nfc.flutter_nfc_kit.ByteUtils.toHexString


object ByteUtils {
    private const val HEX_CHARS = "0123456789ABCDEF"
    private val HEX_CHARS_ARRAY = HEX_CHARS.toCharArray()

    fun String.hexToBytes(): ByteArray {
        if (length % 2 == 1) throw IllegalArgumentException()

        val result = ByteArray(length / 2)

        val str = this.uppercase()
        for (i in 0 until length step 2) {
            val firstIndex = HEX_CHARS.indexOf(str[i])
            val secondIndex = HEX_CHARS.indexOf(str[i + 1])
            require(!(firstIndex == -1 || secondIndex == -1))
            val octet = (firstIndex shl 4) or secondIndex
            result[i shr 1] = octet.toByte()
        }

        return result
    }

    fun ByteArray.toHexString(): String {
        val result = StringBuffer()
        forEach {
            result.append(it.toHexString())
        }
        return result.toString()
    }

    fun Byte.toHexString(): String {
        val octet = this.toInt()
        val firstIndex = (octet and 0xF0) ushr 4
        val secondIndex = octet and 0x0F
        return "${HEX_CHARS_ARRAY[firstIndex]}${HEX_CHARS_ARRAY[secondIndex]}"
    }

    fun canonicalizeData(data: Any): Pair<ByteArray, String> {
        val bytes = when (data) {
            is String -> data.hexToBytes()
            else -> data as ByteArray
        }
        val hex = when (data) {
            is ByteArray -> data.toHexString()
            else -> data as String
        }
        return Pair(bytes, hex)
    }
}
