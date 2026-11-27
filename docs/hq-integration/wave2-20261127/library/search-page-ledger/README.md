# Original backend page journal

This checkpoint adds passive page facts at the original Otzaria, Zayit and generic/Sefaria page owners. It supports a separate continuation consumer; it does not dispatch an additional page, replace a provider, change result grouping, or qualify a native UI outcome.

## Source and ownership

The integration base is `15d283aa0ccbbfe6966f26a2c182810cb39fdafa`. The isolated branch is `codex/otzaria-wave2-search-page-ledger-20261127`, at `/mnt/development/projects/worktrees/Maktabah-wave2-search-page-ledger-20261127`.

The live upstream inspected before editing was `bismillah-100/Maktabah` main `4203de5fd77beb119e5826e039be1a61325f7be0`, with merge base `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`. The retained provenance records distinguish upstream-derived SearchViewModel/Search+Execution from the downstream Otzaria and Zayit owners. The new ledger is a downstream adapter. The exact two upstream source files were read; no algorithm was substituted from a fixture.

Only these five product paths change:

| Path | Change |
| --- | --- |
| `Source/ChavrusaText/SearchContinuation/OriginalSearchPageLedger.swift` | New bounded Foundation-only request, terminal and effect journal. |
| `Source/Otzaria/Search/OtzariaTextSearchViewModel.swift` | Observe the original request and actual result-store commit; revoke the observation on clear, initial search and source-readiness invalidation. |
| `Vendor/ZayitSearchPort/Swift/ZayitSearchViewModel.swift` | Observe original fetch and raw cursor commits; the existing cancel path also covers configure/reset/new search. |
| `Source/Features/Search/ViewModel/SearchViewModel.swift` | Retain one ledger instance beside the existing backend generation. |
| `Source/Features/Search/ViewModel/Extensions/Search+Execution.swift` | Capture the unchanged typed request before await, observe the original committed pagination, and pass the captured offset to the existing explicit `applyNextPage(requestedOffset:...)` overload. |

The original first-page provider parameters, source/generation/cancellation guards, mapping, deduplication and result stores remain. The generic table scanner does not acquire a page commitment. Unified continuation, list lifecycle and native routing are owned by the parallel search and reader agents.

## Journal contract

`OriginalSearchPageLedger` is MainActor-isolated. `Snapshot`, `Request`, `Attempt`, `Commit` and `Terminal` are value types with `Equatable` and `Sendable` conformance. The model exposes `let originalPageLedger`.

`Request.encode` uses sorted JSON from the original typed request. Its configuration is the corresponding original request with only offset set to zero. Request and configuration bytes each have a 256 KiB observation bound. The helper is explicitly MainActor-isolated, matching every production caller. Failed encoding disables observation for the epoch and never guards or suppresses the original provider invocation.

The snapshot separates lifecycle `revision` from accepted `pageRevision`. Dispatch, failure and cancellation do not advance the accepted-page counter. A successful original commit advances it even for a valid empty terminal page or a page that adds no displayed rows after the existing deduplication. Same-generation invalidation still changes lifecycle revision. Stale owner/generation/attempt callbacks cannot overwrite a new attempt. An encoding failure can be rearmed by a real source invalidation; counter overflow permanently removes observation authority instead of wrapping.

The attempt captures the actual pre-request consumed count and cursor. In generic/Sefaria initial search, the original pagination object is not reset until `applyInitialPage`, so a replacing attempt truthfully preserves the prior pagination values. Replacement may reset the consumed count; append cannot regress it.

| Owner | Raw and mapped quantities | Committed cursor facts |
| --- | --- | --- |
| Otzaria | `page.results.count` and original navigation `items.count`, before display deduplication | Original result-store `consumedCount`; current `hasMore`; normalized next cursor and raw computed cursor are separate. |
| Zayit | Original `page.hits.count` for the page, before its existing display deduplication | Original `nextOffset = request.offset + page.hits.count`; terminal status preserves the raw computed cursor separately. |
| Generic/Sefaria | Existing `SourceEvidence.rawHitCount` when supplied, otherwise the `LibrarySearchPage.hits` boundary count; mapped `newResults.count` | Actual `BackendPaginationState.loadedCount`, normalized next cursor and `hasMore`, plus the verbatim `page.nextOffset`. |

Missing Sefaria `sourceEvidence` remains missing. Its fallback page-boundary count does not prove raw network rows or `allRowsMapped`. Negative/nonadvancing advertised cursors are retained separately from the original normalizer's exhaustion decision. Existing optional source evidence is encoded without inventing completeness.

### Retaining an effect after authority is revoked

