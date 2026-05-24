package com.example.scooter_bridge_arch.bridge

import android.Manifest
import android.content.Context
import androidx.annotation.RequiresPermission
import com.example.scooter_android_demo.ble.BleConnection
import com.example.scooter_android_demo.ble.BleScanner
import com.example.scooter_android_demo.ble.BleState
import com.example.scooter_android_demo.ble.ScanResult
import com.example.scooter_android_demo.commands.Tcb02Commands
import com.example.scooter_android_demo.commands.Tcb03Commands
import com.example.scooter_android_demo.commands.Tcb04Commands
import com.example.scooter_android_demo.commands.Tcb05Commands
import com.example.scooter_android_demo.commands.Tcb08Commands
import com.example.scooter_android_demo.commands.Tcb09Commands
import com.example.scooter_android_demo.commands.Tcb0ACommands
import com.example.scooter_android_demo.commands.Tcb0BCommands
import com.example.scooter_android_demo.commands.Tcb1ACommands
import com.example.scooter_android_demo.commands.Tcb22Commands
import com.example.scooter_android_demo.commands.Tcb30Commands
import com.example.scooter_android_demo.commands.TcbSerialNumberCommands
import com.example.scooter_android_demo.model.AmbientRgbStatus
import com.example.scooter_android_demo.model.Heartbeat
import com.example.scooter_android_demo.model.enums.AmbientLightMode
import com.example.scooter_android_demo.model.enums.ScooterGear
import com.example.scooter_android_demo.model.enums.DeviceModel
import com.example.scooter_android_demo.model.enums.TempType
import com.example.scooter_android_demo.protocol.TcbResponse
import com.example.scooter_android_demo.protocol.TcbResponseParser
import com.example.scooter_android_demo.protocol.TcbManualFrame
import com.example.tcblecomminucation.TCBConstant.TCBResponseType
import com.example.tcblecomminucation.cmd.TCB03CMD
import com.example.tcblecomminucation.cmd.TCB22CMD
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.withTimeoutOrNull
import java.util.concurrent.ConcurrentHashMap

