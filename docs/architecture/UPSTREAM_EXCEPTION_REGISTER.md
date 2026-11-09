# Explicitly approved upstream hooks

No exceptions approved as of 2026-10-22.

## 2026-11-04 — Faithful iPad UI rebuild

Owner authorization is the current chat request to execute the attached complete package, including `AGENT_EXECUTION_PROMPT.md` §4 stage 3 and `RESTORE_AND_FILE_BY_FILE_PLAN.md`. It expressly authorizes only the listed narrow hooks, target membership and package pins. See `docs/ipad-ui-rebuild/OWNERSHIP_AND_AUTHORIZATION.md` for exact files, alternatives, regression scope and recovery. The final implemented hunks are recorded in `docs/ipad-ui-rebuild/PROTECTED_HUNKS.diff`; this entry does not authorize unrelated edits or future upstream divergence. No signer, trust key or boundary-checker policy is changed. Runtime/device gates remain open until supported by evidence.

Each future exception must have: exact file and hunk, original upstream SHA, rejected adapter alternatives, explicit owner instruction/reference, test evidence, rollback, reviewer, and expiration/review date. Historical edits are not approvals. Never self-approve.

## 2026-11-09 — Exact strict-10601 repair proposals

Owner approved two reviewable diffs in the current chat, quoting respectively
“מאשר את השינויים המדויקים בשני הקבצים ואת בדיקתם” and
“מאשר את השורה המדויקת ואת בדיקתה”. Scope, rejected downstream alternatives,
upstream SHA, rollback and verification limits are recorded in
`docs/ipad-ui-rebuild/OWNERSHIP_AND_AUTHORIZATION.md` and
`docs/ipad-ui-rebuild/STRICT_10601_REPAIR.md`.
Exact approved scope is preserved in `PROPOSAL_ONLY_strict_10601_protected.diff`
and `PROPOSAL_ONLY_strict_10601_sidebar_title.diff` alongside those documents;
implemented deltas are appended to `PROTECTED_HUNKS.diff`. These cover only
workspace docking/state, Search List backing/rows, and the enabled Library's
inline title. Main-session review; no independent agent/device acceptance.
Re-review on the next upstream sync; no future or unrelated source permission.
