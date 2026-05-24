import Foundation
import CoreBluetooth
import TCBleComminucation

final class BleManager: NSObject {
    static let shared = BleManager()

    private let restoreIdentifier = "cardoo.scooter.central"
    private let scooterServiceUUIDs: [CBUUID] = [
        CBUUID(string: "54430011-0153-3236-FFFF-FFFFFFFBFFFF"),
        CBUUID(string: "54430011-0153-3239-FFFF-FFFFFFF7FFFF"),
    ]
    private let writeCharUUID = CBUUID(string: TCBConstant.uuidWrite)
    private let notifyCharUUID = CBUUID(string: TCBConstant.uuidNotify)

    // Bind userID mirrors the Android client (TCB02CMD.writeConnect(5)). The scooter
    // emits the "paired" tone only when the writeConnect frame carries a non-zero
    // userID after the notify subscription has settled.
    private let bindUserID: UInt32 = 5

    // Manufacturer-data hex patterns lifted from the Android `resolveModelHint` logic
    // (BleManager.kt:1581). When the scooter is in advertising mode it broadcasts one of
    // these patterns embedded in the manufacturer-data field; matching here keeps the
    // device list clean instead of showing every BLE accessory in the room.
    //
    // The list is intentionally strict — many cheap BLE accessories use the reserved
    // 0xFFFF company ID, so we require either a fully-specified 16-byte signature
    // (S26 / S29) or a leading 6-byte prefix that the cardoO firmware actually emits
    // (`FFFFF7…` or `FFFFFB…` followed by a model byte). Bare 4-byte patterns
    // (`FFFFFB31` / `FFFFFB32`) were dropped because they false-positive on too many
    // unrelated devices in the wild.
    private let scooterAdMatches: [String] = [
        "FFFFFBFFFFFFFFFF3632530111004354", // S26 exact
        "FFFFF7FFFFFFFFFF3932530111004354", // S29 exact
        "FFFFF7FFFFFF",                     // cardoO-F7 prefix
        "FFFFFBFFFFFF",                     // cardoO-FB prefix
    ]
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?
    private var discoveredByID: [UUID: ScannedDevice] = [:]
    private var listeners = NSHashTable<AnyObject>.weakObjects()

    private(set) var connectionState: BleConnectionState = .idle {
        didSet { broadcast { $0.onConnectionStateChanged(self.connectionState) } }
    }
    private(set) var telemetry = HeartbeatTelemetry() {
        didSet { broadcast { $0.onHeartbeatUpdated(self.telemetry) } }
    }
    private(set) var otaState: OtaState = .idle {
        didSet { broadcast { $0.onOtaStateChanged(self.otaState) } }
    }
    private(set) var otaProgress: Int = 0 {
        didSet { broadcast { $0.onOtaProgressChanged(self.otaProgress) } }
    }
    private(set) var otaPreview: OtaPreview? {
        didSet { broadcast { $0.onOtaPreviewChanged(self.otaPreview) } }
    }

    private lazy var ota: OtaManager = OtaManager(
        send: { [weak self] frame, label in self?.send(frame, label: label) },
        onState: { [weak self] state in self?.otaState = state },
        onProgress: { [weak self] pct in self?.otaProgress = pct },
        onPreview: { [weak self] preview in self?.otaPreview = preview },
        onLog: { [weak self] msg in self?.log(msg) }
    )

    // MARK: - Lifecycle

    override init() {
        super.init()
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
        listener.onOtaStateChanged(otaState)
        listener.onOtaProgressChanged(otaProgress)
        listener.onOtaPreviewChanged(otaPreview)
    }

    func removeListener(_ listener: BleEventListener) {
        listeners.remove(listener)
    }

    // MARK: - Scan / Connect