internal class RealAndroidBleBridge(
    context: Context,
    private val onConnectionEvent: (Map<String, Any?>) -> Unit,
    private val onTelemetryEvent: (Map<String, Any?>) -> Unit,
    private val onLogEvent: (Map<String, Any?>) -> Unit,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private val scansByMac = ConcurrentHashMap<String, ScanResult>()

    private var latestHeartbeat: Heartbeat? = null
    private var pendingConnectMac: String? = null
    private var connectDeferred: CompletableDeferred<ScanResult>? = null
    private var lockDeferred: CompletableDeferred<Boolean>? = null
    private var expectedLockState: Boolean? = null
    private var gearDeferred: CompletableDeferred<Int>? = null
    private var expectedGear: Int? = null
    private var throttleResponseDeferred: CompletableDeferred<Int>? = null
    private var brakeResponseDeferred: CompletableDeferred<Int>? = null
    private var nfcStatusDeferred: CompletableDeferred<Boolean>? = null
    private var expectedNfcStatus: Boolean? = null
    private var ambientLightDeferred: CompletableDeferred<Boolean>? = null
    private var expectedAmbientLight: Boolean? = null
    private var temperatureDeferred: CompletableDeferred<Int>? = null
    private var expectedTemperatureType: TempType? = null
    private var drivingCurrentDeferred: CompletableDeferred<Pair<Float, Float>>? = null
    private var remainingMileageDeferred: CompletableDeferred<Float>? = null
    private var tripMileageDeferred: CompletableDeferred<Float>? = null
    private var totalMileageDeferred: CompletableDeferred<Float>? = null
    private var speedStatsDeferred: CompletableDeferred<Pair<Float, Float>>? = null
    private var serialNumberDeferred: CompletableDeferred<String>? = null
    private var connectedDeviceId: String? = null
    private var lastScanFingerprint: String? = null
    private var lastHeartbeatRxLogMs: Long = 0L

    private val scanner = BleScanner(
        context = context.applicationContext,
        onStateChange = ::handleBleState,
        onResultChange = ::handleScanResults,
    )

    private val connection = BleConnection(
        context = context.applicationContext,
        scope = scope,
        onState = ::handleBleState,
        onRx = ::handleRx,
        onTx = { hex -> emitLog("tx", hex) },
        onError = { message -> emitLog("error", message) },
    )

    init {
        connection.initialize()
        emitConnection("idle", reason = "bridge_initialized", retriable = false, device = null)
    }

    fun shutdown() {
        runCatching { scanner.stopScan() }
        runCatching { connection.disconnect() }
        scope.cancel()
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
    fun startScan() {
        emitLog("scan", "startScan requested")
        scanner.startScan()
    }

    fun stopScan() {
        emitLog("scan", "stopScan requested")
        scanner.stopScan()
    }

    suspend fun connect(deviceId: String, timeoutMs: Long): Map<String, Any?> {
        emitLog("connection", "connect requested deviceId=$deviceId timeoutMs=$timeoutMs")
        runCatching { scanner.stopScan() }
        val target = scansByMac[deviceId] ?: scansByMac.values.firstOrNull { it.mac == deviceId }
            ?: throw BridgeNativeException(
                code = ErrorCodes.INVALID_ARGUMENT,
                message = "Unknown deviceId. Call startScan and use returned scan MAC.",
                retriable = false,
                details = mapOf("deviceId" to deviceId),
            )

        val model = runCatching { DeviceModel.valueOf(target.model) }.getOrElse {
            throw BridgeNativeException(
                code = ErrorCodes.INVALID_ARGUMENT,
                message = "Unknown device model from scan result",
                retriable = false,
                details = mapOf("model" to target.model),
            )
        }

        connectDeferred?.cancel()
        pendingConnectMac = target.mac
        val deferred = CompletableDeferred<ScanResult>()
        connectDeferred = deferred

        connection.connect(target, model)

        val connected = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Connect timeout",
                retriable = true,
                details = mapOf("deviceId" to deviceId, "timeoutMs" to timeoutMs),
            )
        connectedDeviceId = connected.mac

        return mapOf(
            "state" to "connected",
            "deviceId" to connected.mac,
            "name" to connected.name,
            "model" to connected.model,
        )
    }

    fun disconnect(): Map<String, Any?> {
        emitLog("connection", "disconnect requested")
        connection.disconnect()
        pendingConnectMac = null
        connectedDeviceId = null
        connectDeferred?.cancel()
        connectDeferred = null
        lockDeferred?.cancel()
        lockDeferred = null
        expectedLockState = null
        gearDeferred?.cancel()
        gearDeferred = null
        expectedGear = null
        throttleResponseDeferred?.cancel()
        throttleResponseDeferred = null
        brakeResponseDeferred?.cancel()
        brakeResponseDeferred = null
        nfcStatusDeferred?.cancel()
        nfcStatusDeferred = null
        expectedNfcStatus = null
        ambientLightDeferred?.cancel()
        ambientLightDeferred = null
        expectedAmbientLight = null
        temperatureDeferred?.cancel()
        temperatureDeferred = null
        expectedTemperatureType = null
        drivingCurrentDeferred?.cancel()
        drivingCurrentDeferred = null
        remainingMileageDeferred?.cancel()
        remainingMileageDeferred = null
        tripMileageDeferred?.cancel()
        tripMileageDeferred = null
        totalMileageDeferred?.cancel()
        totalMileageDeferred = null
        speedStatsDeferred?.cancel()
        speedStatsDeferred = null
        serialNumberDeferred?.cancel()
        serialNumberDeferred = null
        return mapOf("state" to "idle")
    }

    fun bind(): Map<String, Any?> {
        emitLog("connection", "bind requested")
        connection.send(Tcb02Commands.connect())
        return mapOf("bound" to true)
    }

    fun unbind(): Map<String, Any?> {
        emitLog("connection", "unbind requested")
        connection.send(Tcb02Commands.readUnbind())
        return mapOf("bound" to false)
    }

    suspend fun setLock(locked: Boolean, timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Boolean>()
        lockDeferred = deferred
        expectedLockState = locked
        emitLog("control", "setLock requested locked=$locked timeoutMs=$timeoutMs")
        connection.send(Tcb02Commands.lockStatus(locked))

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Lock command timeout waiting heartbeat confirmation",
                retriable = true,
                details = mapOf("locked" to locked, "timeoutMs" to timeoutMs),
            )

        return mapOf("lockStatus" to matched)
    }

    fun setCruiseControl(enabled: Boolean): Map<String, Any?> {
        connection.send(Tcb02Commands.cruiseControl(enabled))
        return mapOf("cruiseControl" to enabled)
    }

    fun setStartMode(enabled: Boolean): Map<String, Any?> {
        connection.send(Tcb02Commands.startMode(enabled))
        return mapOf("startMode" to enabled)
    }

    fun setUnitSystem(metric: Boolean): Map<String, Any?> {
        connection.send(Tcb02Commands.unitSystem(metric))
        return mapOf("metricUnit" to metric)
    }

    suspend fun readThrottleResponse(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Int>()
        throttleResponseDeferred?.cancel()
        throttleResponseDeferred = deferred
        emitLog("control", "readThrottleResponse requested timeoutMs=$timeoutMs")
        connection.send(Tcb22Commands.readThrottleResponse())

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Throttle response read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf("throttleResponse" to matched)
    }

    suspend fun readBrakeResponse(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Int>()
        brakeResponseDeferred?.cancel()
        brakeResponseDeferred = deferred
        emitLog("control", "readBrakeResponse requested timeoutMs=$timeoutMs")
        connection.send(Tcb22Commands.readBrakeResponse())

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Brake response read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf("brakeResponse" to matched)
    }

    fun setThrottleBrakeResponse(throttle: Int, brake: Int): Map<String, Any?> {
        if (throttle !in 0..10) {
            throw BridgeNativeException(
                code = ErrorCodes.INVALID_ARGUMENT,
                message = "payload.throttle must be 0..10",
                retriable = false,
                details = mapOf("throttle" to throttle),
            )
        }
        if (brake !in 0..10) {
            throw BridgeNativeException(
                code = ErrorCodes.INVALID_ARGUMENT,
                message = "payload.brake must be 0..10",
                retriable = false,
                details = mapOf("brake" to brake),
            )
        }
        connection.send(TCB22CMD.writeResponseTime(TCBResponseType.throttleResponse, throttle))
        connection.send(TCB22CMD.writeResponseTime(TCBResponseType.brakeResponse, brake))
        return mapOf(
            "throttleResponse" to throttle,
            "brakeResponse" to brake,
        )
    }

    suspend fun readNfcStatus(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Boolean>()
        nfcStatusDeferred?.cancel()
        nfcStatusDeferred = deferred
        expectedNfcStatus = null
        emitLog("control", "readNfcStatus requested timeoutMs=$timeoutMs")
        connection.send(Tcb03Commands.readNfcStatus())

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "NFC status read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf("nfcEnabled" to matched)
    }

    suspend fun setNfcEnabled(enabled: Boolean, timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Boolean>()
        nfcStatusDeferred?.cancel()
        nfcStatusDeferred = deferred
        expectedNfcStatus = enabled
        emitLog("control", "setNfcEnabled requested enabled=$enabled timeoutMs=$timeoutMs")
        connection.send(TCB03CMD.writeNfcStatus(enabled))

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "NFC write timeout waiting status confirmation",
                retriable = true,
                details = mapOf("enabled" to enabled, "timeoutMs" to timeoutMs),
            )
        return mapOf("nfcEnabled" to matched)
    }

    suspend fun setAmbientLight(on: Boolean, timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Boolean>()
        ambientLightDeferred?.cancel()
        ambientLightDeferred = deferred
        expectedAmbientLight = on
        emitLog("control", "setAmbientLight requested on=$on timeoutMs=$timeoutMs")
        connection.send(Tcb04Commands.writeAmbientLight(on))

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Ambient light write timeout waiting status confirmation",
                retriable = true,
                details = mapOf("on" to on, "timeoutMs" to timeoutMs),
            )
        return mapOf("ambientOn" to matched)
    }

    fun setAmbientRgb(mode: Int, red: Int, green: Int, blue: Int, brightness: Int): Map<String, Any?> {
        fun validateColor(name: String, value: Int) {
            if (value !in 0..255) {
                throw BridgeNativeException(
                    code = ErrorCodes.INVALID_ARGUMENT,
                    message = "payload.$name must be 0..255",
                    retriable = false,
                    details = mapOf(name to value),
                )
            }
        }
        validateColor("red", red)
        validateColor("green", green)
        validateColor("blue", blue)
        validateColor("brightness", brightness)
        val ambientMode = when (mode) {
            1 -> AmbientLightMode.Monochrome
            2 -> AmbientLightMode.MonochromeBreathing
            3 -> AmbientLightMode.Rainbow
            4 -> AmbientLightMode.RunningEffect
            else -> throw BridgeNativeException(
                code = ErrorCodes.INVALID_ARGUMENT,
                message = "payload.mode must be 1..4",
                retriable = false,
                details = mapOf("mode" to mode),
            )
        }
        connection.send(
            Tcb1ACommands.writeAmbientLight(
                AmbientRgbStatus(
                    mode = ambientMode,
                    red = red,
                    green = green,
                    blue = blue,
                    brightness = brightness,
                )
            )
        )
        return mapOf(
            "mode" to mode,
            "red" to red,
            "green" to green,
            "blue" to blue,
            "brightness" to brightness,
        )
    }

    fun setRainbowMode(): Map<String, Any?> {
        connection.send(
            Tcb1ACommands.writeAmbientLight(
                AmbientRgbStatus(
                    mode = AmbientLightMode.Rainbow,
                    red = 255,
                    green = 255,
                    blue = 255,
                    brightness = 255,
                )
            )
        )
        return mapOf("rainbowMode" to true)
    }

    suspend fun readControllerTemperature(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Int>()
        temperatureDeferred?.cancel()
        temperatureDeferred = deferred
        expectedTemperatureType = TempType.Controller
        emitLog("control", "readControllerTemperature requested timeoutMs=$timeoutMs")
        connection.send(Tcb0ACommands.readControllerTemp())

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Controller temperature read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf(
            "controllerTemperatureC" to matched,
            "type" to "controller",
        )
    }

    suspend fun readBatteryTemperature(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Int>()
        temperatureDeferred?.cancel()
        temperatureDeferred = deferred
        expectedTemperatureType = TempType.Battery
        emitLog("control", "readBatteryTemperature requested timeoutMs=$timeoutMs")
        connection.send(Tcb0ACommands.readBatteryTemp())

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Battery temperature read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf(
            "batteryTemperatureC" to matched,
            "type" to "battery",
        )
    }

    suspend fun readMotorTemperature(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Int>()
        temperatureDeferred?.cancel()
        temperatureDeferred = deferred
        expectedTemperatureType = TempType.Motor
        emitLog("control", "readMotorTemperature requested timeoutMs=$timeoutMs")
        connection.send(Tcb0ACommands.readMotorTemp())

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Motor temperature read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf(
            "motorTemperatureC" to matched,
            "type" to "motor",
        )
    }

    suspend fun readDrivingCurrent(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Pair<Float, Float>>()
        drivingCurrentDeferred?.cancel()
        drivingCurrentDeferred = deferred
        emitLog("control", "readDrivingCurrent requested timeoutMs=$timeoutMs")
        connection.send(Tcb0BCommands.readDrivingCurrent())

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Driving current read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf(
            "realtimeAmps" to matched.first,
            "limitAmps" to matched.second,
        )
    }

    suspend fun readRemainingMileage(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Float>()
        remainingMileageDeferred?.cancel()
        remainingMileageDeferred = deferred
        emitLog("control", "readRemainingMileage requested timeoutMs=$timeoutMs")
        connection.send(Tcb30Commands.readRemainingMileage())

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Remaining mileage read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf("remainingMileageKm" to matched)
    }

    suspend fun readTripMileage(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Float>()
        tripMileageDeferred?.cancel()
        tripMileageDeferred = deferred
        emitLog("control", "readTripMileage requested timeoutMs=$timeoutMs")
        connection.send(Tcb08Commands.readSingleTripMileage())

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Trip mileage read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf("tripMileageKm" to matched)
    }

    suspend fun readOdo(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Float>()
        totalMileageDeferred?.cancel()
        totalMileageDeferred = deferred
        emitLog("control", "readOdo requested timeoutMs=$timeoutMs")
        connection.send(Tcb09Commands.readTotalTripMileage())

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "ODO read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf("odoKm" to matched)
    }

    suspend fun readSpeedStats(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<Pair<Float, Float>>()
        speedStatsDeferred?.cancel()
        speedStatsDeferred = deferred
        emitLog("control", "readSpeedStats requested timeoutMs=$timeoutMs")
        connection.send(TcbManualFrame.read(functionCode = 0x32))

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Speed stats read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf(
            "avgKmh" to matched.first,
            "maxKmh" to matched.second,
        )
    }

    suspend fun readSerialNumber(timeoutMs: Long): Map<String, Any?> {
        val deferred = CompletableDeferred<String>()
        serialNumberDeferred?.cancel()
        serialNumberDeferred = deferred
        emitLog("control", "readSerialNumber requested timeoutMs=$timeoutMs")
        connection.send(TcbSerialNumberCommands.readSerialNumber())

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Serial number read timeout",
                retriable = true,
                details = mapOf("timeoutMs" to timeoutMs),
            )
        return mapOf("serialNumber" to matched)
    }

    suspend fun setGear(gear: Int, timeoutMs: Long): Map<String, Any?> {
        val resolved = when (gear) {
            0 -> ScooterGear.ZERO
            1 -> ScooterGear.ONE
            2 -> ScooterGear.TWO
            3 -> ScooterGear.THREE
            else -> throw BridgeNativeException(
                code = ErrorCodes.INVALID_ARGUMENT,
                message = "payload.gear must be 0..3",
                retriable = false,
                details = mapOf("gear" to gear),
            )
        }
        val deferred = CompletableDeferred<Int>()
        gearDeferred = deferred
        expectedGear = gear
        emitLog("control", "setGear requested gear=$gear timeoutMs=$timeoutMs")
        connection.send(Tcb05Commands.writeGear(resolved))

        val matched = withTimeoutOrNull(timeoutMs) { deferred.await() }
            ?: throw BridgeNativeException(
                code = ErrorCodes.TIMEOUT,
                message = "Gear command timeout waiting heartbeat confirmation",
                retriable = true,
                details = mapOf("gear" to gear, "timeoutMs" to timeoutMs),
            )

        return mapOf("gear" to matched)
    }

    fun setFrontLight(on: Boolean): Map<String, Any?> {
        connection.send(Tcb04Commands.writeFrontLight(on))
        return mapOf("frontLightOn" to on)
    }

    private fun handleScanResults(results: List<ScanResult>) {
        results.forEach { scansByMac[it.mac] = it }
        val fingerprint = results
            .joinToString(separator = "|") { "${it.mac}:${it.rssi}:${it.model}" }
        if (fingerprint == lastScanFingerprint) return
        lastScanFingerprint = fingerprint

        val payload = mapOf(
            "state" to "scanning",
            "device" to null,
            "reason" to null,
            "retriable" to false,
            "scanResults" to results.map {
                mapOf(
                    "name" to it.name,
                    "deviceId" to it.mac,
                    "mac" to it.mac,
                    "rssi" to it.rssi,
                    "model" to it.model,
                )
            },
        )
        onConnectionEvent(payload)
        if (results.isNotEmpty()) {
            emitLog("scan", "scan callback devices=${results.size} strongest=${results.first().name}/${results.first().mac}/${results.first().rssi}")
        }
    }

    private fun handleBleState(state: BleState) {
        when (state) {
            BleState.Idle -> {
                emitConnection("idle", reason = null, retriable = false, device = null)
                connectedDeviceId = null
                if (pendingConnectMac != null && connectDeferred?.isCompleted == false) {
                    connectDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while connecting",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                if (lockDeferred?.isCompleted == false) {
                    lockDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting lock confirmation",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                lockDeferred = null
                expectedLockState = null
                if (gearDeferred?.isCompleted == false) {
                    gearDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting gear confirmation",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                gearDeferred = null
                expectedGear = null
                if (throttleResponseDeferred?.isCompleted == false) {
                    throttleResponseDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting throttle response read",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                throttleResponseDeferred = null
                if (brakeResponseDeferred?.isCompleted == false) {
                    brakeResponseDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting brake response read",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                brakeResponseDeferred = null
                if (nfcStatusDeferred?.isCompleted == false) {
                    nfcStatusDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting NFC status read",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                nfcStatusDeferred = null
                expectedNfcStatus = null
                if (ambientLightDeferred?.isCompleted == false) {
                    ambientLightDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting ambient light confirmation",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                ambientLightDeferred = null
                expectedAmbientLight = null
                if (temperatureDeferred?.isCompleted == false) {
                    temperatureDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting controller temperature read",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                temperatureDeferred = null
                expectedTemperatureType = null
                if (drivingCurrentDeferred?.isCompleted == false) {
                    drivingCurrentDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting driving current read",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                drivingCurrentDeferred = null
                if (remainingMileageDeferred?.isCompleted == false) {
                    remainingMileageDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting remaining mileage read",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                remainingMileageDeferred = null
                if (tripMileageDeferred?.isCompleted == false) {
                    tripMileageDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting trip mileage read",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                tripMileageDeferred = null
                if (totalMileageDeferred?.isCompleted == false) {
                    totalMileageDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting ODO read",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                totalMileageDeferred = null
                if (speedStatsDeferred?.isCompleted == false) {
                    speedStatsDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting speed stats read",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                speedStatsDeferred = null
                if (serialNumberDeferred?.isCompleted == false) {
                    serialNumberDeferred?.completeExceptionally(
                        BridgeNativeException(
                            code = ErrorCodes.BLE_DISCONNECTED,
                            message = "Disconnected while waiting serial number read",
                            retriable = true,
                            details = null,
                        )
                    )
                }
                serialNumberDeferred = null
                pendingConnectMac = null
            }
            BleState.Scanning -> emitConnection("scanning", reason = null, retriable = false, device = null)
            is BleState.Connecting -> emitConnection("connecting", reason = null, retriable = false, device = state.mac)
            is BleState.Connected -> {
                emitLog("connection", "connect success mac=${state.mac} model=${state.model}")
                emitConnection("connected", reason = null, retriable = false, device = state.mac)
                if (pendingConnectMac == null || pendingConnectMac == state.mac) {
                    val scan = scansByMac[state.mac] ?: ScanResult(
                        name = "Unknown",
                        mac = state.mac,
                        rssi = 0,
                        model = state.model,
                        scanRecord = ByteArray(0),
                    )
                    connectDeferred?.complete(scan)
                    pendingConnectMac = null
                }
            }
            is BleState.Error -> {
                emitLog("connection", "connect failure reason=${state.message}")
                emitConnection("error", reason = state.message, retriable = true, device = pendingConnectMac)
                connectDeferred?.completeExceptionally(
                    BridgeNativeException(
                        code = ErrorCodes.BLE_OPERATION_FAILED,
                        message = state.message,
                        retriable = true,
                        details = null,
                    )
                )
                pendingConnectMac = null
            }
        }
    }

    private fun handleRx(packet: ByteArray) {
        val now = System.currentTimeMillis()
        val functionCode = packet.getOrNull(2)?.toInt()?.and(0xFF)
        val isHeartbeat = functionCode == 0x01
        if (!isHeartbeat || now - lastHeartbeatRxLogMs >= HEARTBEAT_RX_LOG_INTERVAL_MS) {
            emitLog("rx", packet.joinToString("") { "%02X".format(it.toInt() and 0xFF) })
            if (isHeartbeat) {
                lastHeartbeatRxLogMs = now
            }
        }
        val parsed = TcbResponseParser.parse(packet)
        when (parsed) {
            is TcbResponse.HeartbeatUpdate -> {
                latestHeartbeat = parsed.value
                emitTelemetry("heartbeat", heartbeatMap(parsed.value))
                emitTelemetry("faultFlags", faultMap(parsed.value))
                emitTelemetry("operationalStatus", operationalStatusMap(parsed.value))
                val expected = expectedLockState
                if (expected != null && parsed.value.locked == expected) {
                    expectedLockState = null
                    lockDeferred?.complete(parsed.value.locked)
                    lockDeferred = null
                }
                val expectedGearValue = expectedGear
                if (expectedGearValue != null && parsed.value.gear == expectedGearValue) {
                    expectedGear = null
                    gearDeferred?.complete(parsed.value.gear)
                    gearDeferred = null
                }
            }
            is TcbResponse.BindUpdate -> {
                emitTelemetry(
                    "config",
                    mapOf(
                        "bluetoothReady" to parsed.value.bluetoothReady,
                        "locked" to parsed.value.locked,
                        "boundId" to parsed.value.boundId,
                    )
                )
            }
            is TcbResponse.ResponseTuningUpdate -> {
                val throttleValue = parsed.value.throttle
                if (throttleValue != null) {
                    throttleResponseDeferred?.complete(throttleValue)
                    throttleResponseDeferred = null
                    emitTelemetry("responseTuning", mapOf("throttle" to throttleValue))
                } else {
                    val brakeValue = parsed.value.brake
                    if (brakeValue != null) {
                        brakeResponseDeferred?.complete(brakeValue)
                        brakeResponseDeferred = null
                    }
                    emitTelemetry("responseTuning", mapOf("brake" to brakeValue))
                }
            }
            is TcbResponse.NfcStatusUpdate -> {
                val expected = expectedNfcStatus
                if (expected == null || expected == parsed.enabled) {
                    nfcStatusDeferred?.complete(parsed.enabled)
                    nfcStatusDeferred = null
                    expectedNfcStatus = null
                }
                emitTelemetry("nfc", mapOf("enabled" to parsed.enabled))
            }
            is TcbResponse.LightUpdate -> {
                val expected = expectedAmbientLight
                if (expected == null || expected == parsed.value.ambientOn) {
                    ambientLightDeferred?.complete(parsed.value.ambientOn)
                    ambientLightDeferred = null
                    expectedAmbientLight = null
                }
                emitTelemetry("light", mapOf("ambientOn" to parsed.value.ambientOn))
            }
            is TcbResponse.AmbientRgbUpdate -> {
                emitTelemetry(
                    "ambientRgb",
                    mapOf(
                        "mode" to parsed.value.mode.name,
                        "red" to parsed.value.red,
                        "green" to parsed.value.green,
                        "blue" to parsed.value.blue,
                        "brightness" to parsed.value.brightness,
                    )
                )
            }
            is TcbResponse.TemperatureUpdate -> {
                emitTelemetry(
                    "temperature",
                    mapOf(
                        "type" to parsed.type.name.lowercase(),
                        "celsius" to parsed.celsius,
                    )
                )
                val expected = expectedTemperatureType
                if (expected != null && expected == parsed.type) {
                    temperatureDeferred?.complete(parsed.celsius)
                    temperatureDeferred = null
                    expectedTemperatureType = null
                }
            }
            is TcbResponse.DrivingCurrentUpdate -> {
                emitTelemetry(
                    "drivingCurrent",
                    mapOf(
                        "realtimeAmps" to parsed.realtimeAmps,
                        "limitAmps" to parsed.limitAmps,
                    )
                )
                drivingCurrentDeferred?.complete(parsed.realtimeAmps to parsed.limitAmps)
                drivingCurrentDeferred = null
            }
            is TcbResponse.RemainingMileageUpdate -> {
                emitTelemetry("mileage", mapOf("remainingKm" to parsed.value))
                remainingMileageDeferred?.complete(parsed.value)
                remainingMileageDeferred = null
            }
            is TcbResponse.TripMileageUpdate -> {
                emitTelemetry("mileage", mapOf("tripKm" to parsed.value))
                tripMileageDeferred?.complete(parsed.value)
                tripMileageDeferred = null
            }
            is TcbResponse.TotalMileageUpdate -> {
                emitTelemetry("mileage", mapOf("odoKm" to parsed.value))
                totalMileageDeferred?.complete(parsed.value)
                totalMileageDeferred = null
            }
            is TcbResponse.SpeedStatsUpdate -> {
                emitTelemetry(
                    "speedStats",
                    mapOf(
                        "avgKmh" to parsed.avgKmh,
                        "maxKmh" to parsed.maxKmh,
                    )
                )
                speedStatsDeferred?.complete(parsed.avgKmh to parsed.maxKmh)
                speedStatsDeferred = null
            }
            is TcbResponse.SerialNumberUpdate -> {
                emitTelemetry("serialNumber", mapOf("serialNumber" to parsed.serial))
                serialNumberDeferred?.complete(parsed.serial)
                serialNumberDeferred = null
            }
            null -> Unit
            else -> {
                emitTelemetry(
                    "raw",
                    mapOf("responseType" to parsed::class.simpleName)
                )
            }
        }
    }

    private fun heartbeatMap(hb: Heartbeat): Map<String, Any?> =
        mapOf(
            "batteryPercent" to hb.batteryPercent,
            "batteryVoltage" to hb.batteryVoltage,
            "speedKmh" to hb.speed,
            "gear" to hb.gear,
            "lockStatus" to hb.locked,
            "headlightOn" to hb.headlightOn,
            "cruiseEnabled" to hb.cruiseOn,
            "metricUnit" to hb.metricUnit,
            "startMode" to hb.startMode,
            "faults" to faultMap(hb),
        )

    private fun faultMap(hb: Heartbeat): Map<String, Any?> =
        mapOf(
            "undervoltage" to hb.faults.undervoltage,
            "gyroscope" to hb.faults.gyroscope,
            "battery" to hb.faults.battery,
            "controller" to hb.faults.controller,
            "mos" to hb.faults.mos,
            "motorHall" to hb.faults.motorHall,
            "brake" to hb.faults.brake,
            "turnHandle" to hb.faults.turnHandle,
            "communication" to hb.faults.communication,
            "batteryOvervoltage" to hb.faults.batteryOvervoltage,
            "batteryTemperatureHigh" to hb.faults.batteryTemperatureHigh,
            "controllerTemperatureProtection" to hb.faults.controllerTemperatureProtection,
        )

    private fun operationalStatusMap(hb: Heartbeat): Map<String, Any?> =
        mapOf(
            "lockStatus" to hb.locked,
            "headlightOn" to hb.headlightOn,
            "cruiseEnabled" to hb.cruiseOn,
            "startMode" to hb.startMode,
            "gear" to hb.gear,
            "metricUnit" to hb.metricUnit,
        )

    private fun emitConnection(
        state: String,
        reason: String?,
        retriable: Boolean,
        device: String?,
    ) {
        onConnectionEvent(
            mapOf(
                "state" to state,
                "device" to device,
                "reason" to reason,
                "retriable" to retriable,
            )
        )
    }

    private fun emitTelemetry(type: String, data: Map<String, Any?>) {
        onTelemetryEvent(
            mapOf(
                "type" to type,
                "timestampMs" to System.currentTimeMillis(),
                "source" to "android",
                "deviceId" to (connectedDeviceId ?: pendingConnectMac),
                "data" to data,
            )
        )
    }

    private fun emitLog(category: String, message: String) {
        onLogEvent(
            mapOf(
                "category" to category,
                "message" to message,
                "timestampMs" to System.currentTimeMillis(),
                "source" to "android",
            )
        )
    }
}

private const val HEARTBEAT_RX_LOG_INTERVAL_MS = 1_500L

internal class BridgeNativeException(
    val code: String,
    override val message: String,
    val retriable: Boolean,
    val details: Any?,
) : RuntimeException(message)

internal object ErrorCodes {
    const val TIMEOUT = "TIMEOUT"
    const val BLE_DISCONNECTED = "BLE_DISCONNECTED"
    const val BLE_UNAVAILABLE = "BLE_UNAVAILABLE"
    const val BLE_PERMISSION_DENIED = "BLE_PERMISSION_DENIED"
    const val BLE_OPERATION_FAILED = "BLE_OPERATION_FAILED"
    const val SDK_BUILD_FRAME_FAILED = "SDK_BUILD_FRAME_FAILED"
    const val SDK_PARSE_FAILED = "SDK_PARSE_FAILED"
    const val INVALID_PACKET = "INVALID_PACKET"
    const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
    const val UNSUPPORTED_FEATURE = "UNSUPPORTED_FEATURE"
    const val OTA_IN_PROGRESS = "OTA_IN_PROGRESS"
    const val OTA_FAILED = "OTA_FAILED"
    const val INTERNAL_ERROR = "INTERNAL_ERROR"
}
