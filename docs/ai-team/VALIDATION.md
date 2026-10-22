# AI Team Validation & Smoke-Test Procedures

This document outlines the automated and manual verification procedures for the named AI team configuration.

## 1. Static Validation
1. **YAML Frontmatter:**
   - Every file in `.agents/agents/*.md`, `.agents/rules/*.md`, and `.agents/skills/*/SKILL.md` must have valid YAML frontmatter.
   - Rules must have `trigger: always_on`, `model_decision`, `glob`, or `manual`.
   - Rules must not exceed 24 KB.
2. **TOML Syntax:**
   - Every file in `.codex/agents/*.toml` must parse cleanly with `tomllib`.
3. **Link & Path Verification:**
   - All relative file links in `AGENTS.md`, `GEMINI.md`, and `docs/ai-team/*.md` must resolve to existing files.
4. **Policy Integrity:**
   - `ASANA_POLICY.md` must contain the authorized verified completion rule and the two-tier execution policy (NORMAL vs TEAM).
   - Asana writes require explicit user request; any older autonomous-write permission is superseded.

## 2. Runtime Smoke Tests
1. **NORMAL Mode Test (Default):**
   - Verify that the main session automatically identifies the role, loads its instructions from `.agents/roles/<role>.md`, executes directly in the main session without calling `invoke_subagent`, and logs as `[MAIN_SESSION]`.
2. **TEAM Mode Test (Explicit Request Only):**
   - Verify that upon explicit user request, the coordinator delegates via `invoke_subagent`, receives results, and logs as `[SUBAGENT]`.
3. **Asana Integration:**
   - Verify connection via Asana MCP or REST API (`asana_list_workspaces`).
   - Perform read-only checks by default. Write -> read-back tests ONLY when explicitly authorized by the user.
   - Verify task completion gating (tasks without physical device proof remain open).

## 3. Branch Diagnostic Tool
Run `tools/ai-team/ensure-team.ps1 -Check` to verify configuration integrity on any branch.

## Mandatory upstream boundary and approval gate (2026-10-22)

Read [docs/architecture/UPSTREAM_INTEGRITY_POLICY.md](docs/architecture/UPSTREAM_INTEGRITY_POLICY.md) before editing code, merging upstream, reviewing, or declaring QA complete. Upstream-owned files are read-only for downstream features by default. Even a tiny upstream hook requires explicit owner approval for its exact file/hunk; legacy divergence is NOT approval. Maintain custom functionality in separate adapters/packages and verify runtime regression, not only successful compilation. Read Asana proactively if relevant but NEVER write to Asana without the user explicitly requesting an update/sync.
