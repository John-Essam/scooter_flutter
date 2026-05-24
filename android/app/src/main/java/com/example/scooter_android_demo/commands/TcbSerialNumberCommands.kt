package com.example.scooter_android_demo.commands

import com.example.scooter_android_demo.protocol.TcbManualFrame

object TcbSerialNumberCommands {
    fun readSerialNumber(): ByteArray =
        TcbManualFrame.read(functionCode = FUNCTION_SERIAL_NUMBER)

    private const val FUNCTION_SERIAL_NUMBER = 0x1D
}
