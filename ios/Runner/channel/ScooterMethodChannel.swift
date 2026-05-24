import CoreBluetooth
import Flutter
import UIKit

final class IOSScooterBridgePlugin: NSObject {
  private let methodChannel: FlutterMethodChannel

  private var connectionState: [String: Any] = [
    "state": "idle",
    "device": NSNull(),
    "reason": NSNull(),
    "retriable": false,
  ]

  private let ble: IosBleBridgeAdapter

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(name: "scooter/bridge", binaryMessenger: messenger)

    ble = IosBleBridgeAdapter()

    super.init()

    installHandler(methodChannel)
  }

  func dispose() {
    methodChannel.setMethodCallHandler(nil)
    ble.dispose()
  }

  private func onMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let payload = args["payload"] as? [String: Any] ?? [:]
    let timeoutMs = (args["timeoutMs"] as? NSNumber)?.intValue ?? 2500

    switch call.method {
    case "startScan", "stopScan", "connect", "disconnect", "bind", "unbind", "getConnectionState":
      handleConnection(method: call.method, payload: payload, timeoutMs: timeoutMs, result: result)
    default:
      handleControl(method: call.method, payload: payload, timeoutMs: timeoutMs, result: result)
    }
  }

  private func installHandler(_ channel: FlutterMethodChannel) {
    channel.setMethodCallHandler { [weak self] call, result in
      self?.onMethodCall(call: call, result: result)
    }
  }

  private func handleConnection(method: String, payload: [String: Any], timeoutMs: Int, result: @escaping FlutterResult) {
    switch method {
    case "startScan":
      ble.startScan()
      connectionState = [
        "state": "scanning",
        "device": NSNull(),
        "reason": NSNull(),
        "retriable": false,
      ]
      result(successEnvelope(data: ["state": "scanning"]))
    case "stopScan":
      ble.stopScan()
      connectionState = [
        "state": "idle",
        "device": NSNull(),
        "reason": NSNull(),
        "retriable": false,
      ]
      result(successEnvelope(data: ["state": "idle"]))
    case "connect":
      guard let deviceId = payload["deviceId"] as? String else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.deviceId is required", details: nil, retriable: false))
        return
      }
      let connectTimeout = max(timeoutMs, 12_000)
      ble.connect(deviceId: deviceId, timeoutMs: connectTimeout) { connectResult in
        switch connectResult {
        case .success(let data):
          self.connectionState = [
            "state": "connected",
            "device": data["deviceId"] ?? NSNull(),
            "reason": NSNull(),
            "retriable": false,
          ]
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "disconnect":
      ble.disconnect()
      connectionState = [
        "state": "idle",
        "device": NSNull(),
        "reason": NSNull(),
        "retriable": false,
      ]
      result(successEnvelope(data: ["state": "idle"]))
    case "bind":
      ble.bind()
      result(successEnvelope(data: ["bound": true]))
    case "unbind":
      ble.unbind()
      result(successEnvelope(data: ["bound": false]))
    case "getConnectionState":
      result(successEnvelope(data: ["connection": connectionState]))
    default:
      result(unsupported(method: method))
    }
  }

  private func handleControl(method: String, payload: [String: Any], timeoutMs: Int, result: @escaping FlutterResult) {
    switch method {
    case "setLock":
      guard let locked = payload["locked"] as? Bool else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.locked is required", details: nil, retriable: false))
        return
      }
      ble.setLock(locked, timeoutMs: timeoutMs) { lockResult in
        switch lockResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "setCruiseControl":
      guard let enabled = payload["enabled"] as? Bool else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.enabled is required", details: nil, retriable: false))
        return
      }
      result(successEnvelope(data: ble.setCruiseControl(enabled)))
    case "setStartMode":
      guard let enabled = payload["enabled"] as? Bool else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.enabled is required", details: nil, retriable: false))
        return
      }
      result(successEnvelope(data: ble.setStartMode(enabled)))
    case "setUnitSystem":
      guard let metric = payload["metric"] as? Bool else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.metric is required", details: nil, retriable: false))
        return
      }
      result(successEnvelope(data: ble.setUnitSystem(metric)))
    case "readThrottleResponse":
      ble.readThrottleResponse(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readBrakeResponse":
      ble.readBrakeResponse(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readControllerTemperature":
      ble.readControllerTemperature(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readBatteryTemperature":
      ble.readBatteryTemperature(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readMotorTemperature":
      ble.readMotorTemperature(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readDrivingCurrent":
      ble.readDrivingCurrent(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readRemainingMileage":
      ble.readRemainingMileage(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readTripMileage":
      ble.readTripMileage(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readOdo":
      ble.readOdo(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readSpeedStats":
      ble.readSpeedStats(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readSerialNumber":
      ble.readSerialNumber(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readDeviceInfo":
      ble.readDeviceInfo(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readMeterVersion":
      ble.readMeterVersion(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readControllerVersion":
      ble.readControllerVersion(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "readGearMaxSpeed":
      guard let gear = payload["gear"] as? NSNumber else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.gear is required", details: nil, retriable: false))
        return
      }
      ble.readGearMaxSpeed(gear: gear.intValue, timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "setThrottleBrakeResponse":
      guard let throttle = payload["throttle"] as? NSNumber else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.throttle is required", details: nil, retriable: false))
        return
      }
      guard let brake = payload["brake"] as? NSNumber else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.brake is required", details: nil, retriable: false))
        return
      }
      if throttle.intValue < 0 || throttle.intValue > 10 {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.throttle must be 0..10", details: ["throttle": throttle], retriable: false))
        return
      }
      if brake.intValue < 0 || brake.intValue > 10 {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.brake must be 0..10", details: ["brake": brake], retriable: false))
        return
      }
      result(successEnvelope(data: ble.setThrottleBrakeResponse(throttle: throttle.intValue, brake: brake.intValue)))
    case "readNfcStatus":
      ble.readNfcStatus(timeoutMs: timeoutMs) { readResult in
        switch readResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "setNfcEnabled":
      guard let enabled = payload["enabled"] as? Bool else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.enabled is required", details: nil, retriable: false))
        return
      }
      ble.setNfcEnabled(enabled: enabled, timeoutMs: timeoutMs) { writeResult in
        switch writeResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "factoryReset":
      result(successEnvelope(data: ble.factoryReset()))
    case "setGear":
      guard let gear = payload["gear"] as? NSNumber else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.gear is required", details: nil, retriable: false))
        return
      }
      ble.setGear(gear.intValue, timeoutMs: timeoutMs) { gearResult in
        switch gearResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "setFrontLight":
      guard let on = payload["on"] as? Bool else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.on is required", details: nil, retriable: false))
        return
      }
      result(successEnvelope(data: ble.setFrontLight(on)))
    case "setAmbientLight":
      guard let on = payload["on"] as? Bool else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.on is required", details: nil, retriable: false))
        return
      }
      ble.setAmbientLight(on: on, timeoutMs: timeoutMs) { ambientResult in
        switch ambientResult {
        case .success(let data):
          result(self.successEnvelope(data: data))
        case .failure(let err):
          result(self.errorEnvelope(code: err.code, message: err.message, details: err.details, retriable: err.retriable))
        }
      }
    case "setAmbientRgb":
      guard let mode = payload["mode"] as? NSNumber else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.mode is required", details: nil, retriable: false))
        return
      }
      guard let red = payload["red"] as? NSNumber else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.red is required", details: nil, retriable: false))
        return
      }
      guard let green = payload["green"] as? NSNumber else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.green is required", details: nil, retriable: false))
        return
      }
      guard let blue = payload["blue"] as? NSNumber else {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.blue is required", details: nil, retriable: false))
        return
      }
      let brightness = (payload["brightness"] as? NSNumber)?.intValue ?? 255
      if mode.intValue < 1 || mode.intValue > 4 {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "payload.mode must be 1..4", details: ["mode": mode], retriable: false))
        return
      }
      let colors = [red.intValue, green.intValue, blue.intValue, brightness]
      if colors.contains(where: { $0 < 0 || $0 > 255 }) {
        result(errorEnvelope(code: ErrorCodes.invalidArgument, message: "rgb and brightness must be 0..255", details: ["red": red, "green": green, "blue": blue, "brightness": brightness], retriable: false))
        return
      }
      result(successEnvelope(data: ble.setAmbientRgb(mode: mode.intValue, red: red.intValue, green: green.intValue, blue: blue.intValue, brightness: brightness)))
    case "setRainbowMode":
      result(successEnvelope(data: ble.setRainbowMode()))
    default:
      result(unsupported(method: method))
    }
  }

  private func unsupported(method: String) -> [String: Any] {
    errorEnvelope(
      code: ErrorCodes.unsupportedFeature,
      message: "Method is not implemented in current integration phase",
      details: ["method": method, "phase": "scan_connect_lock_gear_heartbeat"],
      retriable: false
    )
  }

  private func emitLog(category: String, message: String) {
    _ = category
    _ = message
  }

  private func successEnvelope(data: [String: Any]) -> [String: Any] {
    data
  }

  private func errorEnvelope(code: String, message: String, details: Any?, retriable: Bool) -> [String: Any] {
    emitLog(category: "error", message: "\(code): \(message)")
    return [
      "ok": false,
      "data": [:],
      "error": [
        "code": code,
        "message": message,
        "details": details ?? NSNull(),
        "retriable": retriable,
      ],
    ]
  }

  private enum ErrorCodes {
    static let timeout = "TIMEOUT"
    static let bleDisconnected = "BLE_DISCONNECTED"
    static let bleUnavailable = "BLE_UNAVAILABLE"
    static let blePermissionDenied = "BLE_PERMISSION_DENIED"
    static let bleOperationFailed = "BLE_OPERATION_FAILED"
    static let sdkBuildFrameFailed = "SDK_BUILD_FRAME_FAILED"
    static let sdkParseFailed = "SDK_PARSE_FAILED"
    static let invalidPacket = "INVALID_PACKET"
    static let invalidArgument = "INVALID_ARGUMENT"
    static let unsupportedFeature = "UNSUPPORTED_FEATURE"
    static let otaInProgress = "OTA_IN_PROGRESS"
    static let otaFailed = "OTA_FAILED"
    static let internalError = "INTERNAL_ERROR"
  }
}

private struct NativeBridgeError: Error {
  let code: String
  let message: String
  let retriable: Bool
  let details: Any?
}

private final class IosBleBridgeAdapter: NSObject {
  var onConnectionEvent: (([String: Any]) -> Void)?
  var onTelemetryEvent: (([String: Any]) -> Void)?
  var onLog: ((String, String) -> Void)?

  var lastHeartbeat: BridgeHeartbeatTelemetry?

  private let manager = HussienBleManagerPhase1.shared
  private var scannedById: [String: BridgeScannedDevice] = [:]

  private var pendingConnect: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var pendingConnectDeviceId: String?
  private var connectTimeoutWorkItem: DispatchWorkItem?

  private var pendingLock: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var expectedLockStatus: Bool?
  private var lockTimeoutWorkItem: DispatchWorkItem?
  private var pendingGear: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var expectedGear: Int?
  private var gearTimeoutWorkItem: DispatchWorkItem?
  private var pendingThrottleResponse: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var throttleResponseTimeoutWorkItem: DispatchWorkItem?
  private var pendingBrakeResponse: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var brakeResponseTimeoutWorkItem: DispatchWorkItem?
  private var pendingControllerTemperature: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var controllerTemperatureTimeoutWorkItem: DispatchWorkItem?
  private var pendingBatteryTemperature: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var batteryTemperatureTimeoutWorkItem: DispatchWorkItem?
  private var pendingMotorTemperature: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var motorTemperatureTimeoutWorkItem: DispatchWorkItem?
  private var pendingDrivingCurrent: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var drivingCurrentTimeoutWorkItem: DispatchWorkItem?
  private var pendingRemainingMileage: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var remainingMileageTimeoutWorkItem: DispatchWorkItem?
  private var pendingTripMileage: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var tripMileageTimeoutWorkItem: DispatchWorkItem?
  private var pendingOdo: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var odoTimeoutWorkItem: DispatchWorkItem?
  private var pendingSpeedStats: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var speedStatsTimeoutWorkItem: DispatchWorkItem?
  private var pendingSerialNumber: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var serialNumberTimeoutWorkItem: DispatchWorkItem?
  private var pendingDeviceInfo: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var deviceInfoTimeoutWorkItem: DispatchWorkItem?
  private var pendingMeterVersion: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var meterVersionTimeoutWorkItem: DispatchWorkItem?
  private var pendingControllerVersion: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var controllerVersionTimeoutWorkItem: DispatchWorkItem?
  private var pendingGearMaxSpeed: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var gearMaxSpeedTimeoutWorkItem: DispatchWorkItem?
  private var expectedGearMaxSpeedGear: Int?
  private var pendingNfcStatus: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var nfcStatusTimeoutWorkItem: DispatchWorkItem?
  private var expectedNfcStatus: Bool?
  private var pendingAmbientLight: ((Result<[String: Any], NativeBridgeError>) -> Void)?
  private var ambientLightTimeoutWorkItem: DispatchWorkItem?
  private var expectedAmbientLight: Bool?

  private var currentConnectionState: BridgeBleConnectionState = .idle

  private func trace(_ message: String) {
    emitLog("[bridge] \(message)", category: "native")
  }

  override init() {
    super.init()
    manager.addListener(self)
    trace("adapter init")
    emitConnectionState(.idle, reason: "bridge_initialized", retriable: false, scanResults: nil)
  }

  func dispose() {
    connectTimeoutWorkItem?.cancel()
    lockTimeoutWorkItem?.cancel()
    gearTimeoutWorkItem?.cancel()
    throttleResponseTimeoutWorkItem?.cancel()
    brakeResponseTimeoutWorkItem?.cancel()
    controllerTemperatureTimeoutWorkItem?.cancel()
    batteryTemperatureTimeoutWorkItem?.cancel()
    motorTemperatureTimeoutWorkItem?.cancel()
    drivingCurrentTimeoutWorkItem?.cancel()
    remainingMileageTimeoutWorkItem?.cancel()
    tripMileageTimeoutWorkItem?.cancel()
    odoTimeoutWorkItem?.cancel()
    speedStatsTimeoutWorkItem?.cancel()
    serialNumberTimeoutWorkItem?.cancel()
    deviceInfoTimeoutWorkItem?.cancel()
    meterVersionTimeoutWorkItem?.cancel()
    controllerVersionTimeoutWorkItem?.cancel()
    gearMaxSpeedTimeoutWorkItem?.cancel()
    nfcStatusTimeoutWorkItem?.cancel()
    ambientLightTimeoutWorkItem?.cancel()
    manager.removeListener(self)
  }

  func startScan() {
    trace("startScan requested")
    manager.startScan()
  }

  func stopScan() {
    trace("stopScan requested")
    manager.stopScan()
  }

  func connect(deviceId: String, timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard let scanned = scannedById[deviceId] else {
      trace("connect rejected unknown deviceId=\(deviceId)")
      completion(.failure(NativeBridgeError(
        code: "INVALID_ARGUMENT",
        message: "Unknown deviceId. Start scan first.",
        retriable: false,
        details: ["deviceId": deviceId]
      )))
      return
    }

    pendingConnect = completion
    pendingConnectDeviceId = deviceId
    trace("connect start deviceId=\(deviceId) timeoutMs=\(timeoutMs) rssi=\(scanned.rssi) model=\(scanned.model)")

    connectTimeoutWorkItem?.cancel()
    let timeoutItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingConnect else { return }
      self.trace("connect timeout deviceId=\(deviceId) timeoutMs=\(timeoutMs)")
      self.pendingConnect = nil
      self.pendingConnectDeviceId = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Connect timeout",
        retriable: true,
        details: ["deviceId": deviceId, "timeoutMs": timeoutMs]
      )))
    }
    connectTimeoutWorkItem = timeoutItem
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: timeoutItem)

    manager.connect(to: scanned)
  }

  func disconnect() {
    trace("disconnect requested")
    pendingConnect = nil
    pendingConnectDeviceId = nil
    connectTimeoutWorkItem?.cancel()

    if let lockCallback = pendingLock {
      pendingLock = nil
      expectedLockStatus = nil
      lockTimeoutWorkItem?.cancel()
      lockCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting lock confirmation",
        retriable: true,
        details: nil
      )))
    }
    if let gearCallback = pendingGear {
      pendingGear = nil
      expectedGear = nil
      gearTimeoutWorkItem?.cancel()
      gearCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting gear confirmation",
        retriable: true,
        details: nil
      )))
    }
    if let throttleCallback = pendingThrottleResponse {
      pendingThrottleResponse = nil
      throttleResponseTimeoutWorkItem?.cancel()
      throttleCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting throttle response read",
        retriable: true,
        details: nil
      )))
    }
    if let brakeCallback = pendingBrakeResponse {
      pendingBrakeResponse = nil
      brakeResponseTimeoutWorkItem?.cancel()
      brakeCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting brake response read",
        retriable: true,
        details: nil
      )))
    }
    if let temperatureCallback = pendingControllerTemperature {
      pendingControllerTemperature = nil
      controllerTemperatureTimeoutWorkItem?.cancel()
      temperatureCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting controller temperature read",
        retriable: true,
        details: nil
      )))
    }
    if let temperatureCallback = pendingBatteryTemperature {
      pendingBatteryTemperature = nil
      batteryTemperatureTimeoutWorkItem?.cancel()
      temperatureCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting battery temperature read",
        retriable: true,
        details: nil
      )))
    }
    if let temperatureCallback = pendingMotorTemperature {
      pendingMotorTemperature = nil
      motorTemperatureTimeoutWorkItem?.cancel()
      temperatureCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting motor temperature read",
        retriable: true,
        details: nil
      )))
    }
    if let currentCallback = pendingDrivingCurrent {
      pendingDrivingCurrent = nil
      drivingCurrentTimeoutWorkItem?.cancel()
      currentCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting driving current read",
        retriable: true,
        details: nil
      )))
    }
    if let mileageCallback = pendingRemainingMileage {
      pendingRemainingMileage = nil
      remainingMileageTimeoutWorkItem?.cancel()
      mileageCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting remaining mileage read",
        retriable: true,
        details: nil
      )))
    }
    if let mileageCallback = pendingTripMileage {
      pendingTripMileage = nil
      tripMileageTimeoutWorkItem?.cancel()
      mileageCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting trip mileage read",
        retriable: true,
        details: nil
      )))
    }
    if let mileageCallback = pendingOdo {
      pendingOdo = nil
      odoTimeoutWorkItem?.cancel()
      mileageCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting ODO read",
        retriable: true,
        details: nil
      )))
    }
    if let speedStatsCallback = pendingSpeedStats {
      pendingSpeedStats = nil
      speedStatsTimeoutWorkItem?.cancel()
      speedStatsCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting speed stats read",
        retriable: true,
        details: nil
      )))
    }
    if let serialNumberCallback = pendingSerialNumber {
      pendingSerialNumber = nil
      serialNumberTimeoutWorkItem?.cancel()
      serialNumberCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting serial number read",
        retriable: true,
        details: nil
      )))
    }
    if let deviceInfoCallback = pendingDeviceInfo {
      pendingDeviceInfo = nil
      deviceInfoTimeoutWorkItem?.cancel()
      deviceInfoCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting device info read",
        retriable: true,
        details: nil
      )))
    }
    if let meterVersionCallback = pendingMeterVersion {
      pendingMeterVersion = nil
      meterVersionTimeoutWorkItem?.cancel()
      meterVersionCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting meter version read",
        retriable: true,
        details: nil
      )))
    }
    if let controllerVersionCallback = pendingControllerVersion {
      pendingControllerVersion = nil
      controllerVersionTimeoutWorkItem?.cancel()
      controllerVersionCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting controller version read",
        retriable: true,
        details: nil
      )))
    }
    if let gearMaxSpeedCallback = pendingGearMaxSpeed {
      pendingGearMaxSpeed = nil
      gearMaxSpeedTimeoutWorkItem?.cancel()
      expectedGearMaxSpeedGear = nil
      gearMaxSpeedCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting gear max speed read",
        retriable: true,
        details: nil
      )))
    }
    if let nfcCallback = pendingNfcStatus {
      pendingNfcStatus = nil
      nfcStatusTimeoutWorkItem?.cancel()
      expectedNfcStatus = nil
      nfcCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting NFC status read",
        retriable: true,
        details: nil
      )))
    }
    if let ambientCallback = pendingAmbientLight {
      pendingAmbientLight = nil
      ambientLightTimeoutWorkItem?.cancel()
      expectedAmbientLight = nil
      ambientCallback(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter disconnected while waiting ambient light confirmation",
        retriable: true,
        details: nil
      )))
    }

    manager.disconnect()
  }

  func bind() {
    trace("bind requested")
    manager.bind()
  }

  func unbind() {
    trace("unbind requested")
    manager.unbind()
  }

  func setLock(_ locked: Bool, timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingLock = completion
    expectedLockStatus = locked
    trace("setLock requested locked=\(locked) timeoutMs=\(timeoutMs)")

    lockTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingLock else { return }
      self.trace("setLock timeout locked=\(locked) timeoutMs=\(timeoutMs)")
      self.pendingLock = nil
      self.expectedLockStatus = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Lock command timeout waiting heartbeat confirmation",
        retriable: true,
        details: ["locked": locked, "timeoutMs": timeoutMs]
      )))
    }
    lockTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.setLocked(locked)
  }

  func setCruiseControl(_ enabled: Bool) -> [String: Any] {
    manager.setCruiseControl(enabled)
    return ["cruiseControl": enabled]
  }

  func setStartMode(_ enabled: Bool) -> [String: Any] {
    manager.setStartMode(enabled: enabled)
    return ["startMode": enabled]
  }

  func setUnitSystem(_ metric: Bool) -> [String: Any] {
    manager.setUnitSystem(metric: metric)
    return ["metricUnit": metric]
  }

  func readThrottleResponse(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingThrottleResponse = completion
    trace("readThrottleResponse requested timeoutMs=\(timeoutMs)")

    throttleResponseTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingThrottleResponse else { return }
      self.trace("readThrottleResponse timeout timeoutMs=\(timeoutMs)")
      self.pendingThrottleResponse = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Throttle response read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    throttleResponseTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readThrottleResponse()
  }

  func readBrakeResponse(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingBrakeResponse = completion
    trace("readBrakeResponse requested timeoutMs=\(timeoutMs)")

    brakeResponseTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingBrakeResponse else { return }
      self.trace("readBrakeResponse timeout timeoutMs=\(timeoutMs)")
      self.pendingBrakeResponse = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Brake response read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    brakeResponseTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readBrakeResponse()
  }

  func readControllerTemperature(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingControllerTemperature = completion
    trace("readControllerTemperature requested timeoutMs=\(timeoutMs)")

    controllerTemperatureTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingControllerTemperature else { return }
      self.trace("readControllerTemperature timeout timeoutMs=\(timeoutMs)")
      self.pendingControllerTemperature = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Controller temperature read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    controllerTemperatureTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readControllerTemperature()
  }

  func readBatteryTemperature(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingBatteryTemperature = completion
    trace("readBatteryTemperature requested timeoutMs=\(timeoutMs)")

    batteryTemperatureTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingBatteryTemperature else { return }
      self.trace("readBatteryTemperature timeout timeoutMs=\(timeoutMs)")
      self.pendingBatteryTemperature = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Battery temperature read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    batteryTemperatureTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readBatteryTemperature()
  }

  func readMotorTemperature(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingMotorTemperature = completion
    trace("readMotorTemperature requested timeoutMs=\(timeoutMs)")

    motorTemperatureTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingMotorTemperature else { return }
      self.trace("readMotorTemperature timeout timeoutMs=\(timeoutMs)")
      self.pendingMotorTemperature = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Motor temperature read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    motorTemperatureTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readMotorTemperature()
  }

  func readDrivingCurrent(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingDrivingCurrent = completion
    trace("readDrivingCurrent requested timeoutMs=\(timeoutMs)")

    drivingCurrentTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingDrivingCurrent else { return }
      self.trace("readDrivingCurrent timeout timeoutMs=\(timeoutMs)")
      self.pendingDrivingCurrent = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Driving current read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    drivingCurrentTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readDrivingCurrent()
  }

  func readRemainingMileage(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingRemainingMileage = completion
    trace("readRemainingMileage requested timeoutMs=\(timeoutMs)")

    remainingMileageTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingRemainingMileage else { return }
      self.trace("readRemainingMileage timeout timeoutMs=\(timeoutMs)")
      self.pendingRemainingMileage = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Remaining mileage read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    remainingMileageTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readRemainingMileage()
  }

  func readTripMileage(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingTripMileage = completion
    trace("readTripMileage requested timeoutMs=\(timeoutMs)")

    tripMileageTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingTripMileage else { return }
      self.trace("readTripMileage timeout timeoutMs=\(timeoutMs)")
      self.pendingTripMileage = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Trip mileage read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    tripMileageTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readTripMileage()
  }

  func readOdo(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingOdo = completion
    trace("readOdo requested timeoutMs=\(timeoutMs)")

    odoTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingOdo else { return }
      self.trace("readOdo timeout timeoutMs=\(timeoutMs)")
      self.pendingOdo = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "ODO read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    odoTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readOdo()
  }

  func readSpeedStats(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingSpeedStats = completion
    trace("readSpeedStats requested timeoutMs=\(timeoutMs)")

    speedStatsTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingSpeedStats else { return }
      self.trace("readSpeedStats timeout timeoutMs=\(timeoutMs)")
      self.pendingSpeedStats = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Speed stats read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    speedStatsTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readSpeedStats()
  }

  func readSerialNumber(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingSerialNumber = completion
    trace("readSerialNumber requested timeoutMs=\(timeoutMs)")

    serialNumberTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingSerialNumber else { return }
      self.trace("readSerialNumber timeout timeoutMs=\(timeoutMs)")
      self.pendingSerialNumber = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Serial number read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    serialNumberTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readSerialNumber()
  }

  func readDeviceInfo(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingDeviceInfo = completion
    trace("readDeviceInfo requested timeoutMs=\(timeoutMs)")

    deviceInfoTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingDeviceInfo else { return }
      self.trace("readDeviceInfo timeout timeoutMs=\(timeoutMs)")
      self.pendingDeviceInfo = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Device info read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    deviceInfoTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readDeviceInfo()
  }

  func readMeterVersion(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingMeterVersion = completion
    trace("readMeterVersion requested timeoutMs=\(timeoutMs)")

    meterVersionTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingMeterVersion else { return }
      self.trace("readMeterVersion timeout timeoutMs=\(timeoutMs)")
      self.pendingMeterVersion = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Meter version read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    meterVersionTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readMeterVersion()
  }

  func readControllerVersion(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingControllerVersion = completion
    trace("readControllerVersion requested timeoutMs=\(timeoutMs)")

    controllerVersionTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingControllerVersion else { return }
      self.trace("readControllerVersion timeout timeoutMs=\(timeoutMs)")
      self.pendingControllerVersion = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Controller version read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    controllerVersionTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readControllerVersion()
  }

  func readGearMaxSpeed(gear: Int, timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }
    guard (0 ... 3).contains(gear) else {
      completion(.failure(NativeBridgeError(
        code: "INVALID_ARGUMENT",
        message: "payload.gear must be 0..3",
        retriable: false,
        details: ["gear": gear]
      )))
      return
    }

    pendingGearMaxSpeed = completion
    expectedGearMaxSpeedGear = gear
    trace("readGearMaxSpeed requested gear=\(gear) timeoutMs=\(timeoutMs)")

    gearMaxSpeedTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingGearMaxSpeed else { return }
      self.trace("readGearMaxSpeed timeout gear=\(gear) timeoutMs=\(timeoutMs)")
      self.pendingGearMaxSpeed = nil
      self.expectedGearMaxSpeedGear = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Gear max speed read timeout",
        retriable: true,
        details: ["gear": gear, "timeoutMs": timeoutMs]
      )))
    }
    gearMaxSpeedTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readGearMaxSpeed(gear: gear)
  }

  func setThrottleBrakeResponse(throttle: Int, brake: Int) -> [String: Any] {
    manager.setThrottleBrakeResponse(throttle: throttle, brake: brake)
    return [
      "throttleResponse": throttle,
      "brakeResponse": brake,
    ]
  }

  func readNfcStatus(timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingNfcStatus = completion
    expectedNfcStatus = nil
    trace("readNfcStatus requested timeoutMs=\(timeoutMs)")

    nfcStatusTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingNfcStatus else { return }
      self.trace("readNfcStatus timeout timeoutMs=\(timeoutMs)")
      self.pendingNfcStatus = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "NFC status read timeout",
        retriable: true,
        details: ["timeoutMs": timeoutMs]
      )))
    }
    nfcStatusTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.readNfcStatus()
  }

  func setNfcEnabled(enabled: Bool, timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingNfcStatus = completion
    expectedNfcStatus = enabled
    trace("setNfcEnabled requested enabled=\(enabled) timeoutMs=\(timeoutMs)")

    nfcStatusTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingNfcStatus else { return }
      self.trace("setNfcEnabled timeout enabled=\(enabled) timeoutMs=\(timeoutMs)")
      self.pendingNfcStatus = nil
      self.expectedNfcStatus = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "NFC write timeout waiting status confirmation",
        retriable: true,
        details: ["enabled": enabled, "timeoutMs": timeoutMs]
      )))
    }
    nfcStatusTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.setNfcEnabled(enabled: enabled)
  }

  func factoryReset() -> [String: Any] {
    trace("factoryReset requested")
    manager.factoryReset()
    return ["factoryResetRequested": true]
  }

  func setGear(_ gear: Int, timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    guard (0 ... 3).contains(gear) else {
      completion(.failure(NativeBridgeError(
        code: "INVALID_ARGUMENT",
        message: "payload.gear must be 0..3",
        retriable: false,
        details: ["gear": gear]
      )))
      return
    }

    pendingGear = completion
    expectedGear = gear
    trace("setGear requested gear=\(gear) timeoutMs=\(timeoutMs)")

    gearTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingGear else { return }
      self.trace("setGear timeout gear=\(gear) timeoutMs=\(timeoutMs)")
      self.pendingGear = nil
      self.expectedGear = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Gear command timeout waiting heartbeat confirmation",
        retriable: true,
        details: ["gear": gear, "timeoutMs": timeoutMs]
      )))
    }
    gearTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.setGear(gear)
  }

  func setFrontLight(_ on: Bool) -> [String: Any] {
    manager.setFrontLight(on: on)
    return ["frontLightOn": on]
  }

  func setAmbientLight(on: Bool, timeoutMs: Int, completion: @escaping (Result<[String: Any], NativeBridgeError>) -> Void) {
    guard case .connected = currentConnectionState else {
      completion(.failure(NativeBridgeError(
        code: "BLE_DISCONNECTED",
        message: "Scooter not connected",
        retriable: true,
        details: nil
      )))
      return
    }

    pendingAmbientLight = completion
    expectedAmbientLight = on
    trace("setAmbientLight requested on=\(on) timeoutMs=\(timeoutMs)")

    ambientLightTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard let callback = self.pendingAmbientLight else { return }
      self.trace("setAmbientLight timeout on=\(on) timeoutMs=\(timeoutMs)")
      self.pendingAmbientLight = nil
      self.expectedAmbientLight = nil
      callback(.failure(NativeBridgeError(
        code: "TIMEOUT",
        message: "Ambient light write timeout waiting status confirmation",
        retriable: true,
        details: ["on": on, "timeoutMs": timeoutMs]
      )))
    }
    ambientLightTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(1000, timeoutMs)), execute: item)

    manager.setAmbientLight(on: on)
  }

  func setAmbientRgb(mode: Int, red: Int, green: Int, blue: Int, brightness: Int) -> [String: Any] {
    manager.setAmbientRgb(mode: mode, red: red, green: green, blue: blue, brightness: brightness)
    return [
      "mode": mode,
      "red": red,
      "green": green,
      "blue": blue,
      "brightness": brightness,
    ]
  }

  func setRainbowMode() -> [String: Any] {
    manager.setRainbowMode()
    return ["rainbowMode": true]
  }

  private func emitConnectionState(
    _ state: BridgeBleConnectionState,
    reason: String?,
    retriable: Bool,
    scanResults: [[String: Any]]?
  ) {
    var payload: [String: Any] = [
      "state": state.bridgeValue,
      "device": state.deviceId ?? NSNull(),
      "reason": reason ?? NSNull(),
      "retriable": retriable,
    ]
    if let scanResults {
      payload["scanResults"] = scanResults
    }
    trace("emitConnectionState state=\(state.bridgeValue) device=\(state.deviceId ?? "nil") reason=\(reason ?? "nil") retriable=\(retriable) scanCount=\(scanResults?.count ?? 0)")
    onConnectionEvent?(payload)
  }

  private func emitTelemetryHeartbeat(_ heartbeat: BridgeHeartbeatTelemetry) {
    onTelemetryEvent?([
      "type": "heartbeat",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": heartbeat.toBridgeMap,
    ])
  }

  private func emitLog(_ message: String, category: String = "native") {
    onLog?(category, message)
  }
}

