package com.example.scooter_android_demo.protocol

object TcbManualFrame {
    private const val HEADER: Byte = 0x5A

    fun read(
        functionCode: Int,
        payload: ByteArray = ByteArray(0),
        address: Byte = TcbAddress.CONTROLLER_READ,
    ): ByteArray = TcbCommandBuilder.build(
        TcbCommand(
            address = address,
            functionCode = functionCode,
            payload = payload,
        )
    )

    fun write(
        functionCode: Int,
        payload: ByteArray,
        address: Byte = TcbAddress.CONTROLLER_WRITE,
    ): ByteArray = TcbCommandBuilder.build(
        TcbCommand(
            address = address,
            functionCode = functionCode,
            payload = payload,
        )
    )

    fun compactRead(
        functionCode: Int,
        payload: ByteArray = ByteArray(0),
        address: Byte = TcbAddress.METER_READ,
    ): ByteArray = buildCompactFrame(
        address = address,
        functionCode = functionCode,
        payload = payload,
    )

    fun compactWrite(
        functionCode: Int,
        payload: ByteArray,
        address: Byte = TcbAddress.METER_WRITE,
    ): ByteArray = buildCompactFrame(
        address = address,
        functionCode = functionCode,
        payload = payload,
    )

    private fun buildCompactFrame(
        address: Byte,
        functionCode: Int,
        payload: ByteArray,
    ): ByteArray {
        val frameWithoutCrc = byteArrayOf(
            HEADER,
            address,
            (functionCode and 0xFF).toByte(),
            payload.size.toByte(),
            *payload,
        )
        val crc = TcbCrc16.calculate(frameWithoutCrc)
        return frameWithoutCrc + byteArrayOf(
            ((crc shr 8) and 0xFF).toByte(),
            (crc and 0xFF).toByte(),
        )
    }
}
