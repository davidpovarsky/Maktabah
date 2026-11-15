# Independent Global Search acceptance contract

Task `1220546245946205`. Runtime status: **NOT_RUN**. The executable UI cases in `GlobalSearchNativeAcceptanceTests.swift` are independent assertions against the real application. They do not install a substitute engine, set session results/errors, or bypass bootstrap. They require manager registration in the existing UI-test target and an immutable integrated candidate before execution.

## Candidate and destination gate

Record integrated commit, S source/test packet commit, test-file SHA256, installed app build, exact specification SHA256, effective app **and** UI-test deployment targets, Xcode/build/Swift/SDK versions, simulator UDID/runtime/device type and actual window dimensions. `native_preflight.py` collects read-only facts and never boots, erases, installs, dispatches CI or changes a shared destination. Its success means preflight facts were collected, not that the app compiles or that input works. Manager owns the deployment blocker described in `baseline-native-blocker.json`.

Run only on an isolated test app/container on a manager-assigned destination. Existing `studyWorkspaceTestingNamespace` isolates workspace sidecars; it does **not** isolate `UserDefaults` search history. These cases deliberately do not clear global history or write fabricated historical entries. History persistence/deletion acceptance requires a backed-up disposable test container; retain before/after canonical `SearchHistory` evidence and restore the original container using the existing runner's procedure. Never run destructive history tests against the user's live app data.

The UI suite uses normal `.realUI` bootstrap with explicit `preferredBackend` and `smokeBackend`. `miniTest10` is genuine installed fixture data, not the production full database. No `smokeBypassBootstrap`, forced results or launch-argument history are used. The suite attaches actual AX trees/screens on failure and success. A missing required element or fixture fails the case; it is not skipped or converted into an optional assertion.

## Native UI case scope

| Case family | Discriminating assertion | Additional evidence needed for full acceptance |
| --- | --- | --- |
| Header/history/editing | Exactly one identified main field within the real header; inline history remains during typing; unique typed text has one visible editable owner; native clear empties that field; options are outside it | Touch/keyboard and AX proof on iPad/compact, both directions and actual Stage Manager widths |
| Native layout | Actual nonempty intersecting frames; options left of query in Hebrew RTL and right in English LTR; secondary books/mode baseline below field | Screenshot review for 11-inch portrait/landscape, narrow/wide, large type; actual setting readback |
| Modes/capabilities | Otzaria default Advanced; Embedded Exact only; unsupported advanced controls absent in Exact/Fuzzy/Embedded; Legacy has its own real controls | Provider request values and source-specific result semantics; a menu alone proves neither |
| Advanced form | Positive/negative scope and conditional distance, word matching/count, grouping, spacing and alternatives are real mounted controls; negative controls appear only after a negative query | S actual session/model tests for every bound value; resulting real engine request/options and match behavior |
| Results/dirty | Real source-derived query yields original stable result IDs; input stays visible; mode change replaces current-results presentation with explicit dirty/rerun feedback; rerun returns real rows | One actual request per accepted Return/rerun; no request on configuration edit |
| Local filter | No-match projection preserves query, mode and book summary; original list remains mounted; clearing restores an original stable row | Provider/engine operation trace unchanged, including **page** calls; exercise 5 and 10-group projections to catch prefetch |
| Paging/filter | No-match projection retains native Load More and makes a real explicit page attempt | Known >100 occurrence fixture, exact canonical IDs/versions and offsets across >50/>100; virtualized cell count is not loaded total |
| Page failure/retry | Actual provider page failure displays retry while retaining an existing stable row; retry removes error and adds a new stable row | Real provider-failure trace, unchanged cursor on failure, exactly-once append on retry, stale/cancel generation protection through actual SearchViewModel body |
| Cancellation | Held real operation shows loading and a usable persistent query field; Stop reaches visible cancelled state | Engine/task cancellation observed at actual provider boundary, held late result/failure released and rejected; disappearance or session revision alone is insufficient |
| Accessibility | Native automatic audit reports actual issues; no issue filter suppresses failures | Actual VoiceOver navigation/announcements/actions; audits do not establish VoiceOver acceptance |

The source-contract IDs were reported by S and independently inspected in immutable candidate `0a60f41bb44d7d3b1f31e7d3c66e67b7a58769d5`; incremental snippet fix `d6f6386346c7083fe9cfd119f19683fd2ebbed77` preserves them. They are **source-verified, not runtime-verified**. Containers: `global-search-screen`, `global-search-header`, `global-search-results-header`, `global-search-results`. Main field: `global-search-query` (UIKit UISearchTextField; XCUITest may classify it as searchField or textField). The native clear button is discovered within that field, never fabricated by a second production control. The legitimate sidebar title filter is excluded by main-header ancestry and unique typed-value checks.

