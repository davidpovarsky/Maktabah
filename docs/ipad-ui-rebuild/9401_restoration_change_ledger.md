# Authentic 9401 restoration — change ledger

## 2026-11-10 — native sidebar repair follow-up

The entries below retain the historical 11001 delivery record. New isolated branch `experiment/ipad-ui-9401-native-sidebar-toc-fix` starts at actual verified tip `8632dd3165c9dabdee62931f0e011f542b4bc815`. Source commit `dcc405d1d82c7dc70118c7e02bdc827dee5c58a7` changes only the exact newly owner-approved five-line `iPadLayout.swift` hook and downstream-owned `ReaderSidebarPager.swift`; all other 11001 application/vendor/build/workflow contracts and all 80 EXACT_9401_BLOB entries remain unchanged. Original reader toolbar, TOC, row and tab implementations are not edited. Approval, before/after provenance, old-pin fail-closed transition and implementation boundaries are recorded under `native-sidebar-11001/` and in the upstream exception register.

The pager conditionally mounts one original navigation owner. Its existing page controls retain their appearance; page swiping is confined to that strip. An additive `UIViewControllerRepresentable` configures the existing public double-column ancestor, without replacing its children or delegate: request `.tile` only when actual width accommodates native primary width plus at least 430pt reader/divider, scaled for Dynamic Type; otherwise retain native adaptation. On iPadOS 27 request the existing native display-mode button with `.always`; add no manual toolbar item. Original columnVisibility/preferredCompactColumn bindings remain the sole visibility/navigation state. Selected TOC anchor and view models remain original; remounting the TOC reconstructs its local query/expansion state as with its original navigation lifetime. Follow-up source commit `8ea4f57806b9f1f6766bfda0a0828cdc07cf6645` keys only the TOC page by its actual reader-tab UUID, preventing book-local node-ID collisions from retaining a prior book's state. The initial run was cancelled before archive/upload to include this correction; its terminal metadata is recorded.

Evidence changes are a separate commit from application changes. The guard retains all previous assertions and adds exact owner-approved iPad/pager pins, 11001 retention checks and native navigation/search/toggle/tile/gesture invariants. All 20 prior negative tests remain, with 14 additional mutations. Actual portable policy: 27 assertions; existing workspace: 61; component/backend/RPC: 379; source adversarial: 34. These are static/portable evidence, not physical geometry or interaction acceptance. Generic-device compilation and distribution must still pass through the existing production TestFlight workflow before a new delivery can be reported. No simulator, UI test, merge, Asana update, signing/configuration/pin change or new workflow was introduced.

Status: **SOURCE_VERIFIED_DEVICE_ACCEPTANCE_PENDING**, main session only, 2026-11-10. This is a locally committed candidate, not a TestFlight delivery or visual acceptance.

## Pinned provenance and isolation

- BASELINE_9401_SHA: `f243d06603cbe506de8f27ea8b9a479af4415e2e`.
- FEATURE_BASE_SHA: `905439c9b41144ab34e7071e067ec09bc474d4f3`.
- Actual remote feature HEAD was checked with `git ls-remote` and equals FEATURE_BASE; no subsequent feature commits were omitted.
- Actual upstream HEAD: `46e893c65139fbb1e582d6595b0d220ea912324a`.
- Original chat worktree HEAD: `f393dc43659ac2e771d25fd570b89d4eb2cfa76f`; it was clean and was not edited.
- Feature worktree was clean; it was not edited or reset.
- New worktree: `C:\Users\DAVID\Code\Maktabah-9401-exact-ui-restoration`.
- New branch: `experiment/ipad-ui-exact-9401-restore`.
- DELIVERY_SHA: `0d2ac9c46fe33d5a650fcf9ee7e66b2aa8bd2a73`. Production TestFlight build 1.0.0 (11001) was archived/signed/exported/uploaded successfully and Apple processing is VALID; see `9401_TESTFLIGHT_11001.he.md` and `9401_evidence/delivery.json`.

## Source reinstatement and exceptions

Commit `3dc51009` restored eight actual 9401 blobs with path-specific `git restore --source`; this was not a wholesale Source rollback. Six remain exact in the candidate after the separately approved reader state hook; the fork-owned workspace was then narrowly adapted for exception A. `3706e3ce` attached the shared-sidebar/palette composition. `1151bb45` moved the scene lifecycle attachment outside the global tabs. None changes backend transitions, provider identities, user databases, signing, package pins, build membership or workflows.

