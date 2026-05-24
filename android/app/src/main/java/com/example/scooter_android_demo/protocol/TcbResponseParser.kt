package com.example.scooter_android_demo.protocol

import com.example.scooter_android_demo.model.*
import com.example.scooter_android_demo.model.enums.AmbientLightMode
import com.example.scooter_android_demo.model.enums.DriveMode
import com.example.scooter_android_demo.model.enums.ScooterGear
import com.example.scooter_android_demo.model.enums.TempType
import android.util.Log
import com.example.tcblecomminucation.TCBConstant.TCBResponseType
import com.example.tcblecomminucation.TCBConstant.TCBDeviceType
import com.example.tcblecomminucation.TCBManager
import com.example.tcblecomminucation.model.TCB01Model
import com.example.tcblecomminucation.model.TCB02Model
import com.example.tcblecomminucation.model.TCB03Model
import com.example.tcblecomminucation.model.TCB04Model
import com.example.tcblecomminucation.model.TCB05DriveModel
import com.example.tcblecomminucation.model.TCB05MaxSpeedModel
import com.example.tcblecomminucation.model.TCB05Model
import com.example.tcblecomminucation.model.TCB08Model
import com.example.tcblecomminucation.model.TCB09Model
import com.example.tcblecomminucation.model.TCB0AModel
import com.example.tcblecomminucation.model.TCB0BModel
import com.example.tcblecomminucation.model.TCB11ControllerModel
import com.example.tcblecomminucation.model.TCB11MeterModel
import com.example.tcblecomminucation.model.TCB11Model
import com.example.tcblecomminucation.model.TCB1AModel
import com.example.tcblecomminucation.model.TCB22Model
import com.example.tcblecomminucation.model.TCB30Model
import com.example.tcblecomminucation.model.TCBE0Model
import com.example.tcblecomminucation.model.TCBE1Model
import com.example.tcblecomminucation.model.TCBE2Model
import java.nio.charset.StandardCharsets

object TcbResponseParser {
    private const val TAG = "TcbResponseParser"

    fun parse(packet: ByteArray): TcbResponse? {
        parseInterceptedFrame(packet)?.let { return it }

        val model = try {
            TCBManager.convertToModel(packet)
        } catch (e: Exception) {
            val func = if (packet.size >= 3) "0x%02X".format(packet[2].toInt() and 0xFF) else "?"
            Log.w(TAG, "SDK parse failed func=$func hex=${packet.toHexString()}", e)
            return parseManualFrame(packet)
        } ?: return null

        return when (model) {
            is TCB01Model -> TcbResponse.HeartbeatUpdate(
                Heartbeat(
                    speed = model.realTimeSpeed / 10,
                    batteryPercent = model.power,
                    batteryVoltage = model.batteryVoltage,
                    gear = model.gear,
                    locked = model.isLockStatus,
                    headlightOn = model.isHeadlight,
                    cruiseOn = model.isCruiseControlFunction,
                    metricUnit = model.metricMileUnit,
                    startMode = model.isStartMode,
                    faults = ScooterFaults(
                        undervoltage = model.isUndervoltageStatus,
                        gyroscope = model.isGyroscopeFault,
                        battery = model.isBatteryFault,
                        controller = model.isControllerFault,
                        mos = model.isMOSFault,
                        motorHall = model.isMotorHallFault,
                        brake = model.isBrakeFault,
                        turnHandle = model.isTurnHandleFault,
                        communication = model.isCommunicationFault,
                        batteryOvervoltage = model.isBatteryOvervoltage,
                        batteryTemperatureHigh = model.isBatteryTemperatureHigh,
                        controllerTemperatureProtection = model.isControllerTemperatureProtection,
                    )
                )
            )

            is TCB02Model -> TcbResponse.BindUpdate(
                BindStatus(
                    bluetoothReady = model.isBluetoothStatus,
                    locked = model.isLockStatus,
                    boundId = model.boundId,
                )
            )

            is TCB04Model -> TcbResponse.LightUpdate(
                LightStatus(ambientOn = model.ambientLightStatus)
            )

            is TCB05DriveModel -> TcbResponse.DriveModeUpdate(
                when (model.driveMode) {
                    2 -> DriveMode.Rear
                    else -> DriveMode.Unknown
                }
            )

            is TCB05MaxSpeedModel -> TcbResponse.MaxSpeedUpdate(model.maxSpeed.toUserSpeedLimit())

            is TCB05Model -> model.toGearMaxSpeedUpdate()

            is TCB11MeterModel -> TcbResponse.MeterVersionUpdate(model.toDeviceVersion())

            is TCB11ControllerModel -> TcbResponse.ControllerVersionUpdate(model.toDeviceVersion())

            is TCBE0Model -> TcbResponse.OtaReadyAck(model.isReadyToUpgrade)

            is TCBE1Model -> TcbResponse.OtaDataAck(model.isDataReceivingStatus, model.index)

            is TCBE2Model -> TcbResponse.OtaCrcAck(model.isUpgradeCompletionResponse)

            // -------------- Mileage -----------------
            is TCB08Model -> TcbResponse.TripMileageUpdate(model.singleTripMileage)
            is TCB09Model -> TcbResponse.TotalMileageUpdate(model.totalMileage)
            is TCB30Model -> TcbResponse.RemainingMileageUpdate(model.remainingMileage)
            is TCB0AModel -> model.type.toTempType()
                ?.let { TcbResponse.TemperatureUpdate(it, model.temp) }
                ?: TcbResponse.Unknown(model)
            is TCB0BModel -> TcbResponse.DrivingCurrentUpdate(
                realtimeAmps = model.drivingCurrent ?: 0f,
                limitAmps = 0f,
            )

            // -------------- Ambient RGB -----------------
            is TCB1AModel -> TcbResponse.AmbientRgbUpdate(
                AmbientRgbStatus(
                    mode  = AmbientLightMode.fromMagicMode(model.magicLightMode),
                    red   = model.r,
                    green = model.g,
                    blue  = model.b,
                )
            )

            // -------------- NFC -----------------
            is TCB03Model -> model.nfcStatus
                ?.let { TcbResponse.NfcStatusUpdate(it) }
                ?: TcbResponse.Unknown(model)

            // -------------- Response tuning -----------------
            is TCB22Model -> when (model.responseType) {
                TCBResponseType.throttleResponse ->
                    TcbResponse.ResponseTuningUpdate(ResponseTuning(throttle = model.response))
                TCBResponseType.brakeResponse ->
                    TcbResponse.ResponseTuningUpdate(ResponseTuning(brake = model.response))
                else -> TcbResponse.Unknown(model)
            }

            else -> parseManualFrame(packet) ?: TcbResponse.Unknown(model)
        }
    }

