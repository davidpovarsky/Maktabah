# F08: original production Search opens and Reader mode transitions

## New selector

`FullV40ReaderModeAcceptanceTests/testOriginalSearchOpensLineParagraphAndChapterAtExactSourceFocus`

The class is additive in the already registered `Maktabah-iOSUITests/Build8401SevenDefectsAcceptanceTests.swift`. Every original Build8401 case and default fixture remains unchanged. It consumes the test-only `OriginalSearchContextUI` shared by the search lane; that helper must be integrated before the actual target build.

## Required real input

Use the original retained installed v40 Simulator, the qualified same-source app and XCTest binaries, and the actual published production search packages. The integration owner supplies:

- `PRODUCTION_SEARCH_CONTAINER_PARENT`: this Simulator's real `Containers/Data/Application` directory.
- `PRODUCTION_SEARCH_PREVIEW_ORACLE` and `PRODUCTION_SEARCH_PREVIEW_ORACLE_SHA256`: the exact separate `preview-targets.json`.
- `PRODUCTION_SEARCH_PREVIEW_SERVICE_SHA256`, `PRODUCTION_SEARCH_PREVIEW_PRESENTATION_SHA256`, and `PRODUCTION_SEARCH_PREVIEW_COMPILE_SHA256`: actual compiler inputs from the qualified source.

The oracle must contain one actual original provider result for **נפשי** in all three modes. Select a nonzero source row with a complete single-paragraph visible text of at most 2,048 UTF16 units, one line-mode row, more than one paragraph-mode row, and strictly more chapter-mode rows. Both real adjacent line descriptors must exist. Its book must be absent from the initial test namespace's imported tabs so this case observes a newly created backend document. Failure to find such a real hit is an admission failure, never permission to invent an ID or substitute another query.

The case uses a fresh test workspace namespace on the same production installation, solely through original app initialization and UI. It does not replace a sidecar or copy a database. It forbids external storage overrides, smoke bootstrap bypass, and a launch argument that would override the unit preference changed by the original controls. The actual complete database hash, size, and 8,259 / 7,925,185 / 7,001,824 SQL counts are independently checked.

## Exact source path distinction

Original Global Search follows `SearchModeView -> UnifiedSearchSessionController.openResult -> MaktabahBackendAdapter.resolveBook -> iOSNavigationManager.openBookAsync -> Reader+Content`. A new Otzaria hit resolves to a book with a backend locator, and its reader uses the original `LibraryReaderRenderModel`.

The oracle now exposes separate `backendReaderSourceUTF8`, SHA256, UTF16 length, rendered segment/visual ranges, and focused visual range. It uses the whole unchanged production presentation model on the original complete anchors and the exact metadata supplied by `OtzariaInspectorDocumentMapper`. Directional marks and two-newline separation are retained. The raw `unit.plainText` fields remain unchanged for the separate native full-corpus route. The test verifies the actual persisted document has the backend locator; it does not accept either source arbitrarily.

Each target also retains the actual descriptor's `previousStartLineIndex` / `nextStartLineIndex` and complete `neighbors.previous` / `neighbors.next` targets. These are independently resolved original service units with exact SQL identities, not fabricated index arithmetic or search hits.

## Native assertions

The same actual publication ID is matched to a retained original provider row, query hash, book title and canonical locator. All three modes are selected through original Reader menu controls, followed by a genuine Search result Open. The case requires:

- Exact canonical unit locator and title, real committed renderer generation, search highlight and segment-selection counts.
- The actual focused source text visible in the native Reader, plus a fresh bounded original TextKit source observation whose complete UTF16 length and exact UTF8 slice match the independently rendered complete unit.
- A real original clear action with a strict nonoptional postcondition on actual attributed highlighting.
- A line-mode forward pull with the independently resolved **different intermediate next unit**, followed by a reverse pull to the original unit. A round-trip no-op cannot pass.
- The original Search query and result identity retained after returning from each mode; the original installation owner and manifest preserved.

Exact selected range identity, Inspector selected-line semantics, TOC selection synchronization, all backend-switch races, and wider R05–R08 acceptance remain separate gates. This case does not claim those from a selected-highlight count. Actual glyph/AX behavior and gesture settling still require the qualified native run and any resulting fixes.

## Verification at this checkpoint

Apple Xcode 27 / Swift 6: full catalog source closure compilation exit **0**; whole registered UI file syntax parse exit **0**; exact additive test block typecheck against actual iOS/XCTest frameworks and explicit test-base/shared-action type boundaries exit **0**. The boundaries are compile-only, never executed; full original app/UI target compilation and native execution remain pending.

Catalog source SHA256: `8fcb34306110043eb58a5f87adf2bbd3ac5ef97ce452fa21a84036ead179d093`.
Whole UI file SHA256: `9584de9a1edafa0af14c4f70c5983afcb6521d3a550ae02f10b45367868ad7e1`.
Catalog binary SHA256: `8ec3f8fdeadda7f0cdc648045a94d4af5c5658f8bf1d0f4da3d7607870325011`.
Raw command/source/exit receipt and logs are in `apple-source-controls`.
Mac retained directory: `/Users/m1/builds/otzaria-wave2-reader-controls-20261127/f08-native-source-admission`.

No current full database generation, application UI pass, full-corpus performance result, or physical-device result is asserted by these compile controls.
