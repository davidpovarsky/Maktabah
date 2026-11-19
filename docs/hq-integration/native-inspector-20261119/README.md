# Original Reader Inspector navigation — 2026-11-19

## Product change

The existing finite UI Registry now exposes `native.reader.inspector` with the original public-v2 inspector policy. The current scene's existing ActionCore, native orchestrator, workspace epoch and retained original Reader perform the operation. Its only effect is to show the original TorahInspectorKit panel.

The binding captures the actual Reader object, active tab UUID, book/section, content identity, reading mode, selected locator, full line anchor and selected range. Every application boundary revalidates them. A background, replaced, unloaded or stale Reader cannot authorize the panel. The public request contains only destination/backend/presentation; it cannot supply private tab, selection, owner or permission fields. No Core/Registry policy was weakened.

An independent UIKit surface witness is attached to the actual existing panel and tied to its own Reader object. The already displayed panel can acknowledge a separate request without creating a Reader or changing selection. The existing App Intent resolves Study Tools only from an actual visible foreground Reader. Root entity resolution for a mounted background window does not invent Inspector visibility.

This opens the top-level panel only. Selecting a commentary, following a related source, choosing a tool, editing notes and adding settings/draft routes remain separate product acceptance work.

## Verification

- `OWNER_RESULT.json`: exact production binding compiled with Swift 6.3.3/MainActor; 17 passed, zero failures or warnings. Model/backend objects are explicit boundary doubles. Zero Native UI passes.
- `PREFLIGHT.json`: changed Swift files parse; all 75 selected XCTest declarations exist; disjoint execution groups contain 61 iPad and 14 iPhone methods, retaining all original 27 phase-1 cases.
- Five new actual app/system tests cover iPad and iPhone public Inspector navigation, original App Intent delivery, idempotent separate requests, exact receipts, preserved workspace/selection and hidden-Reader refusal. They are NOT_RUN until a new immutable Native75 candidate executes.
- Existing Native70 run 44434004471 remains on b3871b1ff65baa92c56ca3bd960a53be8c18221e / source 2c5af4e9e2f0fd2cd774c6705b7f2e2a7dd82f71. It does not contain this change.

Apple app compilation, actual panel/system navigation, original provider content and physical-device acceptance are still required. Syntax and owner doubles do not establish those results.

## Ownership and preservation

Single authorized continuation developer; no independent reviewer or additional agents. Existing worktrees and original databases are preserved. The change is in the separate continuation feature worktree and will be source-pinned before CI dispatch. No engine, database, permissions, account or subscription change.
