# Global Search independent acceptance packet

Task `1220546245946205`, existing I chat `01a1df8b-4498-76c1-8cca-cd5c11120b7a`. QA branch `codex/otzaria-global-search-acceptance-20261115`, based on `13e40d1daa4a53799c94cd8ed5170f1343b9b1e8`. All writes stay in one owned UI-test file and `qa-20261115/**`. The supplied untracked specification is byte-preserved and excluded from this packet's staging. No production/PBX/workflow/other-lane edits, new runner, new chat or native dispatch.

## Integration inventory and first real run

Manager must register **one** new source in the existing Maktabah iOS UI-test target: `Maktabah-iOSUITests/GlobalSearchNativeAcceptanceTests.swift`. It inherits existing `FaithfulReaderUIBase`, uses normal `.realUI` bootstrap and original reader oracle, and adds no test-only production entry point. `LOCAL_VALIDATION.json` records its exact content hash and17 method names. It has syntax validation only; Apple compiler acceptance is pending. S's production registration is its separate nine-file proposal, not applied by I.

First native subset needing no invented query or fault injection (real installed miniTest10/bootstrap and isolated disposable test app required):

1. `testHebrewHeaderUsesActualRTLGeometry`
2. `testEnglishHeaderUsesActualLTRGeometry`
3. `testTypingKeepsInlineHistoryAndSingleNativeFieldWithRealClear`
4. `testOtzariaDefaultAdvancedFormExposesRealConditionalControls`
5. `testExactAndFuzzyHideAdvancedOtzariaBindings`
6. `testOptionsDismissalReturnsToSameQueryWithoutSubmission`
7. `testHeaderAndHistoryNativeAccessibilityAudit` — set `GLOBAL_SEARCH_TEST_BACKEND=otzaria` for this first subset.

These are7 exact selectors under `GlobalSearchNativeAcceptanceTests`, not pre-executed passes. No skip or optional assertion is used. Screenshot/AX attachments are retained by teardown. The audit fails on reported issues without suppression; it is not VoiceOver proof.

Two further no-query cases require their **actual source bootstrap/catalog**: `testEmbeddedOffersExactOnlyAndNoIgnoredOptions`, `testLegacyAdvancedUsesItsOwnSourceControls`. Do not force source-ready flags or silently substitute Otzaria to run them.

The remaining8 methods require real source fixtures/operations: four ordinary query cases (Return results, dirty/rerun, loaded-title filter, canonical history relaunch); one >page fixture; one actual failed-page/retry boundary; one independently expected native reader locator; one held cancellable operation. Exact variables and operation/log oracles are in `TEST_DESIGN.md`. History is not isolated by workspace namespace; use a disposable app container and preserve/restore its original canonical history outside these methods. Query test launch does not seed or clear history.

Manager owns effective app/UI-test26.2 deployment alignment, actual installed Xcode/SDK/destination and shared runner. Keep existing R27 methods/oracles unchanged. Tests do not resize a shared simulator or assert simulated traits as actual Stage Manager. Record actual iPad11 portrait/landscape/narrow/wide/iPhone geometry and settings for each selected execution.

## Source and reproducible evidence

Reviewed S initial packet0a60f41b and actual paging harness:39+18 assertions independently passed. Existing search191 and cached readiness14 independently passed. See `SOURCE_REVIEW.md` and raw logs. R01 canonical snippet inputs was identified by I, fixed by S in d6f63863 and independently reviewed; actual native lazy snippets/highlighting remain NOT_RUN.

Final source pin is **da186f456056fc5b9409de28fc7c989a2911cd1b** (four commits from base: bf5e119a,0a60f41b,d6f63863,da186f45). The last increment also keeps automatic paging disabled after clearing/closing a loaded-title filter until explicit new search/reset; explicit Load More remains available. Review and final immutable reproduction are recorded in `SOURCE_REVIEW.md` / `immutable-execution-inputs.json`, without reading changing S source during that reproduction. Raw logs preserve earlier setup precondition failure separately; it is not counted as native failure.

The task remains **OPEN**. `acceptance-matrix.json` retains every simulator/backend/physical runtime row as NOT_RUN and `acceptanceComplete=false`.0native cases and0physical cases have executed in this lane. Passing portable checks or a prepared UI suite cannot complete native acceptance. Frozen run43736843778 stays untouched; its manager-provided terminal failure is baseline infrastructure evidence only.

Latest actual SDK evidence: manager run43744659996 reached Apple compilation and failed at `GlobalSearchPresentationCoordinator.swift:5:16` (non-Sendable stored EnvironmentKey default action). All18 UI cases, including the7 selected I cases, are NOT_RUN; no xcresult/screenshots. See `native-43744659996-terminal.json` and SOURCE_REVIEW.md. S owns the narrow concurrency-safe action correction; exact source review and manager SDK recompilation must precede any runtime acceptance. The manager-aligned source and existing test oracles remain frozen while this verified defect is corrected separately.

Correction source **09c24e5bcc494cb8795a936ca296a8b5ddc0b6a1** is now independently reviewed in `CONCURRENCY_CORRECTION_REVIEW.md`. Its only production changes are the two MainActor/Sendable action annotations. Exact-blob independent Swift6 strict RED/green/missing-hop checks and6 assertions passed with explicit SwiftUI stand-ins; all16 earlier42+18 input blobs are unchanged. Corrected-candidate Apple SDK compilation and all runtime acceptance remain NOT_RUN. The same17 UI methods/first-run selectors and registration inventory apply unchanged.
