import SwiftUI

struct StatusSection: View {
    let connectionState: BleConnectionState
    let scannedDevices: [ScannedDevice]
    let telemetry: HeartbeatTelemetry
    let onSelect: (ScannedDevice) -> Void

    var body: some View {
        SectionPanel(title: statusTitle) {
            switch connectionState {
            case .idle, .disconnecting:
                Text("Not connected. Tap Scan to find nearby scooters.")
                    .font(.system(size: 13))
                    .foregroundColor(CardooTheme.muted)
            case .scanning, .connecting:
                if scannedDevices.isEmpty {
                    Text("Scanning…")
                        .font(.system(size: 13))
                        .foregroundColor(CardooTheme.muted)
                } else {
                    deviceList
                }
            case .connected:
                HeartbeatGrid(telemetry: telemetry)
            }
        }
    }

    private var statusTitle: String {
        switch connectionState {
        case .connected: return "Heartbeat"
        case .scanning, .connecting: return "Discovered devices"
        default: return "Status"
        }
    }

    private var deviceList: some View {
        VStack(spacing: 6) {
            ForEach(scannedDevices) { device in
                Button { onSelect(device) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name).font(.system(size: 14, weight: .semibold))
                            Text(device.id.uuidString)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(CardooTheme.muted)
                        }
                        Spacer()
                        Text("\(device.rssi) dBm")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(CardooTheme.muted)
                    }
                    .padding(10)
                    .background(CardooTheme.surface)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct HeartbeatGrid: View {
    let telemetry: HeartbeatTelemetry

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            cell("Battery", "\(telemetry.batteryPercent)%")
            cell("Voltage", String(format: "%.1f V", telemetry.batteryVoltage))
            cell("Speed", String(format: "%.1f km/h", telemetry.realtimeSpeedKmh))
            cell("Gear", "\(telemetry.gear)")
            cell("Lock", telemetry.lockStatus ? "LOCKED" : "Unlocked")
            cell("Headlight", telemetry.headlightOn ? "On" : "Off")
            cell("Cruise fn", telemetry.cruiseControlEnabled ? "Enabled" : "Off")
            cell("Cruise active", telemetry.cruiseActive ? "Yes" : "No")
            cell("Charging", telemetry.charging ? "Yes" : "No")
            cell("Motor", telemetry.motorRunning ? "Running" : "Stopped")
            cell("Units", telemetry.metricKm ? "km" : "mile")
            cell("Faults", telemetry.anyFaultActive ? "Active" : "None")
        }
    }

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(CardooTheme.muted)
            Text(value).font(.system(size: 14, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(CardooTheme.surface)
        .cornerRadius(8)
    }
}
