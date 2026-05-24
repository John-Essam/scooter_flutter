package com.example.scooter_android_demo.model

data class BindStatus(
    val bluetoothReady: Boolean,
    val locked: Boolean,
    val boundId: String?
)