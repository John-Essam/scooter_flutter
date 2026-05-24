package com.example.scooter_android_demo.commands

import com.example.tcblecomminucation.TCBConstant.TCBDeviceType
import com.example.tcblecomminucation.cmd.TCB0ACMD

object Tcb0ACommands {
    fun readControllerTemp(): ByteArray = TCB0ACMD.readTemp(TCBDeviceType.control)

    fun readBatteryTemp(): ByteArray = TCB0ACMD.readTemp(TCBDeviceType.battery)

    fun readMotorTemp(): ByteArray = TCB0ACMD.readTemp(TCBDeviceType.motor)
}
