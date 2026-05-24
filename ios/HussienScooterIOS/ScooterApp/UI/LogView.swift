import SwiftUI

struct LogView: View {
    let entries: [LogEntry]

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        SectionPanel(title: "Log") {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(entries) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(Self.formatter.string(from: entry.timestamp))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(CardooTheme.muted)
                                Text(entry.text)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(CardooTheme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .id(entry.id)
                        }
                    }
                }
                .frame(height: 180)
                .background(CardooTheme.surface)
                .cornerRadius(8)
                .onChange(of: entries.count) {
                    if let last = entries.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
    }
}
