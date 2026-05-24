package com.example.scooter_android_demo.commands

import com.example.tcblecomminucation.cmd.TCB0BCMD

object Tcb0BCommands {
    fun readDrivingCurrent(): ByteArray = TCB0BCMD.readDrivingCurrent()
}
