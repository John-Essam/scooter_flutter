package com.example.scooter_android_demo.model.enums

import java.util.UUID

enum class DeviceModel (
    val serviceUuid: UUID,
    val advHex: String
) {
    OX1(
        UUID.fromString("5443000F-0163-6172-646F-467831FBFFFF"),
        "FFFFFB3178466F64726163010F004354"
    ),
    OX2(
        UUID.fromString("5443000F-0163-6172-646F-467832FBFFFF"),
        "FFFFFB3278466F64726163010F004354"
    ),
    OX3(
        UUID.fromString("5443000B-0152-572D-4754-FFFFFFF7FFFF"),
        "FFFFF7FFFFFF54472D5752010B004354"
    );

    companion object {
        fun fromAdvHex(hex: String): DeviceModel? =
            entries.firstOrNull() { hex.contains(it.advHex) }

        fun fromServiceUuid(uuid: UUID): DeviceModel? =
            entries.firstOrNull() { uuid == it.serviceUuid }
    }
}