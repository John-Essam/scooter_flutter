package com.example.scooter_android_demo.model

data class ScooterFaults(
    val undervoltage: Boolean = false,
    val gyroscope: Boolean = false,
    val battery: Boolean = false,
    val controller: Boolean = false,
    val mos: Boolean = false,
    val motorHall: Boolean = false,
    val brake: Boolean = false,
    val turnHandle: Boolean = false,
    val communication: Boolean = false,
    val batteryOvervoltage: Boolean = false,
    val batteryTemperatureHigh: Boolean = false,
    val controllerTemperatureProtection: Boolean = false,
) {
    val activeLabels: List<String>
        get() = buildList {
            if (undervoltage) add("Undervoltage")
            if (gyroscope) add("Gyroscope")
            if (battery) add("Battery")
            if (controller) add("Controller")
            if (mos) add("MOS")
            if (motorHall) add("Motor Hall")
            if (brake) add("Brake")
            if (turnHandle) add("Throttle")
            if (communication) add("Communication")
            if (batteryOvervoltage) add("Battery Overvoltage")
            if (batteryTemperatureHigh) add("Battery Temperature High")
            if (controllerTemperatureProtection) add("Controller Temperature Protection")
        }
}
