package com.example.scooter_android_demo.channel

import android.annotation.SuppressLint
import android.content.Context
import com.example.scooter_bridge_arch.bridge.BridgeNativeException
import com.example.scooter_bridge_arch.bridge.ErrorCodes
import com.example.scooter_bridge_arch.bridge.RealAndroidBleBridge
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class ScooterMethodChannel(
    messenger: BinaryMessenger,
    context: Context,
) {
    private val methodChannel = MethodChannel(messenger, CHANNEL_NAME)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private val native = RealAndroidBleBridge(
        context = context.applicationContext,
        onConnectionEvent = { _ -> },
        onTelemetryEvent = { _ -> },
        onLogEvent = { _ -> },
    )

    init {
        methodChannel.setMethodCallHandler { call, result ->
            onMethodCall(call, result)
        }
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        scope.cancel()
        native.shutdown()
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val timeoutMs = when (val timeout = args["timeoutMs"]) {
            is Int -> timeout.toLong()
            is Long -> timeout
            is Double -> timeout.toLong()
            else -> DEFAULT_TIMEOUT_MS
        }
        val payload = args["payload"] as? Map<*, *> ?: emptyMap<String, Any?>()

        scope.launch {
            try {
                val response = handleMethod(call.method, payload, timeoutMs)
                result.success(response)
            } catch (e: BridgeNativeException) {
                result.error(e.code, e.message, e.details)
            } catch (e: SecurityException) {
                result.error(ErrorCodes.BLE_PERMISSION_DENIED, e.message ?: "Permission denied", null)
            } catch (e: Throwable) {
                result.error(ErrorCodes.INTERNAL_ERROR, e.message ?: "Internal error", null)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private suspend fun handleMethod(
        method: String,
        payload: Map<*, *>,
        timeoutMs: Long,
    ): Map<String, Any?> {
        return when (method) {
            "startScan" -> {
                native.startScan()
                mapOf("state" to "scanning")
            }
            "stopScan" -> {
                native.stopScan()
                mapOf("state" to "idle")
            }
            "connect" -> {
                val deviceId = payload["deviceId"] as? String
                    ?: throw invalidArg("payload.deviceId is required")
                native.connect(deviceId, timeoutMs)
            }
            "bind" -> native.bind()
            "unbind" -> native.unbind()
            "disconnect" -> native.disconnect()
            "setLock" -> {
                val locked = payload["locked"] as? Boolean
                    ?: throw invalidArg("payload.locked is required")
                native.setLock(locked, timeoutMs)
            }
            "setCruiseControl" -> {
                val enabled = payload["enabled"] as? Boolean
                    ?: throw invalidArg("payload.enabled is required")
                native.setCruiseControl(enabled)
            }
            "setStartMode" -> {
                val enabled = payload["enabled"] as? Boolean
                    ?: throw invalidArg("payload.enabled is required")
                native.setStartMode(enabled)
            }
            "setUnitSystem" -> {
                val metric = payload["metric"] as? Boolean
                    ?: throw invalidArg("payload.metric is required")
                native.setUnitSystem(metric)
            }
            "readThrottleResponse" -> native.readThrottleResponse(timeoutMs)
            "readBrakeResponse" -> native.readBrakeResponse(timeoutMs)
            "readControllerTemperature" -> native.readControllerTemperature(timeoutMs)
            "readBatteryTemperature" -> native.readBatteryTemperature(timeoutMs)
            "readMotorTemperature" -> native.readMotorTemperature(timeoutMs)
            "readDrivingCurrent" -> native.readDrivingCurrent(timeoutMs)
            "readRemainingMileage" -> native.readRemainingMileage(timeoutMs)
            "readTripMileage" -> native.readTripMileage(timeoutMs)
            "readOdo" -> native.readOdo(timeoutMs)
            "readSpeedStats" -> native.readSpeedStats(timeoutMs)
            "readSerialNumber" -> native.readSerialNumber(timeoutMs)
            "readDeviceInfo" -> native.readDeviceInfo(timeoutMs)
            "readMeterVersion" -> native.readMeterVersion(timeoutMs)
            "readControllerVersion" -> native.readControllerVersion(timeoutMs)
            "setThrottleBrakeResponse" -> {
                val throttle = numericPayload(payload, "throttle")
                val brake = numericPayload(payload, "brake")
                native.setThrottleBrakeResponse(throttle, brake)
            }
            "readNfcStatus" -> native.readNfcStatus(timeoutMs)
            "setNfcEnabled" -> {
                val enabled = payload["enabled"] as? Boolean
                    ?: throw invalidArg("payload.enabled is required")
                native.setNfcEnabled(enabled, timeoutMs)
            }
            "factoryReset" -> native.factoryReset()
            "setAmbientLight" -> {
                val on = payload["on"] as? Boolean
                    ?: throw invalidArg("payload.on is required")
                native.setAmbientLight(on, timeoutMs)
            }
            "setAmbientRgb" -> {
                val mode = numericPayload(payload, "mode")
                val red = numericPayload(payload, "red")
                val green = numericPayload(payload, "green")
                val blue = numericPayload(payload, "blue")
                val brightness = optionalNumericPayload(payload, "brightness") ?: 255
                native.setAmbientRgb(mode, red, green, blue, brightness)
            }
            "setRainbowMode" -> native.setRainbowMode()
            "readGearMaxSpeed" -> {
                val gear = numericPayload(payload, "gear")
                native.readGearMaxSpeed(gear, timeoutMs)
            }
            "setGear" -> {
                val gear = numericPayload(payload, "gear")
                native.setGear(gear, timeoutMs)
            }
            "setFrontLight" -> {
                val on = payload["on"] as? Boolean
                    ?: throw invalidArg("payload.on is required")
                native.setFrontLight(on)
            }
            else -> throw BridgeNativeException(
                code = ErrorCodes.UNSUPPORTED_FEATURE,
                message = "Method is not implemented in current integration phase",
                details = mapOf("method" to method, "phase" to "scan_connect_lock_gear_heartbeat"),
                retriable = false,
            )
        }
    }

    private fun numericPayload(payload: Map<*, *>, key: String): Int {
        return when (val value = payload[key]) {
            is Int -> value
            is Long -> value.toInt()
            is Double -> value.toInt()
            else -> throw invalidArg("payload.$key is required")
        }
    }

    private fun optionalNumericPayload(payload: Map<*, *>, key: String): Int? {
        return when (val value = payload[key]) {
            null -> null
            is Int -> value
            is Long -> value.toInt()
            is Double -> value.toInt()
            else -> throw invalidArg("payload.$key must be numeric")
        }
    }

    private fun invalidArg(message: String): BridgeNativeException {
        return BridgeNativeException(
            code = ErrorCodes.INVALID_ARGUMENT,
            message = message,
            details = null,
            retriable = false,
        )
    }

    companion object {
        private const val CHANNEL_NAME = "scooter/bridge"
        private const val DEFAULT_TIMEOUT_MS = 2_500L
    }
}
