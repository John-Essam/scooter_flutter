package com.example.scooter_android_demo.commands

import com.example.tcblecomminucation.cmd.TCB04CMD

object Tcb04Commands {
    fun writeFrontLight(on: Boolean): ByteArray = TCB04CMD.writeFrontLightStatus(on)
    fun writeAmbientLight(on: Boolean): ByteArray = TCB04CMD.writeAmbientLightStatus(on)
    fun readAmbientLightStatus(): ByteArray = TCB04CMD.readAmbientLightStatus()
}
