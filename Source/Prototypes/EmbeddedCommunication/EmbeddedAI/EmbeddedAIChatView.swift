import SwiftUI

struct EmbeddedAIChatView: View {
    let context: PrototypeHostContext
    let backgroundColor: Color
    let isDarkMode: Bool
    let presentation: PrototypeSurfacePresentation
    let onClose: () -> Void

    @State private var viewModel: EmbeddedAIChatViewModel

    init(
        context: PrototypeHostContext,
        backgroundColor: Color,
        isDarkMode: Bool,
        presentation: PrototypeSurfacePresentation = .modal,
        viewModel: EmbeddedAIChatViewModel = EmbeddedAIChatViewModel(),
        startsStreaming: Bool = false,
        onClose: @escaping () -> Void
    ) {
        self.context = context
        self.backgroundColor = backgroundColor
        self.isDarkMode = isDarkMode
        self.presentation = presentation
        self.onClose = onClose
        if startsStreaming {
            viewModel.messages.append(
                PrototypeAIMessage(
                    role: .assistant,
                    markdown: "",
                    reasoning: ["Reviewing the local reader context…"]
                )
            )
            viewModel.isStreaming = true
        }
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if presentation == .modal {
                chatContent
                    .navigationTitle("AI Assistant")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        modalToolbar
                    }
                    .onDisappear {
                        viewModel.stopStreaming()
                    }
            } else {
                VStack(spacing: 0) {
                    inspectorActionBar
                    Divider()
                    chatContent
                }
            }
        }
        .background(backgroundColor)
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
    }

    private var chatContent: some View {
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
    }

    @ToolbarContentBuilder
    private var modalToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            modelBadge
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            newConversationButton

            Button("Done", action: onClose)
                .accessibilityLabel("Close")
        }
    }

    private var inspectorActionBar: some View {
        HStack(spacing: 12) {
            modelBadge
            Spacer()
            newConversationButton
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var modelBadge: some View {
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

    private var newConversationButton: some View {
        Button {
            viewModel.startNewConversation()
        } label: {
            Image(systemName: "plus.bubble")
        }
        .accessibilityLabel("New conversation")
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