    func startScan() {
        guard central.state == .poweredOn else {
            log("Bluetooth not ready (state=\(central.state.rawValue)). Cannot scan.")
            return
        }
        if central.isScanning { central.stopScan() }
        discoveredByID.removeAll()
        broadcast { $0.onScanResultsChanged([]) }
        connectionState = .scanning
        log("TX scan start")
        // Pass nil to also find peripherals that don't advertise the service in the primary
        // advertisement packet (some v3 units only advertise the service in the scan response).
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false,
        ])
    }

    func stopScan() {
        if central.isScanning { central.stopScan() }
        if case .scanning = connectionState { connectionState = .idle }
        log("scan stopped")
    }

    func connect(to device: ScannedDevice) {
        if central.isScanning { central.stopScan() }
        peripheral = device.peripheral
        device.peripheral.delegate = self
        connectionState = .connecting(peripheralName: device.name)
        log("TX connect \(device.name) [\(device.id)]")
        central.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        guard let p = peripheral else { return }
        ConnectionPreferences.lastPeripheralUUID = nil
        connectionState = .disconnecting
        log("TX disconnect")
        central.cancelPeripheralConnection(p)
    }

    func unbind() {
        guard let _ = writeChar, let _ = peripheral else {
            log("Cannot unbind: not connected.")
            return
        }
        // Android TCB02CMD.readUnbind() = "5a23020006004000000000" + CRC
        // = writeConnect(on: false, userID: 0) frame via meterWrite (0x23).
        // iOS SDK readUnbind() wrongly uses meterRead (0x03) with only 2 payload bytes.
        sendManuallyAndroidDefault(label: "TX unbind") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.meterWrite,
                functionCode: 0x02,
                payload: [0x00, 0x40, 0x00, 0x00, 0x00, 0x00]
            )
        }
        ConnectionPreferences.lastPeripheralUUID = nil
    }

    // MARK: - Auth / lock

    private func writeConnectAuth() {
        // The 300ms delay mirrors Android's handshake — sending writeConnect immediately
        // after setNotifyValue races the firmware's notify-ready state and the bind tone
        // never plays. userID = 5 matches Android (TCB02CMD.writeConnect(5)).
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) { [weak self] in
            guard let self else { return }
            do {
                let data = try TCB02Command.writeConnect(on: true, userID: self.bindUserID)
                self.send(data, label: "TX writeConnect (bind userID=\(self.bindUserID))")
            } catch {
                self.log("writeConnect failed: \(error)")
            }
        }
    }

    func setLocked(_ locked: Bool) {
        // Android TCB02CMD.writeLockStatus: "5a23020202" + [01/00] + "01" + CRC
        // = meterWrite (0x23), mirror framing (byte[3]=0x02).
        // iOS SDK writeLockStatus uses byte[3]=0x00 — wrong.
        let value: UInt8 = locked ? 0x01 : 0x00
        sendManuallyAndroidDefault(label: locked ? "TX lock" : "TX unlock") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.meterWrite,
                functionCode: 0x02,
                payload: [value, 0x01],
                mirror: true
            )
        }
    }

    // MARK: - Cruise / Unit / Start mode (TCB02)

    func setCruiseControl(_ enabled: Bool) {
        // Android TCB02CMD.writeCruiseControlFunction: "5a23020202" + [04/00] + "04" + CRC
        // = meterWrite (0x23), mirror framing. iOS SDK uses byte[3]=0x00 — wrong.
        let value: UInt8 = enabled ? 0x04 : 0x00
        sendManuallyAndroidDefault(label: enabled ? "TX cruise enable" : "TX cruise disable") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.meterWrite,
                functionCode: 0x02,
                payload: [value, 0x04],
                mirror: true
            )
        }
    }

    func setUnitSystem(kilometers: Bool) {
        // Android TCB02CMD.writeMetricMileSystemTheme: "5a23020202" + [00/80] + "80" + CRC
        // = meterWrite (0x23), mirror framing. iOS SDK uses byte[3]=0x00 — wrong.
        let value: UInt8 = kilometers ? 0x00 : 0x80
        sendManuallyAndroidDefault(label: kilometers ? "TX unit km" : "TX unit mile") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.meterWrite,
                functionCode: 0x02,
                payload: [value, 0x80],
                mirror: true
            )
        }
    }

    func setStartMode(zeroStart: Bool) {
        // Android BleManager builds this manually: "5a23020202" + [00/02] + "02" + CRC
        // = meterWrite (0x23), mirror framing. iOS SDK uses byte[3]=0x00 — wrong.
        let value: UInt8 = zeroStart ? 0x00 : 0x02
        sendManual(label: zeroStart ? "TX zero-start mode" : "TX kick-start mode") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.meterWrite,
                functionCode: 0x02,
                payload: [value, 0x02],
                mirror: true
            )
        }
    }

    // MARK: - Gear (TCB05)

    func setGear(_ gear: Int) {
        // Android TCB05CMD.writeGear: "5a230505022[gear]00" + CRC
        // = meterWrite (0x23), mirror framing (byte[3]=0x05), mask 0x20|gear.
        // iOS SDK uses byte[3]=0x00 — wrong.
        sendManuallyAndroidDefault(label: "TX gear \(gear)") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.meterWrite,
                functionCode: 0x05,
                payload: [0x20 | UInt8(gear & 0x03), 0x00],
                mirror: true
            )
        }
    }

    func readGlobalMaxSpeed() {
        // Android TCB05CMD.readMaxSpeed: "5a010500020000" + CRC
        // = controllerRead (0x01), no mirror. iOS SDK matches — kept for clarity.
        sendSDK(label: "TX read global max speed") { try TCB05Command.readMaxSpeed() }
    }

    func readGearMaxSpeed(gear: Int) {
        // Android TCB05CMD.readGearMaxSpeed: "5a010500021[8+gear]00" + CRC
        // = controllerRead (0x01), mask 0x18|gear. iOS SDK matches exactly.
        sendSDK(label: "TX read gear \(gear) max speed") { try TCB05Command.readGearMaxSpeed(gear: gear) }
    }

    func writeGearMaxSpeed(gear: Int, speed: Int) {
        // Android TCB05CMD.writeGearMaxSpeed: "5a2105000218[speed]" + CRC
        // = controllerWrite (0x21), mask 0x18|gear. iOS SDK matches exactly.
        sendSDK(label: "TX write gear \(gear) max speed \(speed) km/h") {
            try TCB05Command.writeGearMaxSpeed(gear: gear, speed: speed)
        }
    }

    /// Applies a 4-gear max-speed profile (G0..G3). Writes are spaced 1.5s apart so the
    /// controller has time to commit each, then re-reads each gear ~4.5s after the last
    /// write at 0.5s spacing so the user can see what stuck. v3 firmware silently keeps
    /// the old values on these writes (issue #7) — UI ships anyway for protocol parity.
    func applyGearProfile(_ speeds: [Int]) {
        precondition(speeds.count == 4, "applyGearProfile expects 4 entries (G0..G3)")
        let clamped = speeds.map { max(Self.gearMaxSpeedMin, min(Self.gearMaxSpeedMax, $0)) }
        log("Gear profile queued: \(clamped.map(String.init).joined(separator: "/")) km/h")
        for (gear, speed) in clamped.enumerated() {
            let delay = DispatchTimeInterval.milliseconds(gear * Self.gearProfileWriteSpacingMs)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.writeGearMaxSpeed(gear: gear, speed: speed)
            }
        }
        let readbackStart = clamped.count * Self.gearProfileWriteSpacingMs + Self.gearProfileReadbackDelayMs
        log("Gear profile readback in \(readbackStart / 1000) s")
        for gear in clamped.indices {
            let delayMs = readbackStart + gear * Self.gearProfileReadbackSpacingMs
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) { [weak self] in
                self?.readGearMaxSpeed(gear: gear)
            }
        }
    }

    func applySportProfile()  { applyGearProfile(Self.sportProfile) }
    func applyEcoProfile()    { applyGearProfile(Self.ecoProfile) }

    // Gear-profile constants — ported from Android `BleManager.kt:1836`.
    private static let gearMaxSpeedMin = 0
    private static let gearMaxSpeedMax = 50
    private static let gearProfileWriteSpacingMs = 1500
    private static let gearProfileReadbackDelayMs = 4500
    private static let gearProfileReadbackSpacingMs = 500
    static let sportProfile = [10, 15, 30, 45]
    static let ecoProfile   = [6, 6, 12, 20]

    // MARK: - NFC (TCB03)

    func readNfcStatus() {
        // Android TCB03CMD.readNfcStatus: "5a030300020010" + CRC
        // = meterRead (0x03), length=2. iOS SDK wrongly emits length=0x00.
        sendManuallyAndroidDefault(label: "TX read NFC status") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.meterRead,
                functionCode: 0x03,
                payload: [0x00, 0x10]
            )
        }
    }

    func setNfc(enabled: Bool) {
        // Android TCB03CMD.writeNfcStatus: "5a23030002" + [10/00] + "10" + CRC
        // = meterWrite (0x23), length=2. iOS SDK wrongly uses meterRead (0x03) with length=0.
        let value: UInt8 = enabled ? 0x10 : 0x00
        sendManuallyAndroidDefault(label: enabled ? "TX NFC enable" : "TX NFC disable") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.meterWrite,
                functionCode: 0x03,
                payload: [value, 0x10]
            )
        }
    }

    // MARK: - Front light / Ambient status (TCB04)

    func setFrontLight(on: Bool) {
        // Android TCB04CMD.writeFrontLightStatus: "5a23040402" + [20/00] + "20" + CRC
        // = meterWrite (0x23), mirror framing (byte[3]=0x04). iOS SDK uses byte[3]=0x00 — wrong.
        let value: UInt8 = on ? 0x20 : 0x00
        sendManuallyAndroidDefault(label: on ? "TX front light on" : "TX front light off") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.meterWrite,
                functionCode: 0x04,
                payload: [value, 0x20],
                mirror: true
            )
        }
    }

    func readAmbientLightStatus() {
        // Android TCB04CMD.readAmbientLightStatus: "5a010400020008" + CRC
        // = controllerRead (0x01), length=2. iOS SDK wrongly uses controllerWrite (0x21).
        sendManuallyAndroidDefault(label: "TX read ambient light status") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerRead,
                functionCode: 0x04,
                payload: [0x00, 0x08]
            )
        }
    }

    func setAmbientLightStatus(on: Bool) {
        sendSDK(label: on ? "TX ambient light on" : "TX ambient light off") {
            try TCB04Command.writeAmbientLightStatus(on)
        }
    }

    // MARK: - Ambient light color & mode (TCB1A)

    func readAmbientLight() {
        sendSDK(label: "TX read ambient light") { try TCB1ACommand.readAmbientLight() }
    }

    /// mode: 1 = monochrome, 2 = breathing, 3 = rainbow.
    /// Mode 4 (running effect) is sent via setAmbientLightRunningEffect.
    func setAmbientLight(mode: Int, red: Int, green: Int, blue: Int) {
        // Android TCB1ACMD.writeAmbientLight: "5a211A0005" + [mode] + [R] + [G] + [B] + "ff" + CRC
        // = controllerWrite (0x21), length=5. iOS SDK emits length=0x00 (cmdDataLength bug) — wrong.
        sendManuallyAndroidDefault(label: "TX ambient mode=\(mode) rgb=\(rgbHex(red, green, blue))") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0x1A,
                payload: [UInt8(mode & 0xFF),
                          UInt8(red & 0xFF), UInt8(green & 0xFF), UInt8(blue & 0xFF),
                          0xFF]
            )
        }
    }

    // MARK: - Mileage (TCB08 / TCB09 / TCB30)

    func readSingleTripMileage() { sendSDK(label: "TX read single-trip mileage") { try TCB08Command.readSingleTripMileage() } }
    func readTotalMileage() { sendSDK(label: "TX read total mileage") { try TCB09Command.readTotalTripMileage() } }
    func readRemainingMileage() {
        // Android TCB30CMD.readRemainingMileage: "5a21300000" + CRC
        // = controllerWrite (0x21), length=0. iOS SDK wrongly uses controllerRead (0x01).
        sendManuallyAndroidDefault(label: "TX read remaining mileage") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0x30
            )
        }
    }

    // MARK: - Temperature (TCB0A) — controller-only via SDK

    func readControllerTemperature() {
        sendSDK(label: "TX read controller temperature") { try TCB0ACommand.readTemp() }
    }

    // MARK: - Driving current realtime (TCB0B)

    func readDrivingCurrentRealtime() {
        sendSDK(label: "TX read realtime current") { try TCB0BCommand.readDrivingCurrent() }
    }

    // MARK: - Versions (TCB11)

    func readMeterVersion() {
        // Android TCB11CMD.readMeterVersion: "5a23111100" + CRC
        // = meterWrite (0x23), mirror framing (byte[3]=0x11), length=0.
        // iOS SDK wrongly uses meterRead (0x03) with byte[3]=0x00.
        sendManuallyAndroidDefault(label: "TX read meter version") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.meterWrite,
                functionCode: 0x11,
                mirror: true
            )
        }
    }

    func readControllerVersion() {
        // Android TCB11CMD.readControllerVersion: "5a21110000" + CRC
        // = controllerWrite (0x21), length=0. iOS SDK wrongly uses controllerRead (0x01).
        sendManuallyAndroidDefault(label: "TX read controller version") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0x11
            )
        }
    }

    // MARK: - Response time (TCB22)

    /// type 0 = throttle, 1 = brake.
    func readResponseTime(type: Int) {
        let label = type == 0 ? "TX read throttle response" : "TX read brake response"
        sendSDK(label: label) { try TCB22Command.readResponseTime(type: type) }
    }

    /// type 0 = throttle, 1 = brake. SDK validates 0..10; out-of-range values go through
    /// the manual frame (mirrors Android's `writeResponseTime(allowCustom: true)`).
    func writeResponseTime(type: Int, value: Int) {
        let kind = type == 0 ? "throttle" : "brake"
        if (0...10).contains(value) {
            sendSDK(label: "TX write \(kind) response \(value)") {
                try TCB22Command.writeResponseTime(type: type, time: value)
            }
        } else {
            sendManual(label: "TX write \(kind) response raw=\(value & 0xFF)") {
                TcbFrameBuilder.build(
                    addr: TcbFrameBuilder.Addr.controllerWrite,
                    functionCode: 0x22,
                    payload: [UInt8(type & 0xFF), UInt8(value & 0xFF)]
                )
            }
        }
    }

    // MARK: - Customized frames (Android customized-frames.md parity)

    /// Function `0x0003` payload `02 02` = factory reset. Bytes lifted directly from the
    /// Android JAR's `TCB03CMD.restoreFactory()` (`5A 21 03 00 02 02 02` + crc16).
    func factoryReset() {
        sendManual(label: "TX factory reset") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0x03,
                payload: [0x02, 0x02]
            )
        }
    }

    /// Function `0x0006` Auto Power-Off. Read = LEN 0, set = LEN 2 (uint16 BE seconds).
    /// 0 disables, max 1800 (30 min). Silent on v3 — issue #5.
    func readAutoPowerOff() {
        sendManual(label: "TX read auto power-off") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0x06
            )
        }
    }
    func writeAutoPowerOff(seconds: Int) {
        let clamped = max(0, min(seconds, 1800))
        let hi = UInt8((clamped >> 8) & 0xFF)
        let lo = UInt8(clamped & 0xFF)
        sendManual(label: "TX set auto power-off \(clamped)s") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0x06,
                payload: [hi, lo]
            )
        }
    }

    /// Function `0x000B` type=1 = driving current limit (SDK only sends type=0).
    func readDrivingCurrentLimit() {
        sendManual(label: "TX read driving current limit") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerRead,
                functionCode: 0x0B,
                payload: [0x01, 0x00, 0x00]
            )
        }
    }

    /// Function `0x000D` battery capacity. type 0 = internal pack, 1 = external pack.
    func readBatteryCapacity(internalPack: Bool) {
        let type: UInt8 = internalPack ? 0x00 : 0x01
        let label = internalPack ? "TX read battery capacity (internal)"
                                 : "TX read battery capacity (external)"
        sendManual(label: label) {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0x0D,
                payload: [type]
            )
        }
    }

    /// Function `0x001D` serial number — 14-byte ASCII response.
    func readSerialNumber() {
        sendManual(label: "TX read serial number") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerRead,
                functionCode: 0x1D
            )
        }
    }

    /// Function `0x001E` detailed device info — variable-length ASCII underscore-separated.
    func readDetailedDeviceInfo() {
        sendManual(label: "TX read detailed device info") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerRead,
                functionCode: 0x1E
            )
        }
    }

    /// Function `0x0032` speed stats — two uint16 BE in 0.1 km/h (avg, max).
    func readSpeedStats() {
        sendManual(label: "TX read speed stats") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerRead,
                functionCode: 0x32
            )
        }
    }

    // MARK: Password / Security family (0x00A4 / A7 / A8 / A9) — all silent on v3 (issue #8)

    /// Function `0x00A4` Bluetooth password verify.
    func verifyBluetoothPassword(_ pw: String) {
        guard let digits = TcbFrameBuilder.passwordAscii(pw) else {
            log("Verify password: must be 6 digits")
            return
        }
        sendManual(label: "TX verify BT password") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0xA4,
                payload: digits
            )
        }
    }

    /// Function `0x00A7` lock-with-password. lockByte bit7 = lock(1)/unlock(0).
    func lockWithPassword(_ locked: Bool, password: String) {
        guard let digits = TcbFrameBuilder.passwordAscii(password) else {
            log("Lock with password: must be 6 digits")
            return
        }
        let lockByte: UInt8 = locked ? 0x80 : 0x00
        sendManual(label: locked ? "TX lock w/ password" : "TX unlock w/ password") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0xA7,
                payload: [lockByte] + digits
            )
        }
    }

    /// Function `0x00A8` change lock password.
    func changeLockPassword(old: String, new: String) {
        guard let o = TcbFrameBuilder.passwordAscii(old),
              let n = TcbFrameBuilder.passwordAscii(new) else {
            log("Change password: both must be 6 digits")
            return
        }
        sendManual(label: "TX change lock password") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0xA8,
                payload: o + n
            )
        }
    }

    /// Function `0x00A9` read after-sales password.
    func readAfterSalesPassword() {
        sendManual(label: "TX read after-sales password") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerRead,
                functionCode: 0xA9
            )
        }
    }

    /// Function `0x001A` mode 1 with a variable-length color payload — used for hex inputs
    /// like `#RRGGBBAA` or arbitrary debug bytes that the SDK's 3-byte RGB builder can't
    /// represent. Standard 6-hex RGB still routes through the SDK builder.
    func setAmbientLightCustomColor(hex: String) {
        let cleaned = hex.uppercased()
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty, cleaned.count.isMultiple(of: 2),
              cleaned.allSatisfy({ "0123456789ABCDEF".contains($0) }) else {
            log("Custom color: invalid hex `\(hex)`")
            return
        }
        var bytes: [UInt8] = [0x01] // mode = monochrome (1)
        var idx = cleaned.startIndex
        while idx < cleaned.endIndex {
            let next = cleaned.index(idx, offsetBy: 2)
            bytes.append(UInt8(cleaned[idx..<next], radix: 16) ?? 0)
            idx = next
        }
        // Android routes plain RGB (3 bytes) through the SDK which always appends 0xFF
        // brightness. Mirror that here: if only 3 color bytes were parsed, add alpha.
        if bytes.count == 4 { bytes.append(0xFF) } // mode + R + G + B → add brightness
        sendManual(label: "TX ambient custom #\(cleaned) (\(bytes.count - 1) color bytes)") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0x1A,
                payload: bytes
            )
        }
    }

    /// Function `0x001A` mode 4 (running effect / chase). The SDK enum is missing mode 4;
    /// frame structure is identical to mode 3 with alpha = 0xFF.
    func setAmbientLightRunningEffect(red: Int, green: Int, blue: Int) {
        sendManual(label: "TX ambient running \(rgbHex(red, green, blue))") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerWrite,
                functionCode: 0x1A,
                payload: [0x04, UInt8(red & 0xFF), UInt8(green & 0xFF), UInt8(blue & 0xFF), 0xFF]
            )
        }
    }

    /// Function `0x000A` temperature with selector byte. SDK only does controller (0x00);
    /// battery (0x10) and motor (0x30) need this manual variant.
    func readBatteryTemperature() {
        sendManual(label: "TX read battery temperature") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerRead,
                functionCode: 0x0A,
                payload: [0x10]
            )
        }
    }
    func readMotorTemperature() {
        sendManual(label: "TX read motor temperature") {
            TcbFrameBuilder.build(
                addr: TcbFrameBuilder.Addr.controllerRead,
                functionCode: 0x0A,
                payload: [0x30]
            )
        }
    }

    // MARK: - OTA (hand-rolled driver — bypasses TCBECCMD per android-ota-fix.md)

    func startControllerFirmwareOta(bytes: Data, sourceLabel: String) {
        ota.start(fileBytes: bytes, target: .controller, sourceLabel: sourceLabel)
    }
    func startMeterFirmwareOta(bytes: Data, sourceLabel: String) {
        ota.start(fileBytes: bytes, target: .meter, sourceLabel: sourceLabel)
    }
    func cancelOta() { ota.cancel() }

    // MARK: - Transport

    private func send(_ data: Data, label: String) {
        guard let p = peripheral, let ch = writeChar else {
            log("\(label) skipped: no write characteristic")
            return
        }
        let type: CBCharacteristicWriteType = ch.properties.contains(.write) ? .withResponse : .withoutResponse
        log("\(label): \(data.hexString)")
        p.writeValue(data, for: ch, type: type)
    }

    /// SDK-builder wrapper. Hides the throws/guard pair so feature methods read as a
    /// single chained call — mirrors Android's `.send(label)` extension.
    private func sendSDK(label: String, build: () throws -> Data) {
        do {
            let data = try build()
            send(data, label: label)
        } catch {
            log("\(label) — frame build failed: \(error)")
        }
    }

    /// Send arbitrary raw hex bytes entered by the user (e.g. "5A 21 1A 00 05 04 FF 00 00 FF").
    /// Spaces and `0x` prefixes are stripped before parsing.
    func sendRawHex(_ hex: String) {
        let clean = hex.replacingOccurrences(of: " ", with: "")
                       .replacingOccurrences(of: "0x", with: "")
                       .uppercased()
        guard !clean.isEmpty, clean.count % 2 == 0 else {
            log("Raw send: invalid hex string — must be even-length hex (spaces allowed)")
            return
        }
        var bytes: [UInt8] = []
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else {
                log("Raw send: invalid byte at position \(bytes.count)")
                return
            }
            bytes.append(byte)
            index = next
        }
        send(Data(bytes), label: "TX raw")
    }

    /// Manual-frame wrapper. Mirrors Android's `writeRaw(...)` path used for the 14
    /// customized frames that have no SDK builder.
    private func sendManual(label: String, build: () -> Data?) {
        guard let data = build() else {
            log("\(label) — frame build failed")
            return
        }
        send(data, label: label)
    }

    /// Identical to `sendManual` — named to make audit notes readable.
    /// Used when: Android sends via its SDK, iOS SDK produces wrong bytes, so we
    /// manually build the correct frame that mirrors the Android SDK output.
    private func sendManuallyAndroidDefault(label: String, build: () -> Data?) {
        guard let data = build() else {
            log("\(label) — frame build failed")
            return
        }
        send(data, label: label)
    }

    private func rgbHex(_ r: Int, _ g: Int, _ b: Int) -> String {
        String(format: "#%02X%02X%02X", r & 0xFF, g & 0xFF, b & 0xFF)
    }

    // MARK: - Response dispatch

    private func handleNotification(_ data: Data) {
        let hex = data.hexString
        // Manual-frame responses (function codes the SDK's convertToModel doesn't cover)
        // get a first crack at the bytes. Each handler returns true if it consumed them.
        if handleManualResponse(data: data, hex: hex) { return }

        let model = TCBManager.convertToModel(data: data)
        switch model {
        case let m as TCB01Model:
            applyHeartbeat(m)
        case let m as TCB02Model:
            log("  bound=\(m.boundId) ble=\(m.bluetoothStatus) lock=\(m.lockStatus)")
        case let m as TCB03Model:
            log("  NFC=\(m.nfcStatus ? "enabled" : "disabled")")
        case let m as TCB04Model:
            log("  ambient light=\(m.ambientLightStatus ? "on" : "off")")
        case let m as TCB1AModel:
            log("  ambient mode=\(m.magicLightMode) rgb=#\(String(format: "%02X%02X%02X", m.R, m.G, m.B))")
        case let m as TCB22Model:
            let kind = (m.responseType.map { "\($0)" }) ?? "?"
            log("  response \(kind) value=\(m.response)")
        case let m as TCB30Model:
            log("  remaining mileage \(m.remainingMileage) km")
        case let m as TCB08Model:
            log("  single-trip mileage \(m.singleTripMileage) km")
        case let m as TCB09Model:
            log("  total mileage \(m.totalMileage) km")
        case let m as TCB0AModel:
            log("  temperature type=\(m.type) value=\(m.temperature) °C")
        case let m as TCB0BModel:
            log("  driving current \(m.drivingCurrent) A")
        case let m as TCB11MeterModel:
            log("  meter version manuf=\(m.manufacturerCode) bin=\(m.binVersion) hw=\(m.hardwareVersion) id=\(m.meterID)")
        case let m as TCB11ControllerModel:
            log("  controller version manuf=\(m.manufacturerCode) bin=\(m.binVersion) hw=\(m.hardwareVersion)")
        case let m as TCB05Model:
            log("  gear-max-speed gear=\(m.gear) speed=\(m.speed) km/h")
        case let m as TCB05MaxSpeedModel:
            log("  global max speed=\(m.maxSpeed) km/h")
        case let m as TCB05DriveModel:
            log("  drive mode=\(m.driveMode)")
        case let m as TCBE0Model:
            log("  OTA E0 ready=\(m.readyToUpgrade)")
            ota.handleReadyAck(ready: m.readyToUpgrade)
        case let m as TCBE1Model:
            log("  OTA E1 ack accepted=\(m.dataReceivingStatus) index=\(m.index)")
            ota.handleDataAck(accepted: m.dataReceivingStatus, index: m.index)
        case let m as TCBE2Model:
            let success = m.upgradeCompletionResponse == .success
            log("  OTA E2 completion=\(String(describing: m.upgradeCompletionResponse))")
            ota.handleCrcAck(success: success)
        default:
            break
        }
    }

    private func applyHeartbeat(_ m: TCB01Model) {
        var t = telemetry
        t.batteryPercent = m.power
        t.batteryVoltage = Double(m.batteryVoltage) / 10.0
        t.realtimeSpeedKmh = Double(m.realTimeSpeed) / 10.0
        t.gear = m.gear
        t.lockStatus = m.lockStatus
        t.headlightOn = m.headlight
        t.cruiseControlEnabled = m.cruiseControlFunction
        t.cruiseActive = m.cruiseStatus
        t.charging = m.chargingStatus
        t.motorRunning = m.motorRunningStatus
        t.electronicBrake = m.electronicBrakeStatus
        t.mechanicalBrake = m.mechanicalBrakeStatus
        t.metricKm = m.metricMileUnit
        t.lastUpdated = Date()
        t.anyFaultActive = m.gyroscopeFault || m.batteryFault || m.MOSFault
            || m.motorHallFault || m.brakeFault || m.turnHandleFault
            || m.communicationFault || m.batteryOvervoltage
            || m.batteryTemperatureHigh || m.controllerTemperatureProtection
            || m.controllerFault
        telemetry = t
    }

    // MARK: - Helpers

    private func currentDevices() -> [ScannedDevice] {
        discoveredByID.values.sorted { $0.rssi > $1.rssi }
    }

    private func broadcast(_ block: @escaping (BleEventListener) -> Void) {
        DispatchQueue.main.async {
            for case let l as BleEventListener in self.listeners.allObjects {
                block(l)
            }
        }
    }

    private func log(_ message: String) {
        broadcast { $0.onLog(message) }
    }
}

