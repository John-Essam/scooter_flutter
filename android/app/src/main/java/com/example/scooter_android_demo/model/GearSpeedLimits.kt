package com.example.scooter_android_demo.model

import com.example.scooter_android_demo.model.enums.ScooterGear

data class GearSpeedLimits(
    val gear0: Int? = null,
    val gear1: Int? = null,
    val gear2: Int? = null,
    val gear3: Int? = null,
) {
    fun update(gear: ScooterGear, maxSpeed: Int): GearSpeedLimits =
        when (gear) {
            ScooterGear.ZERO -> copy(gear0 = maxSpeed)
            ScooterGear.ONE -> copy(gear1 = maxSpeed)
            ScooterGear.TWO -> copy(gear2 = maxSpeed)
            ScooterGear.THREE -> copy(gear3 = maxSpeed)
        }

    fun valueFor(gear: ScooterGear): Int? =
        when (gear) {
            ScooterGear.ZERO -> gear0
            ScooterGear.ONE -> gear1
            ScooterGear.TWO -> gear2
            ScooterGear.THREE -> gear3
        }
}
