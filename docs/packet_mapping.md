# Packet Mapping Audit (Function Code -> Builders -> Parser Outputs)

## Frame format

Standard frame:
- header `0x5A`
- address
- function low/high
- payload length
- payload
- CRC16 (high byte then low byte)

Android builders:
- `/Users/johnessam/Desktop/projects/scooter_android_demo-main/app/src/main/java/com/example/scooter_android_demo/protocol/TcbCommandBuilder.kt`
- `/Users/johnessam/Desktop/projects/scooter_android_demo-main/app/src/main/java/com/example/scooter_android_demo/protocol/TcbManualFrame.kt`

iOS SDK builders:
- `/Users/johnessam/Desktop/projects/scooter-sdk-hussien-main/sdk/ios/TCBleSDK/TCBleComminucation/Commands/TCBCommands.swift`

## Core command families

| Function | Android wrapper | iOS SDK wrapper | Main feature use |
|---|---|---|---|
| `0x01` | parse-only heartbeat | parse-only heartbeat | telemetry stream |
| `0x02` | `Tcb02Commands` | `TCB02Command` | bind, lock, cruise, unit, start mode |
| `0x03` | `Tcb03Commands` | `TCB03Command` | NFC, factory reset |
| `0x04` | `Tcb04Commands` | `TCB04Command` | front/ambient light |
| `0x05` | `Tcb05Commands` | `TCB05Command` | gear, drive mode, gear speed/max speed |
| `0x06` | `Tcb06Commands` + manual fallback | usually manual in bridge layer | auto power off |
| `0x08` | `Tcb08Commands` | `TCB08Command` | trip mileage |
| `0x09` | `Tcb09Commands` | `TCB09Command` | total mileage |
| `0x0A` | `Tcb0ACommands` | `TCB0ACommand` | temperatures |
| `0x0B` | `Tcb0BCommands` | `TCB0BCommand` | driving current |
| `0x0C/0x0D/0x0E/0x0F/0x20` | manual/parser intercept + battery commands | mixed manual/SDK parsing paths | battery diagnostics |
| `0x11` | `Tcb11Commands` | `TCB11Command` | meter/controller versions |
| `0x1A` | `Tcb1ACommands` | `TCB1ACommand` | ambient RGB/mode |
| `0x1D` | `TcbSerialNumberCommands` | manual read frame or helper | serial number |
| `0x1E` | `TcbDeviceInfoCommands` | manual read frame or helper | device info |
| `0x22` | `Tcb22Commands` | `TCB22Command` | throttle/brake response |
| `0x30` | `Tcb30Commands` | `TCB30Command` | remaining mileage |
| `0x31` | `TcbRidingTimeCommands` | manual read frame path | riding time |
| `0x32` | parse support/manual where needed | manual extension path | speed stats |
| `0xA4` | manual frame expected | manual frame expected | bluetooth password verify |
| `0xA7` | manual frame expected | manual frame expected | lock-with-password |
| `0xA8` | manual frame expected | manual frame expected | change lock password |
| `0xA9` | manual frame expected | manual frame expected | after-sales password read |
| `0xE0` | OTA ready | OTA ready | OTA init |
| `0xE1` | OTA chunk ack | OTA chunk ack | OTA data transfer |
| `0xE2` | OTA completion ack | OTA completion ack | OTA CRC/finalize |

## Parser output mapping (Android reference)

File:
- `/Users/johnessam/Desktop/projects/scooter_android_demo-main/app/src/main/java/com/example/scooter_android_demo/protocol/TcbResponseParser.kt`

Primary outputs:
- `HeartbeatUpdate`
- `BindUpdate`
- `LightUpdate`
- `DriveModeUpdate`
- `MaxSpeedUpdate`
- `MeterVersionUpdate`
- `ControllerVersionUpdate`
- `TripMileageUpdate`
- `TotalMileageUpdate`
- `RemainingMileageUpdate`
- `AmbientRgbUpdate`
- `NfcStatusUpdate`
- `ResponseTuningUpdate`
- `GearMaxSpeedUpdate`
- `TemperatureUpdate`
- `DrivingCurrentUpdate`
- `BatteryCapacityUpdate`
- `BatteryDataUpdate`
- `RidingTimeUpdate`
- `SerialNumberUpdate`
- `DeviceInfoUpdate`
- `AutoPowerOffUpdate`
- OTA acks (`OtaReadyAck`, `OtaDataAck`, `OtaCrcAck`)

## iOS parse paths

SDK parse path:
- `TCBManager.convertToModel(data:)` in
  - `/Users/johnessam/Desktop/projects/scooter-sdk-hussien-main/sdk/ios/TCBleSDK/TCBleComminucation/Helper/TCBManager.swift`

Manual parse path examples:
- bind ack + heartbeat manual parsing in current workspace `HussienBleManagerPhase1`
- additional diagnostics/settings manual frame parsing in reference `TcbProtocolBridge.parseManualPayloadFrame(...)`

