import Foundation

protocol BleEventListener: AnyObject {
    func onConnectionStateChanged(_ state: BleConnectionState)
    func onScanResultsChanged(_ devices: [ScannedDevice])
    func onHeartbeatUpdated(_ telemetry: HeartbeatTelemetry)
    func onOtaStateChanged(_ state: OtaState)
    func onOtaProgressChanged(_ percent: Int)
    func onOtaPreviewChanged(_ preview: OtaPreview?)
    func onLog(_ message: String)
}

extension BleEventListener {
    func onConnectionStateChanged(_ state: BleConnectionState) {}
    func onScanResultsChanged(_ devices: [ScannedDevice]) {}
    func onHeartbeatUpdated(_ telemetry: HeartbeatTelemetry) {}
    func onOtaStateChanged(_ state: OtaState) {}
    func onOtaProgressChanged(_ percent: Int) {}
    func onOtaPreviewChanged(_ preview: OtaPreview?) {}
    func onLog(_ message: String) {}
}
