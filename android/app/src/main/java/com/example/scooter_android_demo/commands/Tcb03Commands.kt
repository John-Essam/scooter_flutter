package com.example.scooter_android_demo.commands

import com.example.tcblecomminucation.cmd.TCB03CMD

object Tcb03Commands {
    fun readNfcStatus(): ByteArray = TCB03CMD.readNfcStatus()
}
