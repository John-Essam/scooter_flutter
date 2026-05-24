import SwiftUI

struct LockUnlockSection: View {
    let enabled: Bool
    let onLock: () -> Void
    let onUnlock: () -> Void

    var body: some View {
        SectionPanel(title: "Lock / Unlock") {
            HStack(spacing: 10) {
                Button("Lock", action: onLock)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!enabled)
                Button("Unlock", action: onUnlock)
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!enabled)
            }
            .opacity(enabled ? 1 : 0.5)
        }
    }
}
