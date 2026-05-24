package com.example.scooter_android_demo.commands

import com.example.tcblecomminucation.cmd.TCB02CMD

object Tcb02Commands {
    fun connect(authLevel: Int = 5): ByteArray = TCB02CMD.writeConnect(authLevel)
    fun lockStatus(locked: Boolean): ByteArray = TCB02CMD.writeLockStatus(locked)
    fun cruiseControl(enabled: Boolean): ByteArray = TCB02CMD.writeCruiseControlFunction(enabled)
    fun readUnbind(): ByteArray = TCB02CMD.readUnbind()
}
