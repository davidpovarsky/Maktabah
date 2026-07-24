import SwiftUI

struct SocialConversationListView: View {
    let backgroundColor: Color
    let isDarkMode: Bool
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List(PrototypeFixtures.socialConversations) { conversation in
                NavigationLink(value: conversation) {
                    SocialConversationRow(conversation: conversation)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(backgroundColor)
            .navigationTitle("Social Chat")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PrototypeConversation.self) { conversation in
                SocialRoomView(conversation: conversation, backgroundColor: backgroundColor)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                        .accessibilityLabel("Close")
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

#Preview("Conversation list") {
    SocialConversationListView(
        backgroundColor: Color(uiColor: .systemBackground),
        isDarkMode: false,
        onClose: {}
    )
}

