# Channel Mapping (Flutter <-> Native)

## 1) Channel names

MethodChannels:
- `scooter/connection`
- `scooter/control`
- `scooter/config`
- `scooter/diagnostics`
- `scooter/ota`

EventChannels:
- `scooter/telemetry`
- `scooter/connection_state`
- `scooter/logs`
- `scooter/ota_progress`

## 2) Where channels are created today

Flutter side constants:
- `/Users/johnessam/Documents/New project 5/lib/bridge/channel_names.dart`

Flutter side method/event clients:
- `/Users/johnessam/Documents/New project 5/lib/bridge/scooter_bridge_client.dart`

Android native channels:
- `/Users/johnessam/Documents/New project 5/android/app/src/main/kotlin/com/example/scooter_bridge_arch/bridge/ScooterBridgePlugin.kt`

iOS native channels:
- `/Users/johnessam/Documents/New project 5/ios/Runner/AppDelegate.swift` (`IOSScooterBridgePlugin` + `EventStreamHandler`)

## 3) Request/response envelope (standardized)

Request:
- `requestId: String`
- `timeoutMs: Int?`
- `payload: Map<String, dynamic>`

Success:
- `ok: true`
- `requestId: String`
- `data: Map<String, dynamic>`
- `nativeTsMs: Int`

Error:
- `ok: false`
- `requestId: String`
- `data: {}`
- `error: { code, message, details, retriable }`
- `nativeTsMs: Int`

## 4) Unified error codes

- `TIMEOUT`
- `BLE_DISCONNECTED`
- `BLE_UNAVAILABLE`
- `BLE_PERMISSION_DENIED`
- `BLE_OPERATION_FAILED`
- `SDK_BUILD_FRAME_FAILED`
- `SDK_PARSE_FAILED`
- `INVALID_PACKET`
- `INVALID_ARGUMENT`
- `UNSUPPORTED_FEATURE`
- `OTA_IN_PROGRESS`
- `OTA_FAILED`
- `INTERNAL_ERROR`

## 5) Unified Flutter-facing method names

### `scooter/connection`
- `startScan`
- `stopScan`
- `connect`
- `disconnect`
- `bind`
- `unbind`
- `getConnectionState`
- `reconnectLastDevice`

### `scooter/control`
- `setLock`
- `setCruiseControl`
- `setGear`
- `setStartMode`
- `setUnitSystem`
- `setThrottleResponse`
- `setBrakeResponse`
- `setNfcEnabled`
- `setFrontLight`
- `setAmbientLightEnabled`
- `setAmbientLightMode`
- `setAmbientLightRgb`
- `setAmbientLightRunningEffect`

### `scooter/config`
- `readAutoPowerOff`
- `writeAutoPowerOff`
- `factoryReset`
- `applyGearSpeedProfile`
- `readGearSpeedLimits`
- `writeGearMaxSpeed`
- `verifyBluetoothPassword`
- `lockWithPassword`
- `changeLockPassword`
- `readAfterSalesPassword`

### `scooter/diagnostics`
- `readHeartbeatSnapshot`
- `readBatteryData`
- `readTemperatures`
- `readDrivingCurrent`
- `readSpeedStats`
- `readTripMileage`
- `readTotalMileage`
- `readRemainingMileage`
- `readRidingTime`
- `readSerialNumber`
- `readDeviceInfo`
- `readMeterVersion`
- `readControllerVersion`

### `scooter/ota`
- `startOtaController`
- `startOtaMeter`
- `cancelOta`
- `getOtaState`

## 6) Event payload schemas

### `scooter/telemetry`
- `type`: `heartbeat|battery|temperature|current|mileage|diagnostics|config|fault|raw`
- `deviceId`
- `timestampMs`
- `source`: `android|ios`
- `data`: normalized map

### `scooter/connection_state`
- `state`: `idle|scanning|connecting|connected|disconnecting|error`
- `device`
- `reason`
- `retriable`
- optional `scanResults`

### `scooter/ota_progress`
- `state`
- `target`
- `sent`
- `total`
- `percent`
- `message`

### `scooter/logs`
- `category`
- `message`
- `timestampMs`
- `source`
- optional `hex`

## 7) Current implementation gap summary

Current bridge handlers in workspace:
- Android: only subset fully wired (scan/connect/bind/setLock/setCruiseControl/setGear/setFrontLight/readHeartbeatSnapshot)
- iOS: same phase subset, other methods return `UNSUPPORTED_FEATURE`

Gap location:
- Android route decisions: `/Users/johnessam/Documents/New project 5/android/app/src/main/kotlin/com/example/scooter_bridge_arch/bridge/ScooterBridgePlugin.kt`
- iOS route decisions: `/Users/johnessam/Documents/New project 5/ios/Runner/AppDelegate.swift`

