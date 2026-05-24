package com.example.scooter_android_demo.commands

import com.example.scooter_android_demo.protocol.TcbManualFrame

object TcbRidingTimeCommands {
    fun writeRidingTimeRequest(): ByteArray =
        TcbManualFrame.write(functionCode = FUNCTION_RIDING_TIME, payload = ByteArray(0))

    fun readRidingTime(): ByteArray =
        TcbManualFrame.read(functionCode = FUNCTION_RIDING_TIME)

    fun readRidingTimeCompatibility(): List<ByteArray> =
        listOf(writeRidingTimeRequest(), readRidingTime())

    private const val FUNCTION_RIDING_TIME = 0x31
}
