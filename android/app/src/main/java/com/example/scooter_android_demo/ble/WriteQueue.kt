package com.example.scooter_android_demo.ble

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class WriteQueue(
    scope: CoroutineScope,
    private val delayMs: Long = 200L,
    private val writeNow: (ByteArray) -> Boolean
) {
    private val queue = Channel<ByteArray>(Channel.UNLIMITED)

    init {
        scope.launch {
            for (packet in queue) {
                writeNow(packet)
                delay(delayMs)
            }
        }
    }

    fun enqueue(packet: ByteArray) {
        queue.trySend(packet)
    }

    fun enqueueAll(packets: List<ByteArray>) {
        packets.forEach(::enqueue)
    }
}
