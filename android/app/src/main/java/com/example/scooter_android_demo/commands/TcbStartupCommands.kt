package com.example.scooter_android_demo.commands

import com.example.scooter_android_demo.model.enums.ScooterGear

object TcbStartupCommands {
    fun packets(): List<ByteArray> = listOf(
        Tcb02Commands.connect(),
        Tcb04Commands.readAmbientLightStatus(),
        Tcb05Commands.readDriveMode(),
        Tcb05Commands.readMaxSpeed(),
        Tcb11Commands.readMeterVersion(),
        Tcb11Commands.readControllerVersion(),
        Tcb08Commands.readSingleTripMileage(),
        Tcb09Commands.readTotalTripMileage(),
        Tcb30Commands.readRemainingMileage(),
        Tcb1ACommands.readAmbientLight(),
        Tcb03Commands.readNfcStatus(),
        Tcb22Commands.readThrottleResponse(),
        Tcb22Commands.readBrakeResponse(),
        Tcb05Commands.readGearMaxSpeed(ScooterGear.ONE),
        Tcb05Commands.readGearMaxSpeed(ScooterGear.TWO),
        Tcb05Commands.readGearMaxSpeed(ScooterGear.THREE),
        Tcb0ACommands.readMotorTemp(),
        Tcb0ACommands.readBatteryTemp(),
        Tcb0ACommands.readControllerTemp(),
        TcbSerialNumberCommands.readSerialNumber(),
        Tcb0BCommands.readDrivingCurrent(),
        Tcb06Commands.readAutoPowerOff(),
    ) + TcbBatteryDataCommands.readBatteryData() +
        TcbRidingTimeCommands.readRidingTimeCompatibility()
}
