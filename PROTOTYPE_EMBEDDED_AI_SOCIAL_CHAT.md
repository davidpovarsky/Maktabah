# Embedded AI and social chat prototype

## Purpose

This branch is a visual, interactive iPhone/iPad experiment that embeds two local-only communication surfaces in the Maktabah reader:

- an AI assistant informed by the current book and visible passage;
- a social conversation list and Exyte Chat room with Maktabah resource cards.

There is no backend, user login, Matrix integration, AI provider, API key, shared database, CloudKit/App Group/Keychain sharing, push notification, or new network request. Sending, streaming, citations, source opening, voice input, attachments, and tool actions are mock interactions backed by in-memory fixtures.

## Source and experiment branches

- Source branch: `fix/ipad-manual-sidebar-toggle-keep-inspector-cache-20260708`
- Source HEAD: `a75e8b3664108f97bee270d284316f7aaebba913`
- Experiment branch: `codex/prototype-embedded-ai-social-chat-20260724`

## Open-source references

- SwiftChat visual/interaction reference: `sachaservan/SwiftChat` at `d6f54ccf9e84d2fec672b7b89d5a67dd6ee0f957`
- Exyte Chat Swift package: `exyte/Chat` at exact revision `554a0798e424ff15440d5af3b675cc9a5e65b759`
- SwiftChat attribution: `Source/Prototypes/EmbeddedCommunication/SwiftChat-ATTRIBUTION.md`

The SwiftChat entry point, storage, API-key handling, network layer, OpenAI integration, and bundle configuration were intentionally not included.

## Added files

- `Source/Prototypes/EmbeddedCommunication/PrototypeCommunicationModels.swift`
- `Source/Prototypes/EmbeddedCommunication/PrototypeFixtures.swift`
- `Source/Prototypes/EmbeddedCommunication/PrototypeHostContext.swift`
- `Source/Prototypes/EmbeddedCommunication/SwiftChat-ATTRIBUTION.md`
- `Source/Prototypes/EmbeddedCommunication/EmbeddedAI/EmbeddedAIChatView.swift`
- `Source/Prototypes/EmbeddedCommunication/EmbeddedAI/EmbeddedAIChatViewModel.swift`
- `Source/Prototypes/EmbeddedCommunication/EmbeddedAI/EmbeddedAIMessageView.swift`
- `Source/Prototypes/EmbeddedCommunication/EmbeddedAI/EmbeddedAIComposer.swift`
- `Source/Prototypes/EmbeddedCommunication/EmbeddedAI/EmbeddedAIReasoningView.swift`
- `Source/Prototypes/EmbeddedCommunication/EmbeddedAI/EmbeddedAICitationView.swift`
- `Source/Prototypes/EmbeddedCommunication/EmbeddedAI/EmbeddedAIToolCard.swift`
- `Source/Prototypes/EmbeddedCommunication/EmbeddedAI/EmbeddedAIContextHeader.swift`
- `Source/Prototypes/EmbeddedCommunication/SocialChat/SocialConversationListView.swift`
- `Source/Prototypes/EmbeddedCommunication/SocialChat/SocialConversationRow.swift`
- `Source/Prototypes/EmbeddedCommunication/SocialChat/SocialRoomView.swift`
- `Source/Prototypes/EmbeddedCommunication/SocialChat/SocialResourceCard.swift`
- `Source/Prototypes/EmbeddedCommunication/SocialChat/SocialChatViewModel.swift`

## Existing files changed

- `Source/iOS/Views/Reader/iOSReaderView.swift` — adds two toolbar buttons, local sheet state, and the narrow host-context bridge.
- `Maktabah.xcodeproj/project.pbxproj` — adds only the isolated prototype files and the exact Exyte Chat package/product to the iOS target.

The existing Otzaria sources inspector visibility, presentation, selection adapter, cache, and close behavior were not changed.

## How to open the prototype

1. Launch the iOS app and open a book in the reader.
2. In the reader’s top trailing toolbar:
   - tap `sparkles` to open **AI Assistant**;
   - tap `bubble.left.and.bubble.right` to open **Social Chat**.
3. In Social Chat, select **Daf Yomi Study Group** to see the Exyte Chat room and Torah resource card.

## Mock-only behavior

- AI responses stream from a local string with `Task.sleep`; **Stop** cancels the local task.
- Reasoning text is illustrative UI copy, not model chain-of-thought.
- Citations, linked-source search results, source opening, attachments, and microphone actions are simulated.
- Social conversations and messages live only in memory.
- Resource-card buttons show local prototype feedback and do not navigate or modify user data.

## Intentionally not implemented

- Backend, authentication, Matrix, Firebase, AI-provider calls, API keys, persistence, synchronization, real attachments/recording, notifications, and network transport.
- Changes to the reader’s data model, navigation architecture, selection system, database, or sources inspector.

## Removal

1. Remove `Source/Prototypes/EmbeddedCommunication/`.
2. Revert the prototype-only additions in `Source/iOS/Views/Reader/iOSReaderView.swift`.
3. Remove the `D0EC…` prototype objects and Exyte Chat package/product entries from `Maktabah.xcodeproj/project.pbxproj`.
4. Delete this document.

## Screenshots

Not produced in the Windows editing environment. Simulator screenshots should be captured from the verified Xcode build if a macOS runner or local Mac simulator is available.

## Build results

Pending GitHub Actions verification with the repository’s `Maktabah-iOS` scheme and configured stable Xcode runner.

