import SwiftUI

// MARK: - Running Effect (CMD 1A, mode 0x04)

struct RunningEffectSection: View {
    let enabled: Bool
    @Binding var red: Double
    @Binding var green: Double
    @Binding var blue: Double
    let onSend: () -> Void

    var body: some View {
        SectionPanel(title: "Ambient Light — Running Effect (CMD 1A mode 04)") {
            VStack(alignment: .leading, spacing: 10) {
                colorPreview

                colorSlider(label: "R", value: $red, color: .red)
                colorSlider(label: "G", value: $green, color: .green)
                colorSlider(label: "B", value: $blue, color: .blue)

                Button("Send Running Effect", action: onSend)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }

    private var colorPreview: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(red: red / 255, green: green / 255, blue: blue / 255))
            .frame(height: 36)
            .overlay(
                Text(String(format: "#%02X%02X%02X", Int(red), Int(green), Int(blue)))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
            )
    }

    private func colorSlider(label: String, value: Binding<Double>, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 14)
            Slider(value: value, in: 0...255, step: 1).tint(color)
            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 32, alignment: .trailing)
                .foregroundColor(CardooTheme.muted)
        }
    }
}

// MARK: - Raw Hex Sender

struct RawHexSenderSection: View {
    let enabled: Bool
    @Binding var hexInput: String
    let onSend: () -> Void

