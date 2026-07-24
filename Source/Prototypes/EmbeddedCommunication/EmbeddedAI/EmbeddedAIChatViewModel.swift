import Foundation
import Observation

@MainActor
@Observable
final class EmbeddedAIChatViewModel {
    var messages: [PrototypeAIMessage]
    var composerText = ""
    var pendingAttachment: PrototypeAIContextAttachment?
    var isStreaming = false
    var notice: String?

    private var streamingTask: Task<Void, Never>?

    init(messages: [PrototypeAIMessage] = PrototypeFixtures.aiMessages) {
        self.messages = messages
    }

    func startNewConversation() {
        stopStreaming()
        messages = []
        composerText = ""
        pendingAttachment = nil
    }

    func toggleContextAttachment() {
        if pendingAttachment == nil {
            pendingAttachment = PrototypeAIContextAttachment(
                title: "Visible passage",
                detail: "Local reader context only",
                systemImage: "text.quote"
            )
        } else {
            pendingAttachment = nil
        }
    }

    func simulateMicrophone() {
        notice = "Voice input is a visual prototype and did not record audio."
    }

    func send(context: PrototypeHostContext) {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        messages.append(
            PrototypeAIMessage(
                role: .user,
                markdown: trimmed,
                attachment: pendingAttachment
            )
        )
        composerText = ""
        pendingAttachment = nil

        let responseID = UUID()
        messages.append(
            PrototypeAIMessage(
                id: responseID,
                role: .assistant,
                markdown: "",
                reasoning: [
                    "Read the local context label and visible excerpt.",
                    "Prepared a short mock response using fixture data only."
                ],
                citations: [
                    PrototypeAICitation(
                        id: "current-context",
                        title: context.title,
                        detail: context.detail ?? "Current reader context"
                    )
                ],
                toolAction: PrototypeAIToolAction(
                    title: "Searching linked sources…",
                    result: "Found 8 related sources",
                    buttonTitle: "View sources"
                )
            )
        )

        let response = """
        **Mock response:** The current passage connects the event’s historical account with the later practice of praise and thanksgiving.

        This answer was generated entirely on-device from prototype fixtures; no network request was made.
        """

        isStreaming = true
        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self else { return }
            for word in response.split(separator: " ", omittingEmptySubsequences: false) {
                if Task.isCancelled { break }
                try? await Task.sleep(for: .milliseconds(34))
                if Task.isCancelled { break }
                guard let index = messages.firstIndex(where: { $0.id == responseID }) else { break }
                messages[index].markdown += messages[index].markdown.isEmpty ? String(word) : " \(word)"
            }

            if let index = messages.firstIndex(where: { $0.id == responseID }),
               messages[index].markdown.isEmpty {
                messages.remove(at: index)
            }
            isStreaming = false
            streamingTask = nil
        }
    }

    func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        if let last = messages.last, last.role == .assistant, last.markdown.isEmpty {
            messages.removeLast()
        }
        isStreaming = false
    }
}
