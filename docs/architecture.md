# Scooter BLE Bridge Architecture Audit (Pre-Implementation)

Date: 2026-05-20
Workspace target: `/Users/johnessam/Documents/New project 5`

## 1) Scope and reference sources (read-only)

- Android native reference:
  - `/Users/johnessam/Desktop/projects/scooter_android_demo-main`
- iOS native reference (SDK + demo):
  - `/Users/johnessam/Desktop/projects/scooter-sdk-hussien-main`
- Additional iOS reference app with stronger architecture modules:
  - `/Users/johnessam/Desktop/projects/ScooterIOSDemo-main`

Notes:
- The local `scooter-sdk-hussien-main` folder is not a git checkout with branches in this environment, so branch-level audit is done from file content snapshots available on disk.

## 2) Non-negotiable runtime rule

Flutter never talks to BLE directly.

Runtime chain:

Flutter UI/state/business
-> MethodChannel/EventChannel bridge
-> native platform bridge
-> native BLE transport + native command builders/parsers + native timing/queues/retries
-> scooter

## 3) Layer boundaries

### Flutter layer (UI + state + business only)
Current files:
- `/Users/johnessam/Documents/New project 5/lib/bridge/channel_names.dart`
- `/Users/johnessam/Documents/New project 5/lib/bridge/scooter_bridge_client.dart`
- `/Users/johnessam/Documents/New project 5/lib/bridge/bridge_response.dart`
- `/Users/johnessam/Documents/New project 5/lib/bridge/bridge_error.dart`

### Android native layer (BLE/protocol/OTA)
Bridge entry:
- `/Users/johnessam/Documents/New project 5/android/app/src/main/kotlin/com/example/scooter_bridge_arch/bridge/ScooterBridgePlugin.kt`
- `/Users/johnessam/Documents/New project 5/android/app/src/main/kotlin/com/example/scooter_bridge_arch/bridge/RealAndroidBleBridge.kt`

Native BLE/protocol reused from Khaled reference (copied into project):
- BLE core:
  - `/Users/johnessam/Documents/New project 5/android/app/src/main/java/com/example/scooter_android_demo/ble/BleScanner.kt`
  - `/Users/johnessam/Documents/New project 5/android/app/src/main/java/com/example/scooter_android_demo/ble/BleConnection.kt`
  - `/Users/johnessam/Documents/New project 5/android/app/src/main/java/com/example/scooter_android_demo/ble/BleTransport.kt`
  - `/Users/johnessam/Documents/New project 5/android/app/src/main/java/com/example/scooter_android_demo/ble/WriteQueue.kt`
- Command builders:
  - `/Users/johnessam/Documents/New project 5/android/app/src/main/java/com/example/scooter_android_demo/commands/*.kt`
- Parser:
  - `/Users/johnessam/Documents/New project 5/android/app/src/main/java/com/example/scooter_android_demo/protocol/TcbResponseParser.kt`

### iOS native layer (BLE/protocol)
Current bridge + BLE implementation is monolithic in:
- `/Users/johnessam/Documents/New project 5/ios/Runner/AppDelegate.swift`

Inside this file:
- `IOSScooterBridgePlugin` (MethodChannel routing)
- `EventStreamHandler` (EventChannel sink)
- `IosBleBridgeAdapter` (bridge-to-native adapter)
- `HussienBleManagerPhase1` (CoreBluetooth transport + manual frame commands + parser)

Reference iOS architecture targets:
- SDK commands/parsing:
  - `/Users/johnessam/Desktop/projects/scooter-sdk-hussien-main/sdk/ios/TCBleSDK/TCBleComminucation/Commands/*.swift`
  - `/Users/johnessam/Desktop/projects/scooter-sdk-hussien-main/sdk/ios/TCBleSDK/TCBleComminucation/Helper/TCBManager.swift`
  - `/Users/johnessam/Desktop/projects/scooter-sdk-hussien-main/sdk/ios/TCBleSDK/TCBleComminucation/Helper/TCBECCMD.swift`
- Modular production-style orchestration:
  - `/Users/johnessam/Desktop/projects/ScooterIOSDemo-main/ScooterIOSDemo/ble/CoreBluetoothTransport.swift`
  - `/Users/johnessam/Desktop/projects/ScooterIOSDemo-main/ScooterIOSDemo/protocol/TcbProtocolBridge.swift`
  - `/Users/johnessam/Desktop/projects/ScooterIOSDemo-main/ScooterIOSDemo/app/ScooterSessionViewModel.swift`

## 4) Native BLE ownership audit

Confirmed native-only BLE ownership:
- scan: native only
- connect/disconnect: native only
- notify subscription: native only
- packet write: native only
- parser: native only
- command builders: native only
- OTA chunk/retry/ack handling: native only

Flutter only issues bridge calls and listens to streams.

## 5) Threading, queue, timing ownership

### Android
- `WriteQueue` serializes writes with fixed pacing (default 200ms).
- BLE callbacks from ViseBle `DeviceMirror` notify listener route into parser.
- Bridge uses coroutine scope for method handling and timeout waits.

### iOS
- CoreBluetooth delegate on main queue.
- Dispatch timers for connect timeout, lock confirmation timeout, delayed bind write.
- Notify callback parses heartbeat/bind and emits event payloads.

## 6) Current feature phase status in workspace

Implemented end-to-end in workspace today:
- scan
- connect/disconnect
- bind
- lock/unlock
- heartbeat stream
- partial controls (`setCruiseControl`, `setGear`, `setFrontLight`)

Present but still unsupported in current bridge responses:
- many config/diagnostics/OTA methods currently return `UNSUPPORTED_FEATURE` in bridge layer.

## 7) Required clean architecture target (next coding phase)

Target folder modularization required by project constraints:
- Flutter bridge remains in `lib/bridge`
- Android split bridge router and event emitter from BLE feature logic
- iOS split bridge router and event emitter from BLE manager and feature modules

Business logic must be removed from channel files and moved to native feature/manager modules.
