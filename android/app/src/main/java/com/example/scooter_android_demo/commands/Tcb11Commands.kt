package com.example.scooter_android_demo.commands

import com.example.tcblecomminucation.cmd.TCB11CMD

object Tcb11Commands {
    fun readMeterVersion(): ByteArray = TCB11CMD.readMeterVersion()
    fun readControllerVersion(): ByteArray = TCB11CMD.readControllerVersion()
}