    var body: some View {
        SectionPanel(title: "Raw Bytes Sender") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Enter hex bytes to send directly to the scooter.\nSpaces allowed — e.g. 5A 21 1A 00 05 04 FF 00 00 FF")
                    .font(.system(size: 11))
                    .foregroundColor(CardooTheme.muted)

                TextField("5A 21 1A 00 05 04 FF 00 00 FF ...", text: $hexInput)
                    .font(.system(size: 13, design: .monospaced))
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding(10)
                    .background(CardooTheme.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(CardooTheme.muted.opacity(0.3), lineWidth: 1)
                    )

                Button("Send Bytes", action: onSend)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(hexInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Auto Power-Off (0x0006) — silent on v3 (issue #5)

struct AutoPowerOffSection: View {
    let enabled: Bool
    @Binding var customSeconds: String
    let onRead: () -> Void
    let onDisabled: () -> Void
    let onFiveMinutes: () -> Void
    let onTenMinutes: () -> Void
    let onSetCustom: () -> Void

    var body: some View {
        SectionPanel(title: "Auto Power-Off (silent on v3)") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button("Read", action: onRead).buttonStyle(SecondaryButtonStyle())
                    Button("Disabled", action: onDisabled).buttonStyle(PrimaryButtonStyle())
                }
                HStack(spacing: 8) {
                    Button("5 min", action: onFiveMinutes).buttonStyle(PrimaryButtonStyle())
                    Button("10 min", action: onTenMinutes).buttonStyle(PrimaryButtonStyle())
                }
                HStack(spacing: 8) {
                    TextField("seconds (0..1800)", text: $customSeconds)
                        .keyboardType(.numberPad)
                        .padding(8)
                        .background(CardooTheme.surface)
                        .cornerRadius(8)
                    Button("Apply", action: onSetCustom).buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 100)
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Battery Capacity (0x000D)

struct BatteryCapacitySection: View {
    let enabled: Bool
    let onInternal: () -> Void
    let onExternal: () -> Void

    var body: some View {
        SectionPanel(title: "Battery Capacity") {
            HStack(spacing: 8) {
                Button("Internal pack", action: onInternal).buttonStyle(SecondaryButtonStyle())
                Button("External pack", action: onExternal).buttonStyle(SecondaryButtonStyle())
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Identity reads (serial / detailed info / speed stats / current limit)

struct IdentitySection: View {
    let enabled: Bool
    let onSerial: () -> Void
    let onDeviceInfo: () -> Void
    let onSpeedStats: () -> Void
    let onCurrentLimit: () -> Void

    var body: some View {
        SectionPanel(title: "Diagnostics — Identity & Stats") {
            let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
            LazyVGrid(columns: cols, spacing: 8) {
                Button("Serial number", action: onSerial).buttonStyle(SecondaryButtonStyle())
                Button("Detailed device info", action: onDeviceInfo).buttonStyle(SecondaryButtonStyle())
                Button("Speed stats avg/max", action: onSpeedStats).buttonStyle(SecondaryButtonStyle())
                Button("Driving current limit", action: onCurrentLimit).buttonStyle(SecondaryButtonStyle())
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Battery & Motor temperature (0x000A manual variants)

struct OtherTemperaturesSection: View {
    let enabled: Bool
    let onBattery: () -> Void
    let onMotor: () -> Void

    var body: some View {
        SectionPanel(title: "Battery & Motor Temperature") {
            HStack(spacing: 8) {
                Button("Battery temp", action: onBattery).buttonStyle(SecondaryButtonStyle())
                Button("Motor temp", action: onMotor).buttonStyle(SecondaryButtonStyle())
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Ambient extensions: running effect (mode 4) + variable-length custom hex

struct AmbientLightExtraSection: View {
    let enabled: Bool
    @Binding var customHex: String
    let onRunning: () -> Void
    let onCustom: () -> Void

    var body: some View {
        SectionPanel(title: "Ambient Light — Extras") {
            VStack(spacing: 8) {
                Button("Running effect (mode 4)", action: onRunning)
                    .buttonStyle(PrimaryButtonStyle())
                HStack(spacing: 8) {
                    TextField("#RRGGBB or #RRGGBBAA…", text: $customHex)
                        .autocapitalization(.allCharacters)
                        .padding(8)
                        .background(CardooTheme.surface)
                        .cornerRadius(8)
                    Button("Custom", action: onCustom).buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 100)
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Password / Security family (silent on v3 — issue #8)

struct PasswordSecuritySection: View {
    let enabled: Bool
    @Binding var verifyPassword: String
    @Binding var lockPassword: String
    @Binding var changeOldPassword: String
    @Binding var changeNewPassword: String
    let onReadAfterSales: () -> Void
    let onVerify: () -> Void
    let onLockWithPassword: () -> Void
    let onUnlockWithPassword: () -> Void
    let onChange: () -> Void

    var body: some View {
        SectionPanel(title: "Password / Security (silent on v3)") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("Read after-sales password", action: onReadAfterSales)
                        .buttonStyle(SecondaryButtonStyle())
                }
                pwField(label: "BT password", binding: $verifyPassword, action: onVerify, actionLabel: "Verify")
                pwField(label: "Lock w/ password", binding: $lockPassword, action: onLockWithPassword, actionLabel: "Lock")
                pwField(label: "Unlock w/ password", binding: $lockPassword, action: onUnlockWithPassword, actionLabel: "Unlock", styleDanger: false)
                VStack(spacing: 6) {
                    TextField("old (6 digits)", text: $changeOldPassword)
                        .keyboardType(.numberPad)
                        .padding(8)
                        .background(CardooTheme.surface)
                        .cornerRadius(8)
                    TextField("new (6 digits)", text: $changeNewPassword)
                        .keyboardType(.numberPad)
                        .padding(8)
                        .background(CardooTheme.surface)
                        .cornerRadius(8)
                    Button("Change lock password", action: onChange)
                        .buttonStyle(DangerButtonStyle())
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }

    private func pwField(label: String,
                         binding: Binding<String>,
                         action: @escaping () -> Void,
                         actionLabel: String,
                         styleDanger: Bool = false) -> some View {
        HStack(spacing: 8) {
            TextField(label, text: binding)
                .keyboardType(.numberPad)
                .padding(8)
                .background(CardooTheme.surface)
                .cornerRadius(8)
            Button(actionLabel, action: action)
                .buttonStyle(styleDanger ? AnyButtonStyle(DangerButtonStyle())
                                         : AnyButtonStyle(PrimaryButtonStyle()))
                .frame(maxWidth: 100)
        }
    }
}

// MARK: - Factory Reset (destructive — two-tap confirmation)

struct FactoryResetSection: View {
    let enabled: Bool
    let onConfirmed: () -> Void

    @State private var awaitingConfirmation = false

    var body: some View {
        SectionPanel(title: "Factory Reset") {
            Button(awaitingConfirmation ? "Tap again to confirm" : "Factory reset") {
                if awaitingConfirmation {
                    awaitingConfirmation = false
                    onConfirmed()
                } else {
                    awaitingConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        awaitingConfirmation = false
                    }
                }
            }
            .buttonStyle(DangerButtonStyle())
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}
