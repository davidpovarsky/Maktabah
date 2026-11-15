# Independent source and portable review

Task `1220546245946205`; I chat `01a1df8b-4498-76c1-8cca-cd5c11120b7a`. This review does not declare native QA complete. Baseline `13e40d1daa4a53799c94cd8ed5170f1343b9b1e8`; S initial packet `0a60f41bb44d7d3b1f31e7d3c66e67b7a58769d5`, implementation `bf5e119a833c973e240f0b50e8e3fc3e15d783b1`.

## Actual execution

Independently ran S's existing unchanged `global-search-presentation-tests.py`: **39 presentation/orchestration assertions and 18 actual Search+Execution assertions passed**. Raw `independent-presentation-paging.log` prints session SHA256 `23ff2dd31aa41aa568db0fe306f41f2e8f4e44de95392968161c1c7b8dfc07b1` and execution SHA256 `93b22547815e7944abc9f1b8e54ec771d9d62209087e9d8b0a9820769e64819a`, matching S's initial code snapshot. Independently ran existing `hq-search-tests.py`: **191 search and 14 cached-readiness assertions passed**, raw `independent-existing-search.log`. Windows Swift6.3.3 / Python3.12.5; dependencies explicitly doubled. These are assertions, not 262 independent XCTest/device cases. No real index installation, remote provider, Apple build or native UI was tested.

**Final immutable reproduction passed42+18 assertions at da186f456056fc5b9409de28fc7c989a2911cd1b.** `immutable-execution-inputs.json` hashes all16 exact committed input blobs exported with `git show` into a temporary source snapshot, including the unchanged S runner. No active S worktree input was used or edited in this execution. `independent-presentation-paging-pinned.log` retains raw output and exit0. These committed-byte hashes differ from S's Windows checkout-byte hashes where Git normalizes CRLF; the compiled source was byte-checked against the exact commit, not inferred from an announced working-tree hash. Existing191+14 were independently executed at the earlier unchanged-engine packet, not re-labelled as a second final run.

Reviewed runner extraction and `GlobalSearchPagingFixtures.swift`: it compiles the actual unchanged `effectiveBackendSearchOptions`, `loadNextBackendPage`, `startSearch`, `stopSearch`, and canonical BackendPaginationState bodies. Held throwing continuations enter the actual catch. This is materially stronger than the separate presentation fixture's manual assignment of `backendPaginationErrorMessage`.

The 18 assertions demonstrate offset50 is retained on failed page, existing50 rows are preserved, loading releases, error clears on retry, ordered50..<150 appends once, stop cancels old work/generation, an old failure cannot clear a newer active page's loading or publish an error, initial search clears old error/rows and starts offset0, a late old page failure cannot overwrite a newer completed search, and no held continuations remain. Provider/storage/result mapping are doubles; this does not verify real network transport, SwiftUI rendering or live source semantics. Source review confirms the new error catch checks generation before mutating either error or falling through to loading cleanup.

## Source contract review

- Additive native presentation retains canonical session/SearchViewModel/history and original rows; no alternate search engine or backend switch was introduced. Main input is native UISearchTextField. Existing iPhone global duplicate searchable is removed. Dedicated iPad Search visibility does not reuse Reader's sidebar state.
- Existing Advanced default remains; Embedded Exact/relevance capability is constrained according to its actual adapter. Local resultKitabFilter is absent from requestConfiguration and automatic prefetch is suppressed while it is nonempty; explicit Load More remains outside the virtualized rows, including zero matches.
- Positive/negative scope, negative distance, grouping and existing options bind directly to canonical session properties. Exact/Fuzzy neutralize hidden Advanced values; Legacy mode mapping avoids SearchViewModel phrase overrides discarding advanced distance/match. No generic public Action capability is substituted for source-specific UI capability.
- Cancellation invokes existing tasks/models, invalidates generation and gates publication. A synchronous FFI may finish internally; actual interruption at native/backend boundary remains unverified. Session/log revisions prove routing only.
- Counts distinguish loaded/filtered from aggregate/unknown totals. Save preserves the numeric-archive gate; durable save/reopen support remains unverified and cannot be accepted from that gate alone.
- Upstream diffs are narrow Search integration/error/prefetch/chooser and Search-only layout connections. PBX/workflows/native host, book-local SearchComponents and Reader/TOC/Library code were not changed by I. Manager owns exact upstream authorization and registration.

## Concrete finding R01 — canonical snippet inputs

At initial packet0a60f41b, SearchMode's original SearchResultsListView mount omitted query/mode/nearDistance. The list defaults query to empty; unresolved rows guard on nonempty extracted keywords before invoking the real resolver, so those rows could stay `...` and lose query-dependent snippet resolution. This omission also existed at the base; retaining it would not satisfy the new preservation requirement. Sent exact source concern to S.

S fixed the narrow mount and made the existing computed Reader getters internal read-only in **d6f6386346c7083fe9cfd119f19683fd2ebbed77**. Independently reviewed that incremental diff: it passes session.query/searchModeForReader/nearDistanceForReader; no copied parser/highlighter or shared-row rewrite. **Source issue addressed; real lazy appearance/highlighting remains NOT_RUN.**

## Filter-clear follow-up

Independently reviewed final **da186f456056fc5b9409de28fc7c989a2911cd1b**: changing a loaded filter disables automatic paging for the current result set, clearing/closing it does not restore implicit requests, and explicit accepted new search/reset restores normal prefetch. The actual original row predicate is still guarded, while explicit paging is unchanged. Final42 assertions include this lifecycle plus5/6/10/50/100-row predicate projections; native remount/request traces remain NOT_RUN.

## Reproduction stability

The first attempt to rerun d6 directly from S's active worktree stopped at a source-string precondition before any test assertions: the runner had received a newer automatic-paging guard before SearchMode's matching hunk was saved. Raw `independent-presentation-paging-final.log` preserves this setup failure. It is neither a runtime FAIL nor evidence that immutable d6 is broken. S was notified immediately; its active worktree was preserved. Final execution used an immutable source snapshot as described above.

Preparation of that immutable reproduction also caught two QA setup issues before final success: Git archive export changed line endings and failed the byte-identity guard before execution; the first git-show snapshot omitted Search+Execution, so42 assertions ran before the missing-file error prevented paging execution. I corrected the temporary input inventory to16 files and reran the unchanged runner. `immutable-initial-snapshot-inputs.json` and `immutable-snapshot-setup.log` retain the latter failed setup; it is not counted as an app/model or UI failure. Final exact-blob execution exit0 supersedes these preparation attempts without deleting their evidence.

Scoped executable-source whitespace checks passed. Whole-packet `git diff --check` reports raw console-log CR/spacing, exit2; no whole-packet whitespace PASS is claimed. Logs are not stripped to hide those findings. The local `.gitattributes` disables text normalization only for this QA directory's logs so their committed bytes retain the recorded raw SHA256 values.

## Native gate

I's17 UI methods have Windows syntax parse only, no XCTest/Apple framework typecheck. `local-preflight.json` records expected BLOCKED exit2: Windows has no Apple SDK and this preparation checkout is not a clean integrated app candidate. The old frozen build failed effective18.6/host26.0 deployment alignment before UI execution. Manager must align effective app and UI-test targets26.2, register nine production files plus I's one test file, compile the exact integrated candidate and coordinate the assigned native destination. All simulator and physical matrix rows remain NOT_RUN. Do not restart/watch the frozen run or mark the task complete from this packet.
