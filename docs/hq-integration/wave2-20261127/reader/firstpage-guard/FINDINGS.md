# Source-traced first-page pagination gap

All line numbers below refer to exact baseline `15d283aa0ccbbfe6966f26a2c182810cb39fdafa`. Complete original files and their source witnesses are retained in `original/` and `TRACE_INPUTS.json`.

## Minimal counterexample

1. The original Search binding captures pagination revision `p` during initialization. The canonical first-page request is applied through the original `session.runSearch()`, and the binding records its accepted submission revision and submitted configuration.
2. Original first-page results settle. Before the semantic completion returns, an original Load More action or the original result list's `onAppear` paging callback calls `loadNextPage()`.
3. The original session increments `paginationRevision` to `p + 1`. The backend/session/model/query/scope/selected books/submission/configuration remain the same. The original code permits `isSearching == false` while `isLoadingMore == true`.
4. The original binding's post-submission `validate()` has no pagination equality. Its `validateCompleted()` checks neither pagination nor `isLoadingMore`. The outer completion chain calls these same methods, so this state is not rejected by an independent pagination guard.
5. If the page operation starts and ends before the next completion check, `isLoadingMore` can return to false. Checking only that Boolean would miss the event. The already-existing monotonically incremented pagination revision supplies the persistent evidence needed to reject this completed intervening operation.

This counterexample is established by the retained original source. It has not been executed in the app. An unsuccessful paging dispatch that still increments the original revision also invalidates the first-page request, conservatively preserving ownership without claiming a page committed.

## Complete original call chain

| Original source | Relevant baseline locations | Observation |
| --- | --- | --- |
| `UnifiedSearchSessionController.swift` | `loadNextPage()` around 562–579 | Guarded original dispatch increments `paginationRevision` before backend handling; Sefaria loading uses `isLoadingMore`. The revision is dispatch evidence, not a page-commit receipt. |
| `SearchResultsListView.swift` | Original row `onAppear` around 137 | The original list can request pagination as a real displayed group approaches the end. No synthetic result source is required for the counterexample. |
| `MaktabahNativeSceneBindings.swift` | Class 567–675; common validate 610–643; apply 645–667; completion 668–673 | Captures initial pagination at 592. Equality exists only in pre-submission branch at 636. Completion checks `!isSearching` but omits `!isLoadingMore`. |
| `MaktabahNativeSceneProjection.swift` | `.searchResults`, 99–106 | Projection checks original Search presentation, submitted/searching/dirty/error state, but contains no pagination revision, load-more state or result identity. |
| `MaktabahNativeSceneSession.swift` | Validate 900–909; apply 1022–1031; surface 1138–1144; retain 1255–1262; final completion 1280–1289 | Calls the same retained binding. Actual scene/surface witness equality does not add missing pagination ownership. |
| `MaktabahNativeSceneSession.swift` | Parent validation around 216; Search presentation observer 323–349 | Other parent guards and the Search entry/presentation observer are separate responsibilities. There is no retained one-shot pagination observation for this Search results binding. |
| `MaktabahNativeRoutingComposition.swift` | Source context 594–614; perform 1315–1386; prepare 1389–1418; receive 1421–1445; final 1448–1457 | The retained Hanlin source observation binds backend/workspace/reader context, not a Search pagination revision. Receive and final stages delegate to the same binding/SceneSession. |
| `ActionExecutor.swift` | Search results action 612–658; completion 733–766 | Uses the original UI sink and validates the original receipt, source/backend authority and completion hook. It does not possess a separate app Search pagination witness. |
| `ActionNavigationAuthority.swift` | Original authority checks | Binds scene/backend/context/rights/lifetime/deadline; it is not an observation of the app's Search owner revisions. |
| `MaktabahNativeRoutingHost.swift` | Root change handlers; native witness 344–389 | Relays actual original surface identity. It does not turn a loading Boolean roundtrip into a retained pagination event. |
| `NativeSearchIntentService.swift` | Original semantic Search invocation and result validation | Validates the supported first-page request and the returned semantic receipt. It does not provide a second app-owner pagination observation. |

`MaktabahNativeComponentBinding.swift` and `ActionSemanticJourneys.swift` are also retained as the inspected surrounding component/lifetime chain. Their existing guards remain unchanged. Observers for Sefaria roots, Search entry focus, Library parents and reader/workspace state must not be attributed to the Search results owner.

## Narrow correction

Move the existing `session.paginationRevision == initialPagination` check into the common `validate()` owner guard, before the submission branches. Every current application and completion call therefore evaluates it. Add `!session.isLoadingMore` to `validateCompleted()` so a currently active load-more state cannot be admitted even if its revision has not changed relative to this binding.

No query is resubmitted, no provider is called, and no UI state is reset. The initial first-page query continues to reject paging/opaque handles through the unchanged Core contract. Any future continuation must be implemented through the separately reserved typed continuation path.

## Existing assertions and outstanding execution

`SearchResultsActionTests.swift` explicitly identifies its fixture scope. Its strict nested arguments test rejects paging fields/handles; its byte-exact purpose test rejects Unicode normalization; its original UI sink test checks one UI command and zero headless searches; later tests reject changed actual results after an await and consumed purpose reuse. These assertions are valuable unchanged Core contracts, but their fixture has no `MaktabahNativeSearchResultsBinding` or original paging owner. No old fixture count is used as validation of this correction.

Meaningful integrated execution still needs original app cases covering: unchanged first-page completion; an intervening accepted manual page; automatic list paging; loading still active at completion; and an operation whose loading flag returned to false before completion. These are pending native cases, not new simulated or mirrored behavioral tests in this checkpoint.
