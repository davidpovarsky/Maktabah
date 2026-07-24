import SwiftUI

struct EmbeddedAIChatView: View {
    let context: PrototypeHostContext
    let backgroundColor: Color
    let isDarkMode: Bool
    let onClose: () -> Void

    @State private var viewModel: EmbeddedAIChatViewModel

    init(
        context: PrototypeHostContext,
        backgroundColor: Color,
        isDarkMode: Bool,
        startsStreaming: Bool = false,
        onClose: @escaping () -> Void
    ) {
        self.context = context
        self.backgroundColor = backgroundColor
        self.isDarkMode = isDarkMode
        self.onClose = onClose
        let model = EmbeddedAIChatViewModel()
        if startsStreaming {
            model.messages.append(
                PrototypeAIMessage(
                    role: .assistant,
                    markdown: "",
                    reasoning: ["Reviewing the local reader context…"]
                )
            )
            model.isStreaming = true
        }
        _viewModel = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 14) {
                    EmbeddedAIContextHeader(context: context)

                    if viewModel.messages.isEmpty {
                        ContentUnavailableView {
                            Label("AI Assistant", systemImage: "sparkles")
                        } description: {
                            Text("Ask a question about the current book or visible passage.")
                        }
                        .frame(minHeight: 280)
                    } else {
                        ForEach(viewModel.messages) { message in
                            EmbeddedAIMessageView(
                                message: message,
                                isStreaming: viewModel.isStreaming && message.id == viewModel.messages.last?.id
                            ) { notice in
                                viewModel.notice = notice
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)

            Divider()

            EmbeddedAIComposer(
                text: $viewModel.composerText,
                pendingAttachment: viewModel.pendingAttachment,
                isStreaming: viewModel.isStreaming,
                onAttach: viewModel.toggleContextAttachment,
                onMicrophone: viewModel.simulateMicrophone,
                onSend: { viewModel.send(context: context) },
                onStop: viewModel.stopStreaming
            )
        }
        .background(backgroundColor)
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                    Text("Mock model")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: .capsule)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.startNewConversation()
                } label: {
                    Image(systemName: "plus.bubble")
                }
                .accessibilityLabel("New conversation")

                Button("Done", action: onClose)
                    .accessibilityLabel("Close")
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .alert(
            "Prototype action",
            isPresented: Binding(
                get: { viewModel.notice != nil },
                set: { if !$0 { viewModel.notice = nil } }
            ),
            actions: {
                Button("OK") {
                    viewModel.notice = nil
                }
            },
            message: {
                Text(viewModel.notice ?? "")
            }
        )
        .onDisappear {
            viewModel.stopStreaming()
        }
    }
}

#Preview("Book context") {
    NavigationStack {
        EmbeddedAIChatView(
            context: PrototypeHostContext(
                title: "מסכת שבת",
                identifier: "42",
                collectionName: "Maktabah",
                excerpt: "מאי חנוכה…",
                detail: "Page 21b"
            ),
            backgroundColor: Color(uiColor: .systemBackground),
            isDarkMode: false,
            onClose: {}
        )
    }
}

#Preview("Streaming") {
    NavigationStack {
        EmbeddedAIChatView(
            context: PrototypeHostContext(
                title: "מסכת שבת",
                identifier: "42",
                collectionName: "Maktabah",
                excerpt: "מאי חנוכה…",
                detail: "Page 21b"
            ),
            backgroundColor: Color(uiColor: .systemBackground),
            isDarkMode: true,
            startsStreaming: true,
            onClose: {}
        )
    }
    .preferredColorScheme(.dark)
}
