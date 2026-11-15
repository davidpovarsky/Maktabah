# Reader/SQLite lane — scoped implementation handoff

[נועם | DEV] [MAIN_SESSION], 2026-11-15. Independent Desktop UUID `01a1dc89-87bb-7521-b249-ed383392e940`, assignment/transport `OTZ-P-151126` / `OTZ-P-151126-DELIVERY`.

Worktree `C:\Users\DAVID\Code\Maktabah-hq-reader-20261115`; branch `codex/otzaria-reader-20261115`; base `df2a21941afa46da716387fce9de620865d2a151`. The implementation commit is the commit containing this report; exact SHA is supplied in the handoff and authorized Asana notes. Pinned upstream `d46af139b3a265399c16d87f5923acd8e3444024`, merge base `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`.

## Demonstrated defects and repairs

- A cached unit with source lines `[0, 2]` incorrectly answered a request for line `1`. Cache and descriptor lookup now use actual membership. Previous/next use semantic summary order, so overlapping spans do not hide a different unit or return duplicate interior lines at the first/last boundary.
- Partial or dangling TOC mappings silently excluded actual rows. The metadata query now starts from `line` with a LEFT JOIN; uncovered rows receive real single-line summaries. Multiple mappings choose a known deepest entry deterministically. Root-title isolation and cycle guards remain intact.
- Descriptor input is normalized to sorted unique indices. The existing strict-contiguity range optimization and 900-index IN chunks remain. A partially fetched nonempty unit throws `inconsistentSourceLines` instead of silently losing requested lines. Genuine row IDs and UTF16 anchor ranges are preserved.
- Reset could occur after generic service validation but before cache insertion. The additive `withCachedReadingUnit` captures a strong service plus generation under the existing bridge lock, performs work and cost calculation outside it, then validates and publishes atomically. Conversion/anchor helpers no longer republish arbitrary old units. Existing `withDatabase` / `withReadingUnitService` bodies, signatures and connection-retention semantics are unchanged.
- Cancellation is checked on metadata/source row mapping and assembly/chunk boundaries, including cache hits. Async anchors cancel their detached worker and reject changed DB generations/modes. The adapter guards its multi-call snapshot again after the worker completes, including a reset during document mapping.
- Side-cache cost accounts conservatively for UTF16 text, anchor text/references, metadata and structural storage, capped at an estimated 20 MiB and 50 entries; oversized results still reach the reader without retention. Service caches have structural/string budgets and generation-gated publication. These budgets are not measurements of process RSS or allocator overhead.
- Multiline fallback text retains a single real locator and all whitespace/content; newline offsets no longer invent SQLite indices. Checked numeric normalization rejects empty/malformed/negative input instead of crashing or falling back to zero.
- The existing render model already accumulates UTF16 offsets. Actual-source tests passed, so `LibraryBackendModels.swift` is unchanged.

## Ownership and integration

Changed production files, all DOWNSTREAM_OWNED and absent from pinned upstream:

1. `Source/Otzaria/App/OtzariaAppContainer.swift`
2. `Source/Otzaria/Reading/OtzariaReadingUnitService.swift`
3. `Source/Otzaria/Reading/OtzariaMaktabahBridge+ReadingUnits.swift`
4. `Source/Otzaria/Reading/OtzariaMaktabahBridge+LineAnchors.swift`
5. `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift`

New downstream test/evidence files are confined to `Tests/HQ/reader/**`, `tools/hq-reader-checks.py`, `docs/hq-reader/**`. No new app source, Xcode registration, original upstream source, UI/TextKit, Inspector, Search, shared HQ register or workflow change. No upstream hook and no conflict resolution/merge was performed. Manual ownership review only; no automated boundary-guard claim. Pre-edit provenance and alternatives: `ACK.md`, `HOOKS.md`. Historical schema10 comparison: `SCHEMA10-COMPARISON.md`.

## Executed focused checks

