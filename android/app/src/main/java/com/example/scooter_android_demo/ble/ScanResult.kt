package com.example.scooter_android_demo.ble

data class ScanResult (
    val name: String,
    val mac: String,
    val rssi: Int,
    val model: String,
    val scanRecord: ByteArray
)
