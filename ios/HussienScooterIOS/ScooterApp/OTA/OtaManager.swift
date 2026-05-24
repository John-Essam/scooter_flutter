import Foundation

/// Drives the OTA upgrade flow end-to-end. This bypasses the bundled
/// `TCBECCMD.startOTA()` driver because it does not progress past the
/// `TCBE0Model` ready ack on v3 firmware.
///
/// The flow:
/// 1. Split the firmware binary into fixed 128-byte chunks.
/// 2. Compute a single CRC-32/MPEG-2 over the whole image (padded with `0xFF`
///    to a 4-byte multiple).
/// 3. Drive `E0 → E1×N → E2` frames manually with a 10-retry-per-chunk budget.
/// 4. Offset the protocol-side chunk index per target: `0` for Controller,
///    `+1` for Meter. Wrong offset causes silent NAKs.
///
/// The SDK is still used to **parse** the `TCBE0/E1/E2Model` responses; the
/// `BleManager` forwards those into `handleReadyAck`/`handleDataAck`/`handleCrcAck`.
final class OtaManager {
    private let send: (_ frame: Data, _ label: String) -> Void
    private let onState: (OtaState) -> Void
    private let onProgress: (_ percent: Int) -> Void
    private let onPreview: (OtaPreview?) -> Void
    private let onLog: (String) -> Void

    private var session: OtaSession?

    var isInProgress: Bool { session != nil }

    init(send: @escaping (_ frame: Data, _ label: String) -> Void,
         onState: @escaping (OtaState) -> Void,
         onProgress: @escaping (_ percent: Int) -> Void,
         onPreview: @escaping (OtaPreview?) -> Void = { _ in },
         onLog: @escaping (String) -> Void = { _ in }) {
        self.send = send
        self.onState = onState
        self.onProgress = onProgress
        self.onPreview = onPreview
        self.onLog = onLog
    }

    // MARK: - Lifecycle

    /// Returns false if an OTA is already in flight or the binary is empty.
    @discardableResult
    func start(fileBytes: Data, target: OtaTarget, sourceLabel: String) -> Bool {
        if isInProgress {
            onLog("OTA already in progress; ignoring new \(target.displayName) upload request.")
            return false
        }
        if fileBytes.isEmpty {
            update(.failed(reason: "Empty firmware file."))
            return false
        }
        update(.preparing)

        let crc32Bytes = TcbCrc32.generate(fileBytes)
        let crc32Hex = "0x" + crc32Bytes.map { String(format: "%02X", $0) }.joined()
        let chunks = OtaChunkPlanner.splitIntoChunks(fileBytes)

        let preview = OtaPreview(sourceLabel: sourceLabel,
                                 sizeBytes: fileBytes.count,
                                 crc32Hex: crc32Hex,
                                 target: target)
        onPreview(preview)
        session = OtaSession(target: target,
                             chunks: chunks,
                             crc32Bytes: crc32Bytes,
                             crc32Hex: crc32Hex,
                             sourceLabel: sourceLabel,
                             totalBytes: fileBytes.count)

        onLog("OTA start: \(sourceLabel) (\(fileBytes.count) bytes, \(chunks.count) chunks, crc32=\(crc32Hex)) -> \(target.displayName)")
        update(.waitingReady)
        sendReadyRequest(target: target)
        return true
    }

    func cancel() {
        guard session != nil else { return }
        session = nil
        onPreview(nil)
        update(.cancelled)
    }

    /// Called by `BleManager` on any BLE disconnect.
    func onDisconnect() {
        guard session != nil else { return }
        session = nil
        onPreview(nil)
        update(.cancelled)
    }

    // MARK: - ACK handlers (called by BleManager from the notify channel)

    func handleReadyAck(ready: Bool) {
        guard let s = session else { return }
        if !ready { fail("Device reported NOT READY for OTA."); return }
        s.nextChunkIndex = 0
        s.retryCount = 0
        update(.sending(sent: 0, total: s.totalChunks))
        sendCurrentChunk(s)
    }

