import SwiftUI
import UniformTypeIdentifiers

// MARK: - Document picker wrapper

struct FirmwareFilePicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.data, .item]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FirmwareFilePicker
        init(_ parent: FirmwareFilePicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { parent.onPicked(url) } else { parent.onCancelled() }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancelled()
        }
    }
}

// MARK: - OTA section

struct OtaSection: View {
    let enabled: Bool
    let fileLoaded: Bool       // true once a firmware file has been picked
    let preview: OtaPreview?   // non-nil only while an OTA session is in-flight
    let state: OtaState
    let progress: Int
    let onSelectFile: () -> Void
    let onStartController: () -> Void
    let onStartMeter: () -> Void
    let onCancel: () -> Void

    var body: some View {
        SectionPanel(title: "OTA Firmware Upgrade") {
            VStack(alignment: .leading, spacing: 10) {
                previewBox

                HStack(spacing: 8) {
                    Button("Select file", action: onSelectFile).buttonStyle(SecondaryButtonStyle())
                    Button("Controller", action: onStartController)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!fileLoaded || inFlight)
                    Button("Meter", action: onStartMeter)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!fileLoaded || inFlight)
                }
                Button("Bootloader (disabled — protocol §3.4)") {}
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(true)

                statusBlock
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }

    private var inFlight: Bool {
        switch state {
        case .preparing, .waitingReady, .sending, .verifying: return true
        default: return false
        }
    }

    @ViewBuilder
    private var previewBox: some View {
        if let p = preview {
            // OTA in-flight: show full session details including target.
            VStack(alignment: .leading, spacing: 2) {
                Text(p.sourceLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CardooTheme.ink)
                Text("\(p.sizeBytes) bytes • crc32 \(p.crc32Hex) • target \(p.target.displayName)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(CardooTheme.muted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardooTheme.surface)
            .cornerRadius(8)
        } else if fileLoaded {
            // File loaded, waiting for user to pick Controller or Meter.
            Text("Firmware ready — tap Controller or Meter to flash.")
                .font(.system(size: 12))
                .foregroundColor(CardooTheme.ink)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CardooTheme.surface)
                .cornerRadius(8)
        } else {
            Text("No firmware selected.")
                .font(.system(size: 12))
                .foregroundColor(CardooTheme.muted)
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusColor)
                Spacer()
                if inFlight {
                    Button("Cancel", action: onCancel).buttonStyle(DangerButtonStyle())
                        .frame(maxWidth: 100)
                }
            }
            ProgressView(value: Double(progress) / 100.0)
                .progressViewStyle(.linear)
                .tint(CardooTheme.lime)
        }
    }

    private var statusText: String {
        switch state {
        case .idle:          return "Idle"
        case .preparing:     return "Preparing…"
        case .waitingReady:  return "Waiting for device ready ack…"
        case .sending(let sent, let total): return "Sending chunk \(sent)/\(total) (\(progress)%)"
        case .verifying:     return "Verifying CRC32…"
        case .completed:     return "Completed."
        case .failed(let r): return "Failed: \(r)"
        case .cancelled:     return "Cancelled."
        }
    }

    private var statusColor: Color {
        switch state {
        case .completed:    return .green
        case .failed:       return CardooTheme.danger
        case .cancelled:    return CardooTheme.muted
        default:            return CardooTheme.ink
        }
    }
}