// MARK: - CBCentralManagerDelegate

extension BleManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("Bluetooth state changed: \(central.state.rawValue)")
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

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let first = peripherals.first {
            first.delegate = self
            peripheral = first
            log("State restored with peripheral \(first.identifier)")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        let advertisedName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let manufacturerHex = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)
            .map { $0.hexString.uppercased() } ?? ""

        guard isScooterCandidate(name: advertisedName,
                                 services: advertisedServices,
                                 manufacturerHex: manufacturerHex) else { return }

        let label = displayName(advertisedName: advertisedName, manufacturerHex: manufacturerHex)
        let id = peripheral.identifier
        let device = ScannedDevice(id: id, name: label, rssi: RSSI.intValue, peripheral: peripheral, manufacturerHex: manufacturerHex)
        discoveredByID[id] = device
        broadcast { $0.onScanResultsChanged(self.currentDevices()) }
    }

    private func isScooterCandidate(name: String?,
                                    services: [CBUUID],
                                    manufacturerHex: String) -> Bool {
        return true
    }

    private func displayName(advertisedName: String?, manufacturerHex: String) -> String {
        if manufacturerHex.contains("FFFFFBFFFFFFFFFF3632530111004354")
            || manufacturerHex.contains("FFFFF7FFFFFFFFFF3932530111004354") {
            return "cardoO Scooter"
        }
        return advertisedName?.trimmingCharacters(in: .whitespaces).nonEmpty ?? "Scooter"
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("Connected: \(peripheral.name ?? "?")")
        ConnectionPreferences.lastPeripheralUUID = peripheral.identifier
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        log("Connect failed: \(error?.localizedDescription ?? "?")")
        connectionState = .idle
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        log("Disconnected: \(error?.localizedDescription ?? "clean")")
        writeChar = nil
        notifyChar = nil
        telemetry = HeartbeatTelemetry()
        ota.onDisconnect()
        connectionState = .idle
    }
}

