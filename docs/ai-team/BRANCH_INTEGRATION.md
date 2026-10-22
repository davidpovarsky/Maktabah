# Maktabah — Branch Integration Manifest

**Source of Truth Base:** `fix/maktabah-search-detail-unification`  
**Setup & Coordination Branch:** `agent/team-orchestration-20261018` (PR #3)

## Active Work Branches (Targeted for Propagation)
- `fix/maktabah-search-detail-unification` (Current active development base)
- `agent/team-orchestration-20261018` (Draft setup PR)
- `codex/sefaria-native-hybrid-backend`
- `feat/torah-photo-study-bridge`
- `codex/shared-torah-inspector-maktabah`

## Default Branch
- `main` — Receives additive team documentation only without merging feature code.

## Audited Exceptions (Skipped Archival / Snapshot Branches)
- `backup/*` (e.g. `backup/main-before-upstream-reset-20260707`, `backup/otzaria-clean-pinned-build-ok-before-main-sync-20260707`)
- `safe-otzaria-before-reorg-20260707`
- `otzaria-reader-ui-units-logs-20260630`
- `diagnostic/*` and `experiment/*` branches

## Future Branch Inheritance
All future branches created from `fix/maktabah-search-detail-unification` or `main` automatically inherit this configuration. Older branches can be checked with `tools/ai-team/ensure-team.ps1 -Check`.

## Mandatory upstream boundary and approval gate (2026-10-22)

Read [docs/architecture/UPSTREAM_INTEGRITY_POLICY.md](docs/architecture/UPSTREAM_INTEGRITY_POLICY.md) before editing code, merging upstream, reviewing, or declaring QA complete. Upstream-owned files are read-only for downstream features by default. Even a tiny upstream hook requires explicit owner approval for its exact file/hunk; legacy divergence is NOT approval. Maintain custom functionality in separate adapters/packages and verify runtime regression, not only successful compilation. Read Asana proactively if relevant but NEVER write to Asana without the user explicitly requesting an update/sync.