    private fun parseManualFrame(packet: ByteArray): TcbResponse? {
        val frame = packet.toTcbFrameOrNull() ?: return null
        return when (frame.functionCode) {
            0x0A -> frame.payload.toTemperatureUpdate()
            0x0B -> frame.payload.toDrivingCurrentUpdate()
            0x0D -> frame.payload.toBatteryCapacityUpdate()
            0x0C,
            0x0E,
            0x0F,
            0x20 -> frame.toBatteryDataUpdate()
            0x31 -> frame.payload.toRidingTimeUpdate()
            0x32 -> frame.payload.toSpeedStatsUpdate()
            0x1D -> TcbResponse.SerialNumberUpdate(frame.payload.toAsciiString())
            0x1E -> TcbResponse.DeviceInfoUpdate(frame.payload.toAsciiString())
            0x06 -> frame.payload.toAutoPowerOffUpdate()
            else -> null
        }
    }

    private fun parseInterceptedFrame(packet: ByteArray): TcbResponse? {
        // The vendor SDK can drop 0x0A temperature replies, so handle them
        // before convertToModel() just like the reference android_demo does.
        if (packet.size < MIN_INTERCEPTED_FRAME_SIZE || packet[0] != TCB_HEADER) return null
        if ((packet[1].toInt() and REPLY_ADDRESS_MASK) != REPLY_ADDRESS_PREFIX) return null
        val funcLow = packet[2].toInt() and 0xFF
        return when (funcLow) {
            0x0A -> packet.toInterceptedTemperatureUpdate()
            0x0B -> packet.toTcbFrameOrNull()?.payload?.toDrivingCurrentUpdate()
            0x05 -> packet.toTcbFrameOrNull()?.payload?.toSpeedLimitUpdate()
            0x0D -> packet.toTcbFrameOrNull()?.payload?.toBatteryCapacityUpdate()
            0x0C,
            0x0E,
            0x0F,
            0x20 -> packet.toTcbFrameOrNull()?.toBatteryDataUpdate()
            0x1D -> packet.toTcbFrameOrNull()?.payload?.let {
                TcbResponse.SerialNumberUpdate(it.toAsciiString())
            }
            0x1E -> packet.toTcbFrameOrNull()?.payload?.let {
                TcbResponse.DeviceInfoUpdate(it.toAsciiString())
            }
            0x32 -> packet.toTcbFrameOrNull()?.payload?.toSpeedStatsUpdate()
            0x06 -> packet.toCompactTcbPayloadOrNull()?.toAutoPowerOffUpdate()
                ?: packet.toTcbFrameOrNull()?.payload?.toAutoPowerOffUpdate()
            else -> null
        }
    }
}