// MARK: - CBPeripheralDelegate

extension BleManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { log("Service discovery error: \(error)"); return }
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error { log("Characteristic discovery error: \(error)"); return }
        for ch in service.characteristics ?? [] {
            if ch.uuid == writeCharUUID {
                writeChar = ch
            } else if ch.uuid == notifyCharUUID {
                notifyChar = ch
                peripheral.setNotifyValue(true, for: ch)
            }
        }
        if writeChar != nil && notifyChar != nil {
            connectionState = .connected(peripheralName: peripheral.name ?? "Scooter")
            writeConnectAuth()
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }
        handleNotification(data)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error { log("Write error: \(error)") }
    }
}

// MARK: - Manual-frame response parsing

extension BleManager {

    /// Returns true if the data was consumed by a manual-frame handler.
    fileprivate func handleManualResponse(data: Data, hex: String) -> Bool {
        guard data.count >= 5 else { return false }
        let bytes = [UInt8](data)
        let functionCode = bytes[2]
        // v3 firmware uses byte 4 as a single-byte length in BOTH the standard and the
        // mirror-framing forms (the protocol-doc form keeps byte 3 = 0x00; the mirror form
        // copies the function code into byte 3). Either way, byte 4 is the payload length.
        let payloadLength = Int(bytes[4])
        guard bytes.count >= 5 + payloadLength else { return false }
        let payload = Array(bytes[5..<(5 + payloadLength)])

        switch functionCode {
        case 0x06: return handleAutoPowerOffResponse(payload: payload, hex: hex)
        case 0x0D: return handleBatteryCapacityResponse(payload: payload, hex: hex)
        case 0x1D: return handleSerialNumberResponse(payload: payload, hex: hex)
        case 0x1E: return handleDetailedDeviceInfoResponse(payload: payload, hex: hex)
        case 0x32: return handleSpeedStatsResponse(payload: payload, hex: hex)
        case 0xA4, 0xA7, 0xA8: return handlePasswordStatusResponse(functionCode: functionCode, payload: payload, hex: hex)
        case 0xA9: return handleAfterSalesPasswordResponse(payload: payload, hex: hex)
        case 0x0A where payload.count >= 2 && payload[0] != 0x00:
            // Battery / motor temp paths: selector byte != 0 means we sent the manual
            // variant. Controller temp (selector 0) still goes through TCB0AModel.
            return handleTempResponse(payload: payload, hex: hex)
        case 0x0B where payload.count >= 3 && payload[0] == 0x01:
            return handleDrivingCurrentLimitResponse(payload: payload, hex: hex)
        default:
            return false
        }
    }

