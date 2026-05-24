# Customized BLE Frames — SDK Gaps & Workarounds

This document catalogs every BLE feature in `BleManager.kt` that **cannot** be expressed as a single `TCBxxCMD.someBuilder(...).send(...)` call. For each one it explains what the **TCBSDK.jar SDK** provides, what the **TaoTao Controller Protocol v1.1.29** requires, and what we had to hand-build to bridge the gap.

> **TL;DR**: every customization here exists because the bundled SDK either doesn't expose a builder for the protocol function we need, or its builder doesn't cover the parameter range / variant we need. The bytes we send on the wire are still 100% protocol-compliant — they just go around the SDK instead of through it.

---

## Conventions used in this doc

- **Manual frame** = bytes assembled inline with `TCBHelper.hexStringToBytes("...")` plus a `TCBHelper.crc16` suffix.
- **SDK builder** = a `byte[]`-returning static method on a `TCBxxCMD` class (e.g. `TCB02CMD.writeLockStatus(true)`).
- All `0x` references use the protocol-doc function-code labels (e.g. `0x000B` = "Driving Current Query/Set Controller").
- Every manual frame is followed by the same `writeRaw(...)` transport that the SDK paths' `.send(...)` extension wraps — the only difference is who built the bytes.

---

## 1. Start Mode — zero-start / kick-start (`0x0002`)

**Method**: `BleManager.setStartMode(zeroStart: Boolean)` via `buildStartModeCommand`

**SDK status**: **No builder exists.** `TCB02CMD` exposes `writeConnect`, `readUnbind`, `writeLockStatus`, `writeCruiseControlFunction`, `writeMetricMileSystemTheme` — but **no `writeStartMode`**. The feature spreadsheet flags this as "Android JAR gap".

**Protocol**: function `0x0002`, LEN=2, byte5 = mode (`0x00` = zero-start, `0x02` = kick-start), byte6 = ack mask.

**What we send**:
```
5A 23 02 02 02 [mode] 02 + crc16
```

**Why this is fine**: identical to what an SDK builder would produce; only the wrapper is missing.

---

## 2. Driving Current Limit (`0x000B` type=1)

**Method**: `BleManager.readDrivingCurrentLimit()` via `buildDrivingCurrentCommand(type = 0x01)`

**SDK status**: **Builder is too narrow.** `TCB0BCMD.readDrivingCurrent()` exists, but it hard-codes the request byte to `0x00` (realtime). The "current limit" query (type=1) is unreachable through the SDK.

**Protocol**: function `0x000B`, LEN=3, byte5 = type (`0x00` realtime / `0x01` limit / `0x02` set), byte6/7 = data (zeros for queries).

**What we send for limit**:
```
5A 01 0B 00 03 01 00 00 + crc16
```

**Why this is fine**: realtime queries still go through the SDK. We only build manually for the limit variant because the SDK locks the type byte to `0x00`.

---

## 3. Auto Power-Off (`0x0006`) — read + set

**Methods**: `BleManager.readAutoPowerOff()`, `BleManager.setAutoPowerOff(seconds: Int)`

**SDK status**: **No builder exists.** Function `0x0006` ("Auto Power-Off Time Configuration Query/Set") has no entry on any `TCBxxCMD` class.

**Protocol**: function `0x0006`, LEN=0 for read / LEN=2 for set, payload = uint16 big-endian seconds, `0` = disabled, max `1800` (30 min).

**What we send**:
- Read: `5A 21 06 00 00 + crc16`
- Set: `5A 21 06 00 02 [hi] [lo] + crc16`

