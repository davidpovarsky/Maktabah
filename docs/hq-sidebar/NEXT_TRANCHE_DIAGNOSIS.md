# Reader follow-up diagnosis — 2026-11-15

[מיה | UX] [MAIN_SESSION], chat `01a1dc8a-c7c4-7080-8a49-d61dd056fa47`.
Manager assigned read-only diagnosis of GIDs `1220120627071765` and `1220120889353811`; both live tasks/notes/comments read (no comments). Inspected at branch `codex/otzaria-sidebar-20261115` HEAD `31ee0727a524606dda2bc33050ec3f7bef7e0c09`, app source remains `d77045feb24f1dc025e0554b2a2bf252a3bf5e14` on df2a2194. No source edit in this tranche; existing U lease retained. No code/Asana claim is based on an old assignment snapshot.

## 1220120627071765 — slider canonical unit vs explicit paragraph

**Finding: existing source correction present; real-device and integration acceptance unverified. Do not reimplement it.**

- `Source/ChavrusaText/Navigation/ReaderNavigationDisplayPolicy.swift` is downstream-owned (absent at pinned upstream). Latest source edit `60cc8583e301e6d58da3bfcd3ee593a88b4b2b1a` (4 Nov), after the 2 Nov user report. It follows actual TOC parent IDs, keeps nearest named daf/chapter/section rather than a fixed depth, excludes paragraph-only leaf fallback, preserves amud punctuation, and falls back to the work title when no unit is established.
- Its existing `ReaderNavigationDisplayLabel` connects that policy to `iOSReaderBottomToolbarView` (line 31) and the navigation popover (current/header, drag preview, first/last slider labels). It asynchronously resolves paragraph descriptor ancestry without changing canonical locators or reader selection. Semantic behavior is gated to faithful iPad Otzaria UI; other backends use existing fallback.
- Precise reference is exposed only when no explicit preview locator was supplied and native/saved selected range has positive length, using `otzariaSelectedLineAnchor.heRef`. A mere current/visible paragraph anchor does not itself permit the fine reference. Content changes clear readerState range and downstream selection anchors. Inspecting current source shows this intended distinction; it does not prove live selection-clear observation or real-corpus hierarchy correctness.
- Existing `tools/test_faithful_study_workspace.swift:210–225` contains canonical daf/paragraph/fallback/chapter/ancestry assertions. They were inspected, **not executed** in this tranche. They do not prove native label refresh, actual fixture descriptors, TOC/scroll accuracy or device behavior.

Remaining targeted acceptance: ordinary reading/scroll vs explicit nonempty selection vs cleared selection in at least a daf work, chapter work, and irregular branching TOC; drag slider without selection while an old paragraph anchor exists; tab/backend switching with asynchronous label loads; verify actual current-unit locator/visible heading and preserved reader viewport. Tap-based Inspector paragraph selection and native text-range selection should be distinguished explicitly in the fixture expectations: current fine-reference gate uses nonempty native range. If owner expects taps alone to display a paragraph reference, that is not established by the present gate. No new algorithm or reading-core edit is proposed without an actual failed oracle.

## 1220120889353811 — global history absent from book search

**Finding: a genuine current source gap remains in book search, not merely an unrun device gate.**

- Global `Source/Features/Search/iOS/SearchModeView.swift` uses the canonical unified session and SearchViewModel store, explicitly binds `$isSearchFieldFocused`, records submissions via `viewModel.addToHistory(session.query)`, and mounts history when that global field is focused. The focus correction is commit `8d69758b72807d29f225620b16b62251cad49d58` (5 Nov). S owns this file; no change requested here.
- `Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift:68–73` still mounts `SearchHistoryOverlay(viewModel:isVisible:.constant(nil))` in book search. Commit `2a46d52c` had removed it; `3dc5100900fc25eac1b312d7893eb50e7bd510cb` (10 Nov, original UI restoration) added it back. This explains why old implementation/test descriptions must not be treated as current PASS evidence.
- `Source/Features/Search/iOS/SearchComponents.swift:18–37` makes that overlay visible during native searching with empty results, and renders history from the same `viewModel.searchHistory`. The overlay also owns the book search mode/near-distance/help controls. Removing the entire overlay would discard those native features and is not an acceptable narrow fix.
- Canonical history storage already exists in `Search+iOS.swift` (`loadHistory`, deduplicated/capped `addToHistory`, `removeFromHistory`, UserDefaults historyKey). No second engine/store is necessary or proposed.
- Existing prepared `FaithfulReaderUIAcceptanceTests/testHistoryRemainsGlobalAndIsAbsentFromBookSearch` exists around line 1509, but was **NOT_RUN**. It must remain a pending runtime test, not proof that the reintroduced overlay is harmless.

### Concrete minimal connection proposal — needs an extended file lease

Both paths below exist in upstream `d46af139b3a265399c16d87f5923acd8e3444024`; neither is currently in U's source lease. No edit applied.

| File | Provenance | Exact proposed hook | Necessity / rollback |
| --- | --- | --- | --- |
| Source/Features/Search/iOS/SearchComponents.swift | UPSTREAM_OWNED/shared component; pinned blob to be recorded before editing | Add default-true `showsGlobalHistory` view parameter to existing SearchHistoryOverlay; gate only history header/list with it. Keep inputControls, help, mode, distance, visibility and existing global callers unchanged. | Existing component owns both unwanted history and required controls; outer composition cannot selectively hide just the history rows. Default preserves all other callers. Revert this tiny parameter/condition hunk. |
| Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift | UPSTREAM_OWNED/shared host seam; pinned blob `3519f971897ee248a0f744a8b04ea28b29ef6d3b` | Pass `showsGlobalHistory: false` only to the existing book overlay. | Narrow host-context configuration, no replacement UI/store/engine. Revert this argument. |

Prefer this existing component extension point to a new downstream duplicated overlay, global environment hack, tree traversal or wholesale restoration. No edits needed in S-owned SearchModeView/SearchResultItem/search engines, or P-owned reader models/core. If another active writer holds SearchComponents, sequence that single conditional through that owner. Exact new lease is required before code changes here; read-only findings/plans are complete and independently reviewable.

Proposed focused validation after such a lease: parse the two touched files; manual upstream hunk audit; test default global history vs book false without removing input controls; authorized existing UI case plus long/short query, backend/book switching, RTL and persisted global history across relaunch. Device gates stay OPEN. No project build, CI, simulator or user DB operation executed.
