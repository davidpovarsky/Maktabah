# Original search continuation: Wave3 integration seam

This packet is separate from the original first-page action. It adds no public App Intent hit/cursor parameters and does not change `NativeSearchIntentService.open`, `ActionSearchResultsQuery`, the original first-page completion binding, SceneSession, registry or Composition. Wave3 owns that integration and the final app/native acceptance.

## Source and exact branch

Original integrated baseline: `15d283aa0ccbbfe6966f26a2c182810cb39fdafa`.

The new isolated Oracle feature branch is `codex/otzaria-search-continuation-20261127`. Its Data worktree fast-forwarded to the exact independent passive-ledger donor `a23ae34c74b1cde8a9344fefd1e41e87101784b0`; no duplicate donor commit was made. When Data capacity became unavailable, candidate source, controls and final publication used a separate private rootfs repository with read-only alternates to the verified Data object store. The original Data branch stays at its clean donor checkpoint; publication does not mutate it. The old core/search/offline branches are unchanged. The continuation packet is for direct Wave3 intake, not for cherry-picking into the older root-core lineage.

The approved fallback component build writes only its private Oracle rootfs directory. When Data fell below the protected floor, no compilation or new candidate-source write had started there. `DATA_FLOOR_BLOCKED.json` and the distinct rootfs admission preserve that boundary. Frozen candidate/source/control receipts are retained with the actual run; a successful portable run does not qualify an Apple build.

## Typed contracts

The additive `ActionSearchContinuation.swift` contains:

- `ActionSearchContinuationSource`: original session/model IDs, source generation/revision, submission/cancel/pagination/page revisions, exact configuration bytes, scene and actual backend/RPC snapshot.
- `ActionSearchContinuationObservation`: that source, metadata and opaque tokens for current loaded original hits, and an optional opaque next-page token.
- `ActionSearchContinuationOperation.revealLoadedHit(token:)` or `.nextOriginalPage(token:)`. Neither accepts an offset, query, URL, provider name override or arbitrary locator lookup.
- `ActionSearchContinuationCommand`: the retained source, exact operation and original `ActionPortInvocation`.
- `ActionSearchContinuationOutcome.acknowledged`, `.refused`, or `.unqualified(command:originalResponse:)`. A qualified failure binds the exact request ID, original source and operation, and retains earlier effects recorded by that operation. An unqualified response remains unchanged under its original provenance; it neither completes the attempted command nor proves that command had no effects.
- Optional `ActionSearchContinuationUICommandSink`, with separate observe/apply/final-validation methods. No existing Core action validator is widened.

The metadata token is a lookup key in one original owner observation. It is not decoded as a row ID and never creates a provider query. Source or command DTOs alone confer no authority.

## Exact app binding API

Wave3 constructs one `MaktabahNativeSearchContinuationBinding` for its actual original scene and the same `UnifiedSearchSessionController` owned by that scene's navigation manager:

```swift
MaktabahNativeSearchContinuationBinding(
    sceneID: actualOriginalSceneID,
    session: actualOriginalManager.unifiedSearchSession,
    currentSnapshot: readActualOriginalBackendAndRPCEpoch
)
```

`currentSnapshot` must use the existing original backend/Action bridge. It must not invent an RPC epoch or return the command's copied snapshot.

The binding exposes:

```swift
func observe(
    invocation: ActionPortInvocation,
    retainAuthority: () throws -> (@MainActor () throws -> Void)
) throws -> ActionSearchContinuationObservation

func perform(
    _ command: ActionSearchContinuationCommand,
    validateAuthority: @escaping @MainActor () throws -> Void
) async -> ActionSearchContinuationOutcome

func validateCompletion(
    _ command: ActionSearchContinuationCommand,
    receipt: ActionSearchContinuationReceipt
) throws
```

`retainAuthority` must retain the existing original scene/workspace/parent/presentation observation, including manager identity and original scene ownership. It returns the existing live one-shot validation closure, not a constant success callback. The binding adds its own original input observation, byte-exact configuration and result identity checks, published Zayit input invalidation, mounted-list ownership, and source-owned one-use tokens.

`validateAuthority` is the current invocation's real authorization/deadline/backend/scene check. It is checked before mutation, around awaits, after actual effects, and before success. The thin `NativeSearchContinuationService` supplies this same live callback to the binding through its `Apply` closure; the wiring must forward it unchanged. Final Core/Scene authority observation must still call `validateCompletion` against the retained live model and UIKit evidence.

## Thin service composition

`NativeSearchContinuationService` is additive in the existing Host package. Its initializer accepts actual owner observe/apply/final-validation closures plus the existing authority closure; the optional clock parameter is used only by portable component controls. Production wiring uses the default monotonic clock.

The service's apply closure has the exact shape:

```swift
@MainActor (
    ActionSearchContinuationCommand,
    @escaping @MainActor () throws -> Void
) async -> ActionSearchContinuationOutcome
```

It must call the binding's `perform(_:validateAuthority:)`. The service joins acknowledgement provenance and receipt shape before any post-apply authority/cancellation check. It joins a failure by exact request ID, source and operation before assigning its effects to the current operation. Failure origin fields are optional solely to represent an unattested response; nil is never trusted. The actual original binding emits both fields from its frozen command. A foreign, malformed, unattested or already unqualified response is retained unchanged inside `.unqualified(command:originalResponse:)`, including nested wrappers. Downstream Wave3 wiring must handle this case explicitly and must not flatten those raw effects into the attempted command or infer that it had no effects.

After a response is joined, genuine earlier effects stay attached if current authority, deadline, cancellation or final native-owner/layout validation refuses. Structural validation is not a replacement for live owner validation.