extension IosBleBridgeAdapter: BleEventListener {
  func onConnectionStateChanged(_ state: BleConnectionState) {
    trace("onConnectionStateChanged nativeState=\(state)")
    switch state {
    case .idle:
      currentConnectionState = .idle
      emitConnectionState(.idle, reason: nil, retriable: false, scanResults: nil)

      if let callback = pendingConnect {
        pendingConnect = nil
        pendingConnectDeviceId = nil
        connectTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while connecting",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingLock {
        pendingLock = nil
        expectedLockStatus = nil
        lockTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting lock confirmation",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingGear {
        pendingGear = nil
        expectedGear = nil
        gearTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting gear confirmation",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingThrottleResponse {
        pendingThrottleResponse = nil
        throttleResponseTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting throttle response read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingBrakeResponse {
        pendingBrakeResponse = nil
        brakeResponseTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting brake response read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingControllerTemperature {
        pendingControllerTemperature = nil
        controllerTemperatureTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting controller temperature read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingBatteryTemperature {
        pendingBatteryTemperature = nil
        batteryTemperatureTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting battery temperature read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingMotorTemperature {
        pendingMotorTemperature = nil
        motorTemperatureTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting motor temperature read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingDrivingCurrent {
        pendingDrivingCurrent = nil
        drivingCurrentTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting driving current read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingRemainingMileage {
        pendingRemainingMileage = nil
        remainingMileageTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting remaining mileage read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingTripMileage {
        pendingTripMileage = nil
        tripMileageTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting trip mileage read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingOdo {
        pendingOdo = nil
        odoTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting ODO read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingSpeedStats {
        pendingSpeedStats = nil
        speedStatsTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting speed stats read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingSerialNumber {
        pendingSerialNumber = nil
        serialNumberTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting serial number read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingDeviceInfo {
        pendingDeviceInfo = nil
        deviceInfoTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting device info read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingMeterVersion {
        pendingMeterVersion = nil
        meterVersionTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting meter version read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingControllerVersion {
        pendingControllerVersion = nil
        controllerVersionTimeoutWorkItem?.cancel()
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting controller version read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingGearMaxSpeed {
        pendingGearMaxSpeed = nil
        gearMaxSpeedTimeoutWorkItem?.cancel()
        expectedGearMaxSpeedGear = nil
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting gear max speed read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingNfcStatus {
        pendingNfcStatus = nil
        nfcStatusTimeoutWorkItem?.cancel()
        expectedNfcStatus = nil
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting NFC status read",
          retriable: true,
          details: nil
        )))
      }
      if let callback = pendingAmbientLight {
        pendingAmbientLight = nil
        ambientLightTimeoutWorkItem?.cancel()
        expectedAmbientLight = nil
        callback(.failure(NativeBridgeError(
          code: "BLE_DISCONNECTED",
          message: "Disconnected while waiting ambient light confirmation",
          retriable: true,
          details: nil
        )))
      }

    case .scanning:
      currentConnectionState = .scanning
      emitConnectionState(.scanning, reason: nil, retriable: false, scanResults: nil)

    case .connecting(let peripheralName):
      let matchedId = pendingConnectDeviceId
      currentConnectionState = .connecting(deviceId: matchedId)
      emitConnectionState(.connecting(deviceId: matchedId), reason: peripheralName, retriable: false, scanResults: nil)

    case .connected(let peripheralName):
      let connectedId = pendingConnectDeviceId
        ?? scannedById.values.first(where: { $0.name == peripheralName })?.id.uuidString
      currentConnectionState = .connected(deviceId: connectedId)
      emitConnectionState(.connected(deviceId: connectedId), reason: nil, retriable: false, scanResults: nil)

      if let callback = pendingConnect {
        pendingConnect = nil
        pendingConnectDeviceId = nil
        connectTimeoutWorkItem?.cancel()

        let connectedName = peripheralName
        trace("connect completion success deviceId=\(connectedId ?? "") name=\(connectedName)")
        callback(.success([
          "state": "connected",
          "deviceId": connectedId ?? "",
          "name": connectedName,
          "model": "unknown",
        ]))
      }

    case .disconnecting:
      currentConnectionState = .disconnecting(deviceId: currentConnectionState.deviceId)
      emitConnectionState(.disconnecting(deviceId: currentConnectionState.deviceId), reason: nil, retriable: false, scanResults: nil)
    }
  }

  func onScanResultsChanged(_ devices: [BridgeScannedDevice]) {
    scannedById = Dictionary(uniqueKeysWithValues: devices.map { ($0.id.uuidString, $0) })

    let mapped = devices.map {
      [
        "name": $0.name,
        "deviceId": $0.id.uuidString,
        "mac": $0.id.uuidString,
        "rssi": $0.rssi,
        "model": $0.model,
      ]
    }

    currentConnectionState = .scanning
    trace("onScanResultsChanged count=\(devices.count)")
    emitConnectionState(.scanning, reason: nil, retriable: false, scanResults: mapped)
  }

  func onHeartbeatUpdated(_ telemetry: BridgeHeartbeatTelemetry) {
    lastHeartbeat = telemetry
    trace("heartbeat battery=\(telemetry.batteryPercent) speedKmh=\(telemetry.realtimeSpeedKmh) lock=\(telemetry.lockStatus) gear=\(telemetry.gear)")
    emitTelemetryHeartbeat(telemetry)
    onTelemetryEvent?([
      "type": "faultFlags",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": telemetry.faults.toBridgeMap,
    ])
    onTelemetryEvent?([
      "type": "operationalStatus",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": [
        "lockStatus": telemetry.lockStatus,
        "headlightOn": telemetry.headlightOn,
        "startMode": telemetry.startMode,
        "cruiseEnabled": telemetry.cruiseControlEnabled,
        "cruiseActive": telemetry.cruiseActive,
        "gear": telemetry.gear,
        "metricUnit": telemetry.metricKm,
        "charging": telemetry.charging,
        "motorRunning": telemetry.motorRunning,
        "electronicBrake": telemetry.electronicBrake,
        "mechanicalBrake": telemetry.mechanicalBrake,
      ],
    ])

    if let expected = expectedLockStatus,
       let callback = pendingLock,
       telemetry.lockStatus == expected {
      pendingLock = nil
      expectedLockStatus = nil
      lockTimeoutWorkItem?.cancel()
      callback(.success(["lockStatus": telemetry.lockStatus]))
    }
    if let expected = expectedGear,
       let callback = pendingGear,
       telemetry.gear == expected {
      pendingGear = nil
      expectedGear = nil
      gearTimeoutWorkItem?.cancel()
      callback(.success(["gear": telemetry.gear]))
    }
  }

  func onThrottleResponseRead(_ value: Int) {
    onTelemetryEvent?([
      "type": "responseTuning",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["throttle": value],
    ])
    if let callback = pendingThrottleResponse {
      pendingThrottleResponse = nil
      throttleResponseTimeoutWorkItem?.cancel()
      callback(.success(["throttleResponse": value]))
    }
  }

  func onBrakeResponseRead(_ value: Int) {
    onTelemetryEvent?([
      "type": "responseTuning",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["brake": value],
    ])
    if let callback = pendingBrakeResponse {
      pendingBrakeResponse = nil
      brakeResponseTimeoutWorkItem?.cancel()
      callback(.success(["brakeResponse": value]))
    }
  }

  func onControllerTemperatureRead(_ celsius: Int) {
    onTelemetryEvent?([
      "type": "temperature",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["type": "controller", "celsius": celsius],
    ])
    if let callback = pendingControllerTemperature {
      pendingControllerTemperature = nil
      controllerTemperatureTimeoutWorkItem?.cancel()
      callback(.success(["controllerTemperatureC": celsius, "type": "controller"]))
    }
  }

  func onBatteryTemperatureRead(_ celsius: Int) {
    onTelemetryEvent?([
      "type": "temperature",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["type": "battery", "celsius": celsius],
    ])
    if let callback = pendingBatteryTemperature {
      pendingBatteryTemperature = nil
      batteryTemperatureTimeoutWorkItem?.cancel()
      callback(.success(["batteryTemperatureC": celsius, "type": "battery"]))
    }
  }

  func onMotorTemperatureRead(_ celsius: Int) {
    onTelemetryEvent?([
      "type": "temperature",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["type": "motor", "celsius": celsius],
    ])
    if let callback = pendingMotorTemperature {
      pendingMotorTemperature = nil
      motorTemperatureTimeoutWorkItem?.cancel()
      callback(.success(["motorTemperatureC": celsius, "type": "motor"]))
    }
  }

  func onDrivingCurrentRead(realtimeAmps: Double, limitAmps: Double) {
    onTelemetryEvent?([
      "type": "drivingCurrent",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["realtimeAmps": realtimeAmps, "limitAmps": limitAmps],
    ])
    if let callback = pendingDrivingCurrent {
      pendingDrivingCurrent = nil
      drivingCurrentTimeoutWorkItem?.cancel()
      callback(.success(["realtimeAmps": realtimeAmps, "limitAmps": limitAmps]))
    }
  }

  func onRemainingMileageRead(_ kilometers: Double) {
    onTelemetryEvent?([
      "type": "mileage",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["remainingKm": kilometers],
    ])
    if let callback = pendingRemainingMileage {
      pendingRemainingMileage = nil
      remainingMileageTimeoutWorkItem?.cancel()
      callback(.success(["remainingMileageKm": kilometers]))
    }
  }

  func onTripMileageRead(_ kilometers: Double) {
    onTelemetryEvent?([
      "type": "mileage",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["tripKm": kilometers],
    ])
    if let callback = pendingTripMileage {
      pendingTripMileage = nil
      tripMileageTimeoutWorkItem?.cancel()
      callback(.success(["tripMileageKm": kilometers]))
    }
  }

  func onOdoRead(_ kilometers: Double) {
    onTelemetryEvent?([
      "type": "mileage",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["odoKm": kilometers],
    ])
    if let callback = pendingOdo {
      pendingOdo = nil
      odoTimeoutWorkItem?.cancel()
      callback(.success(["odoKm": kilometers]))
    }
  }

  func onSpeedStatsRead(avgKmh: Double, maxKmh: Double) {
    onTelemetryEvent?([
      "type": "speedStats",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["avgKmh": avgKmh, "maxKmh": maxKmh],
    ])
    if let callback = pendingSpeedStats {
      pendingSpeedStats = nil
      speedStatsTimeoutWorkItem?.cancel()
      callback(.success(["avgKmh": avgKmh, "maxKmh": maxKmh]))
    }
  }

  func onSerialNumberRead(_ serial: String) {
    onTelemetryEvent?([
      "type": "serialNumber",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["serialNumber": serial],
    ])
    if let callback = pendingSerialNumber {
      pendingSerialNumber = nil
      serialNumberTimeoutWorkItem?.cancel()
      callback(.success(["serialNumber": serial]))
    }
  }

  func onDeviceInfoRead(_ info: String) {
    onTelemetryEvent?([
      "type": "deviceInfo",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["deviceInfo": info],
    ])
    if let callback = pendingDeviceInfo {
      pendingDeviceInfo = nil
      deviceInfoTimeoutWorkItem?.cancel()
      callback(.success(["deviceInfo": info]))
    }
  }

  func onMeterVersionRead(_ version: BridgeDeviceVersion) {
    let mapped = version.toBridgeMap
    onTelemetryEvent?([
      "type": "meterVersion",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": mapped,
    ])
    if let callback = pendingMeterVersion {
      pendingMeterVersion = nil
      meterVersionTimeoutWorkItem?.cancel()
      callback(.success(["meterVersion": mapped]))
    }
  }

  func onControllerVersionRead(_ version: BridgeDeviceVersion) {
    let mapped = version.toBridgeMap
    onTelemetryEvent?([
      "type": "controllerVersion",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": mapped,
    ])
    if let callback = pendingControllerVersion {
      pendingControllerVersion = nil
      controllerVersionTimeoutWorkItem?.cancel()
      callback(.success(["controllerVersion": mapped]))
    }
  }

  func onGearMaxSpeedRead(gear: Int, maxSpeedKmh: Int) {
    onTelemetryEvent?([
      "type": "gearMaxSpeed",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": [
        "gear": gear,
        "maxSpeedKmh": maxSpeedKmh,
      ],
    ])
    if let callback = pendingGearMaxSpeed,
       let expected = expectedGearMaxSpeedGear,
       expected == gear {
      pendingGearMaxSpeed = nil
      expectedGearMaxSpeedGear = nil
      gearMaxSpeedTimeoutWorkItem?.cancel()
      callback(.success([
        "gear": gear,
        "maxSpeedKmh": maxSpeedKmh,
      ]))
    }
  }

  func onNfcStatusRead(_ enabled: Bool) {
    onTelemetryEvent?([
      "type": "nfc",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["enabled": enabled],
    ])
    if let callback = pendingNfcStatus {
      let expected = expectedNfcStatus
      if expected == nil || expected == enabled {
        pendingNfcStatus = nil
        expectedNfcStatus = nil
        nfcStatusTimeoutWorkItem?.cancel()
        callback(.success(["nfcEnabled": enabled]))
      }
    }
  }

  func onAmbientLightStatus(_ on: Bool) {
    onTelemetryEvent?([
      "type": "light",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": ["ambientOn": on],
    ])
    if let callback = pendingAmbientLight {
      let expected = expectedAmbientLight
      if expected == nil || expected == on {
        pendingAmbientLight = nil
        expectedAmbientLight = nil
        ambientLightTimeoutWorkItem?.cancel()
        callback(.success(["ambientOn": on]))
      }
    }
  }

  func onAmbientRgbStatus(_ status: BridgeAmbientRgbTelemetry) {
    onTelemetryEvent?([
      "type": "ambientRgb",
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios",
      "deviceId": currentConnectionState.deviceId ?? NSNull(),
      "data": status.toBridgeMap,
    ])
  }

  func onLog(_ message: String) {
    if message.lowercased().contains("failed") || message.lowercased().contains("error") {
      emitLog(message, category: "error")
    } else if message.lowercased().contains("tx") {
      emitLog(message, category: "tx")
    } else {
      emitLog(message, category: "native")
    }
  }
}

private enum BridgeBleConnectionState {
  case idle
  case scanning
  case connecting(deviceId: String?)
  case connected(deviceId: String?)
  case disconnecting(deviceId: String?)

  var bridgeValue: String {
    switch self {
    case .idle: return "idle"
    case .scanning: return "scanning"
    case .connecting: return "connecting"
    case .connected: return "connected"
    case .disconnecting: return "disconnecting"
    }
  }

  var deviceId: String? {
    switch self {
    case .idle, .scanning:
      return nil
    case .connecting(let id), .connected(let id), .disconnecting(let id):
      return id
    }
  }
}

private enum BleConnectionState: Equatable {
  case idle
  case scanning
  case connecting(peripheralName: String)
  case connected(peripheralName: String)
  case disconnecting
}

private struct BridgeScannedDevice: Identifiable, Equatable {
  let id: UUID
  let name: String
  let rssi: Int
  let peripheral: CBPeripheral
  let manufacturerHex: String
  let model: String
  let preferredServiceUUID: CBUUID?

  static func == (lhs: BridgeScannedDevice, rhs: BridgeScannedDevice) -> Bool {
    lhs.id == rhs.id && lhs.rssi == rhs.rssi && lhs.model == rhs.model
  }
}

private struct BridgeHeartbeatTelemetry: Equatable {
  var batteryPercent: Int = 0
  var batteryVoltage: Double = 0
  var realtimeSpeedKmh: Double = 0
  var gear: Int = 0
  var lockStatus: Bool = false
  var headlightOn: Bool = false
  var startMode: Bool = false
  var cruiseControlEnabled: Bool = false
  var cruiseActive: Bool = false
  var charging: Bool = false
  var motorRunning: Bool = false
  var electronicBrake: Bool = false
  var mechanicalBrake: Bool = false
  var metricKm: Bool = true
  var lastUpdated: Date = .distantPast
  var anyFaultActive: Bool = false
  var faults: BridgeFaultFlags = .init()

  var toBridgeMap: [String: Any] {
    [
      "batteryPercent": batteryPercent,
      "batteryVoltage": batteryVoltage,
      "speedKmh": realtimeSpeedKmh,
      "gear": gear,
      "lockStatus": lockStatus,
      "headlightOn": headlightOn,
      "startMode": startMode,
      "cruiseEnabled": cruiseControlEnabled,
      "cruiseActive": cruiseActive,
      "charging": charging,
      "motorRunning": motorRunning,
      "electronicBrake": electronicBrake,
      "mechanicalBrake": mechanicalBrake,
      "metricUnit": metricKm,
      "faultActive": anyFaultActive,
      "faults": faults.toBridgeMap,
      "lastUpdatedMs": Int64(lastUpdated.timeIntervalSince1970 * 1000),
    ]
  }
}

private struct BridgeFaultFlags: Equatable {
  var undervoltage: Bool = false
  var gyroscope: Bool = false
  var battery: Bool = false
  var controller: Bool = false
  var mos: Bool = false
  var motorHall: Bool = false
  var brake: Bool = false
  var turnHandle: Bool = false
  var communication: Bool = false
  var batteryOvervoltage: Bool = false
  var batteryTemperatureHigh: Bool = false
  var controllerTemperatureProtection: Bool = false

  var toBridgeMap: [String: Any] {
    [
      "undervoltage": undervoltage,
      "gyroscope": gyroscope,
      "battery": battery,
      "controller": controller,
      "mos": mos,
      "motorHall": motorHall,
      "brake": brake,
      "turnHandle": turnHandle,
      "communication": communication,
      "batteryOvervoltage": batteryOvervoltage,
      "batteryTemperatureHigh": batteryTemperatureHigh,
      "controllerTemperatureProtection": controllerTemperatureProtection,
    ]
  }

  var anyActive: Bool {
    undervoltage ||
      gyroscope ||
      battery ||
      controller ||
      mos ||
      motorHall ||
      brake ||
      turnHandle ||
      communication ||
      batteryOvervoltage ||
      batteryTemperatureHigh ||
      controllerTemperatureProtection
  }
}

private struct BridgeAmbientRgbTelemetry: Equatable {
  let mode: Int
  let red: Int
  let green: Int
  let blue: Int
  let brightness: Int

  var toBridgeMap: [String: Any] {
    [
      "mode": mode,
      "red": red,
      "green": green,
      "blue": blue,
      "brightness": brightness,
    ]
  }
}

private struct BridgeDeviceVersion: Equatable {
  let manufacturerCode: String
  let hardwareVersion: String
  let binVersion: String

  var toBridgeMap: [String: Any] {
    [
      "manufacturerCode": manufacturerCode,
      "hardwareVersion": hardwareVersion,
      "binVersion": binVersion,
    ]
  }
}

private protocol BleEventListener: AnyObject {
  func onConnectionStateChanged(_ state: BleConnectionState)
  func onScanResultsChanged(_ devices: [BridgeScannedDevice])
  func onHeartbeatUpdated(_ telemetry: BridgeHeartbeatTelemetry)
  func onThrottleResponseRead(_ value: Int)
  func onBrakeResponseRead(_ value: Int)
  func onControllerTemperatureRead(_ celsius: Int)
  func onBatteryTemperatureRead(_ celsius: Int)
  func onMotorTemperatureRead(_ celsius: Int)
  func onDrivingCurrentRead(realtimeAmps: Double, limitAmps: Double)
  func onRemainingMileageRead(_ kilometers: Double)
  func onTripMileageRead(_ kilometers: Double)
  func onOdoRead(_ kilometers: Double)
  func onSpeedStatsRead(avgKmh: Double, maxKmh: Double)
  func onSerialNumberRead(_ serial: String)
  func onDeviceInfoRead(_ info: String)
  func onMeterVersionRead(_ version: BridgeDeviceVersion)
  func onControllerVersionRead(_ version: BridgeDeviceVersion)
  func onGearMaxSpeedRead(gear: Int, maxSpeedKmh: Int)
  func onNfcStatusRead(_ enabled: Bool)
  func onAmbientLightStatus(_ on: Bool)
  func onAmbientRgbStatus(_ status: BridgeAmbientRgbTelemetry)
  func onLog(_ message: String)
}

private extension BleEventListener {
  func onConnectionStateChanged(_ state: BleConnectionState) {}
  func onScanResultsChanged(_ devices: [BridgeScannedDevice]) {}
  func onHeartbeatUpdated(_ telemetry: BridgeHeartbeatTelemetry) {}
  func onThrottleResponseRead(_ value: Int) {}
  func onBrakeResponseRead(_ value: Int) {}
  func onControllerTemperatureRead(_ celsius: Int) {}
  func onBatteryTemperatureRead(_ celsius: Int) {}
  func onMotorTemperatureRead(_ celsius: Int) {}
  func onDrivingCurrentRead(realtimeAmps: Double, limitAmps: Double) {}
  func onRemainingMileageRead(_ kilometers: Double) {}
  func onTripMileageRead(_ kilometers: Double) {}
  func onOdoRead(_ kilometers: Double) {}
  func onSpeedStatsRead(avgKmh: Double, maxKmh: Double) {}
  func onSerialNumberRead(_ serial: String) {}
  func onDeviceInfoRead(_ info: String) {}
  func onMeterVersionRead(_ version: BridgeDeviceVersion) {}
  func onControllerVersionRead(_ version: BridgeDeviceVersion) {}
  func onGearMaxSpeedRead(gear: Int, maxSpeedKmh: Int) {}
  func onNfcStatusRead(_ enabled: Bool) {}
  func onAmbientLightStatus(_ on: Bool) {}
  func onAmbientRgbStatus(_ status: BridgeAmbientRgbTelemetry) {}
  func onLog(_ message: String) {}
}

private enum ConnectionPreferences {
  private static let key = "cardoo.scooter.lastPeripheralUUID"

  static var lastPeripheralUUID: UUID? {
    get {
      guard let raw = UserDefaults.standard.string(forKey: key),
            let uuid = UUID(uuidString: raw) else { return nil }
      return uuid
    }
    set {
      if let value = newValue {
        UserDefaults.standard.set(value.uuidString, forKey: key)
      } else {
        UserDefaults.standard.removeObject(forKey: key)
      }
    }
  }
}

private final class HussienBleManagerPhase1: NSObject {
  static let shared = HussienBleManagerPhase1()
  private static let logDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private let restoreIdentifier = "cardoo.scooter.central"
  private let scooterServiceUUIDs: [CBUUID] = [
    CBUUID(string: "54430011-0153-3236-FFFF-FFFFFFFBFFFF"),
    CBUUID(string: "54430011-0153-3239-FFFF-FFFFFFF7FFFF"),
    CBUUID(string: "5443000F-0163-6172-646F-467831FBFFFF"),
    CBUUID(string: "5443000F-0163-6172-646F-467832FBFFFF"),
    CBUUID(string: "5443000B-0152-572D-4754-FFFFFFF7FFFF"),
  ]
  private let knownAdvertisementSignatures: [String: String] = [
    "FFFFFB3178466F64726163010F004354": "OX1",
    "FFFFFB3278466F64726163010F004354": "OX2",
    "FFFFF7FFFFFF54472D5752010B004354": "OX3",
    "FFFFFBFFFFFFFFFF3632530111004354": "S26",
    "FFFFF7FFFFFFFFFF3932530111004354": "S26",
  ]
  private let writeCharUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
  private let notifyCharUUID = CBUUID(string: "0000FFE2-0000-1000-8000-00805F9B34FB")

  private let connectAuthUserIds: [UInt32] = [5, 0x272B]
  private var central: CBCentralManager!
  private var peripheral: CBPeripheral?
  private var writeChar: CBCharacteristic?
  private var notifyChar: CBCharacteristic?
  private var expectedServiceUUID: CBUUID?
  private var notifyReady = false
  private var connectAuthSent = false
  private var authAttemptIndex = 0
  private var waitingForProtocolRx = false
  private var lastRxAt: Date?
  private var discoveredByID: [UUID: BridgeScannedDevice] = [:]
  private var listeners = NSHashTable<AnyObject>.weakObjects()
  private var connectAttempt = 0

  private(set) var connectionState: BleConnectionState = .idle {
    didSet { broadcast { $0.onConnectionStateChanged(self.connectionState) } }
  }

  private(set) var telemetry = BridgeHeartbeatTelemetry() {
    didSet { broadcast { $0.onHeartbeatUpdated(self.telemetry) } }
  }

  override init() {
    super.init()
    trace("init restoreIdentifier=\(restoreIdentifier)")
    central = CBCentralManager(
      delegate: self,
      queue: .main,
      options: [
        CBCentralManagerOptionShowPowerAlertKey: true,
        CBCentralManagerOptionRestoreIdentifierKey: restoreIdentifier,
      ]
    )
  }

  func addListener(_ listener: BleEventListener) {
    listeners.add(listener)
    listener.onConnectionStateChanged(connectionState)
    listener.onScanResultsChanged(currentDevices())
    listener.onHeartbeatUpdated(telemetry)
  }

  func removeListener(_ listener: BleEventListener) {
    listeners.remove(listener)
  }

  func startScan() {
    trace("startScan request state=\(central.state.rawValue) isScanning=\(central.isScanning)")
    guard central.state == .poweredOn else {
      log("Bluetooth not ready (state=\(central.state.rawValue)). Cannot scan.")
      return
    }

    if central.isScanning { central.stopScan() }
    discoveredByID.removeAll()
    broadcast { $0.onScanResultsChanged([]) }
    connectionState = .scanning
    log("TX scan start services=\(scooterServiceUUIDs.map(\.uuidString).joined(separator: ","))")

    central.scanForPeripherals(withServices: scooterServiceUUIDs, options: [
      CBCentralManagerScanOptionAllowDuplicatesKey: false,
    ])
  }

  func stopScan() {
    trace("stopScan request isScanning=\(central.isScanning)")
    if central.isScanning { central.stopScan() }
    if case .scanning = connectionState { connectionState = .idle }
    log("scan stopped")
  }

  func connect(to device: BridgeScannedDevice) {
    if central.isScanning { central.stopScan() }
    if let current = peripheral, current.identifier != device.id {
      log("Cancelling previous peripheral before new connect old=\(current.identifier.uuidString) new=\(device.id.uuidString)")
      central.cancelPeripheralConnection(current)
    }
    peripheral = device.peripheral
    device.peripheral.delegate = self
    writeChar = nil
    notifyChar = nil
    notifyReady = false
    connectAuthSent = false
    authAttemptIndex = 0
    waitingForProtocolRx = false
    lastRxAt = nil
    expectedServiceUUID = device.preferredServiceUUID
    connectAttempt += 1
    connectionState = .connecting(peripheralName: device.name)
    log("TX connect attempt=\(connectAttempt) name=\(device.name) id=\(device.id.uuidString) model=\(device.model) rssi=\(device.rssi) service=\(device.preferredServiceUUID?.uuidString ?? "unknown")")
    central.connect(device.peripheral, options: nil)
  }

  func disconnect() {
    guard let activePeripheral = peripheral else { return }
    ConnectionPreferences.lastPeripheralUUID = nil
    writeChar = nil
    notifyChar = nil
    notifyReady = false
    connectAuthSent = false
    authAttemptIndex = 0
    waitingForProtocolRx = false
    lastRxAt = nil
    expectedServiceUUID = nil
    connectionState = .disconnecting
    log("TX disconnect")
    central.cancelPeripheralConnection(activePeripheral)
  }

  func unbind() {
    guard writeChar != nil, peripheral != nil else {
      log("Cannot unbind: not connected.")
      return
    }

    sendManual(label: "TX unbind") {
      self.buildFrame(
        addr: 0x23,
        functionCode: 0x02,
        payload: [0x00, 0x40, 0x00, 0x00, 0x00, 0x00],
        mirror: false
      )
    }
    ConnectionPreferences.lastPeripheralUUID = nil
  }

  func bind() {
    writeConnectAuth()
  }

  func setLocked(_ locked: Bool) {
    let value: UInt8 = locked ? 0x01 : 0x00
    sendManual(label: locked ? "TX lock" : "TX unlock") {
      self.buildFrame(
        addr: 0x23,
        functionCode: 0x02,
        payload: [value, 0x01],
        mirror: true
      )
    }
  }

  func setCruiseControl(_ enabled: Bool) {
    let value: UInt8 = enabled ? 0x04 : 0x00
    sendManual(label: enabled ? "TX cruise enable" : "TX cruise disable") {
      self.buildFrame(
        addr: 0x23,
        functionCode: 0x02,
        payload: [value, 0x04],
        mirror: true
      )
    }
  }

  func setStartMode(enabled: Bool) {
    let value: UInt8 = enabled ? 0x02 : 0x00
    sendManual(label: enabled ? "TX start mode on" : "TX start mode off") {
      self.buildFrame(
        addr: 0x23,
        functionCode: 0x02,
        payload: [value, 0x02],
        mirror: true
      )
    }
  }

  func setUnitSystem(metric: Bool) {
    let value: UInt8 = metric ? 0x00 : 0x80
    sendManual(label: metric ? "TX unit metric" : "TX unit mile") {
      self.buildFrame(
        addr: 0x23,
        functionCode: 0x02,
        payload: [value, 0x80],
        mirror: true
      )
    }
  }

  func readThrottleResponse() {
    sendManual(label: "TX read throttle response") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x22,
        payload: [0x00, 0x00],
        mirror: false
      )
    }
  }

  func readBrakeResponse() {
    sendManual(label: "TX read brake response") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x22,
        payload: [0x01, 0x00],
        mirror: false
      )
    }
  }

  func readControllerTemperature() {
    sendManual(label: "TX read controller temperature") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x0A,
        payload: [0x00],
        mirror: false
      )
    }
  }

  func readBatteryTemperature() {
    sendManual(label: "TX read battery temperature") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x0A,
        payload: [0x10],
        mirror: false
      )
    }
  }

  func readMotorTemperature() {
    sendManual(label: "TX read motor temperature") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x0A,
        payload: [0x30],
        mirror: false
      )
    }
  }

