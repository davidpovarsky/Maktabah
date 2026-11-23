# Library search morph: source and ownership

Prepared on 2026-11-23 for Asana task 1220036884173010.

- Isolated worktree: /mnt/development/projects/worktrees/Maktabah-library-morph-20261123
- Branch: codex/otzaria-library-morph-20261123
- Base: 1969b2065469b55e38e42cbb838a469ffa6a80f7
- Current upstream main, observed read-only through GitHub: 6069ad9068ffaabe53f5cfbab9351d5cbbb5179c.
- Historical integration provenance pin: d46af139b3a265399c16d87f5923acd8e3444024.
- No upstream synchronization is performed.
- Original CommandPalette source: halilozel1903/CommandPalette @ 9ed36f80b81783433d3e5cc5e75987f71d71bd53.
- Existing Gelatin motion adaptation: Polarizz/Gelatin @ 2a3ad4cdabe0b9d33b75b6d8839f6d36a1a1b81e. Bundled notices remain.
- Owner reference Swift: d8d9e8b41b133ec61375a970e0f2fe8fc821141cc049c68d06a5b124496d84f4 (14,577 bytes).
- Owner reference ZIP: f3a657cc1b4e43639bcfbaa210bc9c2cbbcf80f1a610f2b9031d22ab823a784f (9,091 bytes).

## Authorization

The current user instructed ChatGPT to execute the project work fully using chat subagents and direct Oracle SentinelX, with Asana updates after every stage. AGENTS.md records standing owner authorization dated 2026-11-19 for required source, configuration, tests, publication, and integration. This is broad execution authorization, not an assertion that the user reviewed unseen hunks. Root assigned this lane and approved the exact product/test allowlist and the narrow iPadLayout split-level overlay hook before edits.

## Ownership and smallest connection

| Path | Ownership | Planned edit and reason | Verification |
| --- | --- | --- | --- |
| Source/UI/iOS/Views/iPadLayout.swift | UPSTREAM_OWNED; current upstream blob 9ad82bcfaf091056c7ea12a029a2856a89611653 | One overlay modifier after the existing workspace NavigationSplitView. Its bounds include native toolbar and detail. No reader, title, sidebar, Inspector, or iPhone body is rewritten. | Native toolbar containment; real input/outside/result/Escape; resize; reader continuity |
| Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift | DOWNSTREAM_OWNED | Existing scene/sidebar presentation and measured anchor state; retain genuine native toolbar Button; remove old conditional detail overlay. No query model. | Native AX identity; same-window geometry; closing lifecycle |
| Source/ChavrusaText/ToolbarSearch/LibraryCommandPaletteAdapter.swift | DOWNSTREAM_OWNED | Real LibraryViewModel query adapter plus persistent single-shell view. Both children remain mounted; only opacity, clipping, focus, hit testing, and accessibility change. | Query persistence, keyboard, rapid cycles, real row activation |
| Source/ChavrusaText/ToolbarSearch/ReaderToolbarActionAdapter.swift | DOWNSTREAM_OWNED | Extend existing nonvisual window-coordinate reader to full CGRect and window identity, preserving legacy y callback. | Actual compact/expanded bounds and same scene |
| Source/ChavrusaText/ToolbarSearch/SafariToolbarSourcePort.swift | DOWNSTREAM_OWNED owner source/Gelatin adaptation | Restricted handle motion and native compact press callback; existing defaults preserved. No gesture across field/results; no color/shadow effect. | Field selection, result scrolling, Reduce Motion |
| Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette/Views/CommandPaletteView.swift | VENDORED_UPSTREAM with existing downstream query/UIKit keyboard seams | Opt-in external surface and active lifecycle. Default standalone surface/autofocus stay unchanged. Cannot remove a private original background or refocus a persistent private field from an external wrapper. Original search/result/recents/keyboard implementation stays. | Apple SDK compile; actual focus, Escape and keyboard result selection |
| Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift | DOWNSTREAM_OWNED | Add focused morph regression methods using existing original helpers. Preserve existing assertions. | Native simulator only; physical iPad remains separately open |
| Scripts/CI/library-morph-focused-native.py and inputs; dedicated workflow | DOWNSTREAM_OWNED execution | Bind actual candidate source and selected original/new tests; reuse existing original build/native runner. No historical source gate changes. | Actual source/binary/xcresult/zero-skip/owned simulator receipts |
| docs/hq-integration/library-morph-20261123 | DOWNSTREAM_OWNED evidence | Exact reference lineage, review, execution receipts and honest acceptance matrix. | SHA256 and immutable source binding |

The downstream paths and UI test file are absent from the current upstream tree and historical integration pin. Their existing Git lineage was inspected before editing. iPadLayout is the one upstream hook. An overlay inside the detail child can render at toolbar coordinates while remaining outside the parent's hit-test bounds; a separate root UIKit hosting controller would add unnecessary containment and environment ownership. The split-level overlay keeps the existing environment and native hierarchy.

The native toolbar remains the actual compact Button and accessibility target. The overlay's compact presentation is noninteractive; there is one visible glass surface, measured from the native Button's real frame. The original title retains its placement, and narrow windows can shrink the search slot without moving content outside the native item.

## Validation boundaries and rollback

Linux parsing and source checks do not prove Apple compilation, keyboard dispatch, hit testing or native runtime. Existing accepted suites are reused only at their actual source; this lane records new focused evidence separately. No physical-iPad completion is inferred from simulator runs. Source controls must not fabricate generated commands, native results, or geometry.

Rollback is the scoped commit revert, including the one split overlay hook and opt-in palette arguments. No databases, engines, storage, credentials, library files, dependency pins, release source or shared worktrees are changed.
