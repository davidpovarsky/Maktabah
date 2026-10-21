# Project Board

This is a living working-memory document for this repository.
It is intentionally lightweight. Humans and coding agents should update it when useful discoveries, ideas, plans, optimizations, problems, or follow-up work arise during normal development.
Do not turn this into a duplicate issue tracker or a dump of temporary thoughts.

## Inbox

Quick captures that still need classification.

## Ideas & Opportunities

Potential improvements, features, optimizations, or architectural ideas.

## Discoveries & Tips

Useful technical discoveries, undocumented behavior, shortcuts, implementation tricks, platform behavior, or reusable knowledge discovered while working.

- Sefaria Relationship Loading Quadratic Elimination: Parsing `/api/related/{sectionRef}` with a single-pass tolerant collection `SefariaRelatedResponseDTO` reduced Genesis 7 (2,317 links) decode time from >20s (quadratic dictionary re-encoding loop) to ~2.29s with zero MainActor lockup and per-request inspector timeouts.
- Otzaria Relationship Semantic Classification: SeforimLibrary v32 relationships must retain `rawConnectionType`, `matchedSide`, `sourceBookId`, `targetBookId`, `linkedBookIsBaseBook`, and `linkedBookDependenceType`. Commentary categories (`COMMENTARY`, `SUPER_COMMENTARY`, `PARSHANUT`, `DIBUR_HAMATCHIL`, `ELUCIDATION`, `EXPLICATION`, `FOOTNOTES`) must not be squashed to `'SOURCE'` in SQL queries when `matchedSide == 1`, but classified based on whether the linked book is a commentary or base text.
- Multi-Candidate Search Release Resolution: `ZayitSearchArtifactService.resolveArtifact(matching:)` must evaluate database compatibility across all published releases instead of picking the first tag prefix match, gracefully skipping incompatible releases (e.g. v22 vs v32) and presenting `.unavailable` ("אין עדיין חבילה תואמת לגרסת מסד זו") without failing search data views.
- Otzaria schema 6 stores both `line_content.content` and populated `version_line.content` as dictionary-compressed zstd BLOBs in the official v32 database. Decode by the frame's dictionary ID against `zstd_dict`, retain the 16 MiB safety cap, and never treat these values as plain SQLite text.
- Active SQLite prepared statements left unreset cause SQLite to return SQLITE_BUSY / code 5 (`cannot commit transaction - SQL statements in progress`) upon `COMMIT`, `ROLLBACK`, or `RELEASE SAVEPOINT`. Ensure `_executeNoLock` and `_fetchNoLock` always reset statements and clear bindings via `defer`, and call `_resetAllCachedStatements()` before committing or releasing any transaction/savepoint.
- TorahLinkedSource parameter order in TorahInspectorKit places `commentatorID`, `commentatorName`, and `workTitle` right after collective titles and before `hebrewText`; `rawProviderPayload` is the final parameter.
- Otzaria commentator grouping requires resolving real author identity (via `book_author` or title normalization for Hebrew/English patterns like "על", "on", "חידושי", "פירוש", stripping 'ה' on acronyms) so distinct tractates or works by the same author (e.g., Ramban on Torah vs. Talmud) group under one commentator identity while keeping individual work titles distinct.
- Search result full-text previews must bind their view identity and async task to `item.stableID` instead of `item.backendLocator?.persistenceKey`, ensuring switching between versions of the same passage resets view state and triggers an immediate reload of the chosen version.
- Sefaria's mobile relationship path fetches `/api/related/{sectionRef}` once and assigns rows to segments through `anchorRefExpanded`; an empty local `links` array is complete offline data and must not trigger a network fallback.
- Current Sefaria `/api/related` rows may omit `text`/`he` and expose only `displayedText`; use that as the no-extra-request snippet fallback, and sort exact/small `anchorRefExpanded` sets ahead of book-wide relationships for deterministic linked-source navigation.
- Sefaria `/api/index` can list one canonical work under multiple category paths (currently `Ten Paths to God`, and intermittently `Celebrating Life; Finding Happiness in Unexpected Places`). Diffable identifiers must therefore describe a stable tree occurrence; `TextLocator`/canonical book IDs remain persistence identity and must not be used alone as UIKit item identifiers.
- IDB `ui set-value` on iOS Simulator text views sets accessibility value via private `_accessibilitySetValue:(id)value`. In custom `UITextView` subclasses, declaring `@objc func _accessibilitySetValue(_ value: Any?) -> Bool`, supporting `smoke-note-input.txt` container input in debug/smoke mode, and passing `--udid <UDID>` flags before positional text arguments in `idb ui text` ensures automated UI tests reliably synchronize and preserve entered text when saving annotations.
- In `TorahInspectorKit` study notes list, `TorahSegmentDetailView` must invalidate the repository note cache upon receiving `notesDidChange()` before reloading, and provide `accessibilityLabel(note.note)` on note row buttons so UI automation can discover and tap notes by text label.
- When adding notes from Torah Inspector study tools, ensure the Add Note button is placed above the notes list to remain visible in the initial viewport without requiring scroll, and resolve the target range from the inspector selection / backend render model if the reader has not established an active text selection.
- In `iOSAnnotationEditorSheet`, prevent `.onAppear` from re-initializing `@State` after initial display (e.g. during sheet keyboard/layout recalculations) with a `hasInitialized` guard, and protect `AccessibleAutoDirectionTextView` from having its text wiped by empty SwiftUI state passes by maintaining `lastEnteredText` and syncing one-way when non-empty.
- In `MaktabahTorahInspectorAdapter`, inspector note queries matching by range overlap (`overlapsSelectedRange`) must verify that the annotation matches the selected locator's `backend` and `workKey` (or matches `currentBook.id`), preventing cross-backend or cross-tractate annotations (e.g., Otzaria Berakhot) from leaking into unrelated reader documents (e.g., Sefaria Genesis) that share identical character offsets.
- In IDB accessibility automation, direct identifier/label taps (`idb ui tap <id> --match-key AXUniqueId`) use XCTest `[XCUIElement tap]` which automatically resolves orientation in the active interface coordinate space and executes accessibility actions reliably without touch synthesize inaccuracies. Coordinate taps (`idb ui tap <x> <y>`) bypass XCTest and send raw IOHIDEvents to the hardware digitizer, which on iOS Simulator remains fixed in portrait orientation (1032x1376) and requires explicit translation (`(hid_x, hid_y) = (y, screen_w - x)` in landscapeLeft). When parsing `idb ui describe`, handle dictionary return types directly so element frames are not discarded when an outer `elements` list key is absent.
- In iPad modal sheet forms (`iOSAnnotationEditorSheet`), Form bottom action buttons can be scrolled out of the initial modal viewport in landscape orientation (~y > 850), causing IDB coordinate taps to miss the window bounds; placing the action button section (Save, Delete, Cancel) directly beneath the note text ensures all primary targets stay within the initial modal viewport bounds (~y ~ 390..490), while `ToolbarItem(placement: .navigationBarTrailing)` with dedicated accessibility identifier and `label_fallback="Delete Annotation"` ensures navigation bar actions are rendered and accessible.
- Otzaria TOC root title line prepending policy: When a root entry has children and <= 3 title lines (e.g. Tractate Berakhot 103, Tehillim 28, Derashot HaRan 5826), prepending its line indices to the first child unit (Daf 2., Psalm 1, Chapter 1) ensures line 0 is rendered as the header on the opening readable page, lands on content immediately upon opening, maps line 0 lookups to the first unit, and preserves 100% of all lines without omissions. Substantial root entries (> 3 lines, such as Book 2128 with 477 lines) and root-only books (Book 6866 with 3,715 lines) remain independent units.
- Contiguous line index scan vs line_toc join: Table `line` has index `idx_line_book_index (bookId, lineIndex)`. Fetching unit lines via `WHERE l.bookId = ? AND l.lineIndex >= ? AND l.lineIndex <= ?` performs a single contiguous index scan without touching `line_toc`, achieving a 5x speedup (~0.36ms vs ~1.8ms) and automatically incorporating prepended root header lines.
- Fast single-line commentary expansion in TorahInspector: When expanding a commentary segment card in Torah Inspector, performing a point-lookup via `fetchLineContent(bookId:lineIndex:)` returns the snippet/line content in ~0.1ms, avoiding multi-second MainActor stalls and massive SQLite chapter decoding churn.
- Swift Actor Isolation with `Task.detached`: When calling static helpers of a `@MainActor` class from within `Task.detached`, Swift treats them as actor-isolated by default, causing compilation errors. Declaring pure helper functions as `nonisolated static func` on an unisolated utility enum or struct eliminates actor isolation violations while maintaining strict thread safety.
- Zero SQLite I/O on `@MainActor` SwiftUI View Evaluation: Calling database access methods (like `otzaria.getReadingUnit`) inside SwiftUI `body` evaluation (e.g. `selection()`) causes UI hitches and frame drops. Returning a lightweight descriptor/locator selection on cache misses and letting asynchronous background tasks fetch full unit data and commentary links guarantees instant UI responsiveness.
- Multi-Root Title Line Association: When a book contains multiple root TOC entries (each having sub-trees), root title lines must be tracked in a dictionary keyed by `rootEntryId` (`heldRootLinesByRootId`) rather than a single list, ensuring each root's title lines attach strictly to child units descending from that exact root.
- Atomic SQLite Connection Swaps & Generation Tracking: Cache invalidation must occur under the synchronization lock prior to exposing a new connection or dropping an old one, with cache entries tagged by database generation counter (`dbGeneration`). In-flight background queries from an earlier generation must throw `CancellationError` rather than writing stale units to cache or returning empty results.
- Structured Cancellation Bridging for `Task.detached`: When offloading CPU or SQLite operations from `@MainActor` to `Task.detached`, wrapping the task with `withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })` ensures cancellation cascades properly. Throwing `CancellationError` rather than returning empty arrays prevents UI components from misinterpreting a cancelled query as an absence of data.
- Strict Contiguity Range Verification: A count-based span heuristic (`endLineIndex - startLineIndex + 1 == sourceLineIndices.count`) is vulnerable to duplicates or non-monotonic gaps. Explicit monotonic contiguity verification (`val == start + i`) guarantees single-index range scans on `(bookId, lineIndex)` are mathematically sound, falling back to chunked `IN` queries when indices have gaps.
- Eager Commentary Text Decoding in Background Tasks vs Empty Metadata: Stripping `content` (`includeContent: false`) from `getLinks` breaks TorahInspector commentary snippets and fails the shared Torah data diagnostic check (`snippets=0`). With `Task.detached` offloading SQLite from `@MainActor`, batching commentary queries via single `IN` scans decodes tens of commentary rows in 1-2 ms without MainActor hitches, providing full text previews in the inspector.
- Two-Stage Commentary Loading & Progressive Hydration: Eagerly decoding commentary Zstd content inside `getLinks` (even in a background task) blocks the SQLite connection when hundreds or thousands of links exist (e.g. Genesis 1:1 with 1,828 links). Separating commentary link metadata query (`includeContent: false`, taking ~2ms) from on-demand batch snippet decompression (`fetchSnippets(for:)` taking ~6ms for visible rows) eliminates reader stalls while populating card previews progressively without UI jumps.
- Momentary Database Lock Acquisition: Holding `NSRecursiveLock` across long SQLite query iterations stalls the `@MainActor` whenever UI components touch the container. Capturing `(db, dbGeneration)` under momentary lock acquisition followed by an atomic generation guard check post-query guarantees thread safety without blocking the main thread.
- Decoupling Search Data from Library Bootstrap: In bootstrap setup, database activation (`backendCoordinator.commit(.otzaria)`) must precede optional search package installation. Isolating search index downloads and policy checks in a non-fatal `do/catch` block ensures that missing or schema-mismatched search release artifacts (e.g. v22 search packages vs v32 production DB) never block the user from immediately opening and reading library texts.
- Scope Separation in TorahInspectorKit: `TorahInspectorSelection.relationshipRef` must branch strictly on `scope`: `.section` returns `canonicalRef` directly (preventing unit commentary lookup from being narrowed to a title/header line with 0 relationships), whereas `.segment` returns `preferredSegmentRef ?? canonicalRef`.
- Deterministic Snippet Hydration Lifecycle: Batch hydration in `TorahSegmentDetailView` must clean up `loadingSnippetIDs` via `defer` across all exit paths (empty, partial, throw, cancellation). Missing snippets transition explicitly to `unavailableSnippetIDs` to avoid permanent loading spinners.
- Trusted Installed Database Fast-Path on Cold Startup: Running `PRAGMA quick_check(1)` twice on cold startup of a 6.74 GB database causes a ~145.5s launch freeze. Validating file existence, SQLite format 3 magic header (16 bytes), manifest identity, and required tables verifies startup readiness in ~2.93 ms (24,800x faster) while reserving full `quick_check` strictly for initial installation or corruption recovery.
- Reader Title and Locator Hierarchy: The primary reader title in `iOSReaderWorkspaceView` must be anchored strictly to `book.book` (or the active canonical work identity), confining navigation item titles (such as chapter number "2") to the secondary subtitle to prevent numeric index strings from replacing the canonical book title.
- Thread-Safe Reading Unit Service Caches: Protecting `indexCache`, `summariesCache`, `contentCapabilities`, and `contentDecoder` with dedicated `NSLock` synchronization in `OtzariaReadingUnitService` eliminates data races when concurrent reader background tasks perform lookups and mutations simultaneously.
- Otzaria Schema Projection Table Aliasing: `OtzariaBookSchemaCompatibility.projection` defaults alias to `b`. When querying with different table aliases (e.g. `JOIN book linked_book ON ...`), the alias must be passed explicitly (`alias: "linked_book"`) to prevent SQLite statement preparation failures like `no such column: b.isBaseBook`. Furthermore, `OtzariaBookSchemaProjection` must provide safe fallback expressions for optional columns (`isBaseBook`, `hasTeamim`, `hasNekudot`) to guarantee cross-version compatibility across minimal test and production schemas.


