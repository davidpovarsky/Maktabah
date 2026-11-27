# Full search-context native acceptance contract

## Source and execution status

Product prerequisite: e3af7bc78e4cca198150a6a4205aff1a9bc44a8a, integrated by root at f6fabccb4da3ea2b5d254bfd2f5e77ca7d92c1db. The product closure is separate from this additive XCTest/source-oracle change.

The original registered GlobalSearchNativeAcceptanceTests.swift now contains four additive native cases. The actual iPhoneSimulator 27.0 XCTest SDK typecheck of the complete PublishedProduction class, both new context cases and shared original test base passed before the final resize assertions; final current-source typecheck receipt accompanies this contract. This is a typecheck, not a linked app build or native test result. Existing base-class actor warnings are retained. All native execution outcomes remain pending.

## Exact selectors

Use the registered Maktabah-iOSUITests target:

| Selector | Required observation |
| --- | --- |
| PublishedProductionSearchDataTests/testPublishedV40NafshiFirstPageForIndependentFullContextOracle | Original managed production v40, actual UI query נפשי, first 100 original provider IDs and metadata against immutable SQL; provides genuine target candidates for the independent context oracle. This does not itself accept full context. |
| PublishedProductionSearchDataTests/testPublishedV40NafshiFullParagraphAndChapterMatchEveryOriginalSourceSegment | Actual first-page hit must match the independent original-service target; original Reader unit controls change paragraph/chapter; every complete native preview segment must match the source and SQL identity. |
| SefariaFullSearchContextAcceptanceTests/testThreeActualSefariaEditionsAcrossTwoPagesKeepDistinctCompleteBodies | Original public Sefaria UI, exact soul query, Psalms scope, canonical 100-result pages. Psalms 35:17 has two editions at offsets 98/99, third at 100; one source card merges the third edition and all 28 complete translated segments change to the selected edition. |
| SefariaFullSearchContextAcceptanceTests/testHebrewUIEnglishResultHonorsOriginalSourceTranslationAndBothControls | Hebrew application UI, actual English JPS 1917 result, genuine Hebrew counterpart, and original Reader preference controls for Source, Translation and Both. Every complete text slot is checked in each mode. |

Portrait/landscape assertions use actual changed app bounds, original header RTL/LTR geometry, unchanged query/books/mode/count and original first result identity. Otzaria additionally requires that resizing did not issue another original provider request. These are actual orientation/viewport cases; they do not claim Stage Manager split-window testing.

## Full-v40 environment and sequence

Retain the original application installation after the published-package UI install tests. Existing required runner variables:

- PRODUCTION_SEARCH_CONTAINER_PARENT: this exact owned Simulator's data/Containers/Data/Application directory.
- SIMULATOR_UDID: that exact Simulator UUID.
- OTZARIA_SHARED_ROOT_OVERRIDE and OTZARIA_PRODUCTION_DB_PATH must be absent.

The existing installation verifier requires production release 455390662 / v40-20261123094345, 4,355,063,808 database bytes and SHA-256 8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01. Both exact published index installation manifests must remain present. No workspace is seeded, no corpus is substituted, no provider is replaced, and no giant index is rebuilt.

1. Run the first-page selector without a preview oracle. Preserve its XCTest attachment and the original passive trace at the actual app container's Documents/OtzariaLogs/search-native-UUID.jsonl.
2. Select a genuine first-page hit whose original paragraph and chapter have distinct full bounds (chapter row count greater than paragraph). Pass its actual bookID/focusLineIndex to the original FullV40ObservationCatalog, in both modes.
3. Use the reader agent's oracle at 89607b3c or a later qualified descendant. Its input includes actual sourceService and presentationSource paths/hashes plus the same retained compile receipt. It compiles the whole production ReadingUnitService, SQLite/Zstd closure and LibraryBackendModels.swift. Do not normalize its previewPlainText again.
4. Supply the resulting source receipt using the variables below, then run the full-context selector.

