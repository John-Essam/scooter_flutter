package com.example.scooter_android_demo.commands

import com.example.scooter_android_demo.model.enums.ScooterGear
import com.example.tcblecomminucation.TCBConstant.TCBGear
import com.example.tcblecomminucation.cmd.TCB05CMD

object Tcb05Commands {
    fun readDriveMode(): ByteArray = TCB05CMD.readDriveMode()

    fun writeGear(gear: ScooterGear): ByteArray = TCB05CMD.writeGear(
        gear.toVendorGear()
    )

    fun readGearMaxSpeed(gear: ScooterGear): ByteArray = TCB05CMD.readGearMaxSpeed(gear.toVendorGear())

    fun readMaxSpeed(): ByteArray = TCB05CMD.readMaxSpeed()
}

private fun ScooterGear.toVendorGear(): TCBGear =
    when (this) {
        ScooterGear.ZERO -> TCBGear.gear0
        ScooterGear.ONE -> TCBGear.gear1
        ScooterGear.TWO -> TCBGear.gear2
        ScooterGear.THREE -> TCBGear.gear3
    }
