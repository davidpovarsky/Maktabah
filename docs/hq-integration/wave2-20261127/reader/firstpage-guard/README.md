# First-page Search result ownership guard

## Outcome and exact scope

This checkpoint changes only `MaktabahNativeSearchResultsBinding` inside `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneBindings.swift` on base `15d283aa0ccbbfe6966f26a2c182810cb39fdafa`.

The original first-page request now requires its captured `paginationRevision` throughout the request, including after submission. Completion also requires `!session.isLoadingMore`. The existing cancellation, query bytes, model/session identity, backend generation, configuration, scope and visible presentation checks remain intact. A paging revision change fails with the existing `native_search_owner_changed` stale-state error. An unchanged revision with an active load-more operation fails completion with the existing `native_search_results_not_ready` error.

The patch does not add continuation support, a provider, a search submission, a public handle, a result selector, or any UI. It leaves the shared SceneSession, Composition, registry, Core query contract and every other function in this source file unchanged. The original first-page query restrictions remain in their original implementation.

## Reason

The original binding checked `initialPagination` only in its pre-submission branch. After `apply()` recorded `submissionRevision`, an unrelated original Load More action or the original list's automatic pagination could increment the pagination revision without invalidating that branch. `validateCompleted()` also omitted `isLoadingMore`. The complete original SceneSession → Composition → Core completion chain repeatedly used that same incomplete binding and did not retain a separate search-results pagination observation. `FINDINGS.md` gives the source locations and the counterexample; this is a source finding, not a reproduced native failure.

## Provenance and ownership

| Item | Exact provenance | Decision |
| --- | --- | --- |
| Candidate base | `15d283aa0ccbbfe6966f26a2c182810cb39fdafa` | New isolated sparse Oracle worktree; no edits to an active integration checkout. |
| Modified file baseline | Git blob `2c3643f84d0b7a29193a130cbcfa891c5627e595`; SHA256 `607f0a9abd68b361a609f59725d798deda6566c8327ed43996521b8638591079` | Exact original downstream integration seam. |
| Modified file candidate | SHA256 `70d64d593d22dbfb512b74bd8d6ed9d259c9404b8a47072ced30f5bc18d989a2` | Only the two authorized guards. |
| Actual upstream observed before editing | `bismillah-100/Maktabah` main `4203de5fd77beb119e5826e039be1a61325f7be0`, tree `84297735aae2abc831755c3bac57987ff07668a3`, commit date `2026-11-24T02:21:10Z` | This file is absent at that upstream commit. It is downstream-owned, while remaining a shared integration seam requiring coordinated ownership. |
| Downstream file introduction | `d337c60896c6ef24af277697e6012ae1595c0335` | Observed by `git log --follow --diff-filter=A`. |
| Proposal | Exact `adc6013953d03bd3ba6e98818af24dba5f19cee8` proposal blob `1980bcf6f0da9c746842f99684ba545d3a7aa26c`, identical at candidate base | First-page ownership stays separate from the proposed typed continuation. |
| Coordination | Root's Wave3 task `1220939535420506`, comment `1220949623346203`, `2026-11-27 09:55:38 UTC` | Root reserved only this binding for this correction; standing user authorization applies. Root handles publication and direct Wave3 intake. |

`PROVENANCE.json` records actual Git/API metadata. `TRACE_INPUTS.json` binds all retained original call-chain files to their exact base Git blobs and SHA256 values. The retained `original/` files are evidence copies, not modified implementation or replacement behavior.

## Verification and limits

- `PRESERVATION.json` and `SOURCE.patch`: exact baseline/candidate bytes, unchanged 30,515-byte prefix, and reversal of only the three textual replacements reproduces the complete baseline. These are preservation checks, not behavioral tests.
- `oracle-syntax/RESULT.json`: actual whole-file Swift syntax parse at `2026-11-27 10:02:55 UTC`, exit `0`, using the installed Linux ELF Swift frontend 6.4.3 with `-target arm64-apple-ios27.0-simulator`. Its exact binary SHA256, argv and raw logs are retained. No SDK was supplied, and this is not an Apple SDK typecheck or app build.
- Scoped existing-test inventory found no original binding exercise by class/error identifiers in the retained test/tool paths. The existing Core Search results tests explicitly use contract fixtures; their earlier results are not evidence that this app binding works. They were not rerun or relabeled.
- Original app-binding behavioral validation: **NOT_RUN**. Apple SDK typecheck, Simulator execution, UI acceptance and the source-traced automatic/manual pagination timing cases remain pending on the qualified integrated candidate. No native success is claimed.

The handoff commit contains this single production source diff and this dedicated evidence directory. No Mac command, SDK build, Simulator job, corpus query, dependency update or cache allocation was performed for this correction.