Original result IDs are `search-result-preview-toggle-{stableID}`, `search-result-expanded-preview-{stableID}`, `search-result-open-{stableID}`. Original Load More uses its actual localized label. No new book-tree/cell identifier is invented by QA. Actual UIKit tri-state proof must read the installed tree and compare real selected book IDs; count summaries alone do not prove parent/child selection.

## Fixture/environment contract

The runner must supply `GLOBAL_SEARCH_TEST_QUERY` from the **installed** fixture/source and retain independent matching canonical IDs. For the dirty/rerun case it must match both Advanced and Exact. No hardcoded query is assumed to match all sources. Optional language input `GLOBAL_SEARCH_TEST_LANGUAGE` is `he` or `en`; default `he`. Result tests choose backend from `GLOBAL_SEARCH_TEST_BACKEND` (`otzaria`, `sefaria`, `sefariaEmbedded`; default `otzaria`). Backend-specific capability tests explicitly choose their backend.

For `testOriginalResultPreviewOpensExpectedNativeLocator`, provide independently derived `GLOBAL_SEARCH_EXPECTED_LOCATOR` for the first canonical row of that query/source/sort. The method reuses the existing `FaithfulReaderUIBase.assertReaderHasText` native oracle and compares the actual reader locator. It does not infer destination correctness from a successful tap. Context text, all versions and copy correctness remain separate matrix requirements.

`GLOBAL_SEARCH_PAGING_QUERY` must independently have another page after initial list mounting; prefetch may already have fetched pages before filtering. Do not infer `hasMore` from a guessed hit count. For failure/retry select only `testActualPageFailurePreservesRowsAndRetryAppends` with `GLOBAL_SEARCH_PAGE_FAILURE_QUERY` and the existing backend boundary held/faulted by the authorized runner: initial real page succeeds, next real page fails, retry succeeds. No app-side synthetic error is allowed. The runner must control the actual provider/network boundary before Load More, including avoiding early prefetch races. Until a real boundary is available, this case is **NOT_RUN**, not covered by session fixtures.

`testHeldSearchCanBeCancelledWithQueryVisible` needs `GLOBAL_SEARCH_HELD_QUERY` and an actually held operation. A fast query that completes before Stop is a failed setup, not evidence for cancellation. Capture external provider/task traces and release the late response after Stop. The UI test intentionally does not infer cancellation from feedback alone.

## Operation and error oracles

S exposes session submission/cancellation/pagination revisions and DEBUG NSLog lines `[GlobalSearch] submit|cancel|page ...` with no query content. These distinguish accepted UI routing. They are not provider completion/cancellation counts. Capture the real system log from the **installed app process** over each test interval, not an assumed reader-log filename. Correlate generation/backend/scope with the actual provider trace; keep raw logs and the extracted assertions. No query/user content should be newly logged for this test.

At the actual existing backend boundary verify: Return increments accepted submissions exactly once; typing, options editing and result filtering issue no searches; 5/10/zero-group filters issue no pages; explicit Load More issues one page at the retained cursor; Stop cancels the active task/engine and prevents late rows/errors from replacing current state. A plain UI snapshot or a counter whose only writer is a button callback cannot satisfy these checks.

Independently inspect S's immutable test packet for the actual `SearchViewModel.loadNextBackendPage` body: initial loaded rows/offset retained on throw, loading released, retry clears error and appends once, stale generation/cancel late failure cannot overwrite newer rows/error/loading, and initial search clears old page error. An Observation fixture manually assigning `backendPaginationErrorMessage` is presentation coverage only. Do not duplicate or edit S's harness from QA.

## Remaining matrix execution

`acceptance-matrix.json` is the source of unexecuted platform/backend/setting rows. These UI methods cover a bounded subset; their eventual passes cannot mark the entire matrix complete. Genuine grouped-version fixtures, context/highlighting/copy/native-reader locator verification, save/reopen durability, global-vs-book-local history, library/reader/TOC/sidebar independence, source switch without fallback, missing/ready-index/no-redownload, physical iPad, VoiceOver and actual accessibility-setting readback require separate recorded execution. No physical or native PASS is claimed here.
