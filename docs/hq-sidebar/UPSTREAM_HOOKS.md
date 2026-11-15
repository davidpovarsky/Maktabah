# U — Build11201 sidebar repair: minimal hook record

2026-11-15 · [מיה | UX] [MAIN_SESSION] · chat `01a1dc8a-c7c4-7080-8a49-d61dd056fa47`.
Branch `codex/otzaria-sidebar-20261115`; base `df2a21941afa46da716387fce9de620865d2a151`.
Pinned upstream `d46af139b3a265399c16d87f5923acd8e3444024`; read-only `git ls-remote upstream refs/heads/main` returned exactly this SHA. No upstream sync performed. Merge base with HEAD before edits was the base above.

## File ownership and exact hooks

| Path | Ownership | Scope and necessity | Alternatives / risk / rollback |
| --- | --- | --- | --- |
| Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift | DOWNSTREAM_OWNED; absent in pinned upstream | Replace conditional Library/TOC branches with native page-style TabView at the same sidebar location. Keep original page NavigationStacks, stable library identity and existing active-tab TOC identity. Retain native split configuration and dot controls. Respect Reduce Motion for selection animations. Scope native-toggle environment flag to pager descendants. | Conditional transitions would still destroy local navigation/scroll/expansion state. A custom pan/offset container would duplicate native pager arbitration. Native nested navigation/search preferences, RTL, vertical row interactions and screen edges require runtime evidence. Revert this lane's commit. |
| Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift | DOWNSTREAM_OWNED; absent in pinned upstream | Add false-default environment key `readerSidebarOwnsToggle`, set only by pager. No page/state/reader routing changes. | Checking scene-wide coordinator presence would also suppress Close in unrelated sheets. No new source membership. Revert this lane's commit. |
| Source/UI/iOS/Views/iPadLayout.swift | UPSTREAM_OWNED, SHARED_INTEGRATION_SEAM; upstream blob `9ad82bcfaf091056c7ea12a029a2856a89611653` | In existing viewer Library builder only, move the existing searchable modifier from NavigationStack to its Library content; replace `.toolbar` placement with `.navigationBarDrawer(displayMode: .always)`. Exact binding remains `Bindable(bManager.libraryViewModel).searchQuery`. | Pager cannot move an opaque closure's search modifier. Another search field would compete with the canonical native field. No changes to other tabs or library implementation. Revert this exact hunk. |
| Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift | UPSTREAM_OWNED, SHARED_INTEGRATION_SEAM; upstream blob `823c616083095ea89a2c5d90cc88ee58cfe64c57` | Read downstream environment flag; wrap only existing `.topBarLeading` Close ToolbarItem in `if !sidebarOwnsToggle`. Button callback, icon, identifier and other items remain identical. | Descendant cannot remove one ancestor-published item safely after creation. Hiding the whole bar loses TOC principal/search. Global suppression removes sheet Close. Native split owns visibility/toggle in pager; non-pager sheets retain existing item. System-provided sidebar symbol remains system-owned. Revert this exact hunk. |
| Tests/HQ/sidebar/Sidebar11201AcceptanceTests.swift | New DOWNSTREAM_OWNED, test-only | Two prepared black-box cases (Hebrew RTL/English LTR), subclass existing FaithfulReaderUIBase. No app target membership required. | NOT_RUN and not registered in project; requires explicit runtime authorization and existing isolated fixture setup. |
| tools/hq-sidebar-check.py; docs/hq-sidebar/** | New DOWNSTREAM_OWNED | Local bounded checks and audit evidence only. | No CI/workflow/project edits. |

Exact original-source diff against base: `upstream-hooks.patch`. This register is private to this worktree; shared HQ/register files were not edited. Existing 11001 split geometry/native-button configuration, reader mount, active-tab UUID scoping, backend/data/search engines and source anchors were not rewritten. Full historical divergences in the two protected files remain legacy debt, not new permission.

## Validation and review

`py -3 tools/hq-sidebar-check.py`: EXECUTED_PASS (27 real portable policy assertions; five Swift syntax parses including active Apple pager branch; git diff --check). Windows parsing is not Apple-framework typechecking. Source ownership/diff reviewed manually; no automated provenance guard claim. Independent reviewer: OPEN (Roni/Tomer).

No app build, CI, simulator, device, animation capture, reader mount runtime evidence or physical-iPad acceptance run. These remain NOT_RUN, not DONE. Rollback: revert the scoped implementation commit, or restore only these exact hooks from base after preserving any later edits. No data migration, user DB or persisted-format change.

## API evidence

The shared apple-devtools skill was read; `apple-doc` resolved the two focused documentation queries. `apple-api` implementation was inspected and found to dispatch an authority workflow, so no such job was launched. Stable public APIs are documented by Apple:

- [Native paged TabView](https://developer.apple.com/documentation/swiftui/tabviewstyle/page)
- [Search interface attachment and bindings](https://developer.apple.com/documentation/swiftui/adding-a-search-interface-to-your-app)
- [Navigation drawer search placement](https://developer.apple.com/documentation/swiftui/searchfieldplacement/navigationbardrawer(displaymode:))
- [Always-visible drawer display mode](https://developer.apple.com/documentation/swiftui/searchfieldplacement/navigationbardrawerdisplaymode)

These support the API choice, not an assertion that this app's runtime behavior passed. Installed Apple SDK signature/typecheck verification remains NOT_RUN.
