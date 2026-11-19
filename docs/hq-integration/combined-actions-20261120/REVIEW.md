# Combined semantic action regression — 20 November 2026

## Exact scope and result

The integration at `0bc6be41f03855412d7dd24ee72608a7824fb5a7` contains original-owner note drafts and semantic search results, the preserved commentary action, the focused SQLite cancellation fix, and the corrected v32 acceptance seed path.

The actual Windows Swift 6.3.3 package runs finished successfully:

| Package | Executed XCTest cases | Failures |
| --- | ---: | ---: |
| OtzariaActionCore | 117 | 0 |
| OtzariaUIRouting | 99 | 0 |
| ChavrusaUIRoutingHost | 127 | 0 |
| Total for these three separate package suites | 343 | 0 |

All compiled package source/test/manifest hashes were identical before and after each run. Each package used its own build directory. No failed attempt was retried for this combined suite. These are portable contract tests with explicit fixtures; they do not establish Apple app typechecking, original engine results, UIKit visibility, or physical-device performance.

## Integration decisions

The original Core catalog retains 29 entries and now has eight implemented actions. Optional search and note ports are required before those actions are advertised. Readiness observes the exact current scene owner and its original presentation state. The Core search action resolves canonical scopes and passes the same normalized query used for backend assessment; the existing original session and results UI own submission, history and paging.

One-use navigation preparations distinguish a reader destination, a note draft and a search query. A preparation cannot combine or substitute those purposes. New regression cases prove that blocked search scenes are neither advertised nor executed, a missing optional port is unsupported, a native uncertainty failure retains its status and is never made automatically retryable, and note/search purposes cannot be exchanged.

The original scene orchestrator remains the commit owner. Notes and search share sanitized native failure propagation. After a claimed native acknowledgment, mismatched receipts or a failed final source/visibility observation report `native_effect_uncertain` with `retryable=false`; a possibly performed effect is not reported as a safe backend retry. The final original source observation follows the last retained authority read without a further await.

## Evidence and boundaries

Each package directory contains exact inputs, result metadata, a byte-preserving gzip of raw stdout/stderr and a readable normalized log. Original raw hashes are recorded; readable logs normalize line endings and trailing whitespace only. Source parse of 18 changed Swift files and staged source diff checks passed. Syntax parsing is not an Apple SDK check.

Standalone pre-merge note/search suites remain separately documented and overlap these suites; they are not additive new test totals. The original SQLite stress evidence and actual Apple SDK run 44633742619 are recorded in their own bundles and have their own exact source pins.

A later independent source review identified a possible stale note-editor callback lifecycle race in the app adapter. The final app freeze is waiting for its narrow presentation-identity correction and the six actual original-owner Native cases. This package PASS does not close that app-level issue. Native 78 run 44633736259 was dispatched on the older 7d05dd0/application5d8ef991 freeze and cannot accept these new app features. Full current-source Native, v32 strict resume/integrity and Release gates remain required before task completion or distribution.

No original renderer, search engine, annotation persistence path, SDK implementation, project membership or user database was replaced.
