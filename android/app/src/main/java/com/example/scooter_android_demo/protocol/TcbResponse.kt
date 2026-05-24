package com.example.scooter_android_demo.protocol

import com.example.scooter_android_demo.model.AmbientRgbStatus
import com.example.scooter_android_demo.model.BindStatus
import com.example.scooter_android_demo.model.DeviceVersion
import com.example.scooter_android_demo.model.Heartbeat
import com.example.scooter_android_demo.model.LightStatus
import com.example.scooter_android_demo.model.ResponseTuning
import com.example.scooter_android_demo.model.enums.DriveMode
import com.example.scooter_android_demo.model.enums.ScooterGear
import com.example.scooter_android_demo.model.enums.TempType
import com.example.tcblecomminucation.model.TCBBaseModel

sealed interface TcbResponse {
    data class HeartbeatUpdate(val value: Heartbeat) : TcbResponse
    data class BindUpdate(val value: BindStatus) : TcbResponse
    data class LightUpdate(val value: LightStatus) : TcbResponse
    data class DriveModeUpdate(val value: DriveMode) : TcbResponse
    data class MaxSpeedUpdate(val value: Int) : TcbResponse
    data class MeterVersionUpdate(val value: DeviceVersion) : TcbResponse
    data class ControllerVersionUpdate(val value: DeviceVersion) : TcbResponse
    data class Unknown(val rawModel: TCBBaseModel) : TcbResponse
    data class OtaReadyAck(val ready: Boolean) : TcbResponse
    data class OtaDataAck(val accepted: Boolean, val chunkIndex: Int) : TcbResponse
    data class OtaCrcAck(val success: Boolean) : TcbResponse

    // -------------- Mileage -----------------
    data class TripMileageUpdate(val value: Float) : TcbResponse
    data class TotalMileageUpdate(val value: Float) : TcbResponse
    data class RemainingMileageUpdate(val value: Float) : TcbResponse

    // -------------- Ambient RGB & NFC -----------------
    data class AmbientRgbUpdate(val value: AmbientRgbStatus) : TcbResponse
    data class NfcStatusUpdate(val enabled: Boolean) : TcbResponse

    // -------------- Settings -----------------
    data class ResponseTuningUpdate(val value: ResponseTuning) : TcbResponse
    data class GearMaxSpeedUpdate(val gear: ScooterGear, val maxSpeed: Int) : TcbResponse

    // -------------- Missing BLE feature responses -----------------
    data class TemperatureUpdate(val type: TempType, val celsius: Int) : TcbResponse
    data class DrivingCurrentUpdate(val realtimeAmps: Float, val limitAmps: Float) : TcbResponse
    data class BatteryVoltageDetailUpdate(val voltageV: Float) : TcbResponse
    data class BatteryCapacityUpdate(val capacityMah: Int) : TcbResponse
    data class BatteryDataUpdate(val functionCode: Int, val payloadHex: String) : TcbResponse
    data class SpeedStatsUpdate(val avgKmh: Float, val maxKmh: Float) : TcbResponse
    data class RidingTimeUpdate(val seconds: Long) : TcbResponse
    data class SerialNumberUpdate(val serial: String) : TcbResponse
    data class DeviceInfoUpdate(val info: String) : TcbResponse
    data class AutoPowerOffUpdate(val seconds: Int) : TcbResponse
}
