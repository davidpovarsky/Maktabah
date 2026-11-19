# Original Hanlin consumer composition in Otzaria

Status: source implementation and real filesystem proof complete; Apple app and native journeys remain pending. This is the actual SwiftUI/iOS 27 Maktabah application. It does not replace the reader, action core, native router, SDK engine or presentation products.

## Source identity and actual dependencies

The app retains the complete original Hanlin repository at 873607e45e021b40fe5b940c836d398c329f95c8 in Vendor/HanlinSDK. Its 421 package files were verified against immutable Git blobs. The only SDK compatibility change at that source is the reviewed ZIPFoundation range; this consumer keeps its exact existing ZIPFoundation 0.9.20 pin.

The real app target now links original HanlinAgentCore, HanlinHostContracts, HanlinPlatformContracts, HanlinChatCore, HanlinScriptUI, HanlinChatUI, HanlinPresentationKit and HanlinRichUI from their three original packages. Actual SwiftPM resolution retained all nine previous remote pin states and added exactly eight dependencies for the original Markdown product. No version requirement or source verifier was relaxed.

dependency-resolution.json records the actual resolver command and result. dependency-lock-review.json binds the committed lock to the eight additions. This resolution is dependency evidence, not Apple compilation.

## Actual native composition

The existing scene registration creates one OtzariaHanlinChatOwner. Existing global and reader toolbars open its real SwiftUI sheet. The presented window must match the same native scene. Original profile UUID, study-group UUID and selected backend own the conversation namespace.

The original HanlinAgentSession and HanlinAISDKAgentEngine use the existing OtzariaHanlinHostAdapter, which calls the application's existing ActionCore. Its advertised metadata actions remain system.listBackends, catalog.resolveWork and catalog.resolveReference. There is no inferred book-text or selection-read grant and no declaration that all registered actions work.

The UI uses original HanlinChatView, Markdown, OpenUIInlineParts/OpenUIBlock, message presentation state, disclosure, Morph composer, native editor and send controls. App/conversation profile assignment and each assistant message's catalog/form state remain distinct. Both native and React forms share the original per-message state owner; no model-issued native actions are advertised by this metadata-only host.

Connection fields use an explicit user-provided HTTPS service address, model and key. The key stays in the current SDK engine and is discarded when that presentation closes. Loading saved messages does not require reconnecting and cannot restore a credential or execution lease.

## Durable host history

OtzariaHanlinConversationStore is one app-owned MainActor writer under Application Support/ChavrusaText/HanlinConversations/v1. It never writes the existing reader/workspace files or migrates legacy records. Per-profile, group and backend directories hold independent conversation envelopes.

Actual user messages, draft, presentation snapshots, source links, reasoning and tool activity have their own revision. Original SDK conversation metadata has a separate revision/field; user history never overloads SDK draft metadata. Both paths share the exact scoped store lease, and each update preserves the other field. Merely opening/closing a new empty picker does not create a saved chat. Draft-only conversations retain their own meaningful title; metadata-only records stay out of the user history list.

Atomic writes, bounded reads, exact namespaces, live authority, independent CAS revisions and content-free deletion tombstones prevent stale writes or delayed initial SDK saves from replacing or resurrecting user content. Only an actual no-such-file read means missing. Corrupt/future/permission failures preserve the existing generation and report failure. iOS requests complete file protection; no physical-device protection result is claimed here.

## Original source navigation

A source button is projected only from the original SDK's correlated catalog.resolveReference receipt, with exact session, request, backend and generation checks. The original identity bridge, reader destination resolver and public-v2 codec create the public source URL. Saved URLs contain no execution lease and require fresh validation on every user click.

Opening a source queues the exact original native route without claiming a UI effect. The SDK presentation revokes first; the actual onDismiss releases its native modal block. A one-use app-owned continuation then rechecks the original scene, mapping and backend and enters the existing native orchestrator. Only its matching route/content/native-visible receipt may become the app's navigation receipt. That receipt is never delivered as success to an already-retired SDK session.

Original native routes remain blocked while the chat or its dismissal is visible. Changing scene, foreground state, mapping, account/group or backend invalidates the original registration. No global-window selection or fabricated native acknowledgement is used.

## Executed evidence

The original contracts/presentation modules, complete original message DTO and complete new application store compiled and executed in Swift 6 with strict concurrency on Windows Swift 6.3.3. Eleven behavioral tests passed against actual files:

- Complete transcript/OpenUI/draft reopen, separate SDK metadata, and meaningful draft-only history.
- Two independent store instances with stale-history and stale-delete conflicts.
- Foreign namespace/conversation and revoked-owner rejection.
- Actual asynchronous original store-port call after authority changes.
- User deletion followed by a delayed first SDK save, with no content resurrection.
- Real operating-system file lock causing atomic replacement to fail, preserving original bytes and revision.
- Corrupt/future records preserved; foreign message/source identity rejected before disk writes.
- Original native/React message field and disclosure state retained across host and SDK updates.

The driver is tools/hq-hanlin-consumer-store.py; the raw output, complete input hashes and exact boundary are retained beside this document. The test module uses explicit DTO/catalog/authority fixtures. It does not execute a model, UIKit, native reader, cloud account or signed device. The remaining warning lines are generated SwiftPM XCTest discovery isolation diagnostics, not production-store diagnostics.

## Apple and genuine UI gates

The original UI SDK gate now includes the new filesystem proof and HanlinConsumerAcceptanceTests. The real native test launches normal app bootstrap (no smoke bypass), opens the original global chat, configures an explicitly unused model credential, types an RTL/multiline draft, dismisses/reopens through the actual history list, terminates the target and verifies the same draft in a new process. It also requires that credentials remain absent and Send remains disabled after restoration. It never sends a model request and cannot count as provider acceptance.

The existing focused Apple app gate retains exact Source/Vendor/project trees, original SDK byte checks, original React/Pods/Zayit preparation and locked package checks. Native source-opening, actual tool/model streaming, both renderer forms, lifecycle/focus/RTL matrices, physical protection and signed distribution remain required follow-on evidence. No pending gate is converted to PASS by source review or these filesystem tests.
