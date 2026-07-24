import Foundation
import ExyteChat

enum PrototypeFixtures {
    static let aiMessages: [PrototypeAIMessage] = [
        PrototypeAIMessage(
            role: .user,
            markdown: "Summarize the discussion around **מאי חנוכה** and show me where the answer comes from."
        ),
        PrototypeAIMessage(
            role: .assistant,
            markdown: """
            The passage frames Hanukkah through three connected ideas:

            1. the historical event;
            2. the miracle of the oil;
            3. the obligation to mark the days with praise and thanksgiving.

            The linked sources below provide the surrounding discussion and a parallel formulation.
            """,
            reasoning: [
                "Reviewed the current reader context and identified the active tractate passage.",
                "Compared the excerpt with nearby linked-source metadata supplied by the local prototype fixtures.",
                "Prepared a concise synthesis without changing the book, annotations, or source inspector."
            ],
            citations: [
                PrototypeAICitation(
                    id: "shabbat-21b",
                    title: "Shabbat 21b",
                    detail: "The current passage beginning “מאי חנוכה…”"
                ),
                PrototypeAICitation(
                    id: "al-hanissim",
                    title: "Al HaNissim",
                    detail: "A parallel liturgical summary of the event"
                )
            ],
            toolAction: PrototypeAIToolAction(
                title: "Searching linked sources…",
                result: "Found 8 related sources",
                buttonTitle: "View sources"
            ),
            attachment: PrototypeAIContextAttachment(
                title: "Reader context",
                detail: "Current book and visible passage attached locally",
                systemImage: "book.pages"
            )
        )
    ]

    static let socialConversations: [PrototypeConversation] = [
        PrototypeConversation(
            id: "david-miriam",
            name: "Miriam Cohen",
            initials: "MC",
            lastMessage: "The Rambam source fits this reading.",
            time: "10:42",
            unreadCount: 0,
            kind: .direct,
            isTyping: false,
            hasDraft: false,
            isLinkedToHostContent: true
        ),
        PrototypeConversation(
            id: "daf-yomi",
            name: "Daf Yomi Study Group",
            initials: "DY",
            lastMessage: "Eli: I shared today’s passage.",
            time: "10:18",
            unreadCount: 3,
            kind: .studyGroup,
            isTyping: false,
            hasDraft: false,
            isLinkedToHostContent: true
        ),
        PrototypeConversation(
            id: "source-review",
            name: "Source Review",
            initials: "SR",
            lastMessage: "Noa is typing…",
            time: "09:54",
            unreadCount: 0,
            kind: .workGroup,
            isTyping: true,
            hasDraft: false,
            isLinkedToHostContent: true
        ),
        PrototypeConversation(
            id: "jerusalem-chevruta",
            name: "Jerusalem Chevruta",
            initials: "JC",
            lastMessage: "Can we compare the two versions?",
            time: "Yesterday",
            unreadCount: 7,
            kind: .studyGroup,
            isTyping: false,
            hasDraft: false,
            isLinkedToHostContent: false
        ),
        PrototypeConversation(
            id: "rabbi-levi",
            name: "Rabbi Levi",
            initials: "RL",
            lastMessage: "Draft: I think the second source…",
            time: "Yesterday",
            unreadCount: 0,
            kind: .direct,
            isTyping: false,
            hasDraft: true,
            isLinkedToHostContent: false
        ),
        PrototypeConversation(
            id: "translation-team",
            name: "Translation Team",
            initials: "TT",
            lastMessage: "Sara: Updated the terminology notes.",
            time: "Mon",
            unreadCount: 0,
            kind: .workGroup,
            isTyping: false,
            hasDraft: false,
            isLinkedToHostContent: true
        )
    ]

    static let currentUser = User(
        id: "current-user",
        name: "David",
        avatarURL: nil,
        isCurrentUser: true
    )

    static let miriam = User(
        id: "miriam",
        name: "Miriam",
        avatarURL: nil,
        isCurrentUser: false
    )

    static let eli = User(
        id: "eli",
        name: "Eli",
        avatarURL: nil,
        isCurrentUser: false
    )

    static let systemUser = User(
        id: "system",
        name: "Maktabah",
        avatarURL: nil,
        type: .system
    )

    static let groupMessages: [ExyteChat.Message] = [
        Message(
            id: "welcome",
            user: systemUser,
            status: .read,
            createdAt: Date(timeIntervalSinceNow: -4_200),
            text: "Miriam created the study room."
        ),
        Message(
            id: "opening",
            user: miriam,
            status: .read,
            createdAt: Date(timeIntervalSinceNow: -3_600),
            text: "I think the opening question is doing more than introducing the historical account."
        ),
        Message(
            id: "reply",
            user: currentUser,
            status: .read,
            createdAt: Date(timeIntervalSinceNow: -3_100),
            text: "Agreed — it also sets up why these days were established.",
            replyMessage: ReplyMessage(
                id: "opening",
                user: miriam,
                createdAt: Date(timeIntervalSinceNow: -3_600),
                text: "I think the opening question is doing more than introducing the historical account."
            )
        ),
        Message(
            id: "long-message",
            user: eli,
            status: .read,
            createdAt: Date(timeIntervalSinceNow: -2_400),
            text: "The longer literary arc matters here. The question, the account of the oil, and the closing language about praise form one unit rather than three unrelated details.",
            reactions: [
                Reaction(user: currentUser, type: .emoji("👍"), status: .sent),
                Reaction(user: miriam, type: .emoji("💡"), status: .sent)
            ]
        ),
        Message(
            id: "resource-card",
            user: miriam,
            status: .read,
            createdAt: Date(timeIntervalSinceNow: -1_500),
            text: "Shared a source",
            customData: [
                "prototypeCardKind": PrototypeSocialCardKind.resource.rawValue
            ]
        ),
        Message(
            id: "image-card",
            user: eli,
            status: .read,
            createdAt: Date(timeIntervalSinceNow: -900),
            text: "Photo from our study table",
            customData: [
                "prototypeCardKind": PrototypeSocialCardKind.image.rawValue
            ]
        ),
        Message(
            id: "link",
            user: currentUser,
            status: .delivered,
            createdAt: Date(timeIntervalSinceNow: -420),
            text: "This outline may help: https://example.com/study-outline"
        )
    ]
}
