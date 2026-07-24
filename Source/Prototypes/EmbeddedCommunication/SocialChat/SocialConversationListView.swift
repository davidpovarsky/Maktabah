import SwiftUI

struct SocialConversationListView: View {
    let backgroundColor: Color
    let isDarkMode: Bool
    let presentation: PrototypeSurfacePresentation
    @Binding var navigationPath: NavigationPath
    var viewModel: SocialChatViewModel
    let onClose: () -> Void

    init(
        backgroundColor: Color,
        isDarkMode: Bool,
        presentation: PrototypeSurfacePresentation = .modal,
        navigationPath: Binding<NavigationPath> = .constant(NavigationPath()),
        viewModel: SocialChatViewModel,
        onClose: @escaping () -> Void
    ) {
        self.backgroundColor = backgroundColor
        self.isDarkMode = isDarkMode
        self.presentation = presentation
        _navigationPath = navigationPath
        self.viewModel = viewModel
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if presentation == .modal {
                    conversationList
                        .navigationTitle("Social Chat")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done", action: onClose)
                                    .accessibilityLabel("Close")
                            }
                        }
                } else {
                    conversationList
                }
            }
            .navigationDestination(for: PrototypeConversation.self) { conversation in
                SocialRoomView(
                    conversation: conversation,
                    backgroundColor: backgroundColor,
                    viewModel: viewModel
                )
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    private var conversationList: some View {
        List(PrototypeFixtures.socialConversations) { conversation in
            NavigationLink(value: conversation) {
                SocialConversationRow(conversation: conversation)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(backgroundColor)
    }
}
#Preview("Conversation list") {
    SocialConversationListView(
        backgroundColor: Color(uiColor: .systemBackground),
        isDarkMode: false,
        viewModel: SocialChatViewModel(),
        onClose: {}
    )
}
