import SwiftUI

// MARK: - Cruise

struct CruiseSection: View {
    let enabled: Bool
    let onEnable: () -> Void
    let onDisable: () -> Void

    var body: some View {
        SectionPanel(title: "Cruise Control") {
            HStack(spacing: 10) {
                Button("Enable", action: onEnable)
                    .buttonStyle(PrimaryButtonStyle())
                Button("Disable", action: onDisable)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Gear

struct GearSection: View {
    let enabled: Bool
    let onSet: (Int) -> Void

    var body: some View {
        SectionPanel(title: "Gear Selection") {
            HStack(spacing: 8) {
                ForEach(0...3, id: \.self) { gear in
                    Button("\(gear)") { onSet(gear) }
                        .buttonStyle(gear == 0 ? AnyButtonStyle(SecondaryButtonStyle())
                                              : AnyButtonStyle(PrimaryButtonStyle()))
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

/// Type-erased ButtonStyle wrapper so a single `Button` can pick between styles
/// from a `ForEach`. Avoids duplicating the row markup per gear.
struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { config in AnyView(style.makeBody(configuration: config)) }
    }
    func makeBody(configuration: Configuration) -> some View { _makeBody(configuration) }
}

// MARK: - Start Mode

struct StartModeSection: View {
    let enabled: Bool
    let onZero: () -> Void
    let onKick: () -> Void

    var body: some View {
        SectionPanel(title: "Start Mode") {
            HStack(spacing: 10) {
                Button("Zero-start", action: onZero)
                    .buttonStyle(PrimaryButtonStyle())
                Button("Kick-start", action: onKick)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Unit System

struct UnitSystemSection: View {
    let enabled: Bool
    let onKilometer: () -> Void
    let onMile: () -> Void

    var body: some View {
        SectionPanel(title: "Unit System") {
            HStack(spacing: 10) {
                Button("Kilometer", action: onKilometer)
                    .buttonStyle(PrimaryButtonStyle())
                Button("Mile", action: onMile)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - NFC

struct NfcSection: View {
    let enabled: Bool
    let onRead: () -> Void
    let onEnable: () -> Void
    let onDisable: () -> Void

    var body: some View {
        SectionPanel(title: "NFC") {
            HStack(spacing: 8) {
                Button("Read", action: onRead).buttonStyle(SecondaryButtonStyle())
                Button("Enable", action: onEnable).buttonStyle(PrimaryButtonStyle())
                Button("Disable", action: onDisable).buttonStyle(PrimaryButtonStyle())
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Front Light

struct FrontLightSection: View {
    let enabled: Bool
    let onOn: () -> Void
    let onOff: () -> Void

    var body: some View {
        SectionPanel(title: "Front Light") {
            HStack(spacing: 10) {
                Button("On", action: onOn).buttonStyle(PrimaryButtonStyle())
                Button("Off", action: onOff).buttonStyle(SecondaryButtonStyle())
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Ambient Light Status

struct AmbientLightStatusSection: View {
    let enabled: Bool
    let onRead: () -> Void
    let onOn: () -> Void
    let onOff: () -> Void

    var body: some View {
        SectionPanel(title: "Ambient Light") {
            HStack(spacing: 8) {
                Button("Read", action: onRead).buttonStyle(SecondaryButtonStyle())
                Button("On", action: onOn).buttonStyle(PrimaryButtonStyle())
                Button("Off", action: onOff).buttonStyle(PrimaryButtonStyle())
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Ambient Light Color & Mode

struct AmbientLightColorSection: View {
    let enabled: Bool
    @Binding var red: Double
    @Binding var green: Double
    @Binding var blue: Double
    @Binding var brightness: Double   // 0-255; same scale as Android ambientBrightness
    let onRead: () -> Void
    let onSolid: () -> Void
    let onBreathing: () -> Void
    let onRainbow: () -> Void

    // Brightness-scaled channel value matching Android: (color * brightness + 127) / 255
    private func scaled(_ ch: Double) -> Int {
        Int((ch * brightness + 127.0) / 255.0)
    }

    private var scaledColor: Color {
        Color(red: Double(scaled(red)) / 255,
              green: Double(scaled(green)) / 255,
              blue: Double(scaled(blue)) / 255)
    }

    var body: some View {
        SectionPanel(title: "Ambient Light Color") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(scaledColor)
                        .frame(width: 48, height: 32)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.1)))
                    Text(String(format: "#%02X%02X%02X", scaled(red), scaled(green), scaled(blue)))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(CardooTheme.muted)
                    Spacer()
                    Button("Read", action: onRead).buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: 100)
                }
                channelSlider(label: "R", value: $red, tint: .red)
                channelSlider(label: "G", value: $green, tint: .green)
                channelSlider(label: "B", value: $blue, tint: .blue)
                channelSlider(label: "☀", value: $brightness, tint: CardooTheme.lime)
                HStack(spacing: 8) {
                    Button("Solid", action: onSolid).buttonStyle(PrimaryButtonStyle())
                    Button("Breathing", action: onBreathing).buttonStyle(PrimaryButtonStyle())
                    Button("Rainbow", action: onRainbow).buttonStyle(SecondaryButtonStyle())
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }

    private func channelSlider(label: String, value: Binding<Double>, tint: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .semibold)).frame(width: 14)
            Slider(value: value, in: 0...255, step: 1).tint(tint)
            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 32, alignment: .trailing)
                .foregroundColor(CardooTheme.muted)
        }
    }
}

// MARK: - Response Time (throttle / brake)

struct ResponseTimeSection: View {
    let title: String
    let enabled: Bool
    @Binding var customValue: String
    let presets: [(label: String, value: Int)]
    let onRead: () -> Void
    let onSetPreset: (Int) -> Void
    let onSetCustom: () -> Void

    var body: some View {
        SectionPanel(title: title) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("Read", action: onRead).buttonStyle(SecondaryButtonStyle())
                    ForEach(presets, id: \.value) { preset in
                        Button(preset.label) { onSetPreset(preset.value) }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
                HStack(spacing: 8) {
                    TextField("0-10", text: $customValue)
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

// MARK: - Diagnostics (versions / mileage / temp / current — read-only triggers)

struct ReadOnlySection: View {
    struct Item { let label: String; let action: () -> Void }
    let title: String
    let enabled: Bool
    let items: [Item]

    var body: some View {
        SectionPanel(title: title) {
            let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(items.indices, id: \.self) { idx in
                    Button(items[idx].label, action: items[idx].action)
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

// MARK: - Gear Max Speed (read-only for now; writes broken on v3)

struct GearMaxSpeedSection: View {
    let enabled: Bool
    let onReadGear: (Int) -> Void
    let onReadGlobal: () -> Void

    var body: some View {
        SectionPanel(title: "Gear Max Speed (read)") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0...3, id: \.self) { gear in
                        Button("Gear \(gear)") { onReadGear(gear) }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                Button("Global Max", action: onReadGlobal)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}