## Experiments / Investigations

Things worth testing or researching before deciding whether to implement them.

## Open Questions

Important unresolved questions or uncertainties.

## Planned / Todo

Concrete work that is worth doing but is not part of the current task.

Use Markdown checkboxes where useful:

- [ ] Example item

## Done

Completed items that are still useful to retain because they document an important decision, discovery, or implementation.

- [x] Make production UI acceptance fail closed
  - Implemented: 2026-10-13
  - Notes: IDB `describe` responses wrap a matched element under an `elements` key, while `describe-all` returns a list. The acceptance runner now handles both shapes, uses distinct container accessibility elements, and exits on failed gestures, waits, geometry checks, or assertions instead of allowing a green workflow with swallowed UI failures.

- [x] Consolidate the iPad reader into one native three-column split
  - Implemented: 2026-10-12
  - Notes: The Library tab now owns one `NavigationSplitView` with Library/TOC/Reader columns. Study remains an adaptive presentation inside Reader detail, and TextKit restores a source-character viewport anchor after width reflow.

- [x] Keep the Sefaria catalog as durable offline-critical metadata
  - Implemented: 2026-10-12
  - Notes: The last-known-good catalog snapshot is written atomically under Application Support with schema/timestamp metadata, rendered immediately on later launches, and refreshed in the background after its TTL.

