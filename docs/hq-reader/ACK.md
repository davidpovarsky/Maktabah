# OTZ-P-151126 — reader lease ACK

Transport verification: `OTZ-P-151126-DELIVERY` received and recorded 2026-11-15. Local scoped commits with `[skip ci]` authorized; no push/merge.

- Attribution: [נועם | DEV] [MAIN_SESSION]; independent primary Desktop chat `01a1dc89-87bb-7521-b249-ed383392e940`; 2026-11-15.
- Dispatcher: `01a1dc84-2697-7902-b100-9e23913eb7f4`. Explicit activation supersedes the execution plan's PLAN ONLY state.
- Worktree: `C:\Users\DAVID\Code\Maktabah-hq-reader-20261115`; branch `codex/otzaria-reader-20261115`; initial HEAD/base `df2a21941afa46da716387fce9de620865d2a151`.
- Pre-edit: `git status --short` and `git diff --stat` empty. No existing modifications to preserve in this tree. Other worktrees are untouched.
- Pinned upstream `d46af139b3a265399c16d87f5923acd8e3444024` confirmed by `git ls-remote upstream refs/heads/main`; fetched read-only (no merge/ref replacement). Merge base `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`.
- GIDs exclusively assigned: `1219613714504405`, `1219613714507780`, `1219613651433098`; read live with notes/comments. All remain open. Notes/status writes expressly authorized by activation; no automated comments.

## Exclusive source lease

`Source/Otzaria/App/OtzariaAppContainer.swift`; `Source/Otzaria/Reading/OtzariaReadingUnitService.swift`, `OtzariaReadingUnitDescriptor.swift`, `OtzariaReadingUnit.swift`, `OtzariaMaktabahBridge+ReadingUnits.swift`, `OtzariaMaktabahBridge+LineAnchors.swift`; `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift`; `Source/LibraryBackend/LibraryBackendModels.swift`.

New evidence/fixtures/tools only in `docs/hq-reader/**`, `Tests/HQ/reader/**`, `tools/hq-reader-*`. No Inspector, LineSources, Search, original Reader/TextKit/UI, shared HQ registers or other projects. Freeze `withDatabase`/`withReadingUnitService` signatures and connection lifetime semantics. No child agents/chats.

## Pre-edit ownership and validation plan

All leased paths are DOWNSTREAM_OWNED: none exist in pinned upstream's `Source/Otzaria` or `Source/LibraryBackend` tree. Introduction history includes `a6dc4549` (reading units) and `c8cc2745` (generic backend contracts). Planned changes stay in downstream caches, service, adapter, or render-model logic only when reproducible gaps are found. No upstream hook is planned; see local hook register for final audit.

| Area | Alternatives / necessity | Checks | Rollback |
|---|---|---|---|
| Reader cache/service | Reuse existing service/cache; inspect cancellation, generation, exact membership, bounded storage before editing | Cheap portable Swift fixtures against actual source; targeted SQLite fixtures where available | Revert only this lane's commits |
| Backend render model | Preserve existing UTF16 accumulator; change only demonstrated mapping gap | Mixed Unicode/RTL NSRange fixtures; limited synthetic benchmark | Revert scoped hunk |
| App container | Preserve shared lifetime contract; downstream changes only | Deterministic generation/cancellation tests if change needed | Revert scoped hunk |

Read current policies in source checkout: AGENTS, PROJECT_AGENT_GUIDANCE, TEAM, PROJECT_ASSIGNMENTS, ASANA_POLICY, noam role, upstream integrity, exception and legacy registers. Also read execution plan, lane config and hq_otzaria_perf role. Inspect differences to `850b9e47` schema10 without restoring blobs or merging.

No heavy builds/CI, dependency installs, production/user DB, push/merge/TestFlight. Full corpus and physical iPad UI/performance acceptance remain NOT_RUN/BLOCKED_DEVICE; compilation/parse is never runtime evidence.
