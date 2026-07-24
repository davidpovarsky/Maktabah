import SwiftUI

enum MaktabahReaderInspectorSection: String, CaseIterable, Identifiable {
    case sources
    case assistant
    case socialChat

    var id: Self { self }

    var title: String {
        switch self {
        case .sources: String(localized: "Sources")
        case .assistant: String(localized: "AI")
        case .socialChat: String(localized: "Chats")
        }
    }

    var systemImage: String {
        switch self {
        case .sources: "books.vertical"
        case .assistant: "sparkles"
        case .socialChat: "bubble.left.and.bubble.right"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .sources: String(localized: "Reader sources")
        case .assistant: String(localized: "AI Assistant")
        case .socialChat: String(localized: "Social Chat")
        }
    }
}

struct MaktabahCommunicationInspectorView: View {
    var viewModel: ReaderViewModel
    var navigationManager: iOSNavigationManager
    let context: PrototypeHostContext
    let backgroundColor: Color
    let isDarkMode: Bool
    @Binding var selectedSection: MaktabahReaderInspectorSection
    let onClose: () -> Void

    @State private var aiViewModel = EmbeddedAIChatViewModel()
    @State private var socialViewModel = SocialChatViewModel()
    @State private var socialNavigationPath = NavigationPath()

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader
            Divider()
            inspectorContent
        }
        .background(backgroundColor)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onDisappear {
            aiViewModel.stopStreaming()
        }
    }

    private var inspectorHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Reader Inspector")
                    .font(.headline)
                Spacer()
                Button(action: closeInspector) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Inspector")
            }

            Picker("Inspector section", selection: $selectedSection) {
                ForEach(MaktabahReaderInspectorSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .accessibilityLabel(section.accessibilityLabel)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
    }

    @ViewBuilder
    private var inspectorContent: some View {
        switch selectedSection {
        case .sources:
            OtzariaReaderSourcesInspectorHost(
                viewModel: viewModel,
                navigationManager: navigationManager,
                onClose: closeInspector
            )
        case .assistant:
            EmbeddedAIChatView(
                context: context,
                backgroundColor: backgroundColor,
                isDarkMode: isDarkMode,
                presentation: .inspector,
                viewModel: aiViewModel,
                onClose: closeInspector
            )
        case .socialChat:
            SocialConversationListView(
                backgroundColor: backgroundColor,
                isDarkMode: isDarkMode,
                presentation: .inspector,
                navigationPath: $socialNavigationPath,
                viewModel: socialViewModel,
                onClose: closeInspector
            )
        }
    }

    private func closeInspector() {
        aiViewModel.stopStreaming()
        onClose()
    }
}
