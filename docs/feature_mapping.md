# Feature Mapping (Flutter Action -> Channel -> Native -> Packet -> Events)

Status labels:
- `Wired`: implemented in current workspace bridge.
- `Planned`: mapped to native references, bridge routing pending.

## BLE foundation

| Flutter action | Method channel/method | Android native path | iOS native path | Packet/SDK path | Event output | Status |
|---|---|---|---|---|---|---|
| Scan start | `scooter/connection.startScan` | `RealAndroidBleBridge.startScan -> BleScanner.startScan` | `IosBleBridgeAdapter.startScan -> HussienBleManagerPhase1.startScan` | BLE scanner API | `connection_state(scanResults)` + `logs` | Wired |
| Scan stop | `scooter/connection.stopScan` | `BleScanner.stopScan` | `HussienBleManagerPhase1.stopScan` | BLE scanner API | `connection_state(idle)` + `logs` | Wired |
| Connect | `scooter/connection.connect` | `BleConnection.connect` | `HussienBleManagerPhase1.connect` | GATT connect, service/char discovery, notify enable | `connection_state(connecting/connected/error)` | Wired |
| Disconnect | `scooter/connection.disconnect` | `BleConnection.disconnect` | `HussienBleManagerPhase1.disconnect` | GATT disconnect | `connection_state(idle/disconnecting)` | Wired |
| Bind | `scooter/connection.bind` | `Tcb02Commands.connect()` | `writeConnectAuth()` manual `0x02` frame | `TCB02` | telemetry bind update / logs | Wired |
| Unbind | `scooter/connection.unbind` | `Tcb02Commands.readUnbind` + unbind/manual flow | `HussienBleManagerPhase1.unbind` | `TCB02` | bind state + logs | Wired (iOS) / Planned parity cleanup |
| Heartbeat stream | Event only (`scooter/telemetry`) | notify RX -> `TcbResponseParser` -> `HeartbeatUpdate` | notify RX -> `parseHeartbeat` | `TCB01` | telemetry `type=heartbeat` | Wired |

## Core controls

| Flutter action | Method | Android native call | iOS native call | Packet family | Event output | Status |
|---|---|---|---|---|---|---|
| Lock/Unlock | `setLock` | `Tcb02Commands.lockStatus` | `setLocked` manual frame | `0x02` | heartbeat lock state confirmation | Wired |
| Cruise | `setCruiseControl` | `Tcb02Commands.cruiseControl` | `setCruiseControl` manual frame | `0x02` | heartbeat | Wired |
| Gear | `setGear` | `Tcb05Commands.writeGear` | `setGear` manual frame | `0x05` | heartbeat + gear telemetry | Wired |
| Start mode | `setStartMode` | `Tcb02Commands.startMode` | `TCB02Command.writeStartMode`/manual | `0x02` | heartbeat | Planned |
| Unit system | `setUnitSystem` | `Tcb02Commands.metricMileSystem` | `TCB02Command.writeMetricMileSystemTheme`/manual | `0x02` | heartbeat | Planned |
| Throttle response | `setThrottleResponse` | `Tcb22Commands.writeThrottleResponse` | `TCB22Command.writeResponseTime(type:0)` | `0x22` | settings event/telemetry | Planned |
| Brake response | `setBrakeResponse` | `Tcb22Commands.writeBrakeResponse` | `TCB22Command.writeResponseTime(type:1)` | `0x22` | settings event/telemetry | Planned |
| NFC | `setNfcEnabled` | `Tcb03Commands.writeNfcStatus` | `TCB03Command.writeNfcStatus`/manual | `0x03` | settings event | Planned |

## Lights

| Flutter action | Method | Android native call | iOS native call | Packet family | Status |
|---|---|---|---|---|---|
| Front light | `setFrontLight` | `Tcb04Commands.writeFrontLight` | `setFrontLight` manual frame | `0x04` | Wired |
| Ambient light on/off | `setAmbientLightEnabled` | `Tcb04Commands.writeAmbientLight` | `TCB04Command.writeAmbientLightStatus`/manual | `0x04` | Planned |
| Ambient mode/RGB | `setAmbientLightMode`/`setAmbientLightRgb` | `Tcb1ACommands.writeAmbientLight` | `TCB1ACommand.writeAmbientLight` + fallback manual | `0x1A` | Planned |
| Running/rainbow effect | `setAmbientLightRunningEffect` | `Tcb1ACommands.writeRunningEffect/writeRainbowMode` | manual/SDK mode mapping | `0x1A` | Planned |

## Telemetry + diagnostics

| Flutter action | Method | Android packet/read path | iOS packet/read path | Status |
|---|---|---|---|---|
| Battery data | `readBatteryData` | `TcbBatteryDataCommands` (`0x0C/0x0D/0x0E/0x0F/0x20`) | manual + SDK parse path | Planned |
| Temperatures | `readTemperatures` | `Tcb0ACommands` | `TCB0ACommand` + manual device selector | Planned |
| Driving current | `readDrivingCurrent` | `Tcb0BCommands` | `TCB0BCommand` | Planned |
| Trip mileage | `readTripMileage` | `Tcb08Commands` | `TCB08Command` | Planned |
| ODO | `readTotalMileage` | `Tcb09Commands` | `TCB09Command` | Planned |
| Remaining mileage | `readRemainingMileage` | `Tcb30Commands` | `TCB30Command` | Planned |
| Riding time | `readRidingTime` | `TcbRidingTimeCommands` (`0x31`) | manual `0x31` frame path | Planned |
| Serial number | `readSerialNumber` | `TcbSerialNumberCommands` (`0x1D`) | manual/bridge protocol read | Planned |
| Device info | `readDeviceInfo` | `TcbDeviceInfoCommands` (`0x1E`) | manual/bridge protocol read | Planned |
| Meter/controller version | `readMeterVersion`/`readControllerVersion` | `Tcb11Commands` | `TCB11Command` | Planned |
| Heartbeat snapshot | `readHeartbeatSnapshot` | cached parsed heartbeat | cached parsed heartbeat | Wired |

## Config

| Flutter action | Method | Android native path | iOS native path | Packet family | Status |
|---|---|---|---|---|---|
| Factory reset | `factoryReset` | `Tcb03Commands.restoreFactory` | manual fallback frame | `0x03` | Planned |
| Auto power off read/write | `readAutoPowerOff`/`writeAutoPowerOff` | `Tcb06Commands` + fallback/retry | manual/bridge command path | `0x06` | Planned |
| Gear speed profile | `applyGearSpeedProfile` | sequential `Tcb05Commands.writeGearMaxSpeed` + readback | queue/write-readback (reference iOS app) | `0x05` | Planned |
| Password utilities | `verifyBluetoothPassword`, `lockWithPassword`, `changeLockPassword`, `readAfterSalesPassword` | manual frames | manual frames | `0xA4/0xA7/0xA8/0xA9` | Planned |

## OTA

| Flutter action | Method | Android native path | iOS native path | Packet family | Event stream | Status |
|---|---|---|---|---|---|---|
| Start OTA controller | `startOtaController` | `OtaManager.start*` | `TCBECCMD(file:type:.control)` | `E0/E1/E2` | `ota_progress` | Planned |
| Start OTA meter | `startOtaMeter` | `OtaManager.start*` | `TCBECCMD(file:type:.meter)` | `E0/E1/E2` | `ota_progress` | Planned |
| Cancel OTA | `cancelOta` | `OtaManager.cancel` | session cancel | n/a | `ota_progress` + logs | Planned |

