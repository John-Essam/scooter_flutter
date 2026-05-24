import Foundation
import TCBleComminucation

/// Hand-built `5A | addr | funcLow | funcHigh | length | payload | crc16` frames for the
/// 14 v3 functions that the bundled SDK either doesn't expose or whose builder is too
/// narrow (see `ScooterApp/docs/android-customized-frames.md`). CRC-16 reuses the SDK's
/// `TCBCRCManager.crc16Value(by:)` so the bytes match what the firmware verifies.
enum TcbFrameBuilder {

    /// `funcHigh` follows the v3 firmware convention: for most functions, `0x00` (per the
    /// protocol doc); for the handful of functions that v3 only accepts in mirror framing,
    /// callers pass the function code as the high byte too.
    static func build(addr: UInt8,
                      functionCode: UInt8,
                      payload: [UInt8] = [],
                      mirror: Bool = false) -> Data? {
        var bytes: [UInt8] = [0x5A, addr, functionCode]
        bytes.append(mirror ? functionCode : 0x00)
        bytes.append(UInt8(payload.count))
        bytes.append(contentsOf: payload)
        guard let crc = try? TCBCRCManager.crc16Value(by: bytes) else { return nil }
        bytes.append(UInt8((crc >> 8) & 0xFF))
        bytes.append(UInt8(crc & 0xFF))
        return Data(bytes)
    }

    /// Encodes a 6-digit numeric password as ASCII bytes (0x30…0x39). Matches the Android
    /// implementation; pads short input with leading '0' so a 6-digit frame always goes out.
    static func passwordAscii(_ pw: String) -> [UInt8]? {
        let digits = pw.filter(\.isWholeNumber)
        guard !digits.isEmpty, digits.count <= 6 else { return nil }
        let padded = String(repeating: "0", count: 6 - digits.count) + digits
        return padded.map { UInt8($0.asciiValue ?? 0x30) }
    }
}

extension TcbFrameBuilder {

    /// Common header addresses observed in the protocol doc + Android source:
    /// `controllerRead = 0x01`, `controllerWrite = 0x21`, `meterWrite = 0x23`.
    enum Addr {
        static let controllerRead: UInt8  = 0x01
        static let controllerWrite: UInt8 = 0x21
        static let meterRead: UInt8       = 0x03
        static let meterWrite: UInt8      = 0x23
    }
}
