# Explicitly approved upstream hooks

No exceptions approved as of 2026-10-22.

## 2026-11-10 — exact native-sidebar TOC composition hook

Owner reply in this chat: **“מאשר את ה־diff המדויק ב־iPadLayout.swift. המשך לביצוע מלא לפי המסמך, כולל הבדיקות והעלאת build production ל־TestFlight לאחר שכל השערים עוברים.”** This approves only the frozen five-line change in [PENDING_OWNER_iPadLayout.diff](../ipad-ui-rebuild/native-sidebar-11001/PENDING_OWNER_iPadLayout.diff), SHA256 `fbc92c2d348514a7876b945e530dcc9c30d7a5135de63a24477dfd4454f5f2dc`, from blob `80154afddb61a6ef19b04044287851c396057e9e` to `e541d660cdeae48d5f378e1ee198147e6c7f8d85`. It enables the original TOC navigation stack and removes two bar-visibility overrides and two sidebar-toggle removals. Alternatives, ownership, scope and rollback are in [pending-approval.json](../ipad-ui-rebuild/native-sidebar-11001/pending-approval.json). No additional reader-toolbar, TOC implementation, upstream, project-membership or workflow edit is authorized. Main-session implementation; physical-device acceptance remains pending. Re-review on next upstream sync or any change to this exact hunk.

## 2026-11-10 — exact 9401 shared-sidebar reader state hook

Owner explicitly replied **“מאשר את ה־diff המדויק”** to the current chat's four-line proposal for `Source/Features/Reader/iOS/iOSReaderView.swift`. The frozen executable hunks are [9401_PENDING_OWNER_HOOK.diff](../ipad-ui-rebuild/9401_PENDING_OWNER_HOOK.diff); exact original/proposed blob IDs, patch SHA256, rejected alternatives, scope and rollback are in [9401_pending_approval.json](../ipad-ui-rebuild/9401_pending_approval.json). Only the shared-sidebar environment property and page-aware `tableOfContentsIsPresented` expression are approved; the complete original toolbar subtree remains unchanged. This records actual owner approval before application, not self-approval. Main-session verification; device acceptance and review date remain pending owner physical-iPad feedback. No other future protected hunk is authorized.

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