`captureTerminal(for:) -> TerminalCapture?` is registered synchronously for the exact active attempt immediately after original dispatch and before yielding. The ledger holds at most one attached capture. `TerminalCapture` exposes the immutable `attempt` and read-only `terminal`/`isClosed` state; it contains no result arrays or callbacks.

Actual acceptance or failure freezes its terminal once, closes it and detaches it. Invalidation closes a pending capture without inventing a terminal. A caller's already recorded accepted terminal survives later invalidation, so a refusal can still report the real `pageCommitted` effect. This retained historical effect never grants current source authority. The consumer must separately validate the live owner, generation, revision, request configuration and source lease before continuing. Semantic action-token consumption remains the continuation consumer's responsibility.

## Actual verification and its limits

The existing Oracle Linux Swift toolchain was used directly. No SwiftPM package build, Apple SDK, native provider, Simulator, corpus, or application UI was run.

| Actual operation | Result | Scope |
| --- | --- | --- |
| Attempt 1: complete five-file parse with `swift-frontend -parse -parse-as-library -swift-version 6 -target arm64-apple-ios27.0-simulator` | Exit 0, empty diagnostics | Syntax only; no Apple SDK/type checking. |
| Attempt 1: actual Foundation ledger compile | Exit 1; original inputs and diagnostics retained | Nested `Request.encode` needed explicit MainActor isolation before calling the ledger encoder. No control binary ran. |
| Attempt 2: corrected whole ledger plus unchanged original `ZayitSearchModels.swift` and focused controls, Swift 6 strict concurrency | Exit 0, empty diagnostics | Linux Foundation component compilation only. The sole product correction was `@MainActor` on `Request.encode`. |
| Attempt 2: actual resulting component binary | Exit 0; **35/35** assertions | Actual ledger lifecycle, exact original Zayit request encoding, bounded failures, stale/duplicate callback rejection, empty-terminal/raw-cursor facts, replacement state, and retained terminal effects. |

The four unchanged owner files reuse their exact attempt-1 parse evidence; their syntax was not rerun. Their UIKit/Combine/Observation integration is not typechecked by these controls. The component uses synthetic request/count scenarios against the actual ledger; it does not execute an original engine, its deduplication algorithm, a backend task, or UI. The overflow branch was source-reviewed but not dynamically reached. Full Apple compilation and genuine continuation/runtime checks remain required.

Actual tool identities:

- Swift `6.4.3 (swift-6.4.3-RELEASE)`, target `aarch64-unknown-linux-gnu`.
- Driver argv0 is `/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc`; resolved `swift-driver` SHA256 `39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a`.
- Frontend SHA256 `d98470fed50d4efc0075bcbd45ba1f908382dc9222c2b8213d1ff074efaa2083`.
- Final ledger SHA256 `b3b81fa58bf651d41d4acddb2488473ea5192a1b20e3adb9783d9ea0c489146d`.
- Actual component binary: 408,864 bytes, SHA256 `47e243aafcd71e4d8b7a1bbf6c439eb56d8fcce1cf242602ae43045f42aec170`.

## Retained evidence and capacity

`actual-linux-inputs-and-logs.tar.gz` contains 55 exact source, runner, input, output, result and launch/apply files, including the failed compile, corrected compile, actual binary and original control output. `ARCHIVE_INDEX.json` binds their lengths, hashes and original file identities. The archive is 247,958 bytes, SHA256 `40042434d172bdd29cd9c75c75b1a2595f085231bdf7d7b5bc7433dc2a2d4613`.

The original actual result files remain under the isolated worktree's `build/page-ledger-controls-20261127/`:

- Attempt 1 `RESULT.json`: SHA256 `1d16886d2d5bf2620f7806ad3e1c0ef704b11b93f6c85cb35b317f5f94ebbf79`.
- Attempt 2 `RESULT.json`: SHA256 `70a84d22eaea75b8ede0bde4a955cef19a8f6fe1a8af0c65820df67a666adbf5`.

The total owned output/cache budget was 64 MiB while preserving a 687,865,856-byte global floor. Attempt 2 reused the exact attempt-1 cache and admitted only the remaining total budget. Maximum sampled allocation across both attempts was 19,275,776 bytes; this is a sampled measurement, not a claim about an unobserved instantaneous peak. All compiler/test process groups and both runner PIDs were observed absent after completion. No cache deletion is included in this checkpoint. The inactive reproducible module cache is excluded from the archive; its retained allocated size is 17,764,352 bytes.

An earlier setup path tried to create a new external artifact parent as ubuntu and received a filesystem permission error at `mkdir`, before source application or compilation. The work moved into the already owned worktree build directory without changing permissions. No automatic approval denial or extra user authorization was involved.
