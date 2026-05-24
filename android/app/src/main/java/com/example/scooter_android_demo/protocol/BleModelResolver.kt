package com.example.scooter_android_demo.protocol

import com.example.scooter_android_demo.model.enums.DeviceModel

object BleModelResolver {
    fun resolveFromAdvertisment(scanRecord: ByteArray): DeviceModel? {
        val hex = scanRecord.joinToString("") {
            "%02X".format(it.toInt() and 0xFF)
        }
        return DeviceModel.fromAdvHex(hex);
    }
}