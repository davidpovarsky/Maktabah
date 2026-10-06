# AGENTS.md — Repository Agent Instructions

## Maktabah upstream and Otzaria integration policy

Maktabah is the upstream UI and application foundation. Otzaria is a downstream integration that supplies database, content, search, and related engine capabilities. All implementation work must preserve that boundary.

- Preserve Maktabah's original interface, visual language, navigation, components, interaction patterns, and user experience wherever practical.
- Use Otzaria as a backend engine only. Do not introduce a parallel Otzaria-style application interface when the capability can be surfaced through Maktabah's existing UI.
- Do not replace, remove, or broadly rewrite Maktabah's existing search. Add Otzaria-backed search through isolated services and the smallest necessary integration hooks, while preserving existing search behavior unless the user explicitly requests a particular change.
- Keep all Otzaria code isolated in clearly named downstream modules, directories, adapters, services, or extensions. Do not mix Otzaria business logic into upstream-owned Maktabah files.
- Integrate new Otzaria features into Maktabah's existing screens and components whenever possible, so the result continues to look and behave like Maktabah while using Otzaria's data and engines underneath.
- Prefer additive composition, protocols, adapters, dependency injection, extensions, and narrow hooks over invasive changes to upstream code.
- Modify upstream-owned Maktabah files only when an entry point, import, dependency registration, navigation route, lifecycle connection, or other narrow hook is unavoidable. Keep every such edit minimal, localized, and free of unrelated refactoring or formatting.
- Do not duplicate, rename, move, reformat, or broadly rewrite upstream files merely to add Otzaria behavior.
- For substantial changes, report which files are upstream-owned, which isolated Otzaria files were added, every unavoidable upstream-file edit, and any remaining merge risk.

The intended product is Maktabah's original interface powered by Otzaria's database and engines—not two separate applications joined together. Optimize every change for straightforward future merges from Maktabah upstream.

## GitHub Actions policy

- CI, builds, tests, audits, archives, and IPA generation run only on explicit user request.
- Do not add or expand `push`, `pull_request`, scheduled, or automatic workflow triggers without explicit permission.
- Prefer the repository's existing manual `workflow_dispatch` workflows.

### Event-driven run monitoring

After an explicitly authorized GitHub Actions run has been dispatched, monitor it with one long-lived watcher command that exits only when the run completes. Do not repeatedly wake the model to poll the run status.

Preferred command:

```bash
gh run watch <run-id> --exit-status --compact --interval 30
```

Required behavior:

- Resolve the run ID once after dispatch, then start one watcher process for that exact run.
- When the execution environment provides a native wait, resume, or completion-notification primitive, attach it to the watcher so the model is resumed only when the process exits successfully or unsuccessfully.
- Do not implement status loops with repeated `gh run view`, `gh run list`, REST/GraphQL requests, shell polling, short sleeps, or recurring model turns.
- Do not use repeated status checks merely to provide progress messages. The waiting command is expected to remain quiet from the model's perspective until completion.
- After the watcher exits, query final run/job metadata once. Download logs or artifacts only when needed for the requested result or failure diagnosis.
- If the watcher is interrupted by a tool timeout or connection failure, resume or reattach to the same watcher/session when possible. Start a new watcher only when the original process can no longer be resumed; never fall back to frequent model-driven polling.
- `--exit-status` is mandatory so a failed or cancelled workflow wakes the model with a nonzero result instead of appearing successful.

## Living Project Board

`PROJECT_BOARD.md` is this repository's shared living project board. Before starting substantial work, scan it for relevant context. During normal work, agents should proactively add concise, actionable entries when they discover something with genuine future value, including useful technical discoveries, optimization opportunities, implementation tricks, architectural ideas, possible future improvements, experiments worth running, unresolved issues or questions, and follow-up work that should not be lost—even when the discovery is incidental to the current task.

Do not add trivial observations, temporary debugging chatter, information already documented elsewhere, generic suggestions with no project relevance, or every step performed during a task. The board supports memory but is not a source of truth when repository code, documentation, or current state contradicts it. When an item is implemented, mark it complete and optionally record the date and commit/PR, moving it to `Done` when useful; delete or archive obsolete entries when appropriate.

Updating `PROJECT_BOARD.md` as a side effect of another task is allowed and encouraged when a worthwhile discovery is made. Recording an idea is allowed; implementing unrelated ideas is not.

Preserve all existing repository-specific instructions.
