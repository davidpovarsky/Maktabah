# Hanlin Host API 1.2 integration — 20 November 2026

## Scope and immutable dependencies

- Application base: `508d15149b5c1ba0d9949279755ba286fd57a138`.
- Isolated branch: `codex/otzaria-hanlin-api12-20261120`.
- Original Hanlin SDK: `e00498e33f106cc43be0476ffa2e09329c8ca300`, whose API 1.2 product change is `d49801160dd7e84d84db3903a0c6f7dedfe9c017`.
- The original three nested packages and their layout are retained. The existing preparation verifier checked 424 package files against their Git blobs. No SDK sources were edited or copied into application source.
- Current maintained Maktabah upstream HEAD was independently read as `d46af139b3a265399c16d87f5923acd8e3444024`. No upstream merge was attempted.

## Product changes

The thin transport implements the original `HanlinHostNavigationTransitionSource` protocol and Host API 1.2. It checks the actual host session, original navigation scope and foreground identity before admitting one request. A queued request cannot claim presentation. A correlated native receipt is retained before cancellation/freshness checks can suppress delivery; an uncertain operation is never repeated automatically.

A source button keeps the existing UI behavior: the chat closes, its original model task stops, and native navigation begins only after the actual sheet dismissal. The original `HanlinHostDispatcher` now receives the result of the existing Core/Scene Orchestrator route. Only the same native registration, account/profile, workspace/group and backend observed after the exact native acknowledgement can issue the successor. The source-button path records the receipt and closes that temporary successor rather than silently resuming a model or reusing consent. It does not claim a continuing multi-step model conversation.

The live context now carries a canonical public Reader reference and active-tab identity. Every authority check additionally compares the current Reader destination and the canonical selected-range freshness facet, so a new page/focus inside the same book cannot reuse an earlier context. These are metadata references. Existing content and selection access remains denied until an original host rights/consent producer is available.

The original AgentSession invalidation callback now ignores an already-revoked presentation. This prevents the delayed callback from echoing a second close and cancelling a navigation that intentionally retained its host identity through dismissal.

## Ownership and preservation

| File or surface | Classification | Change |
| --- | --- | --- |
| Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinHostAdapter.swift | Downstream transport, original introduction 5f1dea3215441abeb709713dd174aac3fa57cfd0 | Add the original API1.2 capability, typed session/scope validation, bounded request admission and retained receipts |
| Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatOwner.swift | Downstream scene-owned composition | Preserve host identity until actual dismissal and consume original dispatcher transition |
| Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift | Downstream original SDK consumer | Ignore invalidation echo after explicit presentation revocation |
| Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift | Downstream integration seam, original introduction d337c60896c6ef24af277697e6012ae1595c0335 | Fresh metadata context and original native acknowledgement to SDK successor mapping |
| Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift | Downstream scene projection | Read-only accessor to original selected-range identity for freshness; no selected text exposed |
| Vendor/HanlinSDK | Original separately maintained SDK gitlink | Advance only to the exact independently Apple-tested API1.2 commit |
| Tests/HQ/hanlin-host/OtzariaHanlinHostAdapterTests.swift | Downstream component tests | Seven transition boundary cases and two actual original dispatcher-to-adapter cases |
| tools/hq-hanlin-host-contracts.py | Downstream targeted validation harness | Compile the whole thin adapter plus the whole original dispatcher; sibling ChatUI/store components retain their separate dependency graph |

No original upstream UI source, renderer, data files, conversation-store implementation, credentials, shared registry initializers, global Native selection, or source-freeze inputs were modified by this change. The existing user authorization covers the integration and dependency pin. All previous source and evidence are retained.

## Validation record

- Initial component command: FAILED during compilation because its old recursive source selection pulled in the separate conversation store without HanlinChatCore/HanlinPresentationKit. It executed zero tests; this is preserved in `initial-harness-failure/`.
- Corrected command: PENDING collection in `host-tests/`.
- Windows syntax-only parsing of the five changed production files: exit 0 for each. This is not Apple typechecking.
- Git whitespace/error check: passed.
- Original SDK package-byte verification: 424 files passed.

The component suite compiles unchanged original Platform/Host contracts, unchanged original HostDispatcher, actual ActionCore and actual OtzariaHanlinHostAdapter. Backend/authority/native-receipt fixtures are explicit doubles. It does not execute AgentSession, a provider, UIKit, SwiftUI, or a device.

## Remaining acceptance

UI-06 stays OPEN. The newly changed app still requires an Apple SDK full-app build and Native regression of chat/draft/relaunch/reader return and the source-link transition. Three real-model multi-step Core/UI journeys, content/selection permission, physical iPad/system acceptance and release acceptance are not established by component tests or source inspection. No Native result from an earlier commit is transferred to this source.

The previous SDK limitation-reproduction suite using `080d1a2b264ead9e3f9df690f2dd0d3e81ebd07e` remains historical evidence. It must not be relabeled as API1.2 acceptance. Parent integration owns the refreshed global source/dependency freeze and native test dispatch.