  func readDrivingCurrent() {
    sendManual(label: "TX read driving current") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x0B,
        payload: [0x00],
        mirror: false
      )
    }
  }

  func readRemainingMileage() {
    sendManual(label: "TX read remaining mileage") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x30,
        payload: [],
        mirror: false
      )
    }
  }

  func readTripMileage() {
    sendManual(label: "TX read trip mileage") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x08,
        payload: [],
        mirror: false
      )
    }
  }

  func readOdo() {
    sendManual(label: "TX read ODO") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x09,
        payload: [],
        mirror: false
      )
    }
  }

  func readSpeedStats() {
    sendManual(label: "TX read speed stats") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x32,
        payload: [],
        mirror: false
      )
    }
  }

  func readSerialNumber() {
    sendManual(label: "TX read serial number") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x1D,
        payload: [],
        mirror: false
      )
    }
  }

  func readDeviceInfo() {
    sendManual(label: "TX read device info") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x1E,
        payload: [],
        mirror: false
      )
    }
  }

  func readMeterVersion() {
    sendManual(label: "TX read meter version") {
      self.buildFrame(
        addr: 0x23,
        functionCode: 0x11,
        payload: [],
        mirror: true
      )
    }
  }

  func readControllerVersion() {
    sendManual(label: "TX read controller version") {
      self.buildFrame(
        addr: 0x21,
        functionCode: 0x11,
        payload: [],
        mirror: false
      )
    }
  }

  func readGearMaxSpeed(gear: Int) {
    let safe = max(0, min(gear, 3))
    let slot = UInt8(0x18 + safe)
    sendManual(label: "TX read gear \(safe) max speed") {
      self.buildFrame(
        addr: 0x01,
        functionCode: 0x05,
        payload: [slot, 0x00],
        mirror: false
      )
    }
  }

  func setThrottleBrakeResponse(throttle: Int, brake: Int) {
    let throttleValue = UInt8(max(0, min(10, throttle)))
    let brakeValue = UInt8(max(0, min(10, brake)))
    sendManual(label: "TX write throttle response \(throttleValue)") {
      self.buildFrame(
        addr: 0x21,
        functionCode: 0x22,
        payload: [0x00, throttleValue],
        mirror: false
      )
    }
    sendManual(label: "TX write brake response \(brakeValue)") {
      self.buildFrame(
        addr: 0x21,
        functionCode: 0x22,
        payload: [0x01, brakeValue],
        mirror: false
      )
    }
  }

  func readNfcStatus() {
    sendManual(label: "TX read NFC status") {
      self.buildFrame(
        addr: 0x03,
        functionCode: 0x03,
        payload: [0x00, 0x10],
        mirror: false
      )
    }
  }

  func setNfcEnabled(enabled: Bool) {
    let value: UInt8 = enabled ? 0x10 : 0x00
    sendManual(label: enabled ? "TX NFC enable" : "TX NFC disable") {
      self.buildFrame(
        addr: 0x23,
        functionCode: 0x03,
        payload: [value, 0x10],
        mirror: false
      )
    }
  }

  func factoryReset() {
    sendManual(label: "TX factory reset") {
      self.buildFrame(
        addr: 0x21,
        functionCode: 0x03,
        payload: [0x02, 0x02],
        mirror: false
      )
    }
  }

  func setGear(_ gear: Int) {
    let safe = max(0, min(gear, 3))
    sendManual(label: "TX gear \(safe)") {
      self.buildFrame(
        addr: 0x23,
        functionCode: 0x05,
        payload: [0x20 | UInt8(safe & 0x03), 0x00],
        mirror: true
      )
    }
  }

  func setFrontLight(on: Bool) {
    let value: UInt8 = on ? 0x20 : 0x00
    sendManual(label: on ? "TX front light on" : "TX front light off") {
      self.buildFrame(
        addr: 0x23,
        functionCode: 0x04,
        payload: [value, 0x20],
        mirror: true
      )
    }
  }

  func setAmbientLight(on: Bool) {
    let value: UInt8 = on ? 0x08 : 0x00
    sendManual(label: on ? "TX ambient light on" : "TX ambient light off") {
      self.buildFrame(
        addr: 0x21,
        functionCode: 0x04,
        payload: [value, 0x08],
        mirror: false
      )
    }
  }

  func setAmbientRgb(mode: Int, red: Int, green: Int, blue: Int, brightness: Int) {
    let r = UInt8((max(0, min(255, red)) * max(0, min(255, brightness)) + 127) / 255)
    let g = UInt8((max(0, min(255, green)) * max(0, min(255, brightness)) + 127) / 255)
    let b = UInt8((max(0, min(255, blue)) * max(0, min(255, brightness)) + 127) / 255)
    let safeMode = max(1, min(4, mode))
    let tail: UInt8 = safeMode == 4 ? 0xFF : 0x00
    sendManual(label: "TX ambient rgb mode=\(safeMode) rgb=(\(r),\(g),\(b))") {
      self.buildFrame(
        addr: 0x21,
        functionCode: 0x1A,
        payload: [UInt8(safeMode), r, g, b, tail],
        mirror: false
      )
    }
  }

  func setRainbowMode() {
    setAmbientRgb(mode: 3, red: 255, green: 255, blue: 255, brightness: 255)
  }

  private func writeConnectAuth() {
    guard authAttemptIndex < connectAuthUserIds.count else {
      log("writeConnectAuth aborted: exhausted auth candidates")
      return
    }
    let userId = connectAuthUserIds[authAttemptIndex]
    trace("schedule writeConnectAuth delayMs=800 userId=\(userId) attempt=\(authAttemptIndex + 1)/\(connectAuthUserIds.count)")
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) { [weak self] in
      guard let self else { return }
      let userIdBytes: [UInt8] = [
        UInt8((userId >> 24) & 0xFF),
        UInt8((userId >> 16) & 0xFF),
        UInt8((userId >> 8) & 0xFF),
        UInt8(userId & 0xFF),
      ]
      let payload: [UInt8] = [0x40, 0x40] + userIdBytes
      self.sendManual(label: "TX writeConnect (bind userID=\(userId))") {
        self.buildFrame(
          addr: 0x23,
          functionCode: 0x02,
          payload: payload,
          mirror: false
        )
      }
      self.waitingForProtocolRx = true
      // If still no protocol RX, retry with next auth user id.
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(2200)) { [weak self] in
        guard let self else { return }
        guard self.waitingForProtocolRx else { return }
        guard case .connected = self.connectionState else { return }
        let next = self.authAttemptIndex + 1
        if next < self.connectAuthUserIds.count {
          self.authAttemptIndex = next
          self.log("No protocol RX after auth attempt. Retrying with alternate userId=\(self.connectAuthUserIds[next])")
          self.writeConnectAuth()
        } else {
          self.log("No protocol RX after all auth attempts")
        }
      }
    }
  }

  private func send(_ data: Data, label: String) {
    guard let activePeripheral = peripheral, let channel = writeChar else {
      log("\(label) skipped: no write characteristic")
      return
    }
    let type: CBCharacteristicWriteType = channel.properties.contains(.write) ? .withResponse : .withoutResponse
    log("\(label): \(data.hexString) writeType=\(type == .withResponse ? "withResponse" : "withoutResponse") char=\(channel.uuid.uuidString) peripheral=\(activePeripheral.identifier.uuidString)")
    activePeripheral.writeValue(data, for: channel, type: type)
  }

  private func sendManual(label: String, build: () -> Data?) {
    guard let data = build() else {
      log("\(label) frame build failed")
      return
    }
    send(data, label: label)
  }

  private func buildFrame(addr: UInt8, functionCode: UInt8, payload: [UInt8] = [], mirror: Bool = false) -> Data? {
    var bytes: [UInt8] = [0x5A, addr, functionCode]
    bytes.append(mirror ? functionCode : 0x00)
    bytes.append(UInt8(payload.count))
    bytes.append(contentsOf: payload)
    let crc = crc16Tcb(bytes)
    // Protocol uses big-endian CRC bytes in frame tail.
    bytes.append(UInt8((crc >> 8) & 0xFF))
    bytes.append(UInt8(crc & 0xFF))
    return Data(bytes)
  }

  // Matches native SDK CRC implementation (Android TCBSDK.jar + iOS TCBCRC16).
  private func crc16Tcb(_ bytes: [UInt8]) -> UInt16 {
    var crc: UInt16 = 0x0000
    for b in bytes {
      crc = (crc >> 8) | (crc << 8)
      crc ^= UInt16(b)
      crc ^= (crc & 0x00FF) >> 4
      crc ^= (crc << 8) << 4
      crc ^= ((crc & 0x00FF) << 4) << 1
    }
    return crc
  }

  private func handleNotification(_ data: Data) {
    lastRxAt = Date()
    waitingForProtocolRx = false
    log("RX notify len=\(data.count) hex=\(data.hexString)")
    if let parsed = parseHeartbeat(data) {
      telemetry = parsed
      log("RX parse heartbeat battery=\(parsed.batteryPercent) speedKmh=\(parsed.realtimeSpeedKmh) gear=\(parsed.gear) lock=\(parsed.lockStatus)")
      return
    }

    if let bindInfo = parseBindAck(data) {
      if bindInfo.bound {
        log("RX bind status: bound=true locked=\(bindInfo.locked) boundId=\(bindInfo.boundId)")
      } else {
        // Some 0x02 status frames are informational (not an actual unbind action).
        log("RX status frame: boundFlag=false locked=\(bindInfo.locked) boundId=\(bindInfo.boundId)")
      }
      return
    }

    if let throttle = parseThrottleResponse(data) {
      log("RX throttle response value=\(throttle)")
      broadcast { $0.onThrottleResponseRead(throttle) }
      return
    }

    if let brake = parseBrakeResponse(data) {
      log("RX brake response value=\(brake)")
      broadcast { $0.onBrakeResponseRead(brake) }
      return
    }

    if let controllerTemperature = parseControllerTemperature(data) {
      log("RX controller temperature celsius=\(controllerTemperature)")
      broadcast { $0.onControllerTemperatureRead(controllerTemperature) }
      return
    }

    if let batteryTemperature = parseBatteryTemperature(data) {
      log("RX battery temperature celsius=\(batteryTemperature)")
      broadcast { $0.onBatteryTemperatureRead(batteryTemperature) }
      return
    }

    if let motorTemperature = parseMotorTemperature(data) {
      log("RX motor temperature celsius=\(motorTemperature)")
      broadcast { $0.onMotorTemperatureRead(motorTemperature) }
      return
    }

    if let drivingCurrent = parseDrivingCurrent(data) {
      log("RX driving current realtime=\(drivingCurrent.realtimeAmps)A limit=\(drivingCurrent.limitAmps)A")
      broadcast { $0.onDrivingCurrentRead(realtimeAmps: drivingCurrent.realtimeAmps, limitAmps: drivingCurrent.limitAmps) }
      return
    }

    if let remainingMileage = parseRemainingMileage(data) {
      log("RX remaining mileage km=\(remainingMileage)")
      broadcast { $0.onRemainingMileageRead(remainingMileage) }
      return
    }

    if let tripMileage = parseTripMileage(data) {
      log("RX trip mileage km=\(tripMileage)")
      broadcast { $0.onTripMileageRead(tripMileage) }
      return
    }

    if let odo = parseOdo(data) {
      log("RX ODO km=\(odo)")
      broadcast { $0.onOdoRead(odo) }
      return
    }

    if let speedStats = parseSpeedStats(data) {
      log("RX speed stats avg=\(speedStats.avgKmh) max=\(speedStats.maxKmh)")
      broadcast { $0.onSpeedStatsRead(avgKmh: speedStats.avgKmh, maxKmh: speedStats.maxKmh) }
      return
    }

    if let serialNumber = parseSerialNumber(data) {
      log("RX serial number value=\(serialNumber)")
      broadcast { $0.onSerialNumberRead(serialNumber) }
      return
    }

    if let deviceInfo = parseDeviceInfo(data) {
      log("RX device info value=\(deviceInfo)")
      broadcast { $0.onDeviceInfoRead(deviceInfo) }
      return
    }

    if let meterVersion = parseMeterVersion(data) {
      log("RX meter version hw=\(meterVersion.hardwareVersion) bin=\(meterVersion.binVersion) maker=\(meterVersion.manufacturerCode)")
      broadcast { $0.onMeterVersionRead(meterVersion) }
      return
    }

    if let controllerVersion = parseControllerVersion(data) {
      log("RX controller version hw=\(controllerVersion.hardwareVersion) bin=\(controllerVersion.binVersion) maker=\(controllerVersion.manufacturerCode)")
      broadcast { $0.onControllerVersionRead(controllerVersion) }
      return
    }

    if let gearMaxSpeed = parseGearMaxSpeed(data) {
      log("RX gear max speed gear=\(gearMaxSpeed.gear) max=\(gearMaxSpeed.maxSpeedKmh)")
      broadcast { $0.onGearMaxSpeedRead(gear: gearMaxSpeed.gear, maxSpeedKmh: gearMaxSpeed.maxSpeedKmh) }
      return
    }

    if let nfcEnabled = parseNfcStatus(data) {
      log("RX nfc status enabled=\(nfcEnabled)")
      broadcast { $0.onNfcStatusRead(nfcEnabled) }
      return
    }

    if let ambientOn = parseAmbientStatus(data) {
      log("RX ambient status on=\(ambientOn)")
      broadcast { $0.onAmbientLightStatus(ambientOn) }
      return
    }

    if let ambientRgb = parseAmbientRgbStatus(data) {
      log("RX ambient rgb mode=\(ambientRgb.mode) rgb=(\(ambientRgb.red),\(ambientRgb.green),\(ambientRgb.blue)) brightness=\(ambientRgb.brightness)")
      broadcast { $0.onAmbientRgbStatus(ambientRgb) }
      return
    }

    log("RX parse unknown packet")
  }

  private func parseBindAck(_ data: Data) -> (bound: Bool, locked: Bool, boundId: String)? {
    let bytes = [UInt8](data)
    guard bytes.count >= 5 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x02 else { return nil }

    let length = Int(bytes[4])
    guard bytes.count >= 5 + length, length >= 6 else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])

    let status = payload[0]
    let bound = (status & 0x40) != 0
    let locked = (status & 0x01) != 0

    let uid = UInt32(payload[2])
      | (UInt32(payload[3]) << 8)
      | (UInt32(payload[4]) << 16)
      | (UInt32(payload[5]) << 24)
    let boundId = String(uid)
    return (bound: bound, locked: locked, boundId: boundId)
  }

  private func parseHeartbeat(_ data: Data) -> BridgeHeartbeatTelemetry? {
    let bytes = [UInt8](data)
    guard bytes.count >= 5 + 9 else { return nil }
    guard bytes[0] == 0x5A else { return nil }
    guard bytes[2] == 0x01 else { return nil }

    let length = Int(bytes[4])
    guard bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    guard payload.count >= 9 else { return nil }

    let power = Int(payload[0])
    let speedRaw = Int(UInt16(payload[1] & 0x7F) << 8 | UInt16(payload[2]))

    let status8 = payload[3]
    let status9 = payload[4]
    let status10 = payload[5]
    let status11 = payload[6]

    let metricMileUnit = (status8 & 0b0000_1000) != 0
    let gear = Int(status8 & 0b0000_0111)

    let lockStatus = (status10 & 0b0010_0000) != 0
    let headlight = (status10 & 0b0000_1000) != 0
    let startMode = (status10 & 0b0100_0000) != 0

    let cruiseControl = (status8 & 0b0001_0000) != 0
    let cruiseActive = (status8 & 0b0010_0000) != 0
    let charging = (status9 & 0b0001_0000) != 0
    let electronicBrake = (status9 & 0b0000_0100) != 0
    let mechanicalBrake = (status9 & 0b0000_0010) != 0
    let motorRunning = (status9 & 0b0000_0001) != 0

    let faults = BridgeFaultFlags(
      undervoltage: (status9 & 0b1000_0000) != 0,
      gyroscope: (status11 & 0b1000_0000) != 0,
      battery: (status11 & 0b0100_0000) != 0,
      controller: (status11 & 0b0010_0000) != 0,
      mos: (status11 & 0b0001_0000) != 0,
      motorHall: (status11 & 0b0000_1000) != 0,
      brake: (status11 & 0b0000_0100) != 0,
      turnHandle: (status11 & 0b0000_0010) != 0,
      communication: (status11 & 0b0000_0001) != 0,
      batteryOvervoltage: (status11 & 0b0000_0001) != 0,
      batteryTemperatureHigh: (status11 & 0b0000_0010) != 0,
      controllerTemperatureProtection: (status11 & 0b0000_0100) != 0
    )

    let batteryVoltageRaw = Int(UInt16(payload[7]) << 8 | UInt16(payload[8]))

    return BridgeHeartbeatTelemetry(
      batteryPercent: power,
      batteryVoltage: Double(batteryVoltageRaw) / 10.0,
      realtimeSpeedKmh: Double(speedRaw) / 10.0,
      gear: gear,
      lockStatus: lockStatus,
      headlightOn: headlight,
      startMode: startMode,
      cruiseControlEnabled: cruiseControl,
      cruiseActive: cruiseActive,
      charging: charging,
      motorRunning: motorRunning,
      electronicBrake: electronicBrake,
      mechanicalBrake: mechanicalBrake,
      metricKm: metricMileUnit,
      lastUpdated: Date(),
      anyFaultActive: faults.anyActive,
      faults: faults
    )
  }

  private func parseThrottleResponse(_ data: Data) -> Int? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x22 else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    guard payload[0] == 0x00 else { return nil }
    return Int(payload[1])
  }

  private func parseBrakeResponse(_ data: Data) -> Int? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x22 else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    guard payload[0] == 0x01 else { return nil }
    return Int(payload[1])
  }

  private func parseControllerTemperature(_ data: Data) -> Int? {
    let bytes = [UInt8](data)
    guard bytes.count >= 8 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x0A else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    guard payload[0] == 0x00 else { return nil }
    return Int(payload[1]) - 60
  }

  private func parseBatteryTemperature(_ data: Data) -> Int? {
    let bytes = [UInt8](data)
    guard bytes.count >= 8 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x0A else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    guard payload[0] == 0x10 else { return nil }
    return Int(payload[1]) - 60
  }

  private func parseMotorTemperature(_ data: Data) -> Int? {
    let bytes = [UInt8](data)
    guard bytes.count >= 8 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x0A else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    guard payload[0] == 0x30 else { return nil }
    return Int(payload[1]) - 60
  }

  private func parseDrivingCurrent(_ data: Data) -> (realtimeAmps: Double, limitAmps: Double)? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x0B else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])

    func signed16(_ high: UInt8, _ low: UInt8) -> Int {
      let value = (Int(high) << 8) | Int(low)
      return (value & 0x8000) != 0 ? value - 0x10000 : value
    }

    if payload.count >= 3 {
      let limit = Double(Int(payload[0])) / 10.0
      let realtime = Double(signed16(payload[1], payload[2])) / 10.0
      return (realtime, limit)
    }
    if payload.count >= 2 {
      let realtime = Double(signed16(payload[0], payload[1])) / 10.0
      return (realtime, 0.0)
    }
    return nil
  }

  private func parseRemainingMileage(_ data: Data) -> Double? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x30 else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])

    if payload.count >= 4 {
      let raw = (UInt32(payload[0]) << 24) |
        (UInt32(payload[1]) << 16) |
        (UInt32(payload[2]) << 8) |
        UInt32(payload[3])
      return Double(raw) / 10.0
    }
    let raw = (Int(payload[0]) << 8) | Int(payload[1])
    return Double(raw) / 10.0
  }

  private func parseTripMileage(_ data: Data) -> Double? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x08 else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])

    if payload.count >= 4 {
      let raw = (UInt32(payload[0]) << 24) |
        (UInt32(payload[1]) << 16) |
        (UInt32(payload[2]) << 8) |
        UInt32(payload[3])
      return Double(raw) / 10.0
    }
    let raw = (Int(payload[0]) << 8) | Int(payload[1])
    return Double(raw) / 10.0
  }

  private func parseOdo(_ data: Data) -> Double? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x09 else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])

    if payload.count >= 4 {
      let raw = (UInt32(payload[0]) << 24) |
        (UInt32(payload[1]) << 16) |
        (UInt32(payload[2]) << 8) |
        UInt32(payload[3])
      return Double(raw) / 10.0
    }
    let raw = (Int(payload[0]) << 8) | Int(payload[1])
    return Double(raw) / 10.0
  }

  private func parseSpeedStats(_ data: Data) -> (avgKmh: Double, maxKmh: Double)? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x32 else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])

    if payload.count >= 4 {
      let avg = Double((Int(payload[0]) << 8) | Int(payload[1])) / 10.0
      let max = Double((Int(payload[2]) << 8) | Int(payload[3])) / 10.0
      return (avg, max)
    }
    let avg = Double(Int(payload[0])) / 10.0
    let max = Double(Int(payload[1])) / 10.0
    return (avg, max)
  }

  private func parseSerialNumber(_ data: Data) -> String? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x1D else { return nil }
    let length = Int(bytes[4])
    guard length >= 1, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    let serial = String(bytes: payload, encoding: .ascii)?
      .trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
    guard let serial, !serial.isEmpty else { return nil }
    return serial
  }

  private func parseDeviceInfo(_ data: Data) -> String? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x1E else { return nil }
    let length = Int(bytes[4])
    guard length >= 1, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    let info = String(bytes: payload, encoding: .ascii)?
      .trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
    guard let info, !info.isEmpty else { return nil }
    return info
  }

  private func parseMeterVersion(_ data: Data) -> BridgeDeviceVersion? {
    let bytes = [UInt8](data)
    guard bytes.count > 14 else { return nil }
    guard bytes[0] == 0x5A, bytes[1] == 0x23, bytes[2] == 0x11, bytes[3] == 0x11 else { return nil }
    return parseVersionPayload(bytes)
  }

  private func parseControllerVersion(_ data: Data) -> BridgeDeviceVersion? {
    let bytes = [UInt8](data)
    guard bytes.count > 14 else { return nil }
    guard bytes[0] == 0x5A, bytes[1] == 0x21, bytes[2] == 0x11, bytes[3] == 0x00 else { return nil }
    return parseVersionPayload(bytes)
  }

  private func parseVersionPayload(_ bytes: [UInt8]) -> BridgeDeviceVersion? {
    guard bytes.count > 13 else { return nil }
    let manufacturerBytes = Array(bytes[5 ... 8])
    let manufacturerCode = String(bytes: manufacturerBytes, encoding: .ascii)?
      .trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines)) ?? ""
    if manufacturerCode.isEmpty { return nil }

    let hardwareVersion = bytes[13...].map { String(format: "%02X", $0) }.joined()
    let majorRaw = String(format: "%02X", bytes[11])
    let major = majorRaw.hasPrefix("0") ? String(majorRaw.dropFirst()) : majorRaw
    let minor = String(format: "%02X", bytes[12])
    let binVersion = "\(major).\(minor)"
    return BridgeDeviceVersion(
      manufacturerCode: manufacturerCode,
      hardwareVersion: hardwareVersion,
      binVersion: binVersion
    )
  }

  private func parseGearMaxSpeed(_ data: Data) -> (gear: Int, maxSpeedKmh: Int)? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x05 else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    let slot = Int(payload[0])
    guard (0x18 ... 0x1B).contains(slot) else { return nil }
    let gear = slot - 0x18
    let maxSpeed = max(0, Int(payload[1]) - 6)
    return (gear, maxSpeed)
  }

  private func parseNfcStatus(_ data: Data) -> Bool? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x03 else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    guard payload[1] == 0x10 else { return nil }
    return (payload[0] & 0x10) != 0
  }

  private func parseAmbientStatus(_ data: Data) -> Bool? {
    let bytes = [UInt8](data)
    guard bytes.count >= 7 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x04 else { return nil }
    let length = Int(bytes[4])
    guard length >= 2, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    guard payload[1] == 0x08 else { return nil }
    return (payload[0] & 0x08) != 0
  }

  private func parseAmbientRgbStatus(_ data: Data) -> BridgeAmbientRgbTelemetry? {
    let bytes = [UInt8](data)
    guard bytes.count >= 10 else { return nil }
    guard bytes[0] == 0x5A, bytes[2] == 0x1A else { return nil }
    let length = Int(bytes[4])
    guard length >= 5, bytes.count >= 5 + length else { return nil }
    let payload = Array(bytes[5 ..< (5 + length)])
    let mode = Int(payload[0])
    let red = Int(payload[1])
    let green = Int(payload[2])
    let blue = Int(payload[3])
    let brightness = payload[4] == 0xFF ? 255 : Int(payload[4])
    return BridgeAmbientRgbTelemetry(
      mode: mode,
      red: red,
      green: green,
      blue: blue,
      brightness: brightness
    )
  }

  private func currentDevices() -> [BridgeScannedDevice] {
    discoveredByID.values.sorted { $0.rssi > $1.rssi }
  }

  private func broadcast(_ block: @escaping (BleEventListener) -> Void) {
    DispatchQueue.main.async {
      for case let listener as BleEventListener in self.listeners.allObjects {
        block(listener)
      }
    }
  }

  private func trace(_ message: String) {
    log("[trace] \(message)")
  }

  private func threadLabel() -> String {
    Thread.isMainThread ? "main" : "bg"
  }

  private func log(_ message: String) {
    let ts = Self.logDateFormatter.string(from: Date())
    let formatted = "[\(ts)][\(threadLabel())] \(message)"
    print(formatted)
    broadcast { $0.onLog(formatted) }
  }
}