The machine inventory covers every original Source file (592), every current Source module, and vendor/build/workflow/lock contracts. Its iOS/reader/theme scope contains **80 exact baseline files and 9 declared exceptions**. All original TOC/tree/row code, ReaderTabsView and its popover, theme components and original theme asset bytes are exact. Files outside the visual scope that are unchanged from FEATURE_BASE are classified BACKEND_RETAINED, not falsely claimed equal to 9401. Git blob identity, exact diffs and every matching unchanged line block (ranges and SHA256) are generated from real Git objects. The source_commit pins application/build blobs; a later documentation-only commit is checked against those same blobs to avoid a self-referential manifest SHA.

The original iPadLayout root TabView and all five global tabs, Search, Authors, Notes, History, synchronization and unaffected functions are unchanged from 9401. The only edits to that upstream file are exception A/B state and viewer composition plus the owner-requested native study profiles action (follow-up 2026-11-10), original TOC selection's compact-close bridge, and attaching the viewer toolbar modifier. The removed `content:` column becomes the second page of the single original sidebar. ReaderSidebarPager retains the previously agreed page controls/swipe; it never owns a reader. The original native library searchable is present.

The workspace file is **downstream-owned**, absent from pinned upstream; its protected-looking directory is not ownership evidence. Its readerSurface (including original title and inspector button), floatingWorkspace, resize handle, inspector provider, note editor/actions and compact native presentation functions remain exact original blocks. The shared route holds the original wideWorkspace HStack/reader in one structural position across page/width changes, measures the detail column, and attaches the same native FloatingPanel configuration for narrow widths. Its original 430/300/18 reader/panel/handle thresholds and original appearance are retained. No replacement ChavrusaReaderWorkspaceLayout is mounted. This composition is a declared exception, never a claim of whole-file equality. Actual TextKit identity, resize, rotation and visual behavior still require device evidence.

Six other declared exceptions are **unmodified FEATURE_BASE files**, retained under directive sections 2.2/5 to avoid downgrading current focus, search history, dynamic background corrections, canonical references, search-popover state or phone/session behavior. They introduce no new protected hunks. Search result color corrections are specifically reported as retained differences; no full visual parity is claimed. Exact diffs in the manifest remain reviewable. No approval for future edits is implied.

## Active call-site evidence and retained functionality

The active iPad path is iOSMainView -> iPadLayout.viewerTabContent -> one iOSReaderTabView -> iOSReaderWorkspaceView -> original readerSurface -> iOSReaderView -> original _ReaderTextContentView/iOSIbarotTextView. iOSReaderTabView's original regular/compact conditions mount ReaderTabsView from ReaderTabItemView.swift; iOSMainView's iPad sheet still invokes original iOSReaderTabsPopoverView. The sidebar invokes original iOSLibraryView and activeReaderTableOfContents -> original iOSTOCView -> original TOCNodeRow, with the active tab's real view model/provider. No reconstruction is stored alongside the active original views.

ChavrusaReaderHost, SafariLibrarySearchField, DocumentTabsHost, TabsBarViewController, TabSwitcherPagePort and StudyGroupsOverview are not mounted in this iPad viewer route. They remain compiled/retained for other code and the unchanged phone behavior. Non-rendering ReaderSceneIdentityReader and StudyWorkspaceCheckpointObserver are intentionally still referenced from their existing file; its host view is not instantiated. The existing gelatinMotionOnly helper is reused for the palette's motion, without mounting Safari toolbar chrome.

Exactly one Exact9401ViewerToolbar modifier is attached inside the viewer detail. It adds one native topBarTrailing magnifyingglass Button, then renders the **unchanged current** LibraryCommandPaletteAdapter and existing CommandPaletteView. Its existing canonical locator command IDs, manager.openBook, result dismissal, focus/query handling and UIKit Escape implementation are unchanged. The overlay has no new navigation container or safe-area inset and is removed on viewer disappearance. This is call-site evidence only; Hebrew input, rapid open/close, hardware Escape and VoiceOver were not exercised on a device.

The existing iOSMainView scene-lived CompactStudyWorkspaceHostModifier mounts Exact9401WorkspaceLifecycle once for iPad. The old phone modifier's !isIpad enablement and phone overview behavior remain unchanged. The new iPad lifecycle uses the existing durable scene identifier, StudyWorkspaceNavigationAdapter, current-process store, attach, checkpoints, group reconciliation, backend-change and scene-phase synchronization. It has no reader chrome and does not construct another navigation store. It remains mounted when changing global tabs; the detached host no longer owns the iPad lifecycle.

