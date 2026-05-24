import SwiftUI

struct ContentView: View {
    @StateObject private var vm = MainViewModel()

    var body: some View {
        ZStack {
            CardooTheme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBand(connectionState: vm.connectionState)
                Divider()

                ScrollView {
                    VStack(spacing: 12) {
                        controlsRow

                        StatusSection(
                            connectionState: vm.connectionState,
                            scannedDevices: vm.scannedDevices,
                            telemetry: vm.telemetry,
                            onSelect: vm.connect
                        )

                        LockUnlockSection(
                            enabled: vm.isConnected,
                            onLock: vm.lock,
                            onUnlock: vm.unlock
                        )

                        CruiseSection(
                            enabled: vm.isConnected,
                            onEnable: { vm.cruise(true) },
                            onDisable: { vm.cruise(false) }
                        )

                        GearSection(
                            enabled: vm.isConnected,
                            onSet: vm.setGear
                        )

                        StartModeSection(
                            enabled: vm.isConnected,
                            onZero: { vm.startMode(zeroStart: true) },
                            onKick: { vm.startMode(zeroStart: false) }
                        )

                        UnitSystemSection(
                            enabled: vm.isConnected,
                            onKilometer: { vm.unitSystem(kilometers: true) },
                            onMile: { vm.unitSystem(kilometers: false) }
                        )

                        ResponseTimeSection(
                            title: "Throttle Response",
                            enabled: vm.isConnected,
                            customValue: $vm.throttleCustom,
                            presets: [("Sport", 0), ("Normal", 5), ("Careful", 10)],
                            onRead: { vm.readResponse(throttle: true) },
                            onSetPreset: { vm.writeResponse(throttle: true, value: $0) },
                            onSetCustom: vm.applyThrottleCustom
                        )

                        ResponseTimeSection(
                            title: "Brake Response",
                            enabled: vm.isConnected,
                            customValue: $vm.brakeCustom,
                            presets: [("Sport", 0), ("Normal", 5), ("Careful", 10)],
                            onRead: { vm.readResponse(throttle: false) },
                            onSetPreset: { vm.writeResponse(throttle: false, value: $0) },
                            onSetCustom: vm.applyBrakeCustom
                        )

                        NfcSection(
                            enabled: vm.isConnected,
                            onRead: vm.readNfc,
                            onEnable: { vm.setNfc(true) },
                            onDisable: { vm.setNfc(false) }
                        )

                        FrontLightSection(
                            enabled: vm.isConnected,
                            onOn: { vm.frontLight(true) },
                            onOff: { vm.frontLight(false) }
                        )

                        AmbientLightStatusSection(
                            enabled: vm.isConnected,
                            onRead: vm.readAmbientStatus,
                            onOn: { vm.ambientStatus(true) },
                            onOff: { vm.ambientStatus(false) }
                        )

                        AmbientLightColorSection(
                            enabled: vm.isConnected,
                            red: $vm.ambientR, green: $vm.ambientG, blue: $vm.ambientB,
                            brightness: $vm.ambientBrightness,
                            onRead: vm.readAmbientColor,
                            onSolid: { vm.setAmbientMode(1) },
                            onBreathing: { vm.setAmbientMode(2) },
                            onRainbow: { vm.setAmbientMode(3) }
                        )

                        ReadOnlySection(
                            title: "Diagnostics — Versions",
                            enabled: vm.isConnected,
                            items: [
                                .init(label: "Meter Version", action: vm.readMeterVersion),
                                .init(label: "Controller Version", action: vm.readControllerVersion),
                            ]
                        )

                        ReadOnlySection(
                            title: "Mileage",
                            enabled: vm.isConnected,
                            items: [
                                .init(label: "Remaining", action: vm.readRemaining),
                                .init(label: "Single trip", action: vm.readSingleTrip),
                                .init(label: "Total / ODO", action: vm.readTotal),
                            ]
                        )

                        ReadOnlySection(
                            title: "Telemetry — One-shot reads",
                            enabled: vm.isConnected,
                            items: [
                                .init(label: "Controller temp", action: vm.readControllerTemp),
                                .init(label: "Realtime current", action: vm.readRealtimeCurrent),
                            ]
                        )

                        GearMaxSpeedSection(
                            enabled: vm.isConnected,
                            onReadGear: vm.readGearMaxSpeed,
                            onReadGlobal: vm.readGlobalMaxSpeed
                        )

                        GearProfileSection(
                            enabled: vm.isConnected,
                            g0: $vm.gearG0, g1: $vm.gearG1, g2: $vm.gearG2, g3: $vm.gearG3,
                            onSport: vm.applySportProfile,
                            onEco: vm.applyEcoProfile,
                            onApplyCustom: vm.applyCustomGearProfile,
                            onWriteSingle: vm.writeGearMaxSpeed
                        )

                        OtherTemperaturesSection(
                            enabled: vm.isConnected,
                            onBattery: vm.readBatteryTemp,
                            onMotor: vm.readMotorTemp
                        )

                        AmbientLightExtraSection(
                            enabled: vm.isConnected,
                            customHex: $vm.ambientCustomHex,
                            onRunning: vm.runningEffect,
                            onCustom: vm.applyCustomAmbient
                        )

                        BatteryCapacitySection(
                            enabled: vm.isConnected,
                            onInternal: { vm.batteryCapacity(internalPack: true) },
                            onExternal: { vm.batteryCapacity(internalPack: false) }
                        )

                        IdentitySection(
                            enabled: vm.isConnected,
                            onSerial: vm.readSerial,
                            onDeviceInfo: vm.readDeviceInfo,
                            onSpeedStats: vm.readSpeedStats,
                            onCurrentLimit: vm.readCurrentLimit
                        )

                        AutoPowerOffSection(
                            enabled: vm.isConnected,
                            customSeconds: $vm.autoPowerOffSeconds,
                            onRead: vm.readAutoPowerOff,
                            onDisabled: { vm.setAutoPowerOff(0) },
                            onFiveMinutes: { vm.setAutoPowerOff(300) },
                            onTenMinutes: { vm.setAutoPowerOff(600) },
                            onSetCustom: vm.applyAutoPowerOff
                        )

                        PasswordSecuritySection(
                            enabled: vm.isConnected,
                            verifyPassword: $vm.verifyPassword,
                            lockPassword: $vm.lockPassword,
                            changeOldPassword: $vm.oldPassword,
                            changeNewPassword: $vm.newPassword,
                            onReadAfterSales: vm.readAfterSalesPassword,
                            onVerify: vm.verifyPasswordTap,
                            onLockWithPassword: vm.lockWithPasswordTap,
                            onUnlockWithPassword: vm.unlockWithPasswordTap,
                            onChange: vm.changePasswordTap
                        )

                        FactoryResetSection(
                            enabled: vm.isConnected,
                            onConfirmed: vm.factoryReset
                        )

                        OtaSection(
                            enabled: vm.isConnected,
                            fileLoaded: vm.firmwareLoaded,
                            preview: vm.otaPreview,
                            state: vm.otaState,
                            progress: vm.otaProgress,
                            onSelectFile: { vm.showFilePicker = true },
                            onStartController: vm.startControllerOta,
                            onStartMeter: vm.startMeterOta,
                            onCancel: vm.cancelOta
                        )

                        RunningEffectSection(
                            enabled: vm.isConnected,
                            red: $vm.runningR,
                            green: $vm.runningG,
                            blue: $vm.runningB,
                            onSend: vm.sendRunningEffect
                        )

                        RawHexSenderSection(
                            enabled: vm.isConnected,
                            hexInput: $vm.rawHexInput,
                            onSend: vm.sendRawHex
                        )

                        LogView(entries: vm.logs)
                    }
                    .padding(16)
                }
            }
        }
        .onAppear { vm.attach() }
        .sheet(isPresented: $vm.showFilePicker) {
            FirmwareFilePicker(
                onPicked: { vm.handleFirmwareURL($0); vm.showFilePicker = false },
                onCancelled: { vm.showFilePicker = false }
            )
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            Button(vm.isScanning ? "Stop" : "Scan", action: vm.toggleScan)
                .buttonStyle(SecondaryButtonStyle())
            Button("Disconnect", action: vm.disconnect)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!vm.isConnected)
            Button("Unbind", action: vm.unbind)
                .buttonStyle(DangerButtonStyle())
                .disabled(!vm.isConnected)
        }
    }
}

