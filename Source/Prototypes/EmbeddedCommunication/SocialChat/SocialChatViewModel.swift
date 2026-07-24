import ExyteChat
import Foundation
import Observation

@MainActor
@Observable
final class SocialChatViewModel {
    var messages: [ExyteChat.Message]
    var notice: String?

    init(messages: [ExyteChat.Message]? = nil) {
        self.messages = messages ?? PrototypeFixtures.groupMessages
    }

    func send(_ draft: DraftMessage) {
        let trimmed = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(
            Message(
                id: UUID().uuidString,
                user: PrototypeFixtures.currentUser,
                status: .sent,
                createdAt: .now,
                text: trimmed,
                replyMessage: draft.replyMessage
            )
        )
    }
}
