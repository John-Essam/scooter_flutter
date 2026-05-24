package com.example.scooter_android_demo.commands

import com.example.tcblecomminucation.TCBConstant.TCBResponseType
import com.example.tcblecomminucation.cmd.TCB22CMD

object Tcb22Commands {
    fun readThrottleResponse(): ByteArray =
        TCB22CMD.readResponseTime(TCBResponseType.throttleResponse)

    fun readBrakeResponse(): ByteArray =
        TCB22CMD.readResponseTime(TCBResponseType.brakeResponse)
}
