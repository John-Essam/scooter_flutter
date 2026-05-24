package com.example.scooter_android_demo.protocol

data class TcbFrame(
    val header: Byte,
    val address: Byte,
    val functionCode: Int,
    val payload: ByteArray,
    val crc: Int
) {
    val isValid: Boolean
        get() = crc == TcbCrc16.calculate(
            byteArrayOf(header, address) +
                byteArrayOf(
                    (functionCode and 0xFF).toByte(),
                    ((functionCode shr 8) and 0xFF).toByte(),
                    payload.size.toByte()
                ) + payload
        )

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is TcbFrame) return false
        return header == other.header &&
            address == other.address &&
            functionCode == other.functionCode &&
            payload.contentEquals(other.payload) &&
            crc == other.crc
    }

    override fun hashCode(): Int {
        var result = header.toInt()
        result = 31 * result + address.toInt()
        result = 31 * result + functionCode
        result = 31 * result + payload.contentHashCode()
        result = 31 * result + crc
        return result
    }
}
