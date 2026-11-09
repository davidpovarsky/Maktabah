# Strict 10601 repair — 2026-11-09

This is an implementation ledger, not device acceptance. Primary session only;
no Simulator, Asana writes, upstream sync, or rejected-10701 code imports.

## Locked starting evidence

- Worktree: `C:/Users/DAVID/Code/Maktabah-10601-strict-ui-repair`.
- Branch: `experiment/ipad-ui-10601-strict-repair`.
- Initial HEAD and remote: `cd5e8fef38ea2f8cfc9e3f27fbc995ade94934ec`;
  clean porcelain; `Source` identical to `70810eec46ad1fec6f30d983bf31e5f922dacb61`.
- Original upstream HEAD observed read-only: `46e893c65139fbb1e582d6595b0d220ea912324a`;
  merge base: `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`.
- Seven attached owner screenshots inspected. They show intended side Inspector,
  unwanted bottom panel/blank band, frozen toolbar controls and mismatch alert.

## Pre-edit issue / ownership / minimal-hunk matrix

| Defect | Verified code fact; runtime uncertainty | Ownership and planned hunk | Invariant / gate / rollback |
|---|---|---|---|
| BUG-01 | Enabled-sidebar `shouldPresentPanelInContent` always returns true. Detail geometry already exists. | Protected `iOSReaderWorkspaceView.swift`: proposal only until exact approval; downstream `ChavrusaReaderWorkspaceLayout.swift`: width policy. Historical approval is for floating, not the requested reversal. | Same reader structural slot, selection/session untouched; actual-width threshold tests including Dynamic Type; remove policy/hook together. |
| BUG-02 | Search List has no row/background theme policy; existing `Color.appBackground` is dynamic Default/Sepia/Dark. | Protected `SearchResultsListView.swift`: propose only row backgrounds and hidden scroll backing. No approval recorded for these hunks. | No query/provider/highlighting/pagination changes; source row-family checks; revert modifiers. |
| BUG-03 | Library wrapper supplies navigationTitle without inline mode; global TabView and split own separate legitimate bars. Pixel owner not proven by source alone. | Inspect protected iPadLayout/Main/Library/Reader; downstream host/sidebar only if a duplicate is demonstrated. No arbitrary inset or control relocation. | Navigation/safe-area tree ledger; device pixels OWNER_ACCEPTANCE_PENDING. Revert only a demonstrated hunk. |
| BUG-04 | DocumentTabsHost injects identical strip and active-flare backgrounds, eliminating fill contrast. Original UIKit layout/controller retained. | Downstream `DocumentTabsHost.swift`: inject existing semantic secondary strip surface, preserve reader-colored active flare. No vendored geometry changes planned. | 0/1/3/10 source state and original-source audit; hidden embedded buttons remain disabled. Restore theme argument. |
| BUG-05 | Overview selectedID and active-card fast return use group-global active ID, while scene selection has its own ID. Full-context bridge already exists. | Downstream `StudyGroupsOverview.swift`: use scene-qualified active ID through adapter. | UUID/scene selection tests, overCurrentContext and reader identity source checks; revert selection expression only. |
| BUG-06 | SafariGlass already owns group material; its regular glass has no native interactive feedback. | Downstream `SafariToolbarSourcePort.swift`: interactive glass only for existing GlassButtonGroup, after SDK verification. | Original group/order/actions/dimensions unchanged; one material owner; revert rendering modifier. |
| BUG-07 | Hydration happens before target provider preflight; resolver accepts numeric-ID hits with incomplete work identity; nil locator defaults to Otzaria. | Downstream resolver/adapter/models/coordinator only: target-scoped preflight, exact identity, staged group participant if needed, cancellation before commit. Original navigation manager read-only. | Real portable coordinator failures/collision/persistence tests; no JSON migration/placeholders. Revert downstream hunks together. |

All candidate downstream paths must be checked against original upstream tree and
Git introduction history before editing. No protected source permission inferred
from this matrix. Proposed diffs are review artifacts only, never applied without
the required owner approval. No candidate may upload with a blocked mandatory fix.

## Frozen toolbar release gate

BUG-07 necessary allowlist extension, before editing: the existing downstream
`Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift` is absent from
original upstream and introduced by `7a8d06cc`. Its `prepareTransition` writes
outgoing session bytes before later participants can fail. Coordinator-only
rollback cannot preserve those bytes. Add a scoped staging/rollback boundary to
this existing snapshot service; do not change its schema, ordinary calls or the
protected navigation manager. Tests must use an isolated temporary service and
verify actual disk bytes and cache after partial prepare/I/O failure. This is
necessary for the explicitly requested persistent-bytes contract, not unrelated
session work. Rollback removes this boundary and the coordinator call together.

