# OTA fix — what was broken and how it was fixed

The bundled `TCBSDK.jar` ships a `TCBECMD.startOTA()` driver that orchestrates the entire 0xE0 / 0xE1 / 0xE2 firmware-upgrade sequence. On the **cardoO Scooter v3 (S3)** firmware that driver does not progress past the `TCBE0Model` ready-ack — see issue [#6](https://github.com/hussien-ibrahem/scooter-sdk-hussien/issues/6). After comparing against the working implementation in [`scooter_android_demo`](../../../scooter_android_demo-main/), we replaced the SDK driver with a hand-rolled OTA state machine that matches what the v3 firmware actually expects.

## What the SDK got wrong (best guesses)

The SDK is closed-source, so we can't see the exact bug — but three differences between our reference implementation and the SDK's behaviour explain the failure mode.

1. **Protocol-side chunk index offset is target-dependent.**
   * Controller packets are numbered starting at **0**.
   * Meter packets are numbered starting at **1**.
   The SDK appears to use the same starting index for both targets, so the meter firmware silently drops the very first packet and the state machine stalls.

2. **Chunk size is fixed at 128 bytes.** Different chunk sizes produce silent NAKs from the v3 controller. The SDK's `TCBECMD` either uses a different size or computes it from the binary, which our firmware rejects.

3. **CRC32 envelope uses a non-standard polynomial.** The v3 firmware verifies the binary with a CRC-32/MPEG-2 style algorithm (poly `0x04C11DB7`, init `0xFFFFFFFF`, no reflection, no final XOR, input padded with `0xFF` to a 4-byte multiple). The SDK appears to use the IEEE 802.3 CRC variant, so even when the upload completes the final `0xE2` verification frame returns "CRC mismatch".

There is also a fourth, layered problem: the SDK exposes `startOTA()` and `sendNextPacket(TCBE1Model)` but **no public method to acknowledge the `TCBE0Model` ready frame**. The previous workaround in `BleManager` (seeding a synthetic `TCBE1Model(index = 0, isDataReceivingStatus = true)` after E0) is brittle and may be a fifth contributing failure.

## The fix

Bypass `TCBECMD.startOTA()` entirely. Build the OTA frames ourselves and run our own state machine. The SDK is still used to **parse** the `TCBE0Model` / `TCBE1Model` / `TCBE2Model` responses (via `TCBManager.convertToModel`) — we just don't trust it to **send**.

### Frame format used by the OTA driver

```
5A | addr | funcLow | funcHigh | length(1 byte) | payload | crc16(big-endian, 2 bytes)
```

* `addr`: `0x21` for the controller, `0x23` for the meter (write-with-reply address).
* `funcLow` / `funcHigh`: `0xE0 / 0x00` (ready query), `0xE1 / 0x00` (data chunk), `0xE2 / 0x00` (CRC32 verify).
* `length`: single byte. Maxes out at 130 for `0xE1` (2-byte index + 128-byte chunk) — fits in one byte.

This is implemented in `protocol/OtaFrameBuilder.kt` and `protocol/TcbCrc16.kt`.

### State machine

```
Idle
 ├─ start(bytes, target)            →  Preparing
 │                                     │
 │      sendReadyRequest (E0)         ↓
 │                                  WaitingReady
 │                                     │
 │      TCBE0Model.isReadyToUpgrade   ↓
 │      → handleReadyAck(true)        │
 │                                  Sending(0, totalChunks)
 │                                     │
 │      send chunk N (E1)              │
 │      ── repeat until last chunk ────┘
 │                                     ↓
 │      send CRC32 (E2)               Verifying
 │                                     │
 │      TCBE2Model.completion = true  ↓
 │                                  Completed
 │
 ├─ failure / disconnect          →  Failed(reason) / Cancelled
```

Per-chunk retry budget is **10**; a NAK on a chunk or a CRC mismatch retries the same step before giving up.

This is implemented in `ota/OtaManager.kt`, with supporting classes `OtaState`, `OtaTarget`, `OtaSession`, `OtaPreview`, and `OtaChunkPlanner`.

### Bootloader / Flash OTA

Still **intentionally disabled** in the UI. Protocol §3.4 says *"Currently only Instrument APP, Instrument Flash, and Controller APP are upgraded. Other upgrade mechanisms are not implemented."* The reference project we copied from doesn't implement those paths either — its `OtaTarget` enum only has `METER` and `CONTROLLER`. Flashing the bootloader would require vendor-signed binaries plus a JTAG-level recovery setup, neither of which we have.

## Files involved

```
app/src/main/java/com/cardoo/scooter/
├── protocol/
│   ├── OtaFrameBuilder.kt    ← 5A|addr|funcLow|funcHigh|len|payload|crc16 envelope
│   ├── TcbCrc16.kt           ← protocol CRC-16 used by the envelope
│   └── TcbCrc32.kt           ← CRC-32/MPEG-2 used for the 0xE2 finalisation
└── ota/
    ├── OtaTarget.kt          ← Controller (addr 0x21) / Meter (addr 0x23)
    ├── OtaState.kt           ← sealed interface (Idle, Preparing, …, Failed)
    ├── OtaSession.kt         ← in-flight session state holder
    ├── OtaPreview.kt         ← UI preview snapshot
    ├── OtaChunkPlanner.kt    ← fixed 128-byte chunker
    └── OtaManager.kt         ← state machine + retry budget + frame dispatch
```

`BleManager.kt` now:
* Holds a single `OtaManager` instance wired to `writeRaw` and the listener fan-out.
* `startControllerFirmwareOta(bytes, sourceLabel)` / `startMeterFirmwareOta(bytes, sourceLabel)` delegate to `OtaManager.start`.
* Forwards `TCBE0Model` / `TCBE1Model` / `TCBE2Model` responses (still parsed by `TCBManager.convertToModel`) into `OtaManager.handleReadyAck` / `handleDataAck` / `handleCrcAck`.
* On any BLE disconnect, calls `OtaManager.onDisconnect()` so an in-flight OTA is cleanly aborted.

`BleEventListener.onOtaStateChanged(state: OtaState)` now takes the sealed interface from the `ota` package. `MainActivity.onOtaStateChanged` renders the `Sending(sent, total)` value into a `"chunk N/M"` suffix so the user sees concrete progress instead of a blanket "Sending".

The plain enum `OtaState` previously declared in `ble/BleModels.kt` is kept as a `typealias` to the new sealed interface so anything that imports `com.cardoo.scooter.ble.OtaState` keeps compiling.

## Credit

The state-machine layout, chunk size, target-side index offset, retry budget, and CRC-32 implementation were ported from the open-source [`scooter_android_demo`](https://github.com/) reference project at `/Users/dev.husseincardoo.co/Desktop/PC/Projects/cardoO App/scooter_android_demo-main/`. Its `OtaManager`, `OtaChunkPlanner`, `OtaTarget`, and `TcbCrc32` files were the basis for ours — adapted to our Handler-based, no-coroutine code style and to use the project's existing `BleEventListener` fan-out instead of a `StateFlow`.