    func handleDataAck(accepted: Bool, index: Int) {
        guard let s = session else { return }
        if accepted {
            proceedToNextChunk(s)
        } else {
            attemptRetry(s, reason: "Chunk NAK at index \(index)") { self.sendCurrentChunk(s) }
        }
    }

    func handleCrcAck(success: Bool) {
        guard let s = session else { return }
        if success {
            completeOta()
        } else {
            attemptRetry(s, reason: "CRC32 mismatch") { self.sendCrc32(s) }
        }
    }

    // MARK: - Private

    private func proceedToNextChunk(_ s: OtaSession) {
        s.nextChunkIndex += 1
        s.retryCount = 0
        if s.nextChunkIndex >= s.totalChunks {
            update(.verifying)
            onProgress(100)
            sendCrc32(s)
            return
        }
        let sent = s.nextChunkIndex
        let percent = max(0, min(99, Int(Double(sent) / Double(s.totalChunks) * 100)))
        onProgress(percent)
        update(.sending(sent: sent, total: s.totalChunks))
        sendCurrentChunk(s)
    }

    private func attemptRetry(_ s: OtaSession, reason: String, action: () -> Void) {
        if s.retryCount < Self.maxRetries {
            s.retryCount += 1
            onLog("OTA retry \(s.retryCount)/\(Self.maxRetries): \(reason)")
            action()
        } else {
            fail("\(reason) — gave up after \(Self.maxRetries) attempts.")
        }
    }

    private func completeOta() {
        onLog("OTA complete.")
        session = nil
        onProgress(100)
        update(.completed)
    }

    private func sendReadyRequest(target: OtaTarget) {
        guard let frame = TcbFrameBuilder.build(addr: target.address, functionCode: Self.fnReady) else {
            fail("Failed to build E0 frame.")
            return
        }
        send(frame, "TX OTA E0 \(target.displayName.lowercased()) ready")
    }

    private func sendCurrentChunk(_ s: OtaSession) {
        if s.nextChunkIndex >= s.totalChunks {
            update(.verifying)
            sendCrc32(s)
            return
        }
        // Critical: meter starts the protocol index at 1, controller at 0.
        // Wrong offset is the v3 firmware silent-drop trap.
        let protocolIndex: Int
        switch s.target {
        case .meter:      protocolIndex = s.nextChunkIndex + 1
        case .controller: protocolIndex = s.nextChunkIndex
        }
        let chunk = s.chunks[s.nextChunkIndex]
        var payload: [UInt8] = [
            UInt8((protocolIndex >> 8) & 0xFF),
            UInt8(protocolIndex & 0xFF),
        ]
        payload.append(contentsOf: chunk)
        guard let frame = TcbFrameBuilder.build(addr: s.target.address,
                                                functionCode: Self.fnData,
                                                payload: payload) else {
            fail("Failed to build E1 frame.")
            return
        }
        send(frame, "TX OTA E1 \(s.target.displayName.lowercased()) chunk \(s.nextChunkIndex + 1)/\(s.totalChunks) (proto=\(protocolIndex))")
    }

    private func sendCrc32(_ s: OtaSession) {
        guard let frame = TcbFrameBuilder.build(addr: s.target.address,
                                                functionCode: Self.fnCrc,
                                                payload: s.crc32Bytes) else {
            fail("Failed to build E2 frame.")
            return
        }
        send(frame, "TX OTA E2 \(s.target.displayName.lowercased()) crc32=\(s.crc32Hex)")
    }

    private func update(_ state: OtaState) {
        onState(state)
    }

    private func fail(_ reason: String) {
        onLog("OTA failed: \(reason)")
        session = nil
        onPreview(nil)
        update(.failed(reason: reason))
    }

    // MARK: - Constants

    private static let maxRetries = 10
    private static let fnReady: UInt8 = 0xE0
    private static let fnData:  UInt8 = 0xE1
    private static let fnCrc:   UInt8 = 0xE2
}
