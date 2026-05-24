# Channel Specification

## Method channels
- `scooter/connection`
- `scooter/control`
- `scooter/config`
- `scooter/diagnostics`
- `scooter/ota`

## Event channels
- `scooter/telemetry`
- `scooter/connection_state`
- `scooter/logs`
- `scooter/ota_progress`

## Method request envelope
```json
{
  "requestId": "<uuid-or-unique-id>",
  "timeoutMs": 2500,
  "payload": {}
}
```

## Method success envelope
```json
{
  "ok": true,
  "requestId": "<requestId>",
  "data": {},
  "nativeTsMs": 0
}
```

## Method error envelope
```json
{
  "ok": false,
  "requestId": "<requestId>",
  "data": {},
  "error": {
    "code": "BLE_DISCONNECTED",
    "message": "Scooter is not connected",
    "details": {},
    "retriable": true
  },
  "nativeTsMs": 0
}
```

## Event payloads
### `scooter/telemetry`
```json
{
  "type": "heartbeat|battery|temperature|current|mileage|diagnostics|config|fault|raw",
  "deviceId": "<platform-device-id>",
  "timestampMs": 0,
  "source": "android|ios",
  "data": {}
}
```

### `scooter/connection_state`
```json
{
  "state": "idle|scanning|connecting|connected|disconnecting|error",
  "device": "<device-id-or-null>",
  "reason": "<optional>",
  "retriable": false
}
```

### `scooter/logs`
```json
{
  "category": "bridge|connection|telemetry|ota|error|parser",
  "message": "<message>",
  "timestampMs": 0,
  "source": "android|ios"
}
```

### `scooter/ota_progress`
```json
{
  "state": "idle|preparing|sending|verifying|completed|failed|cancelled",
  "target": "controller|meter",
  "sent": 0,
  "total": 0,
  "percent": 0,
  "message": "",
  "timestampMs": 0,
  "source": "android|ios"
}
```