**Known issue on v3 firmware**: see [GitHub issue #5](https://github.com/hussien-ibrahem/scooter-sdk-hussien/issues/5). Read returns no notification; set transmits cleanly but is not echoed.

---

## 4. Battery Total Capacity (`0x000D`)

**Method**: `BleManager.readBatteryCapacity(internal: Boolean)`

**SDK status**: **No builder exists.**

**Protocol**: function `0x000D`, LEN=1, byte5 = battery type (`0x00` = internal / `0x01` = external). Response = LEN=4: type + 16-bit mAh + 8-bit health %.

**What we send**:
```
5A 21 0D 00 01 [type] + crc16
```

**Why this is fine**: works on S3. Confirmed reading both internal and external pack capacity successfully.

---

## 5. Serial Number (`0x001D`)

**Method**: `BleManager.readSerialNumber()`

**SDK status**: **No builder exists.** Sheet flags as "Manual frame 5A 01 1D 00 00 — no SDK helper".

**Protocol**: function `0x001D`, LEN=0 for read. Response is a 14-byte ASCII serial.

**What we send**:
```
5A 01 1D 00 00 + crc16
```

**Why this is fine**: works on S3.

---

## 6. Detailed Device Info (`0x001E`)

**Method**: `BleManager.readDetailedDeviceInfo()`

**SDK status**: **No builder exists.**

**Protocol**: function `0x001E`, LEN=0 for read. Response is a variable-length ASCII string with underscore-separated fields (customer, model, country/spec, voltage/current, HW version, SW version, date).

**What we send**:
```
5A 01 1E 00 00 + crc16
```

**Why this is fine**: works on S3. Parser auto-detects field layout (TC-style 7 fields vs cardoO v3 6 fields).

---

## 7. Speed Stats — avg / max (`0x0032`)

**Method**: `BleManager.readSpeedStats()`

**SDK status**: **No builder exists.**

**Protocol**: function `0x0032`, LEN=0 for read. Response = LEN=4 with two uint16 big-endian values (avg, max) in 0.1 km/h units.

**What we send**:
```
5A 01 32 00 00 + crc16
```

**Why this is fine**: works on S3, but note the "max" field tracks the trip peak with heavy smoothing rather than instantly — this is firmware behaviour, not a parser issue.

---

## 8. Password / Security Utilities (`0x00A4`, `0x00A7`, `0x00A8`, `0x00A9`)

**Methods**:
- `BleManager.verifyBluetoothPassword(password: String)` — `0x00A4`
- `BleManager.lockWithPassword(locked: Boolean, password: String)` — `0x00A7`
- `BleManager.changeLockPassword(old: String, new: String)` — `0x00A8`
- `BleManager.readAfterSalesPassword()` — `0x00A9`

**SDK status**: **No builders exist for any of the `0x00A0–0xAA` family.** Sheet flags entire row as "Protocol 0x00A0-0xAA — no SDK CMD builder".

**Protocol**:
- `0x00A4` BT Password Verify: LEN=6, six ASCII digits (`'0'`–`'9'` = `0x30`–`0x39`).
- `0x00A7` Lock with Password: LEN=7, one lock-control byte (bit7 = lock/unlock) + six ASCII digits.
- `0x00A8` Change Lock Password: LEN=12, six old digits + six new digits.
- `0x00A9` After-Sales Password Query: LEN=0 read, response is six digits.

**What we send**:
- Verify: `5A 21 A4 00 06 [d1..d6] + crc16`
- Lock/Unlock: `5A 21 A7 00 07 [lockByte] [d1..d6] + crc16`
- Change: `5A 21 A8 00 0C [old1..old6] [new1..new6] + crc16`
- After-sales read: `5A 01 A9 00 00 + crc16`

**Encoding assumption**: digits sent as ASCII (`0x30`–`0x39`). The protocol doc is ambiguous between ASCII and raw numeric — ASCII matches the most common Tao Chen controller convention.

**Known issue on v3 firmware**: all four functions are silent on S3 — see [GitHub issue #8](https://github.com/hussien-ibrahem/scooter-sdk-hussien/issues/8).

---

## 9. Ambient Light — Custom Color (variable-length payload)

**Method**: `BleManager.setAmbientLightSolidCustom(hex: String)`

**SDK status**: **Builder is too narrow.** `TCB1ACMD.writeAmbientLight(type, color: Int)` accepts a 24-bit RGB int — perfect for plain `#RRGGBB` inputs. We **do** route through SDK when the user enters exactly 6 hex chars (3 bytes). For longer inputs (`#RRGGBBAA` or arbitrary debug payloads) the SDK has no equivalent.

**Protocol**: function `0x001A`, mode `0x01` = monochrome, followed by RGB(A) bytes.

**What we send for non-RGB payloads**:
```
5A 21 1A 00 [LEN] [mode=01] [variable-length color bytes] + crc16
```

**Why this is fine**: 6-char RGB now goes through the SDK builder verbatim; manual is reserved for debug inputs that the SDK can't represent.

---

## 10. Ambient Light — Running Effect (mode 4, `0x001A`)

**Method**: `BleManager.setAmbientLightRunningEffect(color: Int)`

**SDK status**: **Builder enum is too narrow.** `TCB1ACMD.writeAmbientLight(type, color)` exists, but `TCBAmbientLightType` only declares `monochrome` (mode 1), `monochromeBreathing` (mode 2), and `magicSevenColors` (mode 3). Mode 4 (running effect / chase) is in the protocol but missing from the enum.

**Protocol**: function `0x001A`, mode `0x04`, payload includes 3 RGB bytes + alpha.

**What we send**:
```
5A 21 1A 00 05 04 [R] [G] [B] FF + crc16
```

**Why this is fine**: identical structure to mode 3 (rainbow) which the SDK does handle — only the mode byte differs.

---

## 11. Response Time — Out-of-Range Custom (`0x0022`)

**Method**: `BleManager.setThrottleResponseCustom(value: Int)` / `setBrakeResponseCustom(value: Int)` via the private `writeResponseTime(allowCustom = true)` helper

**SDK status**: **Builder validates range.** `TCB22CMD.writeResponseTime(type, value: Int)` exists and we use it for any value in `0..10` (whether on the standard path or the custom path). The manual frame is **only** built when the user explicitly enters a value outside `0..10` for debug purposes.

**Protocol**: function `0x0022`, LEN=2, byte5 = type (throttle / brake), byte6 = response value 0–10 (instant → progressive).

**What we send for out-of-range**:
```
5A 21 22 00 02 [type] [raw_value & 0xFF] + crc16
```

**Why this is fine**: the standard 0–10 range goes through SDK; out-of-range is a debug-only path used to probe firmware behaviour beyond protocol-documented limits.

---

## 12. OTA Firmware Upgrade (`0x00E0`/`E1`/`E2`) — bleSender callback

**Methods**: `BleManager.startControllerFirmwareOta(bytes)` / `startMeterFirmwareOta(bytes)` via the SDK's `TCBECMD.startOTA()` driver

**SDK status**: **The SDK owns the frame building, but the transport is delegated to us via callback.** `TCBECMD` builds every `0x00E0` / `0x00E1` / `0x00E2` packet internally; it hands the bytes back to the app through the `OtaCallback.bleSender(byte[])` callback. We have to forward those bytes to `writeRaw`. There's no chained `.send` here because the call site isn't in `BleManager`'s top-level methods — it's inside the SDK-driven callback.

**Why this is fine**: this is the *only* place where the SDK explicitly requires the app to handle BLE writes itself rather than producing complete bytes from a static method.

**Known issue on v3 firmware**: OTA stalls without completion — see [GitHub issue #6](https://github.com/hussien-ibrahem/scooter-sdk-hussien/issues/6).

**OTA Bootloader / Flash (`0x00D0`/`D1`/`D2`, `0x00F0`/`F1`/`F2`)**: intentionally **disabled** — the protocol doc itself states *"Currently only Instrument APP, Instrument Flash, and Controller APP are upgraded. Other upgrade mechanisms are not implemented."* The Bootloader OTA button is permanently off in the UI with an explanatory note. No manual bytes are sent until vendor-signed binaries + a JTAG recovery path are available.

---

## Summary table

| # | Feature | Method | Protocol | SDK gap reason |
|---|---|---|---|---|
| 1 | Start Mode | `setStartMode` | `0x0002` | No `writeStartMode` on `TCB02CMD`. |
| 2 | Driving Current Limit | `readDrivingCurrentLimit` | `0x000B` type=1 | `TCB0BCMD.readDrivingCurrent()` only sends type=0. |
| 3 | Auto Power-Off (read + set) | `readAutoPowerOff` / `setAutoPowerOff` | `0x0006` | No SDK builder. |
| 4 | Battery Total Capacity | `readBatteryCapacity` | `0x000D` | No SDK builder. |
| 5 | Serial Number | `readSerialNumber` | `0x001D` | No SDK builder. |
| 6 | Detailed Device Info | `readDetailedDeviceInfo` | `0x001E` | No SDK builder. |
| 7 | Speed Stats avg/max | `readSpeedStats` | `0x0032` | No SDK builder. |
| 8 | Password / Security (4 functions) | `verifyBluetoothPassword`, `lockWithPassword`, `changeLockPassword`, `readAfterSalesPassword` | `0x00A4` / `A7` / `A8` / `A9` | Entire family has no SDK builders. |
| 9 | Ambient Light Custom Color (variable-length) | `setAmbientLightSolidCustom` | `0x001A` mode 1, ≥4 bytes | `TCB1ACMD` takes a 24-bit Int; longer payloads unsupported. |
| 10 | Ambient Light Running Effect | `setAmbientLightRunningEffect` | `0x001A` mode 4 | `TCBAmbientLightType` enum is missing mode 4. |
| 11 | Response Time Out-of-Range Custom | `setThrottleResponseCustom` / `setBrakeResponseCustom` (>10 or <0) | `0x0022` | SDK validates 0..10; debug values bypass that. |
| 12 | OTA bleSender callback | `TCBECMD.OtaCallback.bleSender` | `0x00E0`/`E1`/`E2` | SDK delegates BLE transport to the app via callback. |

---

## Everything else uses the SDK

Every feature **not** listed above routes its bytes through a `TCBxxCMD` builder and the `.send(...)` extension — including Lock, Unlock, Cruise, Gear Selection, Unit System, NFC read/write, Factory Reset, Front Light, Ambient Status, Ambient Solid / Breathing / Rainbow (with standard color), Throttle/Brake Response (0–10 range), Controller / Battery / Motor Temperature, Driving Current Realtime, Remaining / Single-Trip / Total Mileage, Meter / Controller Version, OTA driver invocation, per-gear Max Speed read/write, Global Max Speed read, and the Sport / Eco / Custom gear profile sequences.

When you read those functions in `BleManager.kt` you'll see exactly one prominent expression — the SDK builder call — chained to `.send("TX ...")`. No frame construction in the function body.

---

_Generated alongside the SDK refactor that moved every non-customized BLE write to chained `TCBxxCMD.someBuilder(...).send(...)` form. See `app/src/main/java/com/cardoo/scooter/ble/BleManager.kt`._
