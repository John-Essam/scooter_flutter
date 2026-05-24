# Android Integration Plan

## Host bridge classes
- `MainActivity` initializes `ScooterBridgePlugin` in `configureFlutterEngine`.
- `ScooterBridgePlugin` owns:
  - 5 `MethodChannel` handlers
  - 4 `EventChannel` stream handlers
  - standardized response envelope and error mapping

## Mapping strategy
- Method calls map to native operations (scan/connect/control/config/diagnostics/ota).
- Native push callbacks emit:
  - `scooter/connection_state`
  - `scooter/telemetry`
  - `scooter/logs`
  - `scooter/ota_progress`

## Existing BLE stack alignment
Planned wiring (production integration step):
- Scan: `BleScanner.startScan/stopScan`
- Connect/disconnect: `BleConnection.connect/disconnect`
- Queue: `WriteQueue.enqueue`
- Notify parse: `TcbResponseParser.parse`

## Coroutines and timing
- Keep single writer queue pacing.
- Use coroutine delays for read-after-write checks and compatibility readbacks.
- Ensure bridge emits disconnect-triggered failure for in-flight requests.
