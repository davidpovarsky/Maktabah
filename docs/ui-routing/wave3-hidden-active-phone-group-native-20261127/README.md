# Native selectors: already-active hidden phone workspace Reader

Six additive phone selectors target the narrow production behavior delivered by the separate hidden Group/Profile source packet. They invoke the real `OpenStudyTabGroupIntent` or `OpenStudyProfileIntent` with one actual system-discovered cached entity. The measured invocation has no private chooser, direct perform call, fabricated entity reference, app-activation fallback, or source mutation.

| Selector | Target | Original starting surface |
| --- | --- | --- |
| `testPhoneGroupIntentPresentsSameActiveHiddenReaderFromLibrary` | Current group | Library after original Back |
| `testPhoneProfileIntentPresentsSameActiveHiddenReaderFromLibrary` | Current profile's first ordered group | Library after original Back |
| `testPhoneGroupIntentPresentsSameActiveHiddenReaderFromBackground` | Current group | Background after original Back |
| `testPhoneProfileIntentPresentsSameActiveHiddenReaderFromBackground` | Current profile's first ordered group | Background after original Back |
| `testPhoneGroupIntentPresentsSameActiveHiddenReaderFromOriginalHistory` | Current group | Original History |
| `testPhoneProfileIntentPresentsSameActiveHiddenReaderFromOriginalSearch` | Current profile's first ordered group | Original Search |

Setup uses the original canonical Reader fixture and independent sealed SQL/TextKit oracle. The test captures the original persisted scene/profile/group/tab/work, original document semantics, and process identity. It independently derives the expected metadata identifier and compares it with the real system entity, while delivery always uses that actual entity. The original Back control hides the Reader; retained active tab and document state must remain unchanged and no selection receipt may appear during setup. Profile tests explicitly require the original first ordered group to be the same retained active group.

The measured result requires the actual original Reader/TextKit locator, exact scene/profile/group/active tab and order, preserved original source/search/document semantics, and exactly one strict `native.workspace.selection` receipt from the same original scene. A two-second post-acknowledgement check catches later state, receipt, geometry, or locator drift.

## Source and integration

The helper is an explicit append-only suffix. Its frozen baseline is the complete 375,434-byte original `NativeRoutingAcceptanceTests.swift` at `b463ffd03a76026cea06c79c608df97d00094152`, SHA256 `2157fe667fc215e3ac46e8115a1b1731dc96874cf06bb8d4ee880e5d35f9b74e`. Root is integrating the separate Annotation suffix, yielding 407,115 bytes / SHA256 `93fade04cfeb99c75870f886d211d7144fc20e952ac0c8b56eb385cabc24b01f`. This packet never rewrites either shared prefix. Root appends the exact suffix to its observed current helper and records that join.

The dedicated selector file belongs in `Maktabah-iOSUITests`. Its original filesystem-synchronized target includes new files without a PBX source entry. No product, shared Session/Composition, PBX, or existing test body is changed by this packet.

## Qualification

Only original-source joins and complete-file frontend parsing are performed here. No actual application SDK typecheck, AppIntents metadata validation, simulator execution, device execution, production run, or native PASS is claimed. These selectors use the original miniTest10 fixture. Positive document equality deliberately excludes full viewport, selected range, and TOC restoration. Relaunch, rotation, multiple windows, VoiceOver, physical QA, and broader Workspace restoration remain separate acceptance items.
