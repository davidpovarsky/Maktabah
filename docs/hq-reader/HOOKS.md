# Reader lane pre-edit ownership audit

## Wave R follow-up pre-edit matrix

`Source/LibraryBackend/LibraryBackendModels.swift` is DOWNSTREAM_OWNED and
absent from pinned upstream d46af139. Plan: only skip existing normalization
passes when their ASCII trigger is absent; retain their exact order and
replacement rules. No API, renderer, storage, UI or TextKit replacement.
Alternative: leave repeated regex/entity processing on plain strings; genuine
whole-book Windows model baselines now show this is worth a scoped experiment.
Check: unchanged mixed-Unicode/mode/HTML invariants plus SHA256 identity of
the full rendered output of released Berakhot, Tehillim and Derashot content
before/after, and actual locator/range coverage for every nonempty source row.
This remains portable model evidence, not Apple/TextKit/iPad acceptance.
Rollback: revert only the follow-up commit. The original protected
`Reader+Content.swift` callsite remains read-only; moving its synchronous
render-model construction off MainActor would need a coherent integration
decision and actual native behavior evidence.

## Historical initial tranche

Pinned upstream: `d46af139b3a265399c16d87f5923acd8e3444024`; base `df2a21941afa46da716387fce9de620865d2a151`. Manual provenance review, not an automated guard PASS.

All source below is DOWNSTREAM_OWNED and absent from the pinned upstream tree. No original Maktabah source/hook is edited.

| File / intended hunk | Necessity and alternatives | Focused check | Rollback |
|---|---|---|---|
| `Source/Otzaria/App/OtzariaAppContainer.swift`: additive generation snapshot and atomic reader-cache publication helper | Current generic service guard runs before caller publishes; reset can clear then receive an old unit. Keep existing shared `withDatabase`/`withReadingUnitService` signatures and connection lifetime intact; work remains outside bridge lock, publish under momentary generation guard | Deterministic interleaved reset/cancel/publication fixture using actual helper | Revert lane commit |
| `Source/Otzaria/Reading/OtzariaMaktabahBridge+ReadingUnits.swift`: load paths and conversion | Route unit loads through guarded helper; conversion and anchor helpers must not republish an unstamped old payload | Actual helper/cache fixture and callsite review | Revert scoped hunks |
| `Source/Otzaria/Reading/OtzariaMaktabahBridge+LineAnchors.swift`: exact membership, accounting, async cancellation | Min/max range includes holes; counts omit anchors and use UTF16 units as bytes. Reuse existing cache, no replacement system. Cancel detached worker and avoid reload in changed mode | Sparse membership, eviction, generation and cancellation fixtures | Revert scoped hunks |
| `Source/Otzaria/Reading/OtzariaReadingUnitService.swift`: cancellation and verified line coverage as proven by fixtures | Existing strict contiguity fast path retained; no silent truncation or invented IDs. Add row/loop cancellation at service boundary, and only repair demonstrated coverage defects | Actual source compiled with tiny deterministic DB double; no production DB | Revert scoped hunks |
| `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift`: fallback locators and request guard | Newline offset is not a SQLite line ID. Preserve exact content/locator as one segment; validate cancellation and DB generation across multi-call section load | Fallback multiline identity fixture; request guard review | Revert scoped hunks |

Adjacent exact-locator pre-edit finding: `normalizedLocator(for:)` indexes `pieces[0]` even for empty input and silently maps malformed line text to line zero. Replace with checked parsing of positive book IDs and nonnegative line indices, preserving the existing numeric input contract. Test actual extracted method with empty/leading-separator/malformed/negative cases; no schema10 reference-resolution system is imported.

No planned change to `LibraryBackendModels.swift`: UTF16 running offset is already present. Verify it with actual-source Unicode fixtures before deciding whether a change is necessary. Full production SQLite timing, iPad UI/selection/scroll, RSS, lock wait and p95 remain NOT_RUN/BLOCKED_DEVICE.
