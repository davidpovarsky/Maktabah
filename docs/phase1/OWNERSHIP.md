# Phase 1 ownership and recovery

Owner instruction: execute Phase 1 alone from 493717696eea48446a096381ecc154628962dedd; preserve all other worktrees/data; no main/release. New worktree: Maktabah-phase1-consolidated-20261116; branch codex/otzaria-phase1-consolidated-20261116.

Upstream remote HEAD verified and fetched read-only on 2026-11-16: d46af139b3a265399c16d87f5923acd8e3444024. Prior upstream/main was 46e893c65139fbb1e582d6595b0d220ea912324a. This is not an upstream sync.

| Paths | Ownership | Planned change | Approval / validation |
|---|---|---|---|
| Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift | DOWNSTREAM_OWNED | Reconcile U native body pan with current source; retain reader identities | Phase1 request; actual RTL/LTR UI |
| Source/ChavrusaText/Dependencies/CommandPalette/.../CommandPaletteView.swift and ToolbarSearch/LibraryCommandPaletteAdapter.swift | DOWNSTREAM_OWNED fork adapter | U calibrated Escape implementation; remove superseded diagnostics | U c42 source, actual HID/window cases |
| Source/ChavrusaText/Search/UI/GlobalSearchAdvancedOptionsContent.swift and GlobalSearchHeader.swift | DOWNSTREAM_OWNED | Native Form scroll surface and bounded popover sizing | Original conditional controls and unsuppressed AX audit |
| Source/ChavrusaText/UIRoutingHost and Source/Otzaria/Actions,UIRouting | DOWNSTREAM_OWNED | Only proven current-v1 defect fixes; retain same authority/receipt/replay | Existing security tests plus real History URLs |
| Maktabah-iOSUITests and Scripts/CI | DOWNSTREAM_OWNED acceptance tooling | Reconcile U secure HID/owned-window isolation; repair demonstrably wrong native queries without lowering assertions | Retain original RED evidence, original native assertions, no skipped tests |
| docs/phase1 and docs/hq-ui-inventory/current | DOWNSTREAM_OWNED documentation | Intake, source fingerprints and coverage | Exact immutable Git objects |
| iOSNavigationManager.swift and iPadLayout.swift | UPSTREAM_OWNED / existing approved seams | Preserve bytes of 493 exactly | Existing exact two-hunk approval in docs/hq-native-binding-integration/APPROVED_HOOK_APPLICATION.json; no new approval needed for unchanged code |
| Vendor engines, DB, lockfiles, app project and workflow triggers | UPSTREAM/VENDORED/SHARED; unchanged | No edits | Source-tree comparison and preserved pins |

Intake uses file-scoped three-way merges with recorded base/ours/theirs blobs, never older whole-file replacement over newer code. Existing R startup and canonical workspace owner remain. New test/build execution uses disposable CI simulators and original engine/fixture; no user DB is opened or migrated. Rollback is the frozen original493 worktree or revert of individual phase commits; no reset/clean/stash or data cleanup.
