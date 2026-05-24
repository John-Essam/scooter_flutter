# Android Native Mapping Audit

Reference source (read-only):
- `/Users/johnessam/Desktop/projects/scooter_android_demo-main`

Current workspace native copy:
- `/Users/johnessam/Documents/New project 5/android/app/src/main/java/com/example/scooter_android_demo`

Bridge adapter in workspace:
- `/Users/johnessam/Documents/New project 5/android/app/src/main/kotlin/com/example/scooter_bridge_arch/bridge/RealAndroidBleBridge.kt`

## 1) BLE foundation ownership

### Scan
- Native scanner file:
  - `.../ble/BleScanner.kt`
- Key entrypoints:
  - `startScan()`
  - `stopScan()`
- Behavior:
  - Android 12+ permission checks (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`)
  - emits `BleState.Scanning` and sorted `ScanResult`
  - filters to scooter candidates via `BleModelResolver.resolveFromAdvertisment`

### Connect/Disconnect
- Native connection file:
  - `.../ble/BleConnection.kt`
- Key entrypoints:
  - `initialize()`
  - `connect(result, model)` / `connect(mac, model)`
  - `disconnect()`
- Behavior:
  - configures ViseBle timeouts/retries
  - binds notify/write channels
  - registers notify callback to RX packets
  - sends startup packet sequence after connect (`TcbStartupCommands.packets()`)

### Write pacing / queue
- File:
  - `.../ble/WriteQueue.kt`
- Behavior:
  - single writer channel
  - default 200ms spacing between packets

## 2) Packet build and parse ownership

### Command building
- Frame builder:
  - `.../protocol/TcbCommandBuilder.kt`
  - `.../protocol/TcbManualFrame.kt`
- Feature command wrappers:
  - `.../commands/Tcb02Commands.kt` ... `Tcb30Commands.kt`
  - battery/serial/device info/riding time helpers in `TcbBatteryDataCommands`, `TcbSerialNumberCommands`, `TcbDeviceInfoCommands`, `TcbRidingTimeCommands`

### Parser
- File:
  - `.../protocol/TcbResponseParser.kt`
- Output model:
  - `.../protocol/TcbResponse.kt`
- Parser paths:
  - SDK parser path: `TCBManager.convertToModel(packet)`
  - manual fallback/intercept for unsupported/unstable responses (`0x06`, `0x0A`, `0x0B`, `0x0C`, `0x0D`, `0x0E`, `0x0F`, `0x1D`, `0x1E`, `0x20`, `0x31`)

## 3) OTA ownership

- `.../ota/OtaManager.kt`
- `.../ota/OtaSession.kt`
- `.../ota/OtaChunkPlanner.kt`

Behavior:
- E0 ready -> E1 chunks -> E2 CRC
- chunk retry budget: 10
- meter/controller index handling difference
- disconnect cancellation path

## 4) Main feature entrypoints in reference ViewModel

File:
- `/Users/johnessam/Desktop/projects/scooter_android_demo-main/app/src/main/java/com/example/scooter_android_demo/app/MainViewModel.kt`

Key methods (audited):
- BLE: `startScan`, `stopScan`, `connect`, `disconnect`, `bind`
- Control: `setLock`, `setCruiseControl`, `setMetricUnit`, `setStartMode`, `setHeadlight`, `setAmbientLight`, `setAmbientRgb`, `setNfcStatus`, `setGear`
- Reads: `readAmbientRgb`, `readNfcStatus`, `readDriveMode`, `readResponseTuning`, `readGearSpeedLimits`, `readMaxSpeed`, `readVersions`, `readTemperatures`, `readDrivingCurrent`, `readBatteryData`, `readRidingTime`, `readSerialNumber`, `readDeviceInfo`, `readAutoPowerOff`
- Writes/config: `setThrottleResponse`, `setBrakeResponse`, `setGearMaxSpeed`, `setGearSpeedProfile`, `setAutoPowerOff`, `restoreFactorySettings`
- OTA: `startOtaFromUri`, `startOtaBundledV0013`, `startOtaBundledV0015`, `cancelOta`

## 5) Current workspace bridge-to-native mapping

Mapped now:
- `startScan`, `stopScan`, `connect`, `disconnect`, `bind`
- `setLock`, `setCruiseControl`, `setGear`, `setFrontLight`
- `readHeartbeatSnapshot`

Currently not wired in bridge router:
- most config/diagnostics/OTA methods return `UNSUPPORTED_FEATURE`

Gap location:
- `/Users/johnessam/Documents/New project 5/android/app/src/main/kotlin/com/example/scooter_bridge_arch/bridge/ScooterBridgePlugin.kt`

