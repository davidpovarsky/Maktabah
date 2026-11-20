# Original Inspector/backend harness: pagination-fixture repair

## Outcome and scope

The complete original standalone harness now finishes in Windows after a test-fixture correction. No application source, concurrency actor, request timeout, SDK, original assertion, or original compile-time exclusion changed. The normal iOS workflow still requires a new macOS execution after integration; these portable outcomes do not turn its earlier failure into a pass.

The retained original CI observation is run [44672943654](https://github.com/davidpovarsky/Maktabah/actions/runs/44672943654), checkout 127ee9eddc2a9aea05c45ccf41420bb0cdd47705. Its simulator job reached this harness and was cancelled at its 75-minute job boundary, with the executable still alive. It emitted no completed harness marker. The original Windows baseline, diagnostic trace, controlled repair and current-source repair are separate evidence below.

## Demonstrated local cause

The original SefariaRemoteStore.projectSearchResponse conservatively continues a nonempty page unless its total explicitly has relation eq and has been consumed. A missing relation remains unknown; gte remains a lower bound. That production behavior is preserved.

The older makeCannedSearchResponse fixture provided only total.value. Its scoped fallback handler returned the same three mixed-work rows at every requested offset. The requested ten in-work results could therefore never be satisfied: only two unique Genesis hits were accumulated, while the unknown-total cursor continued. The trace stopped inside precisely this awaited scoped fallback, after its preceding CONTAINS assertions passed.

The corrected fixture declares the complete, known canned total as eq. It also permits explicit gte or missing relation for ten new executed controls: observed evidence and continuation for eq/gte/missing, empty-page termination with unknown evidence retained, and the actual scoped fallback's one request and exact two-match result. The new controls exercise the original decoder, projector and fallback. All original assertions remain byte-equivalent after removing the additive controls and restoring the fixture construction, verified by REPAIR_REVIEW.json.

The original main adds only fixed stage begin/pass messages to stderr around its existing calls, so a later Apple failure has a bounded stage witness. Removing those lines restores the original main exactly. The test-only per-assertion trace used for diagnosis remains in archived evidence, not the committed TestSupport source.

## Actually executed results

| Attempt | Source and boundary | Actual result |
| --- | --- | --- |
| Original Windows baseline | Exact 38 Swift inputs and 7 fixtures from 127ee; original main and assertions | Compile exit 0, 0 warnings; runtime incomplete at 120.406 seconds. No completed assertions were observable in its empty logs. |
| Diagnostic trace | Same original production; inverse-proved stage/assertion writes in two test copies only | Compile exit 0, 0 warnings; runtime incomplete at 120.485 seconds. 102 original assertions and the LocatorAndRef stage completed; scoped fallback did not return. |
| Controlled repair | Same exact original 127ee production and original oracles, corrected fixture, diagnostic assertion trace | Compile exit 0, 0 warnings; runtime exit 0 in 3.516 seconds; 448 observed passing assertions and all six original selected stages completed. |
| Current-source repair | Exact candidate sources on f064 lineage; original TestSupport without assertion tracing | Compile exit 0, 0 warnings; runtime exit 0 in 3.390 seconds; all six original selected stages completed. |

The selected stages are LocatorAndRefTests, DecodingTests, NavigationAndPackageTests, LegacyIdentityRegistryTests, BackendCoordinatorTests and UnifiedSearchArchitectureTests. Assertions are not Native cases. The original OTZARIA_INSPECTOR_MAPPING_TESTS definition continues to exclude its pre-existing performance entry. Neither individual assertion counts nor Native execution are inferred for the untraced current run.

Swift was Windows 6.3.3 with one compiler job and the existing private module cache. The original 240-second compile and 120-second runtime limits were preserved. Source/fixture hashes were checked before and after. The only pre-existing production input difference between 127ee and the current f064 lineage is BackendCoordinator.swift, separately recorded; the controlled run retains the original version to establish the fixture correction independently.

## Evidence and integration

REPAIR_REVIEW.json records exact inverse proofs, original SDK gitlink, canonical LF source hashes and actual results. SHA256SUMS.json authenticates the retained raw gzip files, whose uncompressed bytes preserve the original Windows logs and records. Each result includes exact compiler input paths/hashes, command, exits, elapsed time and executable SHA-256. The tested executables remain under the isolated worktree's ignored build/inspector-harness-baseline-20261120 directory.

The original baseline evidence remains unchanged. The trace and both repair attempts are additive. The evidence class is portable source/harness validation, with zero Apple compiles and zero Native passes. The original URLProtocol fixture is used; this work does not claim independently measured external-network silence.

Merge this test-only repair together with the separately reviewed ActionCore iOS deployment metadata fix (58b32dc24b480007b98027af11ce637aff37cb00) before the next combined normal iOS build. Do not skip this standalone harness or replace it with the narrower successful Inspector-owner fixture. The original SDK and application/Native gates remain required.