| Variable | Required value |
| --- | --- |
| PRODUCTION_SEARCH_PREVIEW_ORACLE | Absolute path to the original preview-targets.json, regular file with no symlink. |
| PRODUCTION_SEARCH_PREVIEW_ORACLE_SHA256 | SHA-256 of those exact bytes. |
| PRODUCTION_SEARCH_PREVIEW_SERVICE_SHA256 | The independently retained actual ReadingUnitService source digest. |
| PRODUCTION_SEARCH_PREVIEW_PRESENTATION_SHA256 | The independently retained actual whole LibraryBackendModels.swift source digest. |
| PRODUCTION_SEARCH_PREVIEW_COMPILE_SHA256 | SHA-256 of the exact catalog compile-input receipt. |

The source receipt is bounded to 2,000,000 bytes by the shared reader. The integration controller must choose a real first-page target with a complete paragraph/chapter oracle within that bound; it must not truncate a larger unit. The test verifies every original SQL anchor and the original presentation helper's complete output. Full source bytes remain in the source receipt and its original service output. The separate Reader performance gate owns the retained very large full-v40 chapter.

The test launch deliberately omits an argument-domain otzaria_reader_unit_mode value. A command-line override would prevent the original UI preference from taking effect. Existing package/page tests keep their prior explicit line-mode arguments.

Query text is not added to the passive provider trace. It retains only querySHA256; the test compares that digest and separately checks the actual native query field.

## Sefaria environment and exact source

- SEFARIA_SEARCH_CONTEXT_ORACLE: absolute path to this directory's sefaria-native-source-oracle.json.
- SEFARIA_SEARCH_CONTEXT_ORACLE_SHA256: 759e939ff99a27b58e3ddea7505855ff18ca8b80416bf1e12f3d24440cf66890.

The oracle is 87,140 bytes. The generator compiled and executed on Apple with the actual Sefaria DTO, domain mapper and complete LibraryBackendModels.swift. It also independently compares both mapped text slots to the actual response's selected edition and genuine source arrays before applying the original readerPlainText helper. It stores per-segment hashes and lengths, not whole copyrighted translations.

Public responses were observed 2026-11-26 23:22 and 23:49 UTC. Every page/text response has its exact URL, raw SHA, byte count, original edition/source metadata and capture time. Raw evidence remains under the owned Oracle artifact directory:
 /mnt/development/projects/artifacts/Maktabah-wave2-search-20261127/sefaria-source-oracles

The UI calls the actual current public Sefaria provider. If current source identities or texts differ from these sealed captures, fail and retain both observations; do not silently update an expected hash or treat fixture transport as live UI acceptance.

These cases are online source-qualified acceptance. They do not claim physical offline, per-process network denial, or selected-edition Reader persistence. The original Open action is used only to reach actual Reader preference controls here. F08 independently verifies the actual Reader destination/focus.

## Shared original controls and evidence

OriginalSearchContextUI and SearchContextExpectedSegment are internal test helpers so the reader agent's registered F08 cases can reuse original actions without duplicating tests. Initialize with .init(app: app, test: self).

Original IDs supplied by the product commit:

- search-result-preview-toggle-ID / search-result-open-ID.
- search-result-versions-CANONICAL_LOCATOR and search-result-version-STABLE_ID.
- search-preview-source-STABLE_ID-SEGMENT_ID and search-preview-translation-STABLE_ID-SEGMENT_ID.
- reader-more-menu; reader-display-unit-menu; reader-display-unit-line/paragraph/chapter.
- reader-text-options; reader-text-mode; reader-text-mode-source/translation/both; reader-options-close.

The root Search tab is selected only through the native tab bar (or the original navigation back button). The helper never uses Reader's separate in-book Search button as a root-tab substitute.

Each context assertion visits all expected native text nodes, checks full label SHA/byte length, rejects extra or duplicate segments, reaches the original end-of-context Open action, and keeps first/last screenshots, native hierarchy and observed hashes. Provider/source-only receipts remain separately labelled.

Allow at least 1,800 seconds per Sefaria complete-context case and 3,600 seconds for the two-mode production full-context case. This prevents the runner's generic short timeout from replacing actual bounded UI traversal with a false acceptance. The already defined package installation test still needs its longer 5,400-second install wait and corresponding runner allowance.
