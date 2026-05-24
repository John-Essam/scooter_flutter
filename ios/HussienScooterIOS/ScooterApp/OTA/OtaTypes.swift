import Foundation

/// Which slave the OTA targets. The address used here is the write-with-reply
/// address for the OTA channel — controller `0x21`, meter `0x23`.
enum OtaTarget: Equatable {
    case controller
    case meter

    var address: UInt8 {
        switch self {
        case .controller: return 0x21
        case .meter:      return 0x23
        }
    }

    var displayName: String {
        switch self {
        case .controller: return "Controller"
        case .meter:      return "Meter"
        }
    }
}

/// Lifecycle state of a single OTA session. `Sending` carries chunk progress;
/// `Failed` carries a human-readable reason. Mirrors Android's sealed interface.
enum OtaState: Equatable {
    case idle
    case preparing
    case waitingReady
    case sending(sent: Int, total: Int)
    case verifying
    case completed
    case failed(reason: String)
    case cancelled
}

/// Snapshot of the firmware payload the OTA flow is about to send.
struct OtaPreview: Equatable {
    let sourceLabel: String
    let sizeBytes: Int
    let crc32Hex: String
    let target: OtaTarget
}

/// In-flight session state. Mutable index/retry counters live here; the
/// `OtaManager` owns the only reference.
final class OtaSession {
    let target: OtaTarget
    let chunks: [[UInt8]]
    let crc32Bytes: [UInt8]
    let crc32Hex: String
    let sourceLabel: String
    let totalBytes: Int
    var nextChunkIndex: Int = 0
    var retryCount: Int = 0

    init(target: OtaTarget,
         chunks: [[UInt8]],
         crc32Bytes: [UInt8],
         crc32Hex: String,
         sourceLabel: String,
         totalBytes: Int) {
        self.target = target
        self.chunks = chunks
        self.crc32Bytes = crc32Bytes
        self.crc32Hex = crc32Hex
        self.sourceLabel = sourceLabel
        self.totalBytes = totalBytes
    }

    var totalChunks: Int { chunks.count }
}

/// Splits a firmware binary into the fixed-size data chunks the `0xE1` frame
/// carries. **128 bytes per chunk** is what the v3 controller and meter both
/// accept — different chunk sizes get silently NAK'd.
enum OtaChunkPlanner {
    static let defaultChunkSize = 128

    static func splitIntoChunks(_ data: Data, chunkSize: Int = defaultChunkSize) -> [[UInt8]] {
        precondition(chunkSize > 0)
        var chunks: [[UInt8]] = []
        chunks.reserveCapacity((data.count + chunkSize - 1) / chunkSize)
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            chunks.append(Array(data[offset..<end]))
            offset = end
        }
        return chunks
    }
}
