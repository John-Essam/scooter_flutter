package com.example.scooter_android_demo.ble

import android.content.Context
import android.bluetooth.BluetoothManager
import android.util.Log
import com.example.scooter_android_demo.commands.TcbStartupCommands
import com.example.scooter_android_demo.baseble.ViseBle
import com.example.scooter_android_demo.baseble.callback.IBleCallback
import com.example.scooter_android_demo.baseble.callback.IConnectCallback
import com.example.scooter_android_demo.baseble.common.PropertyType
import com.example.scooter_android_demo.baseble.core.BluetoothGattChannel
import com.example.scooter_android_demo.baseble.core.DeviceMirror
import com.example.scooter_android_demo.baseble.exception.BleException
import com.example.scooter_android_demo.baseble.model.BluetoothLeDevice
import com.example.scooter_android_demo.model.enums.DeviceModel
import com.example.scooter_android_demo.util.toHexString
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class BleConnection(
    private val context: Context,
    private val scope: CoroutineScope,
    private val onState: (BleState) -> Unit,
    private val onRx: (ByteArray) -> Unit,
    private val onTx: (String) -> Unit,
    private val onError: (String) -> Unit
) {
    private var mirror: DeviceMirror? = null
    private var model: DeviceModel? = null
    private val transport = BleTransport(onTx)
    private val writeQueue = WriteQueue(scope, writeNow = transport::write)



    fun initialize() {
        ViseBle.config()
            .setConnectTimeout(10_000)
            .setOperateTimeout(5_000)
            .setConnectRetryCount(3)
            .setConnectRetryInterval(2_000)
            .setOperateRetryCount(3)
            .setOperateRetryInterval(1000)
            .setMaxConnectCount(1)

        ViseBle.getInstance().init(context.applicationContext)
    }

    fun connect(result: ScanResult, deviceModel: DeviceModel) {
        val bluetoothManager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val device = bluetoothManager.adapter?.getRemoteDevice(result.mac)

        if (device == null) {
            val message = "Bluetooth adapter is unavailable"
            onError(message)
            onState(BleState.Error(message))
            return
        }

        val bluetoothLeDevice = BluetoothLeDevice(
            device,
            result.rssi,
            result.scanRecord,
            System.currentTimeMillis()
        )

        connect(bluetoothLeDevice, result.mac, deviceModel)
    }

    fun connect(mac: String, deviceModel: DeviceModel) {
        model = deviceModel
        onState(BleState.Connecting(mac))

        ViseBle.getInstance().connectByMac(mac, buildConnectCallback(mac, deviceModel))
    }

    private fun connect(
        bluetoothLeDevice: BluetoothLeDevice,
        mac: String,
        deviceModel: DeviceModel
    ) {
        model =  deviceModel
        onState(BleState.Connecting(mac))

        ViseBle.getInstance().connect(bluetoothLeDevice, buildConnectCallback(mac, deviceModel))
    }

    private fun buildConnectCallback(mac: String, deviceModel: DeviceModel): IConnectCallback =
        object : IConnectCallback {
            override fun onConnectSuccess(deviceMirror: DeviceMirror) {
                mirror = deviceMirror
                transport.mirror = deviceMirror
                bindChannels(deviceMirror, deviceModel)
                onState(BleState.Connected(mac, deviceModel.name))

                scope.launch {
                    delay(2_000)
                    writeQueue.enqueueAll(TcbStartupCommands.packets())
                }
            }

            override fun onConnectFailure(exception: BleException) {
                Log.e(TAG, "Connect failed: $exception")
                val message = formatConnectError(exception)
                onError(message)
                onState(BleState.Error(message))
            }

            override fun onDisconnect(isActive: Boolean) {
                mirror = null
                transport.mirror = null
                onState(BleState.Idle)
            }
        }

    fun disconnect() {
        mirror?.disconnect()
        mirror = null
        transport.mirror = null
        model = null
        onState(BleState.Idle)
    }

    fun send(packet: ByteArray) {
        writeQueue.enqueue(packet)
    }

    fun bindChannels(deviceMirror: DeviceMirror, deviceModel: DeviceModel) {
        val serviceUuid = deviceModel.serviceUuid

        val notifyChannel = BluetoothGattChannel.Builder()
            .setBluetoothGatt(deviceMirror.bluetoothGatt)
            .setPropertyType(PropertyType.PROPERTY_NOTIFY)
            .setServiceUUID(TcbUuids.serviceFor(deviceModel))
            .setCharacteristicUUID(TcbUuids.notify)
            .setDescriptorUUID(TcbUuids.cccd)
            .builder()

        val writeChannel = BluetoothGattChannel.Builder()
            .setBluetoothGatt(deviceMirror.bluetoothGatt)
            .setPropertyType(PropertyType.PROPERTY_WRITE)
            .setServiceUUID(serviceUuid)
            .setCharacteristicUUID(TcbUuids.write)
            .setDescriptorUUID(TcbUuids.cccd)
            .builder()

        deviceMirror.bindChannel(object : IBleCallback {
            override fun onSuccess(
                data: ByteArray?,
                channel: BluetoothGattChannel?,
                device: BluetoothLeDevice?
            ) = Unit

            override fun onFailure(exception: BleException) {
                onError("Notify bind failed: $exception")
            }
        }, notifyChannel)

        deviceMirror.bindChannel(object : IBleCallback {
            override fun onSuccess(
                data: ByteArray?,
                channel: BluetoothGattChannel?,
                device: BluetoothLeDevice?
            ) = Unit

            override fun onFailure(exception: BleException) {
                onError("Write bind failed: $exception")
            }
        }, writeChannel)

        deviceMirror.setNotifyListener(notifyChannel.gattInfoKey, object : IBleCallback {
            override fun onSuccess(
                data: ByteArray?,
                channel: BluetoothGattChannel?,
                device: BluetoothLeDevice?
            ) {
                data ?: return
                Log.d(TAG, "RX ${data.toHexString()}")
                onRx(data)
            }

            override fun onFailure(exception: BleException) {
                onError("Notify failed: $exception")
            }
        })

        fun send(packet: ByteArray) {
            writeQueue.enqueue(packet)
        }

        deviceMirror.registerNotify(false)
    }

    private fun formatConnectError(exception: BleException): String =
        when {
            exception.toString().contains("gattStatus=8") ->
                "Connect timed out at the BLE link layer (GATT status 8). Move closer, make sure the scooter is not connected to another phone, then retry."
            else -> exception.toString()
        }

    companion object {
        private const val TAG = "BleConnection"
    }
}

