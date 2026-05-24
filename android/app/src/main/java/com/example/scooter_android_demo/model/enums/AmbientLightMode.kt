package com.example.scooter_android_demo.model.enums

enum class AmbientLightMode {
    Monochrome,
    MonochromeBreathing,
    MagicSevenColors,
    Rainbow,
    RunningEffect;

    companion object {
        fun fromMagicMode(mode: Int): AmbientLightMode = when (mode) {
            1 -> Monochrome
            2 -> MonochromeBreathing
            3 -> Rainbow        // mode 3 = seven-color cycling (both MagicSevenColors and Rainbow use this)
            4 -> RunningEffect  // mode 4 = running effect with color bytes
            else -> Monochrome
        }
    }
}
