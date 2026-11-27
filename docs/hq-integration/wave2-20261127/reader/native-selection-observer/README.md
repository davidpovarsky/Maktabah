# Original UIKit selection observation

Only `Source/ChavrusaText/Testing/ReaderViewportAcceptanceObserver.swift` changes application source. The existing DEBUG/UIKit boundary remains. Explicit `CHAVRUSA_READER_SELECTION_OBSERVATION=1` adds an observation of the actual UITextView selected UTF16 range, original renderer mapping, exact selected text, original diagnostic locator/render generation, process ID and fresh request ID. It changes no selection, focus, renderer, layout or persistent state. Removing this addition recovers the complete original file byte-for-byte, including the unchanged full-v32 sample and UUID/deduplication logic.

The observer rejects missing/duplicate identity, native text differing from currentRenderResult, invalid native/mapped ranges and oversized payloads. Empty selections are EMPTY. Limits are 2,048 displayed UTF16 units, 4,096 mapped source units and 32,768 JSON bytes. Rejected reports omit selection text. Both the original TextKit 2 state before and after the optional observation are recorded.

## Actual Apple verification

The whole candidate observer parsed and typechecked against iPhoneSimulator27.0, Swift 6 strict concurrency, exit 0. Unrelated application dependencies are explicitly bounded in AppTypeBoundaries.swift; this is not a complete application build.

A Mac Catalyst executable used a real UIKit UITextView and the exact candidate report helper, complete original ReaderSelectionRangeMapper, exact original ArabicRenderResult/TextDeltaEvent fragments and original RenderedHighlightSnapshot data types. All 12 controls passed, exit 0. Cases include combining marks/surrogates, original delta mapping, empty selection, request/process/reader identity, missing/duplicate identity, stale render text, oversized selection/JSON, invalid mapped ranges and split-surrogate rejection. The component view/diagnostic inputs were seeded deliberately. **Maktabah UI executed: 0.**

Actual Xcode 27.0 (27A266a), Swift 6.4, SDK paths, commands, exits, input hashes and raw outputs are in apple-source-controls/RESULT.json and its sibling files. Original source hashes were verified against clean Oracle checkout 425603045a1c106028fc6d452b057e6446aa576b before transfer. Mac directory: `/Users/m1/builds/otzaria-wave2-reader-controls-20261127/selection-observer-20261127T014358Z`.

Original app selection → native edit-menu annotation → actual read-only Annotations.sqlite remains a separate pending native test. This bounded report is not full-body rendering or first-pixel evidence.

Raw original Swift input fragments are retained byte-for-byte, including three existing trailing blank-line warnings from git diff --check. The actual product Source diff passes the whitespace check; no evidence bytes were trimmed to suppress those warnings.
