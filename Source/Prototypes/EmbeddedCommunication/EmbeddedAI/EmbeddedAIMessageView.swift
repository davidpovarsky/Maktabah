import SwiftUI

struct EmbeddedAIMessageView: View {
    let message: PrototypeAIMessage
    let isStreaming: Bool
    let onMockAction: (String) -> Void

    private var renderedMarkdown: AttributedString {
        (try? AttributedString(
            markdown: message.markdown,
            options: .init(interpretedSyntax: .full)
        )) ?? AttributedString(message.markdown)
    }

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                if message.role == .assistant {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)
                        .frame(width: 28, height: 28)
                        .background(.tint.opacity(0.12), in: .circle)
                } else {
                    Spacer(minLength: 44)
                }

                VStack(alignment: .leading, spacing: 10) {
                    if !message.markdown.isEmpty {
                        Text(renderedMarkdown)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if isStreaming {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Generating…")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let attachment = message.attachment {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(attachment.title)
                                    .font(.caption.weight(.semibold))
                                Text(attachment.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: attachment.systemImage)
                        }
                        .padding(8)
                        .background(.quaternary.opacity(0.45), in: .rect(cornerRadius: 10))
                    }

                    if !message.reasoning.isEmpty {
                        EmbeddedAIReasoningView(paragraphs: message.reasoning)
                    }

                    if let toolAction = message.toolAction {
                        EmbeddedAIToolCard(action: toolAction) {
                            onMockAction(toolAction.result)
                        }
                    }

                    if !message.citations.isEmpty {
                        EmbeddedAICitationView(citations: message.citations) { citation in
                            onMockAction("Would open \(citation.title) locally.")
                        }
                    }
                }
                .padding(12)
                .background(
                    message.role == .user
                        ? AnyShapeStyle(Color.accentColor.opacity(0.16))
                        : AnyShapeStyle(.regularMaterial),
                    in: .rect(cornerRadius: 16)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .accessibilityElement(children: .combine)
    }
}
