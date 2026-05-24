package com.example.scooter_android_demo.ble

import android.util.Log
import com.example.scooter_android_demo.baseble.core.DeviceMirror
import com.example.scooter_android_demo.util.toHexString

class BleTransport(
    private val onTx: (String) -> Unit
) {
    var mirror: DeviceMirror? = null

    fun write(data: ByteArray): Boolean {
        val activeMirror = mirror ?: return false
        val hex = data.toHexString()
        Log.d(TAG, "TX $hex")
        onTx(hex)
        activeMirror.writeData(data)
        return true
    }

    companion object {
        private const val TAG = "BleTransport"
    }
}