`safariToolbar` must retain one unconditional GlassButtonGroup containing overview
then plus, before collapsedSearchField, with original IDs and callbacks.
DocumentTabsHost must retain `TabsBarViewController(showsToolbarButtons: false)`.
No toolbar or reader geometry change is authorized as a styling shortcut.

## Verification / delivery

## Implemented source changes (not device acceptance)

| Defect | Implementation | Source status / device status |
|---|---|---|
| BUG-01 | Measured detail width; 430pt reader minimum scaled with Dynamic Type + 300pt Inspector + existing 18pt handle. Existing reader/HStack/Inspector session retained; presentation state updates when threshold changes. | IMPLEMENTED / OWNER_ACCEPTANCE_PENDING |
| BUG-02 | Existing dynamic app background on grouped/expanded results, progress and load-more rows, plus hidden native List scroll backing and outer background. Parent empty state already themed. Parsing, highlights, providers and pagination unchanged. | IMPLEMENTED / OWNER_ACCEPTANCE_PENDING |
| BUG-03 | Exact owner-approved inline title only in the enabled Library navigation content; matches existing inline reader. No new navigation container, hidden controls, offset or safe-area change. | IMPLEMENTED title-mode correction; screenshot band's precise pixel cause/effect remains OWNER_ACCEPTANCE_PENDING |
| BUG-04 | Existing secondary app background on inactive strip; active flare retains actual reader background. All original UIKit layout/controller/cell/flare/overview code is byte-identical to 10601. | IMPLEMENTED theme adapter / OWNER_ACCEPTANCE_PENDING |
| BUG-05 | Scene-qualified active document UUID controls selected card and no-navigation return. Existing overCurrentContext bridge, Grid/List, gestures and mounted reader unchanged. | IMPLEMENTED / OWNER_ACCEPTANCE_PENDING |
| BUG-06 | Existing group's sole glass owner gains native interaction. Original 54/52/39×44 geometry, action order, IDs and toolbar host unchanged. | IMPLEMENTED / OWNER_ACCEPTANCE_PENDING |
| BUG-07 | Target-scoped catalog before group hydration or settings async switch; qualified backend/work/local-ID match; no nil→Otzaria inference; real target metadata only. Group persistence is the final throwing step before backend/group publication. Session writes stage during participant preparation and restore original bytes/cache after failure. Cancellation/stale-generation guards retain outgoing state. | IMPLEMENTED async settings/group paths / UIKit/device races OWNER_ACCEPTANCE_PENDING |

Original upstream protected files touched: only workspace, Search results and
enabled iPad Library title, with the exact three owner-approved scopes preserved
in the two proposal diffs and protected-hunk ledger. All other production edits
are verified downstream introductions (2a46d52c, b1b4f29f, 8de3d8f5, c8cc2745,
7a8d06cc); none exists in the observed original-upstream tree. No new production
Swift files, project membership, package pins, renderers, bottom toolbar, original
navigation manager, database, localization, signing or workflow changes.

The 32-entry provenance audit preserves all original hashes/pins. Only the Safari
rendering adapter differs among recorded original-port destinations; its exact
additional patch is retained. Seven original DuckDuckGo production port files
are also enforced as baseline-identical by the source gate.

The source gate asserts the **entire reader host** is baseline-identical, not
just that action tokens exist. It checks the unconditionally grouped overview
then plus before Search, original callbacks/IDs/row height, disabled embedded
buttons and full-context overview. Seven injected regression mutants must fail.
The real portable suite tests source width policy, original tab-width algorithm
at 0/1/3/10 tabs and compact/wide widths, scene selection, actual coordinator
preflight/publication/abort/cancellation, and actual snapshot disk bytes/cache.

Final-code local gates: 61 strict repair assertions, 61 workspace contracts and
379 existing component assertions passed. Seven toolbar regression mutants were
rejected; `git diff --check` passed. Exact logs are under `build/artifacts/`.
Swift syntax parsing and actual iOS target membership check passed. Xcode generic
device compilation/signing/Apple processing remain pending until the delivery
workflow completes; no Simulator execution or simulator suite is authorized.

Glass semantics/signature reference: Apple's
[interactive(_:)](https://developer.apple.com/documentation/swiftui/glass/interactive(_:))
and [SwiftUI new design guidance](https://developer.apple.com/videos/play/wwdc2025/323/).
Automatic title behavior reference: Apple's
[automatic title mode](https://developer.apple.com/documentation/swiftui/toolbartitledisplaymode/automatic).
SDK symbol searches 42679108421/42679847413 completed but did not isolate the Glass
method; those successful jobs are **not** claimed as API/compiler acceptance.
The final device build must compile the actual changed glass source.

Simulator: NOT_RUN (owner instruction). All native UI and physical iPad checks:
OWNER_ACCEPTANCE_PENDING. Experimental candidate dispatch follows final source
and portable gates only; no visual fidelity claim or public App Store submission.
