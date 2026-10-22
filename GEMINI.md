# Antigravity Project Instructions

This repository is configured for the persistent named AI team across Antigravity and Codex:
- **איתן (eitan)**: Architecture
- **נועם (noam)**: Engineering
- **מיה (maya)**: Native UX & RTL
- **רוני (roni)**: Independent QA & Evidence
- **תומר (tomer)**: Integration & PRs
- **יעל (yael)**: Research & Schemas
- **דנה (dana)**: Security & Permissions

## Two-Tier Execution Policy: NORMAL vs TEAM
1. **NORMAL Mode (Default):** Standard single-session execution. The agent identifies the active role, loads its instructions from `.agents/roles/<role>.md` and `docs/ai-team/PROJECT_ASSIGNMENTS.md`, and executes directly without invoking subagents. Documented in Asana as `[<Role> | <Specialty>] [MAIN_SESSION]`.
2. **TEAM Mode (Explicit Request Only):** Subagents are invoked via `invoke_subagent` ONLY when explicitly requested by the user ("עבוד במצב צוות" / "הפעל סוכני משנה"). Documented as `[<Role> | <Specialty>] [SUBAGENT]`.

## Required Context Loading
For all substantive work, review:
- Root `AGENTS.md` and repository-specific guidance
- `docs/ai-team/TEAM.md`
- `docs/ai-team/PROJECT_ASSIGNMENTS.md`
- `docs/ai-team/ASANA_POLICY.md`
- Agent profiles under `.agents/agents/` and roles under `.agents/roles/`

Asana may be read as needed; writes require an explicit user update/sync request, following `docs/ai-team/ASANA_POLICY.md`. All existing release gates, PR merges to main, and destructive actions require explicit owner approval.

## Mandatory upstream boundary and approval gate (2026-10-22)

Read [docs/architecture/UPSTREAM_INTEGRITY_POLICY.md](docs/architecture/UPSTREAM_INTEGRITY_POLICY.md) before editing code, merging upstream, reviewing, or declaring QA complete. Upstream-owned files are read-only for downstream features by default. Even a tiny upstream hook requires explicit owner approval for its exact file/hunk; legacy divergence is NOT approval. Maintain custom functionality in separate adapters/packages and verify runtime regression, not only successful compilation. Read Asana proactively if relevant but NEVER write to Asana without the user explicitly requesting an update/sync.