@MainActor
final class MainViewModel: ObservableObject, BleEventListener {
    @Published var connectionState: BleConnectionState = .idle
    @Published var scannedDevices: [ScannedDevice] = []
    @Published var telemetry: HeartbeatTelemetry = HeartbeatTelemetry()
    @Published var logs: [LogEntry] = []

    @Published var ambientR: Double = 255
    @Published var ambientG: Double = 60
    @Published var ambientB: Double = 0
    @Published var ambientBrightness: Double = 255

    @Published var throttleCustom: String = ""
    @Published var brakeCustom: String = ""

    @Published var ambientCustomHex: String = ""
    @Published var autoPowerOffSeconds: String = ""

    @Published var verifyPassword: String = ""
    @Published var lockPassword: String = ""
    @Published var oldPassword: String = ""
    @Published var newPassword: String = ""

    @Published var otaState: OtaState = .idle
    @Published var otaProgress: Int = 0
    @Published var otaPreview: OtaPreview?
    @Published var firmwareLoaded: Bool = false
    @Published var showFilePicker: Bool = false

    // Running effect
    @Published var runningR: Double = 255
    @Published var runningG: Double = 0
    @Published var runningB: Double = 0

    // Raw hex sender
    @Published var rawHexInput: String = ""

    // Gear-profile sliders default to the Sport preset so the user has a
    // reasonable starting point (and matches what Android shows on launch).
    @Published var gearG0: Double = 10
    @Published var gearG1: Double = 15
    @Published var gearG2: Double = 30
    @Published var gearG3: Double = 45