extension HussienBleManagerPhase1: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    log("CB didUpdateState state=\(central.state.rawValue) isScanning=\(central.isScanning)")
    if central.state == .poweredOn,
       let saved = ConnectionPreferences.lastPeripheralUUID,
       let restored = central.retrievePeripherals(withIdentifiers: [saved]).first {
      restored.delegate = self
      peripheral = restored
      connectionState = .connecting(peripheralName: restored.name ?? "Scooter")
      log("Restoring connection to \(saved)")
      central.connect(restored, options: nil)
    }
  }

  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    log("CB willRestoreState keys=\(Array(dict.keys))")
    if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
       let first = peripherals.first {
      first.delegate = self
      peripheral = first
      log("State restored with peripheral \(first.identifier)")
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let advertisedName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
    let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
    let manufacturerHex = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)
      .map { $0.hexString.uppercased() } ?? ""

    guard isScooterCandidate(name: advertisedName, services: advertisedServices, manufacturerHex: manufacturerHex) else { return }

    let model = resolveScooterModel(name: advertisedName, services: advertisedServices, manufacturerHex: manufacturerHex)
    let label = displayName(advertisedName: advertisedName, peripheralName: peripheral.name, model: model)
    let preferredService = advertisedServices.first(where: { service in
      scooterServiceUUIDs.contains(where: { $0.uuidString.caseInsensitiveCompare(service.uuidString) == .orderedSame })
    })
    let id = peripheral.identifier
    let device = BridgeScannedDevice(
      id: id,
      name: label,
      rssi: RSSI.intValue,
      peripheral: peripheral,
      manufacturerHex: manufacturerHex,
      model: model ?? "unknown",
      preferredServiceUUID: preferredService
    )
    discoveredByID[id] = device
    log("CB didDiscover name=\(label) id=\(id.uuidString) rssi=\(RSSI.intValue) model=\(device.model) services=\(advertisedServices.map(\.uuidString).joined(separator: ",")) mfg=\(manufacturerHex)")
    broadcast { $0.onScanResultsChanged(self.currentDevices()) }
  }

  private func isScooterCandidate(name: String?, services: [CBUUID], manufacturerHex: String) -> Bool {
    if resolveScooterModel(name: name, services: services, manufacturerHex: manufacturerHex) != nil {
      return true
    }
    return false
  }

  private func matchesScooterService(_ services: [CBUUID]) -> Bool {
    services.contains(where: { service in
      scooterServiceUUIDs.contains(where: { $0.uuidString.caseInsensitiveCompare(service.uuidString) == .orderedSame })
    })
  }

  private func resolveScooterModel(name: String?, services: [CBUUID], manufacturerHex: String) -> String? {
    let normalizedHex = manufacturerHex.uppercased()
    for (signature, model) in knownAdvertisementSignatures where normalizedHex.contains(signature) {
      return model
    }

    if matchesScooterService(services) {
      return "S26"
    }

    let normalizedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalizedName.contains("cardoo") || normalizedName.hasPrefix("ox1") || normalizedName.hasPrefix("ox2") || normalizedName.hasPrefix("ox3") {
      return "SCOOTER"
    }
    return nil
  }

  private func displayName(advertisedName: String?, peripheralName: String?, model: String?) -> String {
    let adv = advertisedName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    if let adv, adv.caseInsensitiveCompare("unknown") != .orderedSame {
      return adv
    }
    let per = peripheralName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    if let per, per.caseInsensitiveCompare("unknown") != .orderedSame {
      return per
    }
    if let model {
      return "cardoO \(model)"
    }
    return "Scooter"
  }

  private func isKnownScooterService(_ uuid: CBUUID) -> Bool {
    scooterServiceUUIDs.contains(where: { $0.uuidString.caseInsensitiveCompare(uuid.uuidString) == .orderedSame })
  }

  private func finalizeConnectionIfReady(_ peripheral: CBPeripheral) {
    trace("finalizeConnectionIfReady writeReady=\(writeChar != nil) notifyCharReady=\(notifyChar != nil) notifyEnabled=\(notifyReady) authSent=\(connectAuthSent)")
    guard writeChar != nil, notifyChar != nil, notifyReady else { return }
    if case .connected = connectionState {
      if !connectAuthSent {
        connectAuthSent = true
        writeConnectAuth()
      }
      return
    }
    connectionState = .connected(peripheralName: peripheral.name ?? "Scooter")
    if !connectAuthSent {
      connectAuthSent = true
      writeConnectAuth()
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    log("CB didConnect name=\(peripheral.name ?? "?") id=\(peripheral.identifier.uuidString)")
    ConnectionPreferences.lastPeripheralUUID = peripheral.identifier
    if let expectedServiceUUID {
      peripheral.discoverServices([expectedServiceUUID])
      log("discoverServices expected=\(expectedServiceUUID.uuidString)")
    } else {
      peripheral.discoverServices(nil)
      log("discoverServices all")
    }
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    log("CB didFailToConnect id=\(peripheral.identifier.uuidString) error=\(error?.localizedDescription ?? "?")")
    writeChar = nil
    notifyChar = nil
    notifyReady = false
    connectAuthSent = false
    authAttemptIndex = 0
    waitingForProtocolRx = false
    connectionState = .idle
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    log("CB didDisconnect id=\(peripheral.identifier.uuidString) error=\(error?.localizedDescription ?? "clean")")
    writeChar = nil
    notifyChar = nil
    notifyReady = false
    connectAuthSent = false
    authAttemptIndex = 0
    waitingForProtocolRx = false
    expectedServiceUUID = nil
    telemetry = BridgeHeartbeatTelemetry()
    connectionState = .idle
  }
}

