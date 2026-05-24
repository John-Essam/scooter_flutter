package com.example.scooter_android_demo.commands

import com.example.scooter_android_demo.protocol.TcbManualFrame

object TcbBatteryDataCommands {
    val probeFunctionCodes: List<Int> = listOf(0x0C, 0x0D, 0x0E, 0x0F, 0x20)

    fun readBatteryData(): List<ByteArray> =
        probeFunctionCodes.map(::readBatteryData)

    fun readBatteryData(functionCode: Int): ByteArray =
        TcbManualFrame.read(
            functionCode = functionCode,
            payload = byteArrayOf(0x00),
        )
}
