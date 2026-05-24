package com.example.scooter_android_demo.commands

import com.example.scooter_android_demo.model.AmbientRgbStatus
import com.example.scooter_android_demo.model.enums.AmbientLightMode
import com.example.scooter_android_demo.protocol.TcbManualFrame
import com.example.tcblecomminucation.TCBConstant.TCBAmbientLightType
import com.example.tcblecomminucation.cmd.TCB1ACMD

object Tcb1ACommands {
    fun readAmbientLight(): ByteArray = TCB1ACMD.readAmbientLight()

    fun writeAmbientLight(status: AmbientRgbStatus): ByteArray {
        val r = status.red.scaledBy(status.brightness)
        val g = status.green.scaledBy(status.brightness)
        val b = status.blue.scaledBy(status.brightness)
        return when (status.mode) {
            AmbientLightMode.Monochrome ->
                TCB1ACMD.writeAmbientLight(TCBAmbientLightType.monochrome, packedRgb(r, g, b))
            AmbientLightMode.MonochromeBreathing ->
                TCB1ACMD.writeAmbientLight(TCBAmbientLightType.monochromeBreathing, packedRgb(r, g, b))
            AmbientLightMode.RunningEffect ->
                TcbManualFrame.write(
                    functionCode = FUNCTION_AMBIENT_LIGHT,
                    payload = byteArrayOf(MODE_RUNNING_EFFECT.toByte(), r.toByte(), g.toByte(), b.toByte(), 0xFF.toByte()),
                )
            AmbientLightMode.MagicSevenColors,
            AmbientLightMode.Rainbow ->
                TCB1ACMD.writeAmbientLight(TCBAmbientLightType.magicSevenColors, WHITE_COLOR)
        }
    }

    private fun Int.scaledBy(brightness: Int): Int =
        (this * brightness + MAX_COLOR / 2) / MAX_COLOR

    private fun packedRgb(r: Int, g: Int, b: Int): Int = (r shl 16) or (g shl 8) or b

    private const val WHITE_COLOR = 0xFFFFFF
    private const val FUNCTION_AMBIENT_LIGHT = 0x1A
    private const val MODE_RUNNING_EFFECT = 4
    private const val MAX_COLOR = 255
}