    private func handleAutoPowerOffResponse(payload: [UInt8], hex: String) -> Bool {
        guard payload.count >= 2 else { return false }
        let seconds = (Int(payload[0]) << 8) | Int(payload[1])
        let detail = seconds == 0 ? "disabled" : "\(seconds)s"
        log("RX auto power-off \(detail)")
        return true
    }

    private func handleBatteryCapacityResponse(payload: [UInt8], hex: String) -> Bool {
        // Spec: 1 byte type + uint16 BE capacity mAh; optional 4th byte = health %.
        // Android BATTERY_CAPACITY_RESPONSE_PAYLOAD_BYTES = 3 — health is not guaranteed.
        guard payload.count >= 3 else { return false }
        let packType = payload[0] == 0 ? "internal" : "external"
        let mah = (Int(payload[1]) << 8) | Int(payload[2])
        let healthSuffix = payload.count >= 4 ? ", health \(Int(payload[3]))%" : ""
        log(String(format: "RX battery capacity (\(packType)) \(mah) mAh\(healthSuffix) (raw type=0x%02X)", payload[0]))
        return true
    }

    private func handleSerialNumberResponse(payload: [UInt8], hex: String) -> Bool {
        let serial = String(bytes: payload, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters) ?? "(non-ASCII)"
        log("RX serial number `\(serial)`")
        return true
    }

