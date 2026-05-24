package com.example.scooter_android_demo.model

import com.example.scooter_android_demo.model.enums.AmbientLightMode

data class AmbientRgbStatus(
    val mode: AmbientLightMode,
    val red: Int,
    val green: Int,
    val blue: Int,
    val brightness: Int = 255,
) {
    val packed: Int get() = (red shl 16) or (green shl 8) or blue
}