private fun TCB11Model.toDeviceVersion() = DeviceVersion(
    manufacturerCode = manufacturerCode.orEmpty(),
    hardwareVersion = hardwareVersion.orEmpty(),
    binVersion = binVersion.orEmpty()
)

private fun TCB05Model.toGearMaxSpeedUpdate(): TcbResponse =
    when (gear) {
        0 -> TcbResponse.GearMaxSpeedUpdate(ScooterGear.ZERO, speed.toUserSpeedLimit())
        1 -> TcbResponse.GearMaxSpeedUpdate(ScooterGear.ONE, speed.toUserSpeedLimit())
        2 -> TcbResponse.GearMaxSpeedUpdate(ScooterGear.TWO, speed.toUserSpeedLimit())
        3 -> TcbResponse.GearMaxSpeedUpdate(ScooterGear.THREE, speed.toUserSpeedLimit())
        else -> TcbResponse.Unknown(this)
    }

private fun TCBDeviceType?.toTempType(): TempType? =
    when (this) {
        TCBDeviceType.control -> TempType.Controller
        TCBDeviceType.battery -> TempType.Battery
        TCBDeviceType.motor -> TempType.Motor
        else -> null
    }

private fun ByteArray.toTcbFrameOrNull(): TcbFrame? {
    if (size < MIN_FRAME_SIZE || this[0] != TCB_HEADER) return null
    val payloadLength = u8(4)
    val crcIndex = FRAME_PREFIX_SIZE + payloadLength
    if (crcIndex + CRC_SIZE != size) return null

    val functionCode = u8(2) or (u8(3) shl 8)
    val crc = (u8(crcIndex) shl 8) or u8(crcIndex + 1)
    val frame = TcbFrame(
        header = this[0],
        address = this[1],
        functionCode = functionCode,
        payload = copyOfRange(FRAME_PREFIX_SIZE, crcIndex),
        crc = crc,
    )
    return frame.takeIf { it.isValid }
}

private fun ByteArray.toCompactTcbPayloadOrNull(): ByteArray? {
    if (size < MIN_COMPACT_FRAME_SIZE || this[0] != TCB_HEADER) return null
    val payloadLength = u8(3)
    val crcIndex = COMPACT_FRAME_PREFIX_SIZE + payloadLength
    if (crcIndex + CRC_SIZE != size) return null
    val expectedCrc = (u8(crcIndex) shl 8) or u8(crcIndex + 1)
    val actualCrc = TcbCrc16.calculate(copyOfRange(0, crcIndex))
    if (expectedCrc != actualCrc) return null
    return copyOfRange(COMPACT_FRAME_PREFIX_SIZE, crcIndex)
}

private fun ByteArray.toTemperatureUpdate(): TcbResponse.TemperatureUpdate? {
    if (size < 2) return null
    val type = when (u8(0)) {
        0x00 -> TempType.Controller
        0x10 -> TempType.Battery
        0x30 -> TempType.Motor
        else -> return null
    }
    return TcbResponse.TemperatureUpdate(type, u8(1).toTemperatureCelsius())
}

private fun ByteArray.toInterceptedTemperatureUpdate(): TcbResponse.TemperatureUpdate? {
    val raw = u8(size - 3)
    val celsius = raw.toTemperatureCelsius()
    if (size < STANDARD_TEMP_REPLY_SIZE) {
        return TcbResponse.TemperatureUpdate(TempType.Controller, celsius)
    }

    val typeNibble = (u8(size - 4) shr 4) and 0x0F
    val type = when (typeNibble) {
        0x0 -> TempType.Controller
        0x1 -> TempType.Battery
        0x3 -> TempType.Motor
        else -> return null
    }
    return TcbResponse.TemperatureUpdate(type, celsius)
}

private fun Int.toTemperatureCelsius(): Int = this - 60

private fun ByteArray.toDrivingCurrentUpdate(): TcbResponse.DrivingCurrentUpdate? =
    when {
        size >= 3 -> TcbResponse.DrivingCurrentUpdate(
            realtimeAmps = s16(1) / TENTH_SCALE,
            limitAmps = u8(0) / TENTH_SCALE,
        )
        size >= 2 -> TcbResponse.DrivingCurrentUpdate(
            realtimeAmps = s16(0) / TENTH_SCALE,
            limitAmps = 0f,
        )
        size >= 1 -> TcbResponse.DrivingCurrentUpdate(
            realtimeAmps = u8(0) / TENTH_SCALE,
            limitAmps = 0f,
        )
        else -> null
    }

