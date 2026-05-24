import Foundation
import CoreBluetooth

enum BleConnectionState: Equatable {
    case idle
    case scanning
    case connecting(peripheralName: String)
    case connected(peripheralName: String)
    case disconnecting
}

struct ScannedDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
    let manufacturerHex: String

    static func == (lhs: ScannedDevice, rhs: ScannedDevice) -> Bool {
        lhs.id == rhs.id && lhs.rssi == rhs.rssi
    }
}

struct HeartbeatTelemetry: Equatable {
    var batteryPercent: Int = 0
    var batteryVoltage: Double = 0
    var realtimeSpeedKmh: Double = 0
    var gear: Int = 0
    var lockStatus: Bool = false
    var headlightOn: Bool = false
    var cruiseControlEnabled: Bool = false
    var cruiseActive: Bool = false
    var charging: Bool = false
    var motorRunning: Bool = false
    var electronicBrake: Bool = false
    var mechanicalBrake: Bool = false
    var metricKm: Bool = true
    var lastUpdated: Date = .distantPast
    var anyFaultActive: Bool = false
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let text: String
}
