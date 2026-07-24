import SwiftUI

struct SocialConversationRow: View {
    let conversation: PrototypeConversation

    private var groupSymbol: String? {
        switch conversation.kind {
        case .direct:
            nil
        case .studyGroup:
            "person.3.fill"
        case .workGroup:
            "person.2.badge.gearshape.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(.tint.opacity(0.14))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(conversation.initials)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.tint)
                    }

                if let groupSymbol {
                    Image(systemName: groupSymbol)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.tint, in: .circle)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(conversation.time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    if conversation.hasDraft {
                        Text("Draft")
                            .foregroundStyle(.red)
                    }
                    Text(conversation.isTyping ? "Typing…" : conversation.lastMessage)
                        .foregroundStyle(conversation.isTyping ? .tint : .secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if conversation.isLinkedToHostContent {
                        Image(systemName: "link.circle.fill")
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Linked to Maktabah content")
                    }
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.tint, in: .capsule)
                            .accessibilityLabel("\(conversation.unreadCount) unread messages")
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 60)
        .contentShape(.rect)
    }
}
