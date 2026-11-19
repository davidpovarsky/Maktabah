# Original native search results through the common action engine

Prepared on 2026-11-20 (Asia/Hebron). Base: `7d05dd0bb25a7df307b35174e49e18d0f22eecee`. This is a source/portable tranche; Apple typechecking and native acceptance are pending.

## Behavior

`search.openResults` accepts a strict nested `searchQuery` and reaches the existing Core, destination registry, `commitPrepared`, original scene bindings, `UnifiedSearchSessionController.runSearch()`, original engines, and original Search UI. It does not run a second provider, create results, or infer an occurrence count.

The represented common UI subset is phrase search with exact matching. Existing canonical/relevance order is retained for Otzaria; supported Sefaria orders use its existing controls; Embedded remains limited to the original supported defaults. Otzaria book scopes require canonical resolver proof and exact positive `book:<id>` identities. Unsupported modes/scope/revision, opaque handles, paging fields and unknown nested fields are refused. The original UI continues to own paging; requested paging fields are never silently dropped.

The new internal destination `native.search.results` shares the existing Search screen. It is not a new public route, chat tool, renderer, or permission system. Existing public navigation to Search still preserves the user's current query and does not submit it.

A non-Codable, single-use Core preparation retains the exact query, invocation and scene. Generic navigation or another query cannot borrow it. The original model and its configuration/submission/cancellation identities remain bound across waits. An already running identical query is refused before presentation; no artificial cancellation/restart is used to increase a counter.

A successful result requires an actual completed original engine submission, no original error/dirty configuration, and the original visible Search container. The final Core observation rechecks current authority and the original results state. A spinner or echoed query is not acceptance.

## Native presentation ownership

A passive optional callback on the existing root identity reader supplies its exact UIView/UIWindow. References are weak; an older detached source cannot erase a newer owner. The precommit guard reads that actual active/key/visible window and original controller tree, including presentation/dismissal/transition intervals. No global/first window lookup is used.

Search's original save/saved-results/FTS overlay State bindings supply a passive live blocker. Existing book-filter, search-data and Advanced Options sheets also block preparation. An opaque overlay prevents a results witness. A hidden still-blocked Search owner remains retained until its actual state clears, a new actual owner replaces it, or its scene unmounts.

## Executed evidence

| Execution | Actual outcome | Boundary |
|---|---|---|
| Core attempt 1 | Compilation failed in the new test's nonexistent `ActionStatus.notFound` assertion; 0 tests ran | Product Core had compiled; this is not a pass |
| Core attempt 2 | 95/96 passed; exact implementation-set oracle still expected six instead of the newly implemented seven | All ten new semantic-action tests passed; old catalog/resource checks retained |
| Core attempt 3 | **96/96 passed**, 0 failures, source hashes unchanged during run | Swift 6.3.3 Windows; 86 existing + 10 new tests |
| UIRouting attempt 1 | **90/90 passed**, 0 failures, source hashes unchanged during run | Real Core/registry/authorized command contracts with explicit synthetic scene/UI ports; 85 existing + 5 new tests |
| Presentation guards | **30 assertions passed** after hidden-blocker cleanup correction | Extracted actual guard source with declared UIKit model doubles; no UIKit runtime |
| Swift parse / diff | Passed for edited Swift syntax and whitespace | Syntax alone is not an Apple SDK typecheck |

New contract cases cover strict options, exact Unicode query binding, source-qualified scope rejection, headless refusal, native authority revocation, invalid acknowledgement, changed results after the last backend await, purpose reuse, substituted query/destination/scene and missing UI advertisement.

Raw Windows logs are retained as deterministic gzip with hashes. Readable copies normalize line endings only. The initial compile failure and failed exact-set oracle are preserved. One guard fixture compiler warning about mutable captured local state was corrected with an actual MainActor-owned fixture; the initial warning output remains retained.

## Remaining gates and integration

- Integrate the independently tested notes tranche and its shared `ActionNativeUIFailure` so all search post-effect failures preserve `native_effect_uncertain` and `retryable=false`.
- Bind Core readiness/advertisement to the original scene's synchronous `canPrepareSearchResults()`, then run the combined Core/Routing/Host checks.
- Actual Apple app build and focused Native semantic search/notes acceptance on the combined immutable source.
- Run the affected native regression selection with the combined source; the active Native78 run on source `5d8ef991` does not accept this later change.
- No exact occurrence-count provider is introduced or claimed.

## Original UI hook and rollback

`SearchModeView.swift` only gains passive owner/blocker registration and the existing native surface witness. Its controls, layout, engine calls, history behavior and saved-result flows remain original. The root identity reader callback is optional and preserves existing callers. Source policy review is recorded in the exception register.

Rollback removes this additive semantic action, its purpose/typed preparation and passive integration hooks together. It does not delete or migrate any user database, annotation, history, index, SDK or source capability.