    private var pendingFirmware: (data: Data, label: String)?

    private let manager = BleManager.shared

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }

    var isScanning: Bool {
        if case .scanning = connectionState { return true }
        return false
    }

    func attach() { manager.addListener(self) }

    // MARK: Connection

    func toggleScan() {
        if isScanning { manager.stopScan() } else { manager.startScan() }
    }
    func connect(_ device: ScannedDevice) { manager.connect(to: device) }
    func disconnect() { manager.disconnect() }
    func unbind() { manager.unbind() }

    // MARK: Lock + cruise + gear

    func lock() { manager.setLocked(true) }
    func unlock() { manager.setLocked(false) }
    func cruise(_ enabled: Bool) { manager.setCruiseControl(enabled) }
    func setGear(_ gear: Int) { manager.setGear(gear) }
    func startMode(zeroStart: Bool) { manager.setStartMode(zeroStart: zeroStart) }
    func unitSystem(kilometers: Bool) { manager.setUnitSystem(kilometers: kilometers) }

    // MARK: Response time

    func readResponse(throttle: Bool) { manager.readResponseTime(type: throttle ? 0 : 1) }
    func writeResponse(throttle: Bool, value: Int) {
        manager.writeResponseTime(type: throttle ? 0 : 1, value: value)
    }
    func applyThrottleCustom() {
        guard let v = Int(throttleCustom) else { return }
        writeResponse(throttle: true, value: v)
    }
    func applyBrakeCustom() {
        guard let v = Int(brakeCustom) else { return }
        writeResponse(throttle: false, value: v)
    }

    // MARK: NFC / lights

    func readNfc() { manager.readNfcStatus() }
    func setNfc(_ on: Bool) { manager.setNfc(enabled: on) }
    func frontLight(_ on: Bool) { manager.setFrontLight(on: on) }
    func readAmbientStatus() { manager.readAmbientLightStatus() }
    func ambientStatus(_ on: Bool) { manager.setAmbientLightStatus(on: on) }
    func readAmbientColor() { manager.readAmbientLight() }
    // Matches Android: (color * brightness + 127) / 255
    private func scaledAmbient(_ ch: Double) -> Int {
        Int((ch * ambientBrightness + 127.0) / 255.0)
    }

    func setAmbientMode(_ mode: Int) {
        manager.setAmbientLight(mode: mode,
                                red: scaledAmbient(ambientR),
                                green: scaledAmbient(ambientG),
                                blue: scaledAmbient(ambientB))
    }

    // MARK: Diagnostics / mileage / versions

    func readMeterVersion() { manager.readMeterVersion() }
    func readControllerVersion() { manager.readControllerVersion() }
    func readRemaining() { manager.readRemainingMileage() }
    func readSingleTrip() { manager.readSingleTripMileage() }
    func readTotal() { manager.readTotalMileage() }
    func readControllerTemp() { manager.readControllerTemperature() }
    func readRealtimeCurrent() { manager.readDrivingCurrentRealtime() }
    func readGearMaxSpeed(_ gear: Int) { manager.readGearMaxSpeed(gear: gear) }
    func readGlobalMaxSpeed() { manager.readGlobalMaxSpeed() }

    // Gear profile writes (batch 4 — broken on v3 firmware per issue #7)
    func writeGearMaxSpeed(_ gear: Int, _ speed: Int) {
        manager.writeGearMaxSpeed(gear: gear, speed: speed)
    }
    func applySportProfile() {
        let p = BleManager.sportProfile
        gearG0 = Double(p[0]); gearG1 = Double(p[1]); gearG2 = Double(p[2]); gearG3 = Double(p[3])
        manager.applySportProfile()
    }
    func applyEcoProfile() {
        let p = BleManager.ecoProfile
        gearG0 = Double(p[0]); gearG1 = Double(p[1]); gearG2 = Double(p[2]); gearG3 = Double(p[3])
        manager.applyEcoProfile()
    }
    func applyCustomGearProfile() {
        manager.applyGearProfile([Int(gearG0), Int(gearG1), Int(gearG2), Int(gearG3)])
    }

    // MARK: Manual frames (batch 2 — customized frames)

    func readBatteryTemp() { manager.readBatteryTemperature() }
    func readMotorTemp() { manager.readMotorTemperature() }

    func runningEffect() {
        manager.setAmbientLightRunningEffect(red: scaledAmbient(ambientR),
                                             green: scaledAmbient(ambientG),
                                             blue: scaledAmbient(ambientB))
    }

    func sendRunningEffect() {
        manager.setAmbientLightRunningEffect(red: scaledAmbient(runningR),
                                             green: scaledAmbient(runningG),
                                             blue: scaledAmbient(runningB))
    }

    func sendRawHex() {
        manager.sendRawHex(rawHexInput)
    }
    func applyCustomAmbient() { manager.setAmbientLightCustomColor(hex: ambientCustomHex) }

    func batteryCapacity(internalPack: Bool) { manager.readBatteryCapacity(internalPack: internalPack) }
    func readSerial() { manager.readSerialNumber() }
    func readDeviceInfo() { manager.readDetailedDeviceInfo() }
    func readSpeedStats() { manager.readSpeedStats() }
    func readCurrentLimit() { manager.readDrivingCurrentLimit() }

    func readAutoPowerOff() { manager.readAutoPowerOff() }
    func setAutoPowerOff(_ s: Int) { manager.writeAutoPowerOff(seconds: s) }
    func applyAutoPowerOff() {
        guard let v = Int(autoPowerOffSeconds) else { return }
        setAutoPowerOff(v)
    }

    func readAfterSalesPassword() { manager.readAfterSalesPassword() }
    func verifyPasswordTap()      { manager.verifyBluetoothPassword(verifyPassword) }
    func lockWithPasswordTap()    { manager.lockWithPassword(true, password: lockPassword) }
    func unlockWithPasswordTap()  { manager.lockWithPassword(false, password: lockPassword) }
    func changePasswordTap()      { manager.changeLockPassword(old: oldPassword, new: newPassword) }

    func factoryReset() { manager.factoryReset() }

    // MARK: OTA

    func handleFirmwareURL(_ url: URL) {
        // UIDocumentPicker returns a file we can read directly because asCopy=true.
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            pendingFirmware = (data, url.lastPathComponent)
            firmwareLoaded = true
            logs.append(LogEntry(timestamp: Date(),
                                 text: "Firmware loaded: \(url.lastPathComponent) (\(data.count) bytes)"))
        } catch {
            firmwareLoaded = false
            logs.append(LogEntry(timestamp: Date(),
                                 text: "Firmware load failed: \(error.localizedDescription)"))
        }
    }

    func startControllerOta() {
        guard let fw = pendingFirmware else { return }
        manager.startControllerFirmwareOta(bytes: fw.data, sourceLabel: fw.label)
    }
    func startMeterOta() {
        guard let fw = pendingFirmware else { return }
        manager.startMeterFirmwareOta(bytes: fw.data, sourceLabel: fw.label)
    }
    func cancelOta() { manager.cancelOta() }

    // MARK: BleEventListener

    nonisolated func onConnectionStateChanged(_ state: BleConnectionState) {
        Task { @MainActor in self.connectionState = state }
    }
    // Mirrors Android resolveModelHint — device is a scooter candidate when the result
    // is anything other than "unknown".
    private nonisolated static func resolveModelHint(name: String, adHex: String) -> String {
        let lower = name.lowercased()
        if adHex.contains("FFFFFBFFFFFFFFFF3632530111004354") { return "s26" }
        if adHex.contains("FFFFF7FFFFFFFFFF3932530111004354") { return "s29" }
        if adHex.contains("FFFFFB31") || lower.hasPrefix("cardoox1") { return "cardoOx1" }
        if adHex.contains("FFFFFB32") || lower.hasPrefix("cardoox2") { return "cardoOx2" }
        if lower.hasPrefix("cardoox3") { return "cardoOx3" }
        if adHex.contains("FFFFF7FFFFFF") { return "cardoO-F7" }
        if adHex.contains("FFFFFBFFFFFF") { return "cardoO-FB" }
        return "unknown"
    }

    nonisolated func onScanResultsChanged(_ devices: [ScannedDevice]) {
        let filtered = devices.filter { device in
            Self.resolveModelHint(name: device.name, adHex: device.manufacturerHex) != "unknown"
        }
        Task { @MainActor in self.scannedDevices = filtered }
    }
    nonisolated func onHeartbeatUpdated(_ telemetry: HeartbeatTelemetry) {
        Task { @MainActor in self.telemetry = telemetry }
    }
    nonisolated func onOtaStateChanged(_ state: OtaState) {
        Task { @MainActor in self.otaState = state }
    }
    nonisolated func onOtaProgressChanged(_ percent: Int) {
        Task { @MainActor in self.otaProgress = percent }
    }
    nonisolated func onOtaPreviewChanged(_ preview: OtaPreview?) {
        Task { @MainActor in self.otaPreview = preview }
    }
    nonisolated func onLog(_ message: String) {
        Task { @MainActor in
            self.logs.append(LogEntry(timestamp: Date(), text: message))
            if self.logs.count > 500 { self.logs.removeFirst(self.logs.count - 500) }
        }
    }
}

// No `#Preview` block intentionally — the canvas cannot host CoreBluetooth, and
// instantiating `MainViewModel` here would trigger `BleManager.shared`, which
// crashes the preview agent on `CBCentralManager` init with a restore identifier.
// Run the app on a real device for any live testing.
