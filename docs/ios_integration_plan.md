# iOS Integration Plan

## Host bridge classes
- `AppDelegate` initializes `ScooterBridgePlugin` from the implicit Flutter engine messenger.
- `ScooterBridgePlugin` owns:
  - 5 `FlutterMethodChannel` handlers
  - 4 `FlutterEventChannel` streams
  - unified method and error envelopes

## Mapping strategy
- Method calls dispatch to native command functions.
- CoreBluetooth delegate and parser outputs emit event streams.

## Existing BLE stack alignment
Planned wiring (production integration step):
- Primary runtime manager: `BleManager` in `scooter-ios` branch.
- SDK command/parsing: `TCB*Command` + `TCBManager.convertToModel`.
- Manual frame overrides for firmware compatibility and unsupported SDK command builders.
- OTA pipeline: native `E0/E1/E2` manager with retry budget and CRC validation.

## Dispatch/threading
- Maintain BLE operations on CoreBluetooth-safe queue (main-backed delegate model).
- Apply controlled dispatch delays for known firmware notify/auth timing races.
- Stream parsing outputs directly to EventChannel sinks.