    private func handleDetailedDeviceInfoResponse(payload: [UInt8], hex: String) -> Bool {
        let info = String(bytes: payload, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters) ?? "(non-ASCII)"
        log("RX device info `\(info)`")
        let fields = info.split(separator: "_").map(String.init).filter { !$0.isEmpty }
        if !fields.isEmpty {
            log("  fields: \(fields.joined(separator: " | "))")
        }
        return true
    }

    private func handleSpeedStatsResponse(payload: [UInt8], hex: String) -> Bool {
        // Two uint16 BE in 0.1 km/h units (avg, max).
        guard payload.count >= 4 else { return false }
        let avg = Double((Int(payload[0]) << 8) | Int(payload[1])) / 10.0
        let max = Double((Int(payload[2]) << 8) | Int(payload[3])) / 10.0
        log("RX speed stats avg=\(String(format: "%.1f", avg)) km/h max=\(String(format: "%.1f", max)) km/h")
        return true
    }

    private func handlePasswordStatusResponse(functionCode: UInt8, payload: [UInt8], hex: String) -> Bool {
        let kind: String
        switch functionCode {
        case 0xA4: kind = "BT password verify"
        case 0xA7: kind = "lock w/ password"
        case 0xA8: kind = "change password"
        default:   kind = String(format: "0x%02X", functionCode)
        }
        let status = payload.first.map { $0 == 0 ? "OK" : "fail (code \($0))" } ?? "no payload"
        log("RX \(kind) status: \(status)")
        return true
    }

    private func handleAfterSalesPasswordResponse(payload: [UInt8], hex: String) -> Bool {
        let pw = String(bytes: payload, encoding: .ascii) ?? "(non-ASCII)"
        log("RX after-sales password `\(pw)`")
        return true
    }

    private func handleTempResponse(payload: [UInt8], hex: String) -> Bool {
        // Payload = 1 selector byte + signed temp (Celsius). Battery=0x10, motor=0x30.
        let label = payload[0] == 0x10 ? "battery" : payload[0] == 0x30 ? "motor" : "?"
        let temp = Int8(bitPattern: payload[1])
        log("RX \(label) temperature \(temp) °C")
        return true
    }

    private func handleDrivingCurrentLimitResponse(payload: [UInt8], hex: String) -> Bool {
        // type=1 + uint16 BE limit in 0.1 A.
        let value = Double((Int(payload[1]) << 8) | Int(payload[2])) / 10.0
        log("RX driving current limit \(String(format: "%.1f", value)) A")
        return true
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
