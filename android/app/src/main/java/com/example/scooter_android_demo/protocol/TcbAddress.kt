package com.example.scooter_android_demo.protocol

object TcbAddress {
    const val BROADCAST: Byte = 0x00
    // read (master requests data from device)
    const val METER_READ: Byte = 0x03
    const val CONTROLLER_READ: Byte = 0x01
    const val METER: Byte = METER_READ
    const val CONTROLLER: Byte = CONTROLLER_READ
    // write-with-reply (used for OTA and commands that expect an ACK)
    const val METER_WRITE: Byte = 0x23.toByte()
    const val CONTROLLER_WRITE: Byte = 0x21
}
