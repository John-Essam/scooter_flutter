package com.example.scooter_bridge_arch.bridge

import android.annotation.SuppressLint
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

internal class ScooterMethodHandler(
    private val eventEmitter: ScooterEventEmitter,
) {
    private lateinit var native: RealAndroidBleBridge
    private val methodScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    fun onConnectionEvent(event: Map<String, Any?>) {
        eventEmitter.emitConnection(event)
    }

    fun bindNative(nativeBridge: RealAndroidBleBridge) {
        native = nativeBridge
    }

    fun onMethodCall(channel: String, call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val requestId = args?.get("requestId") as? String

        if (requestId.isNullOrBlank()) {
            result.success(errorEnvelope("", ErrorCodes.INVALID_ARGUMENT, "requestId is required", null, false))
            return
        }

        val timeoutMs = when (val timeout = args["timeoutMs"]) {
            is Int -> timeout.toLong()
            is Long -> timeout
            is Double -> timeout.toLong()
            else -> BridgeContract.DEFAULT_TIMEOUT_MS
        }
        val payload = args["payload"] as? Map<*, *> ?: emptyMap<String, Any?>()

        methodScope.launch {
            try {
                val response = when (channel) {
                    BridgeContract.CHANNEL_CONNECTION -> handleConnection(call.method, payload, requestId, timeoutMs)
                    BridgeContract.CHANNEL_CONTROL -> handleControl(call.method, payload, requestId, timeoutMs)
                    else -> errorEnvelope(requestId, ErrorCodes.INTERNAL_ERROR, "Unknown channel", mapOf("channel" to channel), false)
                }
                result.success(response)
            } catch (e: BridgeNativeException) {
                result.success(errorEnvelope(requestId, e.code, e.message, e.details, e.retriable))
            } catch (e: SecurityException) {
                result.success(errorEnvelope(requestId, ErrorCodes.BLE_PERMISSION_DENIED, e.message ?: "Permission denied", null, false))
            } catch (e: Throwable) {
                result.success(errorEnvelope(requestId, ErrorCodes.INTERNAL_ERROR, e.message ?: "Internal error", null, false))
            }
        }
    }

    fun dispose() {
        methodScope.cancel()
    }

    @SuppressLint("MissingPermission")
    private suspend fun handleConnection(
        method: String,
        payload: Map<*, *>,
        requestId: String,
        timeoutMs: Long,
    ): Map<String, Any?> {
        val data = when (method) {
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
                    ?: throw BridgeNativeException(
                        code = ErrorCodes.INVALID_ARGUMENT,
                        message = "payload.deviceId is required",
                        retriable = false,
                        details = null,
                    )
                native.connect(deviceId, timeoutMs)
            }
            "bind" -> native.bind()
            "disconnect" -> native.disconnect()
            else -> return unsupported(requestId, method)
        }

        return successEnvelope(requestId, data)
    }

    private suspend fun handleControl(
        method: String,
        payload: Map<*, *>,
        requestId: String,
        timeoutMs: Long,
    ): Map<String, Any?> {
        val data = when (method) {
            "setLock" -> {
                val locked = payload["locked"] as? Boolean
                    ?: throw BridgeNativeException(
                        code = ErrorCodes.INVALID_ARGUMENT,
                        message = "payload.locked is required",
                        retriable = false,
                        details = null,
                    )
                native.setLock(locked, timeoutMs)
            }
            "setCruiseControl" -> {
                val enabled = payload["enabled"] as? Boolean
                    ?: throw BridgeNativeException(
                        code = ErrorCodes.INVALID_ARGUMENT,
                        message = "payload.enabled is required",
                        retriable = false,
                        details = null,
                    )
                native.setCruiseControl(enabled)
            }
            "setGear" -> {
                val gear = when (val value = payload["gear"]) {
                    is Int -> value
                    is Long -> value.toInt()
                    is Double -> value.toInt()
                    else -> throw BridgeNativeException(
                        code = ErrorCodes.INVALID_ARGUMENT,
                        message = "payload.gear is required",
                        retriable = false,
                        details = null,
                        )
                }
                native.setGear(gear, timeoutMs)
            }
            "setFrontLight" -> {
                val on = payload["on"] as? Boolean
                    ?: throw BridgeNativeException(
                        code = ErrorCodes.INVALID_ARGUMENT,
                        message = "payload.on is required",
                        retriable = false,
                        details = null,
                    )
                native.setFrontLight(on)
            }
            else -> return unsupported(requestId, method)
        }

        return successEnvelope(requestId, data)
    }

    private fun unsupported(requestId: String, method: String): Map<String, Any?> {
        return errorEnvelope(
            requestId = requestId,
            code = ErrorCodes.UNSUPPORTED_FEATURE,
            message = "Method is not implemented in current integration phase",
            details = mapOf("method" to method, "phase" to "scan_connect_lock_gear_heartbeat"),
            retriable = false,
        )
    }
}
