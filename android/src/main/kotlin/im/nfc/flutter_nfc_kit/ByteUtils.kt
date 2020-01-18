package im.nfc.flutter_nfc_kit

import java.nio.ByteBuffer

object ByteUtils {
    private val HEX_CHARS = "0123456789ABCDEF"
    private val HEX_CHARS_ARRAY = "0123456789ABCDEF".toCharArray()

    fun String.hexToBytes(): ByteArray {
        val result = ByteArray(length / 2)

        val str = this.toUpperCase()
        for (i in 0 until length step 2) {
            val firstIndex = HEX_CHARS.indexOf(str[i])
            val secondIndex = HEX_CHARS.indexOf(str[i + 1])
            val octet = (firstIndex shl 4) or secondIndex
            result[i shr 1] = octet.toByte()
        }

        return result
    }

    fun ByteArray.toHexString(): String {
        val result = StringBuffer()
        forEach {
            val octet = it.toInt()
            val firstIndex = (octet and 0xF0) ushr 4
            val secondIndex = octet and 0x0F
            result.append(HEX_CHARS_ARRAY[firstIndex])
            result.append(HEX_CHARS_ARRAY[secondIndex])
        }
        return result.toString()
    }
}
