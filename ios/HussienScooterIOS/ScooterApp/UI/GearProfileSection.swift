import SwiftUI

/// Gear max-speed write panel — Sport / Eco presets and a custom-slider apply.
/// Writes are known broken on v3 firmware (issue #7): the BLE write is accepted
/// but the readback returns the old value. The UI surfaces the readback log
/// regardless so the user can confirm the v3 behaviour first-hand.
struct GearProfileSection: View {
    let enabled: Bool
    @Binding var g0: Double
    @Binding var g1: Double
    @Binding var g2: Double
    @Binding var g3: Double
    let onSport: () -> Void
    let onEco: () -> Void
    let onApplyCustom: () -> Void
    let onWriteSingle: (_ gear: Int, _ speed: Int) -> Void

    var body: some View {
        SectionPanel(title: "Gear Max Speed Writes (broken on v3 — issue #7)") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("Sport profile", action: onSport).buttonStyle(PrimaryButtonStyle())
                    Button("Eco profile", action: onEco).buttonStyle(PrimaryButtonStyle())
                }

                Text("Custom profile (G0..G3, 0..50 km/h)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(CardooTheme.muted)

                gearSlider(label: "G0", value: $g0, write: { onWriteSingle(0, Int(g0)) })
                gearSlider(label: "G1", value: $g1, write: { onWriteSingle(1, Int(g1)) })
                gearSlider(label: "G2", value: $g2, write: { onWriteSingle(2, Int(g2)) })
                gearSlider(label: "G3", value: $g3, write: { onWriteSingle(3, Int(g3)) })

                Button("Apply custom profile", action: onApplyCustom)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }

    private func gearSlider(label: String, value: Binding<Double>, write: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 12, weight: .semibold)).frame(width: 26)
            Slider(value: value, in: 0...50, step: 1).tint(CardooTheme.lime)
            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 28, alignment: .trailing)
                .foregroundColor(CardooTheme.muted)
            Button("Write", action: write)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 72)
        }
    }
}