Command: `py -3 tools/hq-reader-checks.py --suite all` (Swift 6.3.3 Windows, Python 3.12.5 SQLite). Detailed results: `results/summary.json`, per-suite compile/test logs. The `*-baseline.log` files retain reproduced failures before correction.

| Suite | Actual scope |
|---|---|
| Cache | Actual cache class + actual unit/anchor models: sparse membership, mode/book isolation, clear, LRU, oversized text/metadata rejection |
| Service | Complete actual service and descriptors with explicit DB/decoder/telemetry doubles: metadata-only descriptors; exact IDs/UTF16; sparse next/previous; partial TOC coverage; all three modes traverse once; invalid locator; duplicate normalization; partial read error; cycles; per-root title isolation; 901 sparse rows cross two chunks; oversized structural caches; cancellation before decode |
| Bridge/adapter | Exact extracted production lease/publication/reset methods; complete reading and anchor extensions; exact adapter section/normalization methods with app-environment and Inspector-mapper doubles: reset/cancel interleaving, no conversion republish, real async anchor, multiline identity, reset during mapper, invalid input rejection |
| Render | Complete actual neutral models, no render-model double: source/translation/both, Hebrew/Arabic/English, niqqud/combining marks/emoji/ZWJ, UTF16 NSRange/visualRange and locator mapping. Five tiny 200-segment Windows timing samples, recorded in log; no device-performance inference |
| SQLite | Actual metadata mapping SQL executed on an in-memory SQLite fixture: unmapped row survives; another book remains excluded; fixture query plan recorded |

Extraction isolates the existing Apple-dependent application shell; tested method bodies are not rewritten. The adapter's existing iOS conditional is enabled only in its portable fixture. DB/decoder/mapper doubles do not establish SQLite connection concurrency, zstd correctness, Inspector conversion behavior, Apple SDK integration or app runtime performance. The separate Python SQLite fixture validates only its actual query and tiny synthetic schema.

## Acceptance still open

| Task | Scoped progress | Remaining acceptance |
|---|---|---|
| PERF-01 `1219613714504405` | Coverage, exact sparse navigation/anchors and metadata-only regressions tested | NOT_RUN: full installed corpus (Berakhot 2,875 rows, Tehillim, Derashot HaRan), cold/warm first-content/p95, history/search/focus/relaunch, large TOC performance. BLOCKED_DEVICE: physical iPad responsiveness |
| PERF-02 `1219613714507780` | Atomic publication/reset, cancellation and retention budgets tested | NOT_RUN: real SQLite/ZSTD simultaneous load, SQL step/lock wait, SQLITE_BUSY stress, measured RSS, competing UI/search/Inspector/annotation writes and backend swaps. BLOCKED_DEVICE: physical iPad stress |
| PERF-03 `1219613651433098` | Actual unchanged renderer UTF16/RTL mapping and tiny synthetic timing checked | NOT_RUN: original TextKit/viewport/scroll/highlights/notes/footnotes/selection and Sefaria/Maktabah UI regression, Instruments CPU/p50/p95/longest main slice. BLOCKED_DEVICE: physical iPad |

All three tasks remain incomplete. READY_FOR_QA applies to this scoped patch, not full task completion. No CI/project build, Apple SDK build, production/user DB, dependency installation, push/merge, signing or TestFlight occurred.

## Review and rollback

Independent QA should rerun the focused command and inspect exact coverage/navigation and generation interleavings, then schedule separately authorized Apple/app/device acceptance. Review production query plans on the real schema before claiming performance improvement. Large books still require metadata indexing; no claim of fully lazy/windowed reading is made.

Rollback is a scoped revert of this lane's implementation commit. Preserve all other branches/worktrees and do not reset or restore whole schema10 files. Integration risk is confined to downstream files/APIs; future schema10 work has its own version/TOC/metadata contracts and must reconcile the small accessor and adapter hunks deliberately.
