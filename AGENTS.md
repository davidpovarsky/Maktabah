# AGENTS.md — Repository Agent Instructions

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
