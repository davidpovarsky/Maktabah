import SwiftUI

struct EmbeddedAIComposer: View {
    @Binding var text: String
    let pendingAttachment: PrototypeAIContextAttachment?
    let isStreaming: Bool
    let onAttach: () -> Void
    let onMicrophone: () -> Void
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let pendingAttachment {
                HStack(spacing: 8) {
                    Image(systemName: pendingAttachment.systemImage)
                    Text(pendingAttachment.title)
                        .font(.caption.weight(.medium))
                    Spacer()
                    Button(action: onAttach) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove attachment")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.5), in: .capsule)
            }

            HStack(alignment: .bottom, spacing: 6) {
                Button(action: onAttach) {
                    Image(systemName: "paperclip")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Attach")

                TextField("Ask about this book…", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.quaternary.opacity(0.45), in: .rect(cornerRadius: 14))
                    .submitLabel(.send)
                    .onSubmit {
                        if !isStreaming {
                            onSend()
                        }
                    }

                Button(action: onMicrophone) {
                    Image(systemName: "microphone")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Microphone")

                Button(action: isStreaming ? onStop : onSend) {
                    Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.tint, in: .circle)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(isStreaming ? "Stop streaming" : "Send")
                .disabled(!isStreaming && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