Group/profile models, data and APIs remain unchanged. The owner follow-up on 2026-11-10 adds study profiles to the toolbar as a third approved visible difference. The native toolbar Menu uses the existing StudyProfileMenu actions, with its original Safari-style wrapper confined to the old phone route. Selecting a profile uses the same workspace.switchGroup action. Its management action presents the unchanged StudyProfileManagementView, including profile create/edit/delete/reorder and existing group rename/reorder/move-to-profile actions. It shares the one scene-lived adapter through an environment value; no duplicate store or coordinator is created. The original reader buttons are untouched. `d96e87e4` records this separately.

The old StudyGroupsOverview remains hidden on iPad: group creation/deletion, full group overview/switching, cross-group document move/copy and its document overview/reorder controls are not claimed accessible. Original book tabs remain available; phone management presentation is retained. These are source accessibility statements, not device interaction PASS.

## Exact protected hook — explicitly approved and applied

The owner replied **“מאשר את ה־diff המדויק”** in the current chat on 2026-11-10 to the four-line proposal in `9401_PENDING_OWNER_HOOK.diff`. It adds the existing shared-sidebar environment property and computes the original TOC state using the sidebar page in upstream-owned iOSReaderView.swift. The complete original toolbar subtree remains byte-identical. `9401_pending_approval.json` freezes original/proposed blob IDs, patch SHA256, actual owner response reference, alternatives, scope and rollback; despite its historical filename, its status is APPROVED_EXACT_HUNK and applied=true. The exception register records the actual approval. Commit `730a5b83` applies only those four lines.

The source gate accepts only the exact approved reader blob `67146db4a47746c8412a8ee7d8b16328ff951e19`, verifies the frozen patch digest and approval record, and tests missing/altered approval negatively. Any further protected deviation remains blocked. This is not an approval for new toolbar or layout changes. The gate in UPSTREAM_INTEGRITY_POLICY.md section 1 was followed before application.

## Verification and delivery limits

- Portable workspace checks: executed; 61 persistence/migration/rollback/scene/semantic-location checks passed.
- Existing portable component suite: executed; 379/379 assertions passed, including backend transition/rollback/identity, source-anchor, search routing and RPC contracts.
- Adversarial source checks: executed; 20 checks cover original-button removal, active DuckDuckGo tabs, altered TOC, duplicate title, missing feature coordinator, original global tabs, single reader, current palette reuse, original inspector action, forged/false blob claims, backend drift, inventory omission, approval and classification bypass, plus native profile access and unchanged profile switch actions. The actual approved-source fixture has zero static route violations; missing or modified hunk authorization is rejected.
- Static source gate: **PASS** on actual committed Git objects; this does not imply visual/device acceptance.
- Existing project-membership verifier: executed; 91 Otzaria sources, both search frameworks and dictionaries verified. Added types live in already-member downstream files; project membership was not changed.
- Windows Swift syntax parse: executed for the changed application files, including the profile menu. It is not Apple-framework typechecking.
- Full app device SDK compilation, archive, signing, IPA, TestFlight upload/processing: **SUCCESS** in run 42711662307, exact DELIVERY_SHA, production build 11001; Apple processing **VALID**. Full device/visual acceptance remains pending.
- No simulator, simulator UI tests, xcodebuild test or physical-device interaction was run.
- All actual reader durability, TOC/selection/rotation, themes, original tab layout/toolbar geometry and palette interaction acceptance: **OWNER_DEVICE_ACCEPTANCE_PENDING**. Neither hashes nor these portable tests prove UI acceptance.
- Merge risk: six upstream-owned original paths are changed from FEATURE_BASE: iPadLayout, iOSLibraryView, iOSBookSearchView, iOSReaderTabView, iOSReaderView, and iOSIbarotTextView. iPadLayout and the approved four-line reader state hook remain non-identical to 9401; the other four are original blob reinstatements. Every changed path is listed below and the manifest records all non-identical baseline hunks; the one new protected reader hook was applied only after exact-hunk owner approval. Restore/reset nothing in existing worktrees. Recovery is to stop using this isolated branch; its source changes are separated into reviewable commits.

## Every original UI file changed between 9401 and FEATURE_BASE

