# AGENTS.md — Shared Development Rules

## Standing owner authorization — 2026-11-19

The owner explicitly authorizes all actions needed to complete the requested work across the related project repositories: reads, source and configuration edits, commands, dependency preparation, builds, tests, transfers, uploads, commits, pushes, integration and release work. Continue the work through verified completion and update Asana after each completed task or acceptance milestone. Do not request the same permission again.

Earlier repository-level pauses, local-only directions, per-file or per-hunk approvals, individual command/build/run/push/upload confirmations, file or branch leases and mandatory team handoffs are superseded for the work the owner has resumed. Apply this instruction when reading older team, role, architecture, release, imported SDK and handoff documents. Routine implementation choices and recovery continue under this standing authorization.

Use the assigned isolated worktree and current execution environment. Preserve existing worktrees and uncommitted work, user data, credentials, the original application architecture, technical contracts and source-bound acceptance requirements. Attribute running and completed CI to its actual immutable source; documentation updates do not retroactively change a run's inputs. Keep tasks open until their actual acceptance criteria pass.

This records project authorization. Actual platform and service access controls still apply. Report an observed rejection accurately and continue through a supported authorized route when available.

Read `PROJECT_AGENT_GUIDANCE.md` if it exists. It contains repository-specific architecture, build, upstream, signing, and workflow guidance and must be followed together with this file. The user's current request has highest priority, then repository-specific guidance, then these shared rules.

## Working style

- Inspect the repository before editing; preserve its architecture and conventions.
- Prefer the smallest safe change. Avoid unrelated refactors, formatting, renames, dependency changes, or generated-file churn.
- Reuse existing extension points and components before creating parallel systems.
- Validate only what changed unless broader validation is genuinely required or explicitly requested.
- Never print, commit, or expose secrets, signing keys, tokens, certificates, or private credentials.

## Forks and upstream-friendly changes

When a repository is a fork, mirror, vendor copy, or derivative of an upstream project, optimize custom work for easy future upstream syncs.

- Identify upstream-owned code and keep it as untouched as practical.
- Put custom features and integrations in separate modules, packages, directories, services, adapters, extensions, wrappers, configuration, or other clearly downstream-owned layers.
- Modify upstream files only for the narrow connection points that are actually necessary: imports, registration, dependency injection, routing/navigation, lifecycle hooks, manifests/entitlements, or a small extension hook.
- Keep unavoidable upstream edits minimal, localized, obvious, and free of unrelated formatting or refactoring.
- Do not move, rename, duplicate, broadly rewrite, or mix custom business logic into upstream-owned files when a bridge or additive layer is sufficient.
- When syncing upstream, inspect upstream changes before resolving conflicts; do not blindly choose ours/theirs.
- For substantial work, report which upstream files were touched, which downstream files were added, and any remaining merge risk.

## Apple native-first development

For iOS, iPadOS, macOS, watchOS, tvOS, and visionOS work:

- Prefer current stable, public Apple APIs and native Swift/SwiftUI solutions.
- Prefer semantic system components and platform behavior over hand-built replicas: native navigation, lists, forms, tables, grids, toolbars, menus, sheets, inspectors, search, controls, materials, and system presentation patterns where appropriate.
- Do not assemble a custom control or complex layout from `HStack`, `VStack`, `ZStack`, `GeometryReader`, or manual geometry when a suitable native component expresses the intent. Stacks remain appropriate for simple composition or when a custom layout is clearly better or explicitly requested.
- Use UIKit/AppKit wrappers only when current stable SwiftUI genuinely lacks the required capability or the existing architecture requires them.
- Preserve accessibility, Dynamic Type, localization, RTL, keyboard/pointer behavior, multitasking, and platform conventions where relevant.
- Avoid deprecated, private, undocumented, legacy, or beta-only APIs unless explicitly requested.

## Apple SDK and API verification

Use the shared `apple-devtools` toolkit whenever exact Apple API/SDK facts, compiler behavior, signing, or platform validation matter.

