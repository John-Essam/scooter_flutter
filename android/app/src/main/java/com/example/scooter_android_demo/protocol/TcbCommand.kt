package com.example.scooter_android_demo.protocol

data class TcbCommand(
    val address: Byte,
    val functionCode: Int,
    val payload: ByteArray = ByteArray(0)
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is TcbCommand) return false
        return address == other.address &&
            functionCode == other.functionCode &&
            payload.contentEquals(other.payload)
    }

    override fun hashCode(): Int {
        var result = address.toInt()
        result = 31 * result + functionCode
        result = 31 * result + payload.contentHashCode()
        return result
    }
}
