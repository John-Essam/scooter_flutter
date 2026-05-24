# Flutter-Native Scooter Bridge Architecture

## Baseline
- Android audited baseline: `KhaledAli0907/scooter_android_demo` `main` @ `920bcacca63ad6efc9dbe68376291967088d6033`
- iOS audited baseline: `hussien-ibrahem/scooter-sdk-hussien` `scooter-ios` @ `b248be5c4ef11fa266fe39d76a92e9c71a0e33e4`

## Core Rule
Flutter never talks directly to BLE or the scooter protocol.

Runtime path:
1. Flutter UI + state + business logic
2. MethodChannel / EventChannel
3. Native platform bridge (Kotlin / Swift)
4. Native BLE + SDK + packet builders/parsers + queue/timing
5. Scooter

## Why MethodChannel and EventChannel
- MethodChannel is used for command/response operations (`connect`, `setLock`, `readBatteryData`) where Flutter expects one result.
- EventChannel is used for continuous push updates (`telemetry`, `connection state`, `OTA progress`, `logs`) where native emits asynchronously.

## Why BLE stays native
- Android and iOS BLE stacks have different callback models, timing constraints, permission behavior, and background semantics.
- OEM SDK behavior and packet compatibility fixes already exist in native code and should not be re-implemented in Dart.
- Native layers can enforce serialized writes, retry windows, and notify pacing close to GATT callbacks.

## Platform-specific constraints
### Android
- GATT status/transient failures require retry and stable queue pacing.
- Scan/connect permission behavior differs by API level.
- Command writes must be serialized to avoid dropped or reordered writes.

### iOS
- CoreBluetooth delegate callback ordering and notify subscription races require dispatch timing guards.
- Some firmware paths need manual frame builders where SDK command builders are incomplete.
- Reconnect and state restoration behave differently from Android and must stay native.

## Performance strategy
- Native queue pacing for BLE writes.
- Event-only continuous telemetry path to avoid blocking command calls.
- Read-after-write verification for fragile settings.
- OTA handled fully native (chunking, retries, ACK handling, CRC verification).

## Error model
Both native layers emit the same error envelope schema and shared code set:
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

## State synchronization
- Native is source of truth for BLE/protocol state.
- Flutter stores normalized cross-platform state.
- Every method result and event can mutate Flutter state.
- Request correlation uses `requestId`.
