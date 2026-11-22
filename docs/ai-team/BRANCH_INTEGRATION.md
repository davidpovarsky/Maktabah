# Maktabah — Branch Integration Manifest

**Historical Source Base (18 October 2026):** `fix/maktabah-search-detail-unification`

**Historical Setup & Coordination Branch:** `agent/team-orchestration-20261018` (PR #3)

## Historical Propagation Targets (18 October 2026)
- `fix/maktabah-search-detail-unification` (Development base at that snapshot)
- `agent/team-orchestration-20261018` (Draft setup PR)
- `codex/sefaria-native-hybrid-backend`
- `feat/torah-photo-study-bridge`
- `codex/shared-torah-inspector-maktabah`

## Verified Branch State (snapshot: 22 November 2026, 01:57 UTC)
- GitHub's current default branch is `dev` at `9859c754545aed8c34b311b63490778a51db5d7e`. At this snapshot it contains `AGENTS.md`, but not the 32 added named-team paths from PR #3.
- The active integration branches `codex/otzaria-completion-20261121` at `34d06949e7fedbda6e0d256a769b3d0b8659c211` and `codex/otzaria-completion-20261122` at `9c66b4ccc06340a04de53a4c3370182873ed18bc` contain all 33 PR paths with identical configuration blobs between those branches.
- The team package entered their history through `33d65c2b32531f67e4f341eccc285eb0d1d86142`. PR #3 remains a separate open draft at `bdeb71d0f5a3840750b7cf2bff2c1dc600034ac9`; it is not an ancestor of those active branches.
- The older `main` propagation plan is historical. Verify the current assigned worktree, branch and immutable source before integration; this inventory does not select a product merge destination.

## Audited Exceptions (Skipped Archival / Snapshot Branches)
- `backup/*` (e.g. `backup/main-before-upstream-reset-20260707`, `backup/otzaria-clean-pinned-build-ok-before-main-sync-20260707`)
- `safe-otzaria-before-reorg-20260707`
- `otzaria-reader-ui-units-logs-20260630`
- `diagnostic/*` and `experiment/*` branches

## Future Branch Inheritance
New branches inherit only the files present at their actual base commit. Use `tools/ai-team/ensure-team.ps1 -Check` to check the original required-file inventory, then validate YAML/TOML and document links as described in [VALIDATION.md](VALIDATION.md). Presence alone is not complete configuration or product acceptance.

## Mandatory upstream boundary and approval gate (2026-10-22)

Read [docs/architecture/UPSTREAM_INTEGRITY_POLICY.md](../architecture/UPSTREAM_INTEGRITY_POLICY.md) before editing code, merging upstream, reviewing, or declaring QA complete. Upstream-owned files are read-only for downstream features by default. Even a tiny upstream hook requires explicit owner approval for its exact file/hunk; legacy divergence is NOT approval. Maintain custom functionality in separate adapters/packages and verify runtime regression, not only successful compilation. Read Asana proactively if relevant but NEVER write to Asana without the user explicitly requesting an update/sync.
