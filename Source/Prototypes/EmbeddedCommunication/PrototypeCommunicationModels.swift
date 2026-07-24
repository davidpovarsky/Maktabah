import Foundation

enum PrototypeSurfacePresentation {
    case modal
    case inspector
}

enum PrototypeAIRole: Equatable, Sendable {
    case user
    case assistant
}

struct PrototypeAICitation: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
}

struct PrototypeAIToolAction: Sendable {
    let title: String
    let result: String
    let buttonTitle: String
}

struct PrototypeAIContextAttachment: Sendable {
    let title: String
    let detail: String
    let systemImage: String
}

struct PrototypeAIMessage: Identifiable, Sendable {
    let id: UUID
    let role: PrototypeAIRole
    var markdown: String
    let reasoning: [String]
    let citations: [PrototypeAICitation]
    let toolAction: PrototypeAIToolAction?
    let attachment: PrototypeAIContextAttachment?

    init(
        id: UUID = UUID(),
        role: PrototypeAIRole,
        markdown: String,
        reasoning: [String] = [],
        citations: [PrototypeAICitation] = [],
        toolAction: PrototypeAIToolAction? = nil,
        attachment: PrototypeAIContextAttachment? = nil
    ) {
        self.id = id
        self.role = role
        self.markdown = markdown
        self.reasoning = reasoning
        self.citations = citations
        self.toolAction = toolAction
        self.attachment = attachment
    }
}

enum PrototypeConversationKind: Hashable, Sendable {
    case direct
    case studyGroup
    case workGroup
}

struct PrototypeConversation: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let initials: String
    let lastMessage: String
    let time: String
    let unreadCount: Int
    let kind: PrototypeConversationKind
    let isTyping: Bool
    let hasDraft: Bool
    let isLinkedToHostContent: Bool
}

enum PrototypeSocialCardKind: String, Sendable {
    case resource
    case image
}
