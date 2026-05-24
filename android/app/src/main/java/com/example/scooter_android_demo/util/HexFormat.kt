package com.example.scooter_android_demo.util

fun ByteArray.toHexString(): String =
    joinToString("") { "%02X".format(it.toInt() and 0xFF) }
