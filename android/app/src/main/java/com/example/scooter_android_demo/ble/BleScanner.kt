package com.example.scooter_android_demo.ble

import android.Manifest
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanSettings
import android.bluetooth.le.ScanResult as AndroidScanResult
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresPermission
import androidx.core.content.ContextCompat
import com.example.scooter_android_demo.protocol.BleModelResolver

class BleScanner(
    private val context: Context,
    private val onStateChange: (BleState) -> Unit,
    private val onResultChange: (List<ScanResult>) -> Unit
) {
    private companion object {
        const val TAG = "BleScanner"
    }

    private val bluetoothManager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val scanner get () = bluetoothManager.adapter.bluetoothLeScanner
    private val results = mutableMapOf<String, ScanResult>()
    private var callback:ScanCallback? = null

    @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
    fun startScan() {
        Log.d(TAG, "startScan requested")

        val missingPermission = missingPermission()
        if (missingPermission != null) {
            Log.w(TAG, "Cannot start scan. Missing permission: $missingPermission")
            onStateChange(BleState.Error("Missing permission: $missingPermission"))
            return
        }

        val adapter = bluetoothManager.adapter
        if (adapter == null || !adapter.isEnabled) {
            Log.w(TAG, "Cannot start scan. Bluetooth adapter is unavailable or disabled")
            onStateChange(BleState.Error("Bluetooth is off"))
            return
        }

        results.clear()
        onResultChange(emptyList())
        onStateChange(BleState.Scanning)

        callback = object: ScanCallback() {
            @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
            override fun onScanResult(callbackType: Int, result: AndroidScanResult) {
                handleResult(result)
            }

            override fun onBatchScanResults(batchResults: List<AndroidScanResult?>) {
                Log.d(TAG, "Batch scan results received: count=${batchResults.size}")
                batchResults.filterNotNull().forEach(::handleResult)
            }

            override fun onScanFailed(errorCode: Int) {
                Log.e(TAG, "Scan failed: $errorCode")
                onStateChange(BleState.Error("Scan failed: $errorCode"))
            }
        }

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanner.startScan(null, settings, callback)
        Log.d(TAG, "BLE scan started")
    }

    fun stopScan() {
        val activeCallback = callback ?: return
        callback = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "Cannot stop scan. Missing permission: ${Manifest.permission.BLUETOOTH_SCAN}")
            return
        }

        scanner.stopScan(activeCallback)
        Log.d(TAG, "BLE scan stopped")
        onStateChange(BleState.Idle)
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    private fun handleResult(result: AndroidScanResult) {
        val device = result.device
        val record = result.scanRecord?.bytes ?: return
        val model = BleModelResolver.resolveFromAdvertisment(record) ?: return
        val name = device.name ?: "Unknown"

//        Log.d(
//            TAG,
//            "Scan result: name=$name mac=${device.address} rssi=${result.rssi} model=${model.name} record=${record.toHexString()}"
//        )

        val item = ScanResult(
            name = name,
            mac = device.address,
            rssi = result.rssi,
            model = model.name,
            scanRecord = record
        )

        results[item.mac] = item
        onResultChange(results.values.sortedByDescending { it.rssi })
    }

    private fun ByteArray.toHexString(): String =
        joinToString(separator = "") { byte -> "%02X".format(byte) }

    private fun missingPermission(): String? = when {
        // For Android 12 (API 31) and above
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> when {
            !hasPermission(Manifest.permission.BLUETOOTH_SCAN) -> Manifest.permission.BLUETOOTH_SCAN
            !hasPermission(Manifest.permission.BLUETOOTH_CONNECT) -> Manifest.permission.BLUETOOTH_CONNECT
            !hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) -> Manifest.permission.ACCESS_FINE_LOCATION
            else -> null
        }
        // For older versions
        !hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) -> Manifest.permission.ACCESS_FINE_LOCATION
        else -> null
    }

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

}
