package com.example.scooter_android_demo.model

data class Heartbeat(
    val speed: Int,
    val batteryPercent: Int,
    val batteryVoltage: Int,
    val gear: Int,
    val locked: Boolean,
    val headlightOn: Boolean,
    val cruiseOn: Boolean,
    val metricUnit: Boolean,
    val startMode: Boolean,
    val faults: ScooterFaults = ScooterFaults(),
)
