# Explicitly approved upstream hooks

No exceptions approved as of 2026-10-22.

## 2026-11-04 — Faithful iPad UI rebuild

Owner authorization is the current chat request to execute the attached complete package, including `AGENT_EXECUTION_PROMPT.md` §4 stage 3 and `RESTORE_AND_FILE_BY_FILE_PLAN.md`. It expressly authorizes only the listed narrow hooks, target membership and package pins. See `docs/ipad-ui-rebuild/OWNERSHIP_AND_AUTHORIZATION.md` for exact files, alternatives, regression scope and recovery. The final implemented hunks are recorded in `docs/ipad-ui-rebuild/PROTECTED_HUNKS.diff`; this entry does not authorize unrelated edits or future upstream divergence. No signer, trust key or boundary-checker policy is changed. Runtime/device gates remain open until supported by evidence.

Each future exception must have: exact file and hunk, original upstream SHA, rejected adapter alternatives, explicit owner instruction/reference, test evidence, rollback, reviewer, and expiration/review date. Historical edits are not approvals. Never self-approve.


## 2026-11-09 — specifically approved seven-fix hooks

Verifiable authorization: owner reply in this task to the exact three-file proposal, “מאשר את ה־diff המדויק בשלושת הקבצים”. [Frozen executable hunks](../ipad-ui-rebuild/SEVEN_FIXES_APPROVED_HOOKS.diff) and [pre-edit ownership matrix](../ipad-ui-rebuild/SEVEN_FIXES_20261109.md) record alternatives, scope and rollback against original upstream46e893c65139fbb1e582d6595b0d220ea912324a. This is an evidence record of actual scoped approval, not a boundary-checker/policy exception created to bypass a gate. Only iOSReaderWorkspaceView.swift detail-geometry/presentation, SearchResultsListView.swift conditional List/row surfaces, and the enabled library title's inline modifier in iPadLayout.swift are authorized. No other protected hunks were changed. Main-session engineering/QA; no independent subagent review. Physical QA/review date remains open until owner feedback on this experimental candidate; future source changes require fresh scoped approval.
