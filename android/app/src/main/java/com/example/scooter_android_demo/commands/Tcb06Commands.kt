package com.example.scooter_android_demo.commands

import com.example.scooter_android_demo.protocol.TcbManualFrame

object Tcb06Commands {
    fun readAutoPowerOff(): ByteArray =
        TcbManualFrame.read(functionCode = FUNCTION_AUTO_POWER_OFF)

    private const val FUNCTION_AUTO_POWER_OFF = 0x06
}
