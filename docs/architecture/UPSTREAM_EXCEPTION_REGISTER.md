# Explicitly approved upstream hooks

## 2026-11-15 — owner-approved Global Search presentation connections

Authorization: binding HQ `single-manager-wave-20261115/GLOBAL_SEARCH_ASSIGNMENT_1220546245946205.md`, task `1220546245946205`, complete owner-approved native Global Search specification (SHA256 `88d91318f0436aa98221acb688fa5245c466b53d3831149a87a8c393824bb100`). Covers only SearchModeView's global header/content/toolbar composition, dedicated Search split visibility and search functions in iPadLayout, and iPhone Global Search composition/duplicate searchable removal. Upstream pinned `d46af139b3a265399c16d87f5923acd8e3444024`; task base `13e40d1d`. Presentation is additive in `Source/ChavrusaText/Search/UI`; private existing compositions cannot be replaced through an extension. Exact ownership, rejected alternatives, verification gates and rollback: `docs/features/search/GLOBAL_SEARCH_OWNERSHIP_20261115.md`. No Reader/TOC/Library/Palette/lifecycle/project/workflow approval is implied. Manager reviews the final concrete diff; native and physical-device acceptance remain OPEN. Re-review on next upstream sync.

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

## Global Search manager registration and deployment alignment — 2026-11-15

Task1220546245946205 and its owner-approved native iOS26–27 plan authorize the narrow Search registration connections. The sole manager applied S's exact nine-file additive `Maktabah-iOS` Sources registration and changed only that app target's Debug/Release overrides18.6→26.2, matching the specification/existing project setting and fixing the observed host-minimum import mismatch in run43736843778. Exact source, graph evidence, preserved baseline warnings, necessity and rollback: `docs/features/search/manager-integration/INTEGRATION_REVIEW.md` and `SOURCE_REGISTRATION_REVIEW.json`. SDK/runtime/physical acceptance remain pending; no signing/workflow/release/data permission is implied.

## 2026-11-16 — Exact Phase1 sidebar search/title hooks

Before protected edits, the owner answered **“מאשר את שני ה־diffים המדויקים”** to the exact two-file proposal, SHA256 `4fc4058cfa0f233830fb54b386baa388b6a437d999a2ebf421e27bc327d55a42`. Verifiable source: Codex chat `01a1e20f-d054-7523-8b89-7f523fbf54d2`, user message `01a1e438-7aa0-7131-9a78-2ff234a70253`, turn `01a1e438-7999-7a53-b68e-f6db4362425d`. The actual question/answer readback is [PHASE1_OWNER_APPROVAL_EVIDENCE.json](../phase1/proposals/PHASE1_OWNER_APPROVAL_EVIDENCE.json).

Only [PHASE1_PENDING_OWNER_SIDEBAR.diff](../phase1/proposals/PHASE1_PENDING_OWNER_SIDEBAR.diff) is authorized: `Source/UI/iOS/Views/iPadLayout.swift` delegates its paged Library search to the existing downstream sidebar; `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift` connects the downstream search bridge and uses its semantic title only in that sidebar. Standalone TOC keeps its original search/principal title. Original/proposed whole-file hashes, rejected native/container alternatives, risk and rollback are frozen in [PHASE1_PENDING_OWNER_SIDEBAR.json](../phase1/proposals/PHASE1_PENDING_OWNER_SIDEBAR.json). Upstream provenance pin remains `d46af139b3a265399c16d87f5923acd8e3444024`; no upstream sync or additional hunk is authorized.

Real Native run43844345630 exposed retained TOC search after Library return and duplicate title AX nodes. Actual nine-file XCTest and self-contained sidebar adapter SDK compilation passed in run43855733156; the unrelated incomplete standalone Toolbar aggregate failed. Native full27 acceptance remains pending. Main-session review only, no independent reviewer. Re-review these exact hooks on the next upstream sync. Rollback: revert this frozen diff and return shared-search activation to its false default; preserve engines, user databases, frozen493 and producer trees. No main, signing, TestFlight or Phase2 permission.
