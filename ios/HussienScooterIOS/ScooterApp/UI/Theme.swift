import SwiftUI

enum CardooTheme {
    static let lime    = Color(red: 0.79, green: 0.96, blue: 0.26)   // #C9F542
    static let ink     = Color(red: 0.08, green: 0.08, blue: 0.08)   // near-black text
    static let surface = Color(red: 0.96, green: 0.97, blue: 0.97)   // light surface
    static let muted   = Color(red: 0.45, green: 0.45, blue: 0.45)   // secondary text
    static let danger  = Color(red: 0.78, green: 0.16, blue: 0.16)   // #C62828
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(CardooTheme.ink)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(CardooTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(CardooTheme.lime)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(CardooTheme.danger)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct SectionPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(CardooTheme.ink)
            content()
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}