- [x] Publish miniTest10 only after enabling GitHub immutable releases
  - Implemented: 2026-10-12
  - Notes: Repository release immutability applies only to future releases. Bump the canonical profile version/tag when enabling it, and pass all assets directly to `gh release create` so GitHub can upload them while the release is a draft and lock the tag and assets atomically on publication.

- [x] Make native bootstrap resume and search screenshots deterministic
  - Implemented: 2026-10-12
  - Notes: A production download may be resumable even when a later unauthenticated GitHub release lookup is rate-limited. Resume only from an app-owned sidecar whose repository, GitHub HTTPS asset URL, production asset name, size, SHA-256, partial file, and strong validator all pass validation. Simulator search evidence now waits for an explicit success marker from the production search controller instead of relying on a fixed sleep.

- [x] Preserve the intended Reader/TOC column and sequence Study-to-TOC transitions in compact layouts
  - Implemented: 2026-10-08
  - Notes: A collapsed `NavigationSplitView` must bind `preferredCompactColumn` in addition to `columnVisibility` for its initial column. On iOS 26, mutating those bindings after a sheet dismissal may leave the visible column unchanged; rendering the TOC through its detail fallback adds a second automatic navigation bar, while changing the split view identity can leave the column subtree empty. For a runtime compact transition, present the same `tocColumn` at the workspace root until it closes; this preserves one TOC implementation without reintroducing the old sheet or duplicate toolbar controls. When TOC is requested from the Study sheet, defer that transition until the sheet's dismissal callback so the two presentations never overlap; screenshot scenarios must first observe the sheet's presented state before exercising it.

Example:

- [x] Example improvement
  - Implemented: YYYY-MM-DD
  - Commit/PR: ...
  - Notes: ...

## Archive

Older completed/superseded items that still have historical value.
