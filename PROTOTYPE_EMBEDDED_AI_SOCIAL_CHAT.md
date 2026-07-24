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
- `Source/Prototypes/EmbeddedCommunication/MaktabahCommunicationInspectorView.swift`
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
- `Scripts/verify-embedded-frameworks.sh`

## Existing files changed

- `Source/iOS/Views/Reader/iOSReaderView.swift` — replaces the two communication sheets and the sources-only inspector with one reader inspector.
- `Source/Otzaria/Reading/OtzariaReaderSourcesInspectorHost.swift` — allows the unified host to own the close action.
- `EmbeddedAIChatView.swift`, `SocialConversationListView.swift`, and `SocialRoomView.swift` — add an embedded inspector presentation while retaining modal previews.
- `Maktabah.xcodeproj/project.pbxproj` — adds the exact Giphy package/product to the iOS target and corrects the iOS runpath.
- `.github/workflows/ios-build.yml` — verifies all embedded `@rpath` dependencies for simulator and device products, launches the simulator app, and captures runtime evidence.

The Otzaria selection adapter and source lookup path are unchanged. Switching from Sources to AI or Chats does not call `closeOtzariaSourcesInspector()`, so cached results, the line anchor, and source navigation remain intact. The existing full-close behavior is used only when the entire inspector closes.

## Launch crash and packaging fix

The original app terminated before SwiftUI startup with `DYLD Library missing` because the Maktabah executable referenced `@rpath/GiphyUISDK.framework/GiphyUISDK`, but the framework was absent from `Maktabah.app/Frameworks`. Exyte Chat was linked, but its dynamic Giphy dependency was only transitive, so Xcode did not copy that product into this target. The iOS configurations also used the macOS-style `@executable_path/../Frameworks` runpath.

The standard SPM fix is:

- retain Exyte Chat at revision `554a0798e424ff15440d5af3b675cc9a5e65b759`;
- add one direct `https://github.com/Giphy/giphy-ios-sdk` package reference at exact version `2.2.16`;
- add `GiphyUISDK` to the `Maktabah-iOS` target's package products and Frameworks build phase;
- use `$(inherited)` and `@executable_path/Frameworks` for iOS Debug and Release;
- let Xcode's standard Swift-package embedding copy the binary—there is no DerivedData copy script and no checked-in binary.

The final device `otool -L` evidence includes:

```text
Maktabah.app/Maktabah:
    @rpath/GiphyUISDK.framework/GiphyUISDK (compatibility version 1.0.0, current version 1.0.0)
```

The generic verifier inspected both the main executable and the embedded Giphy executable and reported:

```text
Verified 2 Mach-O binary/binaries: every @rpath framework dependency is embedded.
```

Both the device app and the unsigned IPA contain:

```text
Payload/Maktabah.app/Frameworks/GiphyUISDK.framework/GiphyUISDK
Payload/Maktabah.app/Frameworks/GiphyUISDK.framework/Info.plist
```

## How to open the prototype

1. Launch the iOS app, configure the library database, and open a book in the reader.
2. Tap linked text to open **Sources** in the unified reader inspector.
3. In the reader’s top trailing toolbar:
   - tap `sparkles` to open the same inspector on **AI**;
   - tap `bubble.left.and.bubble.right` to open it on **Chats**.
4. Use the **Sources / AI / Chats** segmented control to switch without closing the inspector. Tapping the toolbar button for the already-selected section closes it.
5. In Chats, select **Daf Yomi Study Group** to see the Exyte Chat room and Torah resource card.

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
2. Revert the prototype-only additions in `Source/iOS/Views/Reader/iOSReaderView.swift` and `Source/Otzaria/Reading/OtzariaReaderSourcesInspectorHost.swift`.
3. Remove the `D0EC…` prototype objects and Exyte Chat/Giphy package-product entries from `Maktabah.xcodeproj/project.pbxproj`.
4. Delete this document.

## Screenshots

The final CI diagnostics contain `launch-simulator.png`, which shows Maktabah running at its clean-install database setup screen. Inspector-state screenshots were not captured because the clean ephemeral runner has no configured Maktabah database/book fixture and the app has no UI-test path that can seed one.

## Build results

- Final runtime verification: [iOS Build run 30091324308](https://github.com/davidpovarsky/Maktabah/actions/runs/30091324308) succeeded for commit `a4201e94b47977bdd48bbc663ca5dd344a4cd11e`.
- Environment: `macos-26`, Xcode 26, `Maktabah.xcodeproj`, `Maktabah-iOS` scheme.
- Package resolution retained Exyte Chat at the pinned revision and resolved Giphy `2.2.16`.
- The unsigned Debug simulator build succeeded, passed the recursive `otool -L` verifier, installed with `simctl install`, and launched as `com.Drn.maktabah`.
- Launch output was `com.Drn.maktabah: 16661`; after ten seconds the workflow confirmed `Maktabah remained alive for 10 seconds after launch (PID 16661)`. The captured system log contains no `DYLD Library missing` termination.
- The unsigned Release device build also passed the recursive verifier. `find` showed `Maktabah.app/Frameworks/GiphyUISDK.framework/GiphyUISDK`, and the uploaded IPA contains the Giphy executable and `Info.plist`.
- The workflow uploaded `Maktabah-iOS-simulator-app`, `Maktabah-iOS-unsigned-ipa-not-installable`, `zayit-configured-xcode-project`, and `build-logs`.
- Existing Otzaria and Zayit Search preparation/build steps remain in the workflow and succeeded.
