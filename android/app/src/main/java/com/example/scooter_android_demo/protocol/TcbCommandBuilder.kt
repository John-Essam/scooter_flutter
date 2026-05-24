package com.example.scooter_android_demo.protocol

object TcbCommandBuilder {
    private const val HEADER: Byte = 0x5A.toByte()

    fun build(command: TcbCommand): ByteArray {
        val payload = command.payload
        val funcLow = (command.functionCode and 0xFF).toByte()
        val funcHigh = ((command.functionCode shr 8) and 0xFF).toByte()
        val length = payload.size.toByte()

        val frameWithoutCrc = byteArrayOf(
            HEADER,
            command.address,
            funcLow,
            funcHigh,
            length,
            *payload
        )

        val crc = TcbCrc16.calculate(frameWithoutCrc)
        // Protocol requires big-endian CRC (high byte first).
        return frameWithoutCrc + byteArrayOf(
            ((crc shr 8) and 0xFF).toByte(),
            (crc and 0xFF).toByte()
        )
    }
}
