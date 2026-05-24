import SwiftUI

struct HeaderBand: View {
    let connectionState: BleConnectionState

    private var pillText: String {
        switch connectionState {
        case .idle: return "idle"
        case .scanning: return "scanning"
        case .connecting(let name): return "connecting \(name)"
        case .connected(let name): return "connected \(name)"
        case .disconnecting: return "disconnecting"
        }
    }

    private var pillColor: Color {
        switch connectionState {
        case .idle, .disconnecting: return CardooTheme.muted
        case .scanning, .connecting: return CardooTheme.lime
        case .connected: return Color.green
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("cardoO")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(CardooTheme.ink)
                Text("Scooter SDK Test Harness")
                    .font(.system(size: 12))
                    .foregroundColor(CardooTheme.muted)
            }
            Spacer()
            Text(pillText)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(pillColor)
                .foregroundColor(CardooTheme.ink)
                .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
}
