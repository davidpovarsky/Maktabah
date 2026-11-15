# Sidebar lease ACK — 2026-11-15

[מיה | UX] [MAIN_SESSION] NORMAL; independent primary Desktop chat.

Transport: `OTZ-U-151126`, `OTZ-U-151126-DELIVERY`.
Chat UUID: `01a1dc8a-c7c4-7080-8a49-d61dd056fa47`.
Dispatcher: `01a1dc84-2697-7902-b100-9e23913eb7f4`.
Worktree: `C:\Users\DAVID\Code\Maktabah-hq-sidebar-20261115`.
Branch: `codex/otzaria-sidebar-20261115`.
Base/initial HEAD: `df2a21941afa46da716387fce9de620865d2a151`.
Pinned upstream: `d46af139b3a265399c16d87f5923acd8e3444024`.
Pre-edit status/diff: clean; no existing user changes. Merge base equals base HEAD.

## Explicit lease

Own ReaderSidebarPager.swift, ReaderSidebarPageCoordinator.swift and new downstream files in Source/ChavrusaText/ReaderHost; new Tests/HQ/sidebar/**, tools/hq-sidebar-* and docs/hq-sidebar/**. Tiny necessary hooks only in Source/UI/iOS/Views/iPadLayout.swift and Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift. No other source, shared registers or HQ writes. GIDs: 1220036777923344, 1220036883843537 only.

## Pre-edit provenance / hook plan

| File | Classification / origin | Proposed scope | Alternative / necessity | Validation | Rollback |
| --- | --- | --- | --- | --- | --- |
| ReaderSidebarPager.swift | DOWNSTREAM_OWNED; absent at pinned upstream; last observed change 8ea4f578 | Repair body swipe/animation and preserve page state | Existing downstream pager is correct seam | Focused policy checks + review; real iPad NOT_RUN | Revert scoped commit |
| ReaderSidebarPageCoordinator.swift | DOWNSTREAM_OWNED; absent at pinned upstream | Only necessary shared ownership/state support | Prefer existing coordinator | Focused checks; runtime NOT_RUN | Revert scoped commit |
| iPadLayout.swift | UPSTREAM_OWNED / shared seam; upstream blob 9ad82bcf | Move existing canonical searchable modifier out of toolbar content, if confirmed | SearchQuery binding belongs to existing Library navigation view; a new search system would duplicate it | Diff/manual source audit; iPad NOT_RUN | Revert exact hook |
| iOSTOCView.swift | UPSTREAM_OWNED / shared seam; upstream blob 823c6160 | Suppress manual close item only in native sidebar context, if confirmed | Existing native split already owns toggle; retain sheet/non-sidebar close | Diff/manual source audit; iPad NOT_RUN | Revert exact hook |

Source policies read from current main worktree (15 Nov revision), not stale worktree copies. Exception/debt registers reviewed; no historical debt treated as approval. No push, merge, CI, full build, TestFlight, user DB access, dependency installation or delegation. Current scope is documented Build11201 regression repair, not planned new UX. Physical iPad and visual/runtime acceptance remain NOT_RUN until evidence exists.

Pre-edit diagnosis: the actual base already attaches searchable outside the toolbar builder, but requests `.toolbar` placement on the Library NavigationStack. The narrow hook will move it onto that stack's existing Library content with `.navigationBarDrawer(displayMode: .always)`, preserving the exact SearchQuery binding. The earlier task wording is historical. For page retention and continuous interactive motion, use native `TabView(selection:)` / `.page(indexDisplayMode: .never)` inside the existing sidebar only, preserving the two original NavigationStacks; do not add a competing custom body drag. Existing dot-strip direction policy remains available. Set a downstream environment flag only within this pager so the TOC's existing close ToolbarItem can be conditional; unrelated sheets keep their close action. These exact hook scopes are recorded before source edits.
