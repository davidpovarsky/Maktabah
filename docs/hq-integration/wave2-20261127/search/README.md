# Wave 2 search continuation — 27 November 2026

Base: `29a731e273f9a757c743c49e182fece0e8047d46`; upstream remote HEAD/main observed read-only at `4203de5fd77beb119e5826e039be1a61325f7be0`. Isolated Oracle worktree `Maktabah-wave2-search-20261127`.

## Actual Native116 history failure

The retained immutable original xcresult search cohort has 19 passing and 3 failing tests on the original iPad Pro 11-inch/iOS27.0 run. Original path: `/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/original-native116-prebuilt-evidence.X0L7wYFd/Maktabah/build/artifacts/result-11-search.xcresult`.

The `R27NativePadTests/testNormalBootstrapGlobalHistoryUsesActualSubmit` attachment proves the original installation metadata and UUID matched, while the bounded preferences reader exhausted 1,048,576 bytes. It read 1,048,577 bytes, reported `oversize`, and never parsed the dictionary. The real screen had already settled on missing-index feedback with no loading/cancel controls. This is a failed observation, not proof of a failed history writer.

The read-only helper now admits a finite 8 MiB preferences file, consistent with retaining the original qualified-locator registries in that same plist. It still rejects oversize, symlinks, non-regular files, ambiguous installation, changed metadata, missing/malformed preferences, and missing/duplicate exact query. It does not flush UserDefaults, write history, seed data, or alter the native test assertions/deadline. The original simulator was already removed, so its final full preferences byte size was unavailable; the immutable lower-bound oversize failure is retained verbatim.

`history-observer/test.py` compiles the exact original observer block under Swift6.4.3/Linux and compares baseline against candidate with explicitly disposable Foundation fixtures. Baseline:11 PASS/2 FAIL (legitimate 2MiB dictionary and its actual read count). Candidate:13 PASS/0 FAIL, including the new finite-budget rejection and unchanged ownership/count controls. This is observer/component evidence, not native UI acceptance. The original UI case remains pending on the composed app.

Files touched: `Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift` is a downstream acceptance test; only its bounded history read and explanatory comment changed. New documentation/fixtures are downstream. No upstream product, engine, package, index, or user data changed. Root and reader owner approved the disjoint history helper scope. Rollback is the single read-budget hunk.

## Other original search failures

`testHeaderAndHistoryNativeAccessibilityAudit` reports a UILabel with partially unsupported Dynamic Type; `issue.element` was unavailable. The actual unfiltered issue and screenshot are retained. Passive native font records show the main query and history heading scale correctly across all categories. A second UISearchBar placeholder belongs to the native book filter and has `adjustsFontForContentSizeCategory=false` despite point-size changes. This is a candidate boundary for further diagnosis, not a proven correction; the original full audit remains required.

`testExactAndFuzzyHideAdvancedOtzariaBindings` lost the app process. The retained Apple crash report points to AXCoreUtilities `_AXDyldImageMonitor`; no product-root-cause claim or test skip is made.