private fun ByteArray.toSpeedLimitUpdate(): TcbResponse? {
    if (size < 2) return null
    val speed = u8(1).toUserSpeedLimit()
    return when (u8(0)) {
        0x00 -> TcbResponse.MaxSpeedUpdate(speed)
        0x18 -> TcbResponse.GearMaxSpeedUpdate(ScooterGear.ZERO, speed)
        0x19 -> TcbResponse.GearMaxSpeedUpdate(ScooterGear.ONE, speed)
        0x1A -> TcbResponse.GearMaxSpeedUpdate(ScooterGear.TWO, speed)
        0x1B -> TcbResponse.GearMaxSpeedUpdate(ScooterGear.THREE, speed)
        else -> null
    }
}

private fun Int.toUserSpeedLimit(): Int =
    (this - SPEED_LIMIT_OFFSET).coerceAtLeast(0)

private fun TcbFrame.toBatteryDataUpdate(): TcbResponse.BatteryDataUpdate =
    TcbResponse.BatteryDataUpdate(
        functionCode = functionCode,
        payloadHex = payload.toHexString(),
    )

private fun ByteArray.toBatteryVoltageDetailUpdate(): TcbResponse.BatteryVoltageDetailUpdate? =
    when {
        size >= 2 -> TcbResponse.BatteryVoltageDetailUpdate(u16(0) / TENTH_SCALE)
        size >= 1 -> TcbResponse.BatteryVoltageDetailUpdate(u8(0) / TENTH_SCALE)
        else -> null
    }

private fun ByteArray.toBatteryCapacityUpdate(): TcbResponse.BatteryCapacityUpdate? {
    // Payload layout: [type_byte][capacity_hi][capacity_lo][health?]
    // type 0x00 = internal, 0x01 = external; capacity is at offset 1, not 0
    if (size < 3) return null
    return TcbResponse.BatteryCapacityUpdate(u16(1))
}

private fun ByteArray.toSpeedStatsUpdate(): TcbResponse.SpeedStatsUpdate? =
    when {
        size >= 4 -> TcbResponse.SpeedStatsUpdate(
            avgKmh = u16(0) / TENTH_SCALE,
            maxKmh = u16(2) / TENTH_SCALE,
        )
        size >= 2 -> TcbResponse.SpeedStatsUpdate(
            avgKmh = u8(0) / TENTH_SCALE,
            maxKmh = u8(1) / TENTH_SCALE,
        )
        else -> null
    }

private fun ByteArray.toRidingTimeUpdate(): TcbResponse.RidingTimeUpdate? =
    when {
        size >= 4 -> TcbResponse.RidingTimeUpdate(u32(0))
        size >= 2 -> TcbResponse.RidingTimeUpdate(u16(0).toLong())
        else -> null
    }

private fun ByteArray.toAutoPowerOffUpdate(): TcbResponse.AutoPowerOffUpdate? =
    when {
        size >= 2 -> TcbResponse.AutoPowerOffUpdate(u16(0))
        size >= 1 -> TcbResponse.AutoPowerOffUpdate(u8(0))
        else -> null
    }

private fun ByteArray.toAsciiString(): String =
    String(this, StandardCharsets.US_ASCII).trim('\u0000', ' ', '\r', '\n', '\t')

private fun ByteArray.u8(index: Int): Int = this[index].toInt() and 0xFF

private fun ByteArray.u16(index: Int): Int =
    (u8(index) shl 8) or u8(index + 1)

private fun ByteArray.s16(index: Int): Int {
    val value = u16(index)
    return if ((value and 0x8000) != 0) value - 0x10000 else value
}

private fun ByteArray.u32(index: Int): Long =
    ((u8(index).toLong() shl 24) or
        (u8(index + 1).toLong() shl 16) or
        (u8(index + 2).toLong() shl 8) or
        u8(index + 3).toLong())

private fun ByteArray.toHexString(): String =
    joinToString("") { "%02X".format(it.toInt() and 0xFF) }

private const val TCB_HEADER: Byte = 0x5A
private const val FRAME_PREFIX_SIZE = 5
private const val COMPACT_FRAME_PREFIX_SIZE = 4
private const val CRC_SIZE = 2
private const val MIN_FRAME_SIZE = FRAME_PREFIX_SIZE + CRC_SIZE
private const val MIN_COMPACT_FRAME_SIZE = COMPACT_FRAME_PREFIX_SIZE + CRC_SIZE
private const val MIN_INTERCEPTED_FRAME_SIZE = 7
private const val STANDARD_TEMP_REPLY_SIZE = 8
private const val REPLY_ADDRESS_MASK = 0xF0
private const val REPLY_ADDRESS_PREFIX = 0xB0
private const val TENTH_SCALE = 10f
private const val SPEED_LIMIT_OFFSET = 6
