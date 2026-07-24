import ExyteChat
import SwiftUI

struct SocialRoomView: View {
    let conversation: PrototypeConversation
    let backgroundColor: Color

    @State private var viewModel = SocialChatViewModel()

    var body: some View {
        ChatView(messages: viewModel.messages) { draft in
            viewModel.send(draft)
        } messageBuilder: { parameters in
            if let rawKind = parameters.message.customData["prototypeCardKind"] as? String,
               let kind = PrototypeSocialCardKind(rawValue: rawKind) {
                SocialResourceCard(kind: kind) { notice in
                    viewModel.notice = notice
                }
            } else {
                parameters.defaultMessageView()
            }
        }
        .setAvailableInputs([.text])
        .chatTheme(themeColor: .accentColor, background: .static(backgroundColor))
        .keyboardDismissMode(.interactive)
        .navigationTitle(conversation.name)
        .navigationBarTitleDisplayMode(.inline)
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
}

#Preview("Group room with Torah resource") {
    NavigationStack {
        SocialRoomView(
            conversation: PrototypeFixtures.socialConversations[1],
            backgroundColor: Color(uiColor: .systemBackground)
        )
    }
}