An invocation that wants another page and then a hit must perform explicit separate operations. It first consumes one current original next-page token, retains that operation's outcome/receipt, then reads a fresh qualified observation and selects a token actually present in the new original list. There is no loop that searches providers for an unmaterialized hit. A failed later selection must not overwrite an earlier acknowledged first-page or continuation receipt.

## Original provider semantics

The original backend loaders remain the only query/offset/result owners. `OriginalSearchPageLedger` records their exact captured requests and actual commits. It is not a result cache, engine or DEBUG callback.

- Otzaria continues from the original consumed raw-row count. Display deduplication is not used as a cursor.
- Zayit continues from original request offset plus raw hits, preserving its original limit and filtering.
- Sefaria retains both raw provider cursor and the original normalized `BackendPaginationState` cursor. A normalized nil caused by loop protection is distinguishable from advertised exhaustion. If `LibrarySearchPage.sourceEvidence` is absent, raw rows are qualified only at the `LibrarySearchPage` boundary; wire-level API coverage is not inferred.
- Empty accepted terminal pages and wholly deduplicated pages still advance the ledger's accepted-page revision. Neither an increased dispatch counter nor a cleared loading flag alone is completion.
- A passive `TerminalCapture` is registered synchronously for the actual original attempt, before any await. An accepted commit remains available as an effect even if clear/cancel/rebind occurs before the consumer resumes. It never grants authority over the current source.

The controller's cancellation/dirty-input guards additionally inspect synchronous original leaf busy state. This closes the observed interval before the queued Unified loading mirror publishes. Cancellation uses the original cancellation path; it is allowed for a continuation only if the exact currently active ledger attempt still matches.

## Original list behavior

The existing original global `SearchResultsListView` receives only its same session's optional downstream source. Other callers keep the existing defaults. Existing grouping, original version menu, preview expansion, footer, reader Open and provider paths remain their owners.

Reveal resolves the actual current hit identity, including original locator, provider ID, exact version/language, title/reference/snippet and highlight metadata. It refuses stable-ID collisions under the original grouping semantics and refuses a filtered-out or missing hit. It sets the original matching version index, expands the original preview and scrolls to the existing original group ID. It does not clear filters or open the reader. The receipt qualifies the selected visible row/header, not completion of the preview's asynchronous full-text loading.

Success requires the actual mounted UIKit row/list in the original active key window and scene. Layout revisions advance only in actual `layoutSubviews`. The witness honors original clipping and adjusted scroll insets, rejects original modal/transition occlusion, and is revalidated against the same retained source and selected version. A request, `onAppear`, `scrollTo` call, body evaluation or visible label alone is not a receipt. While waiting for the owned updated content's real layout, the boundary check retains exact attachment/window/list ownership; initial and final acceptance still require current layout.

Each operation synchronously claims one token before touching the original loader or State. Automatic row-onAppear paging consults the live claim guard inside the callback. A local guard remains after programmatic reveal/page so delayed appearances cannot start another provider page. A real original pan gesture, new original input or explicit original Load More releases it. No recognizer/delegate is replaced. Manual scroll and original version/expansion/input changes retire the retained proof, including value restoration.

**Native qualification still required:** keyboard/VoiceOver scrolling that does not produce the original pan gesture has not been shown to restore automatic prefetch. The original explicit Load More footer remains available. No unqualified accessibility notification is used to release the guard. The new behavior must be tested on the qualified iPad and iPhone app before exposing system hit/cursor parameters.

## Project membership and shared-owner boundaries

The original project uses explicit PBXGroup membership. Wave3 owns one combined membership update for these new app files:

1. `Source/ChavrusaText/SearchContinuation/OriginalSearchPageLedger.swift` (library donor): all three original app targets, because its original search-model callers are shared.
2. `Source/ChavrusaText/SearchContinuation/OriginalSearchContinuationClaim.swift`: the iOS target only, matching its original controller caller.
3. `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchContinuation.swift`: the iOS target only, matching the original integration/UI callers.

The new Core contract and Host service reside in their existing SwiftPM Sources directories. The packet does not edit the project file, SceneSession, registry, Composition or original first-page binding. Preserve the separate first-page correction `b5f52c446a5eba31273b6e3ee61d53ba022244d5` during integration.

## Verification boundaries

The focused portable run compiles the whole original 28-file ActionCore plus the new contract; the Host module build contains only the new service. The claim policy is the actual production source. Baseline/candidate controller controls use verbatim cancellation/dirty-configuration declarations and an explicit leaf/stop boundary; they do not execute real providers or UIKit. Syntax parsing with the Linux frontend is not an Apple SDK typecheck. The historical original 68-case suite is not rerun or reattributed.

The retained 26-case result is tied to Candidate3 contract/service bytes. Its apply, visible and authority/retained-state responses are explicit fixtures, with no original UIKit binding or provider execution. In particular, the old case named “all-deduplicated accepted page” validates an ordinary 50-row receipt shape; it does not exercise display deduplication. The separate controller result is baseline 3 passed / 5 failed versus candidate 8 passed, proving caller guards against declared leaf/stop stubs, not engine teardown. The attribution follow-up reuses these unchanged receipts and runs only the affected service/contract counterexamples and controls against separately retained source.

Required final native cases include loaded-hit/version reveal; filtered and ambiguous hit refusal; source/config/scene/backend and manual-state ABA; one original continuation including empty/deduplicated terminal behavior; cancellation before/after actual commit; no extra onAppear page; footer/pan/keyboard/VoiceOver continuation; and actual source-bound row/layout evidence after resize. The final running application's original result/model/provider identity and original first-page invariants remain mandatory.
