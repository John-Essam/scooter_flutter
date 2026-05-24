package com.example.scooter_android_demo.model

data class ResponseTuning(
    val throttle: Int? = null,
    val brake: Int? = null,
) {
    companion object {
        const val MIN = 0
        const val MAX = 10
    }
}
