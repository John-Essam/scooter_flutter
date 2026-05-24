# iOS Native Mapping Audit

Reference sources (read-only):
- `/Users/johnessam/Desktop/projects/scooter-sdk-hussien-main`
- `/Users/johnessam/Desktop/projects/ScooterIOSDemo-main`

Current workspace iOS implementation:
- `/Users/johnessam/Documents/New project 5/ios/Runner/AppDelegate.swift`

## 1) CoreBluetooth ownership

Reference transport pattern:
- `/Users/johnessam/Desktop/projects/ScooterIOSDemo-main/ScooterIOSDemo/ble/CoreBluetoothTransport.swift`

Current workspace transport owner:
- `HussienBleManagerPhase1` in `AppDelegate.swift`

Behavior:
- scan (`scanForPeripherals`)
- connect/disconnect (`connect`, `cancelPeripheralConnection`)
- service/characteristic discovery
- notify enable and RX (`didUpdateValueFor`)

## 2) SDK + command ownership

SDK command builders:
- `/Users/johnessam/Desktop/projects/scooter-sdk-hussien-main/sdk/ios/TCBleSDK/TCBleComminucation/Commands/*.swift`

SDK parser:
- `/Users/johnessam/Desktop/projects/scooter-sdk-hussien-main/sdk/ios/TCBleSDK/TCBleComminucation/Helper/TCBManager.swift`

OTA helper:
- `/Users/johnessam/Desktop/projects/scooter-sdk-hussien-main/sdk/ios/TCBleSDK/TCBleComminucation/Helper/TCBECCMD.swift`

Advanced protocol orchestration reference:
- `/Users/johnessam/Desktop/projects/ScooterIOSDemo-main/ScooterIOSDemo/protocol/TcbProtocolBridge.swift`
- `/Users/johnessam/Desktop/projects/ScooterIOSDemo-main/ScooterIOSDemo/app/ScooterSessionViewModel.swift`

## 3) Current workspace iOS behavior

In `AppDelegate.swift`, bridge and native BLE are currently combined.

### BLE + callback flow
- `IOSScooterBridgePlugin` routes MethodChannel calls
- `IosBleBridgeAdapter` converts platform callbacks to bridge payloads
- `HussienBleManagerPhase1` owns CoreBluetooth delegates and packet send/parse

### Packet strategy currently used
- Manual frame builder in `HussienBleManagerPhase1.buildFrame(...)`
- Manual commands for:
  - bind/unbind (`0x02` payload variants)
  - lock/unlock (`0x02`)
  - cruise (`0x02`)
  - gear (`0x05`)
  - front light (`0x04`)
- Heartbeat parser is manual (`parseHeartbeat`) and drives telemetry event stream

### Timeout handling currently used
- connect timeout via `DispatchWorkItem` in `IosBleBridgeAdapter.connect`
- lock confirmation timeout via heartbeat verification in `IosBleBridgeAdapter.setLock`

## 4) Reference iOS feature coverage patterns

SDK demo command usage:
- `/Users/johnessam/Desktop/projects/scooter-sdk-hussien-main/sdk/ios/TCBDemo/TCBDemo/CmdListViewModel.swift`

Production-style sequencing/queueing/timeouts:
- `/Users/johnessam/Desktop/projects/ScooterIOSDemo-main/ScooterIOSDemo/app/ScooterSessionViewModel.swift`

Includes:
- sequential command spacing
- settings readback confirmation
- settings timeout fallback
- heartbeat stale detection
- gear write queue/debounce
- startup diagnostics/settings command batches
- OTA session state machine

## 5) Current workspace bridge mapping status

Mapped now:
- `startScan`, `stopScan`, `connect`, `disconnect`, `bind`, `unbind`, `getConnectionState`
- `setLock`, `setCruiseControl`, `setGear`, `setFrontLight`
- `readHeartbeatSnapshot`

Not yet fully wired in bridge routing:
- many `config`, `diagnostics`, and `ota` calls return `UNSUPPORTED_FEATURE`

Gap location:
- `/Users/johnessam/Documents/New project 5/ios/Runner/AppDelegate.swift`

