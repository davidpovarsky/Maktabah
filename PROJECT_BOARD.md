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
- In iPad modal sheet forms (`iOSAnnotationEditorSheet`), Form bottom action buttons (like Delete Annotation) can be scrolled out of the initial modal viewport in landscape orientation (~y > 850), causing IDB coordinate taps to miss the window bounds; providing a `ToolbarItem(placement: .destructiveAction)` with dedicated accessibility identifier and `label_fallback="Delete Annotation"` ensures both XCTest accessibility taps and coordinate taps hit the navigation bar reliably without requiring manual Form scrolling.

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
