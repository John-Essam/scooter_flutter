# iOS ↔ Android BLE Frame Audit

Bytes verified by decompiling `TCBSDK.jar` with `javap -c`.  
Frame format: `5A | addr | funcLow | funcHigh | length | payload | CRC16_H | CRC16_L`

**Mirror framing** = byte[3] (funcHigh) equals byte[2] (funcLow).  
Android SDK uses mirror framing for several cmd02, cmd04, cmd05 writes.  
iOS SDK always emits byte[3] = `0x00`.

---

## Categories

| Category | Meaning | iOS implementation |
|---|---|---|
| ✅ iOS SDK correct | iOS SDK bytes match Android SDK bytes exactly | `sendSDK(...)` |
| ⚠️ sendManuallyAndroidDefault | Android uses its SDK; iOS SDK sends wrong bytes | `sendManuallyAndroidDefault(...)` |
| 🔧 sendManual | Android builds frame manually; iOS SDK sends wrong bytes | `sendManual(...)` |

---

## Full Function Table

### Auth / Bind (TCB02 — 0x02)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `writeConnectAuth` | `5A 23 02 00 06 40 40 00 00 00 05` + CRC | `5A 23 02 00 06 40 40 00 00 00 05` + CRC | ✅ Correct | `sendSDK` (TCB02Command.writeConnect) |
| `unbind` | `5A 23 02 00 06 00 40 00 00 00 00` + CRC | `5A 03 02 00 02 00 40` + CRC (wrong addr + length) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setLocked(true)` | `5A 23 02 02 02 01 01` + CRC | `5A 23 02 00 02 01 01` + CRC (missing mirror) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setLocked(false)` | `5A 23 02 02 02 00 01` + CRC | `5A 23 02 00 02 00 01` + CRC (missing mirror) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setCruiseControl(true)` | `5A 23 02 02 02 04 04` + CRC | `5A 23 02 00 02 04 04` + CRC (missing mirror) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setCruiseControl(false)` | `5A 23 02 02 02 00 04` + CRC | `5A 23 02 00 02 00 04` + CRC (missing mirror) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setUnitSystem(km)` | `5A 23 02 02 02 00 80` + CRC | `5A 23 02 00 02 00 80` + CRC (missing mirror) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setUnitSystem(mile)` | `5A 23 02 02 02 80 80` + CRC | `5A 23 02 00 02 80 80` + CRC (missing mirror) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setStartMode(zeroStart)` | `5A 23 02 02 02 00 02` + CRC (manual build) | `5A 23 02 00 02 00 02` + CRC (missing mirror) | 🔧 Fixed | `sendManual` |
| `setStartMode(kickStart)` | `5A 23 02 02 02 02 02` + CRC (manual build) | `5A 23 02 00 02 02 02` + CRC (missing mirror) | 🔧 Fixed | `sendManual` |

### Parameter Config / NFC (TCB03 — 0x03)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `factoryReset` | `5A 21 03 00 02 02 02` + CRC | `5A 21 03 00 02 02 02` + CRC | ✅ Correct | `sendManual` |
| `readNfcStatus` | `5A 03 03 00 02 00 10` + CRC | `5A 03 03 00 00 00 10` + CRC (wrong length) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setNfc(true)` | `5A 23 03 00 02 10 10` + CRC | `5A 03 03 00 00 10 10` + CRC (wrong addr + length) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setNfc(false)` | `5A 23 03 00 02 00 10` + CRC | `5A 03 03 00 00 00 10` + CRC (wrong addr + length) | ⚠️ Fixed | `sendManuallyAndroidDefault` |

### Lighting (TCB04 — 0x04)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `setFrontLight(on)` | `5A 23 04 04 02 20 20` + CRC | `5A 23 04 00 02 20 20` + CRC (missing mirror) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setFrontLight(off)` | `5A 23 04 04 02 00 20` + CRC | `5A 23 04 00 02 00 20` + CRC (missing mirror) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `readAmbientLightStatus` | `5A 01 04 00 02 00 08` + CRC | `5A 21 04 00 02 00 08` + CRC (wrong addr) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setAmbientLightStatus(on)` | `5A 21 04 00 02 08 08` + CRC | `5A 21 04 00 02 08 08` + CRC | ✅ Correct | `sendSDK` (TCB04Command.writeAmbientLightStatus) |
| `setAmbientLightStatus(off)` | `5A 21 04 00 02 00 08` + CRC | `5A 21 04 00 02 00 08` + CRC | ✅ Correct | `sendSDK` |

### Gear / Speed (TCB05 — 0x05)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `setGear(n)` | `5A 23 05 05 02 [0x20\|n] 00` + CRC | `5A 23 05 00 02 [0x20\|n] 00` + CRC (missing mirror) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `readGlobalMaxSpeed` | `5A 01 05 00 02 00 00` + CRC | `5A 01 05 00 02 00 00` + CRC | ✅ Correct | `sendSDK` (TCB05Command.readMaxSpeed) |
| `readGearMaxSpeed(n)` | `5A 01 05 00 02 [0x18\|n] 00` + CRC | `5A 01 05 00 02 [0x18\|n] 00` + CRC | ✅ Correct | `sendSDK` (TCB05Command.readGearMaxSpeed) |
| `writeGearMaxSpeed(n, s)` | `5A 21 05 00 02 [0x18\|n] s` + CRC | `5A 21 05 00 02 [0x18\|n] s` + CRC | ✅ Correct | `sendSDK` (TCB05Command.writeGearMaxSpeed) |

### Auto Power-Off (0x06)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `readAutoPowerOff` | `5A 21 06 00 00` + CRC | `5A 21 06 00 00` + CRC | ✅ Correct | `sendManual` |
| `writeAutoPowerOff(s)` | `5A 21 06 00 02 [hi] [lo]` + CRC | same | ✅ Correct | `sendManual` |

### Mileage (TCB08/09/30)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `readSingleTripMileage` | (SDK match) | (SDK match) | ✅ Correct | `sendSDK` |
| `readTotalMileage` | (SDK match) | (SDK match) | ✅ Correct | `sendSDK` |
| `readRemainingMileage` | `5A 21 30 00 00` + CRC | `5A 01 30 00 00` + CRC (wrong addr) | ⚠️ Fixed | `sendManuallyAndroidDefault` |

### Temperature (TCB0A — 0x0A)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `readControllerTemperature` | (SDK match) | (SDK match) | ✅ Correct | `sendSDK` |
| `readBatteryTemperature` | `5A 01 0A 00 01 10` + CRC | same | ✅ Correct | `sendManual` |
| `readMotorTemperature` | `5A 01 0A 00 01 30` + CRC | same | ✅ Correct | `sendManual` |

### Driving Current (TCB0B — 0x0B)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `readDrivingCurrentRealtime` | (SDK match) | (SDK match) | ✅ Correct | `sendSDK` |
| `readDrivingCurrentLimit` | `5A 01 0B 00 03 01 00 00` + CRC | same | ✅ Correct | `sendManual` |

### Battery Capacity (0x0D)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `readBatteryCapacity` | `5A 21 0D 00 01 [type]` + CRC | same | ✅ Correct | `sendManual` |

### Versions (TCB11 — 0x11)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `readMeterVersion` | `5A 23 11 11 00` + CRC | `5A 03 11 00 00` + CRC (wrong addr + byte[3]) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `readControllerVersion` | `5A 21 11 00 00` + CRC | `5A 01 11 00 00` + CRC (wrong addr) | ⚠️ Fixed | `sendManuallyAndroidDefault` |

### Ambient Light Color (TCB1A — 0x1A)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `readAmbientLight` | `5A 01 1A 00 00` + CRC | `5A 01 1A 00 00` + CRC | ✅ Correct | `sendSDK` |
| `setAmbientLight(mode,r,g,b)` | `5A 21 1A 00 05 [mode] R G B FF` + CRC | `5A 21 1A 00 00 [mode] R G B FF` + CRC (length=0) | ⚠️ Fixed | `sendManuallyAndroidDefault` |
| `setAmbientLightRunningEffect` | `5A 21 1A 00 05 04 R G B FF` + CRC | `5A 21 1A 00 05 04 R G B FF` + CRC | ✅ Correct | `sendManual` |
| `setAmbientLightCustomColor(rgb)` | `5A 21 1A 00 05 01 R G B FF` + CRC | `5A 21 1A 00 04 01 R G B` + CRC (missing 0xFF) | 🔧 Fixed | `sendManual` (appends 0xFF for 3-byte input) |

### Response Time (TCB22 — 0x22)

| iOS function | Android bytes | iOS SDK bytes | Verdict | iOS impl |
|---|---|---|---|---|
| `readResponseTime(type)` | (SDK match) | (SDK match) | ✅ Correct | `sendSDK` |
| `writeResponseTime (in-range)` | (SDK match) | (SDK match) | ✅ Correct | `sendSDK` |
| `writeResponseTime (out-of-range)` | manual frame | same manual frame | ✅ Correct | `sendManual` |

### Diagnostics / Identity (manual frames)

| iOS function | Bytes | Verdict | iOS impl |
|---|---|---|---|
| `readSerialNumber` | `5A 01 1D 00 00` + CRC | ✅ Correct | `sendManual` |
| `readDetailedDeviceInfo` | `5A 01 1E 00 00` + CRC | ✅ Correct | `sendManual` |
| `readSpeedStats` | `5A 01 32 00 00` + CRC | ✅ Correct | `sendManual` |

### Password / Security (silent on v3)

| iOS function | Bytes | Verdict | iOS impl |
|---|---|---|---|
| `verifyBluetoothPassword` | `5A 21 A4 00 06 [6 ASCII digits]` + CRC | ✅ Correct | `sendManual` |
| `lockWithPassword` | `5A 21 A7 00 07 [lock byte] [6 digits]` + CRC | ✅ Correct | `sendManual` |
| `changeLockPassword` | `5A 21 A8 00 0C [old 6 digits] [new 6 digits]` + CRC | ✅ Correct | `sendManual` |
| `readAfterSalesPassword` | `5A 01 A9 00 00` + CRC | ✅ Correct | `sendManual` |

---

## Summary Counts

| Category | Count |
|---|---|
| ✅ iOS SDK correct (no change needed) | 22 |
| ⚠️ sendManuallyAndroidDefault (iOS SDK wrong, Android uses SDK) | 13 |
| 🔧 sendManual (iOS SDK wrong, Android builds manually) | 3 |
| **Total audited** | **38** |

---

## Known iOS SDK Bugs (root causes)

| Bug | Affected commands |
|---|---|
| `headerHighByte` always `0x00` — no mirror framing | cmd02 writes (lock/cruise/unit), cmd04 writeFrontLight, cmd05 writeGear, cmd11 readMeterVersion |
| `cmdDataLength` = `0x00` for cmd03, cmd1A | readNfcStatus (length), setAmbientLight (length) |
| Wrong address for read-style queries | readAmbientLightStatus (should be 0x01), readRemainingMileage (should be 0x21), readControllerVersion (should be 0x21), readMeterVersion (should be 0x23) |
| Wrong address for NFC write | setNfc uses meterRead (0x03) instead of meterWrite (0x23) |
| readUnbind uses meterRead+short payload | unbind should use meterWrite with 6-byte writeConnect(off) payload |