extension HussienBleManagerPhase1: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error {
      log("Service discovery error: \(error)")
      return
    }
    log("CB didDiscoverServices peripheral=\(peripheral.identifier.uuidString) count=\(peripheral.services?.count ?? 0)")
    for service in peripheral.services ?? [] {
      log("service=\(service.uuid.uuidString)")
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    if let error {
      log("Characteristic discovery error: \(error)")
      return
    }

    guard expectedServiceUUID == nil || service.uuid == expectedServiceUUID || isKnownScooterService(service.uuid) else {
      return
    }

    for characteristic in service.characteristics ?? [] {
      log("CB didDiscoverCharacteristics peripheral=\(peripheral.identifier.uuidString) service=\(service.uuid.uuidString) char=\(characteristic.uuid.uuidString) props=\(characteristic.properties.rawValue)")
      if characteristic.uuid == writeCharUUID {
        writeChar = characteristic
      } else if writeChar == nil && (characteristic.properties.contains(.writeWithoutResponse) || characteristic.properties.contains(.write)) {
        writeChar = characteristic
        log("fallback write characteristic selected uuid=\(characteristic.uuid.uuidString)")
      } else if characteristic.uuid == notifyCharUUID {
        notifyChar = characteristic
        notifyReady = characteristic.isNotifying
        peripheral.setNotifyValue(true, for: characteristic)
      } else if notifyChar == nil && (characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)) {
        notifyChar = characteristic
        notifyReady = characteristic.isNotifying
        log("fallback notify characteristic selected uuid=\(characteristic.uuid.uuidString)")
        peripheral.setNotifyValue(true, for: characteristic)
      }
    }

    finalizeConnectionIfReady(peripheral)
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
    if let error {
      log("CB didUpdateNotificationState ERROR peripheral=\(peripheral.identifier.uuidString) uuid=\(characteristic.uuid.uuidString): \(error.localizedDescription)")
      return
    }
    log("CB didUpdateNotificationState peripheral=\(peripheral.identifier.uuidString) uuid=\(characteristic.uuid.uuidString) enabled=\(characteristic.isNotifying)")
    if notifyChar?.uuid == characteristic.uuid {
      notifyReady = characteristic.isNotifying
      finalizeConnectionIfReady(peripheral)
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    if let error {
      log("CB didUpdateValue ERROR peripheral=\(peripheral.identifier.uuidString) uuid=\(characteristic.uuid.uuidString) error=\(error.localizedDescription)")
      return
    }
    guard notifyChar?.uuid == characteristic.uuid, let data = characteristic.value else { return }
    handleNotification(data)
  }

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    if let error {
      log("CB didWriteValue ERROR peripheral=\(peripheral.identifier.uuidString) uuid=\(characteristic.uuid.uuidString) error=\(error)")
    } else {
      log("CB didWriteValue OK peripheral=\(peripheral.identifier.uuidString) uuid=\(characteristic.uuid.uuidString)")
    }
  }
}

private extension Data {
  var hexString: String {
    map { String(format: "%02x", $0) }.joined()
  }
}

private extension String {
  var nonEmpty: String? { isEmpty ? nil : self }
}