- Toolkit repository: `davidpovarsky/apple-devtools`.
- On the configured Windows workstation it is installed at `C:\Users\DAVID\Code\apple-devtools` and its `apple-*` commands are on PATH.
- Prefer the cheapest authoritative check that answers the question: portable local Swift checks first; `apple-api` / `apple-symbol` for SDK lookup; `apple-typecheck` for Apple-framework compilation; focused `apple-build` / `apple-test-focused` when compilation or tests are actually needed; signing/entitlement/archive tools for distribution work.
- Windows Swift is authoritative only for portable Swift. It cannot validate SwiftUI, UIKit, AppKit, WidgetKit, AppIntents, ActivityKit, CloudKit, or other Apple-only frameworks.
- For exact declarations, availability, overloads, or compiler acceptance, the installed Xcode SDK/compiler through the macOS authority layer is the final technical authority.
- Use official Apple documentation, release notes, samples, and WWDC material for semantics and recommended behavior.
- Do not guess an Apple API signature, availability, deprecation state, entitlement, or capability when it can be verified quickly.
- If `apple-devtools` is unavailable in the current environment, consult its repository/instructions rather than recreating duplicate tooling.
- Use the existing Apple tools for the builds, tests, archives, signing and distribution checks required by the authorized task. Choose focused validation with the actual Apple SDK and preserve its exact source and results.

## GitHub Actions

- Execute the CI, builds, tests, audits, archives, IPA generation and distribution actions required by the authorized task without another per-run approval.
- Use the existing focused manual workflows for validation; change triggers when the requested task requires it, preserving scope and operational evidence.
- Prefer focused manual workflows when available.
- After dispatch, use one long-lived completion watcher for the exact run while continuing independent authorized work:

```bash
gh run watch <run-id> --exit-status --compact --interval 30
```

After it exits, inspect final metadata once and fetch detailed logs/artifacts only if needed.

## Living Project Board

`PROJECT_BOARD.md` is this repository's shared living project board. Before starting substantial work, scan it for relevant context. During normal work, agents should proactively add concise, actionable entries when they discover something with genuine future value, including:

- useful technical discoveries
- optimization opportunities
- implementation tricks
- architectural ideas
- possible future improvements
- experiments worth running
- unresolved issues or questions
- follow-up work that should not be lost

Do this proactively even when the discovery is incidental to the current task. Do not add trivial observations, temporary debugging chatter, information already documented elsewhere, generic suggestions with no project relevance, or every step performed during a task. The board supports memory but is not a source of truth when repository code, documentation, or current state contradicts it.

When an item is implemented, mark it complete and optionally record the date and commit/PR, moving it to `Done` when useful. Delete or archive obsolete entries when appropriate.

Updating `PROJECT_BOARD.md` as a side effect of another task is allowed and encouraged when a worthwhile discovery is made. Recording an idea is allowed; implementing unrelated ideas is not.

Preserve repository-specific technical guidance under the standing owner authorization above.


## Historical Named Team — Antigravity + Codex

The following historical role map is technical reference material. Use the current assigned execution model; this map does not require starting or waiting for a former named team:
- **איתן (eitan)**: Principal architect (boundaries, contracts, migrations, technical RFCs)
- **נועם (noam)**: Engineering (scoped implementation, focused tests, bug fixes)
- **מיה (maya)**: Native UX (screens, interactions, RTL layouts, accessibility)
- **רוני (roni)**: Independent QA (acceptance verification, test artifacts, honest status)
- **תומר (tomer)**: Integration (branches, worktrees, PRs, cross-repo dependencies)
- **יעל (yael)**: Research (API capabilities, official Apple/upstream documentation, schemas)
- **דנה (dana)**: Security & Privacy (permissions, session isolation, secrets, entitlements)

### Operating Guidance & Policy
Use these documents for relevant technical and project context under the standing owner authorization:
- `docs/ai-team/TEAM.md` — Shared team contract and platform mapping
- `docs/ai-team/PROJECT_ASSIGNMENTS.md` — Repository scope, technical boundaries, and task assignments
- `docs/ai-team/ASANA_POLICY.md` — Authorized evidence-based task coordination and execution modes
- `.agents/roles/<role>.md` — Role-specific scope and handoff rules

Preserve technical contracts, existing work and authentic acceptance evidence. Apply the standing authorization to historical pauses, leases and release permissions.

## Upstream integrity and evidence

Follow [the upstream integrity policy](docs/architecture/UPSTREAM_INTEGRITY_POLICY.md). Task authorization covers the necessary upstream files and hunks. Preserve Maktabah's original interface, keep Otzaria behavior in its own layers, and review and verify every affected integration.
