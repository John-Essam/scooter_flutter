package com.example.scooter_android_demo.ble

sealed interface BleState {
    data object Idle: BleState
    data object Scanning: BleState
    data class Connecting(val mac: String) : BleState
    data class Connected(val mac: String, val model: String) : BleState
    data class Error(val message: String) : BleState
}
