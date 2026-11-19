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

## 2026-11-16 — Exact Phase1 single-stack and Dynamic Type correction

Before these additional protected edits, the owner explicitly answered **“מאשר את ה־diff המדויק”** to [PHASE1_PENDING_OWNER_STACK_AND_DYNAMIC_TYPE.diff](../phase1/proposals/PHASE1_PENDING_OWNER_STACK_AND_DYNAMIC_TYPE.diff), SHA256 `bacd3db43a194e9ae7ecb4ee2ccfc3f7ad462798c61c7b2e1dea85d4456fec2c`. Actual Codex chat `01a1e20f-d054-7523-8b89-7f523fbf54d2`, turn `01a1e4b0-8770-7ce0-bc3b-b544b49514d2`, owner message `01a1e4b0-8a45-70c2-9849-f55a2bc8c92e`; exact question/answer readback: [PHASE1_STACK_OWNER_APPROVAL_EVIDENCE.json](../phase1/proposals/PHASE1_STACK_OWNER_APPROVAL_EVIDENCE.json).

Only the frozen hunks in `Source/UI/iOS/Views/iPadLayout.swift` and `Source/UI/iOS/Views/Common/ListContentView.swift` are authorized. The original Library/TOC bodies share the downstream pager's single native NavigationStack instead of nesting independent stacks; original list labels use native Dynamic Type scaling and multiline layout. First approved4fc hooks and their evidence remain preserved. Original/proposed whole-file hashes, provenance `d46af139b3a265399c16d87f5923acd8e3444024`, rejected alternatives, acceptance scope and rollback are in [PHASE1_PENDING_OWNER_STACK_AND_DYNAMIC_TYPE.json](../phase1/proposals/PHASE1_PENDING_OWNER_STACK_AND_DYNAMIC_TYPE.json).

Actual Native43863125434 exposed zero Sidebar search fields and an unfiltered non-scaling UILabel audit failure. Xcode27.1 SDK43878256318 compiled all9 actual UI test files and the downstream single-stack/search/split adapters; unchanged incomplete standalone Toolbar graph still failed. Native acceptance of the new composition/font hunks remains pending. Sole primary developer review, no independent QA. Re-review exact hunks at the next upstream sync. Rollback only this frozen correction; no original engine/database/project/signing/main/TestFlight/Phase2 change is authorized.


## 2026-11-17 — Continuation Reader preprocessing

The current owner's all-three-phase instruction authorizes completing Reader performance work. This is phase-wide authorization, not an attestation that the owner reviewed an unseen exact diff. Two original Reader call sites delegate to the existing downstream adapter; only pure Foundation text normalization moves outside MainActor. Publication retains cancellation, active request, current book and current text-mode guards. Original reader engines and user data remain unchanged.

Exact patch, hashes, necessity, alternatives, source pin and rollback: [REVIEW.json](../hq-integration/reader-offmain-20261117/REVIEW.json) and [READER_OFFMAIN.diff](../hq-integration/reader-offmain-20261117/READER_OFFMAIN.diff). Actual portable tests passed on 6081 real miniTest10 rows, including exact UTF16/RTL/metadata parity and cancellation. Apple compilation, native UI and physical-device performance acceptance for this new change remain pending. Sole developer review; re-review the hooks on the next upstream sync.


## 2026-11-17 — iPhone global native destinations

The current three-phase owner instruction authorizes native routing integration. One additive original iPhone History modifier supplies the same passive visible-surface witness already used by iPad; the downstream scene host now mounts the real iPhone scene for the existing global History/Settings registry. iPad workspace gates and all authority/receipt/refusal checks remain. Content/workspace-specific destinations remain unsupported. Exact patch, source pin, necessity, limits and rollback: [phone-routing review](../hq-integration/phone-routing-20261117/REVIEW.json). Three supplemental phone tests reuse the complete original system-entry and receipt oracles; native acceptance remains pending.


## 2026-11-18 — Passive original TextKit reader evidence

The current all-three-phase instruction includes native Reader/ActionCore integration. Two original hooks add only a weak-reference callback from the existing iOSIbarotTextView to its existing ReaderViewModel. Downstream native routing reads the original renderer, actual UITextView text, live foreground scene, viewport and exact focused glyph before acknowledging a reader surface. It does not scroll, select, replace the renderer, install a second policy or mutate data. Exact patch, authorization scope, proof limits and rollback: [native reader witness review](../hq-integration/native-reader-witness-20261118/REVIEW.json). Actual app compilation and native acceptance remain pending; no public route/sink activation is implied.

## CONTINUATION_20261118_NATIVE_READER_CORE_FENCE

Current owner authorizes phase-wide native Core/Reader integration. One optional synchronous original Reader destination callback fences passage ownership through the full Core result. Exact diff, scope limits, pending Native acceptance and rollback: docs/hq-integration/native-reader-core-20261118/REVIEW.json. No independent review or unseen exact-hunk approval is claimed.

## 2026-11-18 — original SQLite error propagation

The concrete frozen two-hunk proposal was presented before the owner's continuation reply, after which exact application was accepted. The owner then explicitly authorized all required fixes/builds/uploads without further confirmation. Actual quotations, the historical rejection, unchanged patch digest and test evidence are retained in [APPLIED_REVIEW.json](../hq-integration/sqlite-error-propagation-20261118/APPLIED_REVIEW.json). Require SQLITE_DONE after fetch and SQLITE_OK from the existing bind calls, using original error types. A downstream adapter cannot recover errors already discarded by these private methods. Identical real-SQLite tests improved from9/21 to21/21 pass; source data is read-only, failure writes use owned fixtures. Apple/Native/full-data/device validation remains pending. Revert only these two hunks for rollback; re-review on the next upstream change. Sole developer review.


## 2026-11-19 — Original Reader selection colors and tab identity

The current owner explicitly authorizes all necessary three-phase fixes and existing CI. This is phase-wide permission, not a claim that the owner reviewed an unseen exact diff. The original TextKit selection hook now fills only ranges without existing backgrounds, retaining real search highlights and annotation identity. Existing original tab select/close buttons gain stable UUID accessibility identifiers; actions and layout remain original. Exact hunks, hashes, original provenance, necessity, alternatives, authorization, proof boundaries and rollback: [REVIEW.json](../hq-integration/native65-fixes-20261119/REVIEW.json) and [ORIGINAL_READER.diff](../hq-integration/native65-fixes-20261119/ORIGINAL_READER.diff). Six attributed-string behavior cases improve from1PASS5FAIL to6PASS0FAIL; Apple and actual Native acceptance remain pending. Sole developer review. Re-review at the next upstream sync; do not change approval/signing policy or original data.

## 2026-11-20: semantic search original UI ownership

See `docs/hq-integration/search-openresults-20261120/REVIEW.md` and the exact compressed original Search UI diff. Current owner authorization covers this narrow passive hook; Apple/native acceptance is still pending.
