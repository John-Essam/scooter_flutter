package com.example.scooter_android_demo.protocol

object TcbCrc16 {
    fun calculate(data: ByteArray): Int {
        var crc = 0
        data.forEach { byte ->
            crc = (((crc ushr 8) and 0xFF) or ((crc and 0xFF) shl 8)) and 0xFFFF
            crc = (crc xor (byte.toInt() and 0xFF)) and 0xFFFF
            crc = (crc xor ((crc and 0xFF) ushr 4)) and 0xFFFF
            crc = (crc xor ((crc shl 12) and 0xFFFF)) and 0xFFFF
            crc = (crc xor (((crc and 0xFF) shl 5) and 0xFFFF)) and 0xFFFF
        }
        return crc and 0xFFFF
    }
}
