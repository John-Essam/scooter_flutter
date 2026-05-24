package com.example.scooter_android_demo.commands

import com.example.scooter_android_demo.protocol.TcbAddress
import com.example.scooter_android_demo.protocol.TcbCommand
import com.example.scooter_android_demo.protocol.TcbCommandBuilder
import com.example.tcblecomminucation.cmd.TCB02CMD

object Tcb02Commands {
    private const val FEATURE_FUNCTION_CODE = 0x0202
    private const val START_MODE_MASK = 0x02

    fun connect(authLevel: Int = 5): ByteArray = TCB02CMD.writeConnect(authLevel)
    fun unitSystem(metric: Boolean): ByteArray = TCB02CMD.writeMetricMileSystemTheme(metric)
    fun lockStatus(locked: Boolean): ByteArray = TCB02CMD.writeLockStatus(locked)
    fun cruiseControl(enabled: Boolean): ByteArray = TCB02CMD.writeCruiseControlFunction(enabled)
    fun startMode(enabled: Boolean): ByteArray = writeFeatureBit(enabled, START_MODE_MASK)
    fun readUnbind(): ByteArray = TCB02CMD.readUnbind()

    private fun writeFeatureBit(enabled: Boolean, mask: Int): ByteArray =
        TcbCommandBuilder.build(
            TcbCommand(
                address = TcbAddress.METER_WRITE,
                functionCode = FEATURE_FUNCTION_CODE,
                payload = byteArrayOf(
                    if (enabled) mask.toByte() else 0x00.toByte(),
                    mask.toByte(),
                )
            )
        )
}
