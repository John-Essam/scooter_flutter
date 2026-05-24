package com.example.scooter_android_demo.ble

import com.example.scooter_android_demo.model.enums.DeviceModel
import java.util.UUID

object TcbUuids {
    val notify: UUID = UUID.fromString("0000ffe2-0000-1000-8000-00805f9b34fb")
    val write: UUID = UUID.fromString("0000ffe1-0000-1000-8000-00805f9b34fb")
    val cccd: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    fun serviceFor(model: DeviceModel): UUID = model.serviceUuid
}