| Path | Ownership | Baseline blob | Candidate blob | Classification |
|---|---|---|---|---|
| `Source/Features/Library/iOS/iOSLibraryView.swift` | UPSTREAM_OWNED | `ede65ecf6d6117a1fe48c8bd51f51e229c2c3be9` | `ede65ecf6d6117a1fe48c8bd51f51e229c2c3be9` | EXACT_9401_BLOB |
| `Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift` | UPSTREAM_OWNED | `6f19264c9248b1a06c3bfa57092f90bc319965e8` | `6f19264c9248b1a06c3bfa57092f90bc319965e8` | EXACT_9401_BLOB |
| `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift` | UPSTREAM_OWNED | `95e0e8cb3085b82fffc23f77c89e2f3c3ea879ec` | `de504b55304909dc804606aa7e4b3c80a52f5bc5` | DECLARED_EXCEPTION |
| `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift` | UPSTREAM_OWNED | `6381e62df4fe0dace12efb44987a7bcbf7d3c6a2` | `e7fdeeada1226cf42552b3b4484234e44d478293` | DECLARED_EXCEPTION |
| `Source/Features/Reader/iOS/iOSReaderTabView.swift` | UPSTREAM_OWNED | `21968285d3de6fc1fa1dd1614084c3e1a099436b` | `21968285d3de6fc1fa1dd1614084c3e1a099436b` | EXACT_9401_BLOB |
| `Source/Features/Reader/iOS/iOSReaderView.swift` | UPSTREAM_OWNED | `9578ce48ac743cdca1fb02ca03a3dfc9b2c53824` | `67146db4a47746c8412a8ee7d8b16328ff951e19` | DECLARED_EXCEPTION |
| `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` | DOWNSTREAM_OWNED | `b1da0865cbf084f00b25e0456784569b34663a47` | `005860a415963af2fbcdd90028b6bae75a87e4a7` | DECLARED_EXCEPTION |
| `Source/Features/Search/iOS/SearchComponents.swift` | UPSTREAM_OWNED | `f2d54d4ecb370af011054fa1dfe65a8350d1575f` | `05f7b870a52ca30a1df8442f46abcc03e589acec` | DECLARED_EXCEPTION |
| `Source/Features/Search/iOS/SearchModeView.swift` | UPSTREAM_OWNED | `6e45959aa5f828127eeac199471f060463865c0a` | `8e2882537e0ab3b65debb870d249e205ca1502b5` | DECLARED_EXCEPTION |
| `Source/Features/Search/iOS/SearchResultsListView.swift` | UPSTREAM_OWNED | `1354ba65a888ad38683e1f39bf57a13a81034046` | `34c3d6a711d81404f8ed7a9edd9a872e5a5d77c9` | DECLARED_EXCEPTION |
| `Source/Otzaria/Reading/OtzariaReaderSourcesInspectorHost.swift` | DOWNSTREAM_OWNED | `a89ca4e0b5459d170ec3bdb20fbdfb34c2361384` | `a89ca4e0b5459d170ec3bdb20fbdfb34c2361384` | EXACT_9401_BLOB |
| `Source/UI/iOS/Views/Common/iOSTabBarVisibilityPolicy.swift` | DOWNSTREAM_OWNED | `d647b4da1b5bb3a7bc5b2023cdd3efc57db77741` | `d647b4da1b5bb3a7bc5b2023cdd3efc57db77741` | EXACT_9401_BLOB |
| `Source/UI/iOS/Views/iOSMainView.swift` | UPSTREAM_OWNED | `5b96b54da1d7bd3733b01a0663ed049103ade249` | `d601e433fd214b772469e228c1877a518977913c` | DECLARED_EXCEPTION |
| `Source/UI/iOS/Views/iPadLayout.swift` | UPSTREAM_OWNED | `64f9da17d651be152abe062c8d7ccdb9d95e79f5` | `80154afddb61a6ef19b04044287851c396057e9e` | DECLARED_EXCEPTION |
| `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | UPSTREAM_OWNED | `23cd37e5897b51b9d19839a089d8d3f4a0abc597` | `23cd37e5897b51b9d19839a089d8d3f4a0abc597` | EXACT_9401_BLOB |

All 9 exception diffs and unchanged-block proofs are in `9401_exact_source_manifest.json`; all 15 pre-edit original UI diffs/hunks are in `9401_before_edit_ownership_matrix.json`. No historical screenshot, Safari prototype or rejected build was used as design authority.
