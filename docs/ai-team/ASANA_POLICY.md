# Asana Team Coordination & Verified Completion Policy

**Owner Authorization Date:** 2026-10-18  
**Scope:** Approved project management hub across five repositories:
- `davidpovarsky/Maktabah` (Asana Project: `1219602719070493` — אוצריא)
- `davidpovarsky/TorahInspectorKit` (Shared across Maktabah and Pinkha)
- `davidpovarsky/hanlin-ai` (Asana Project: `1219603102275846`)
- `davidpovarsky/cherri` (Asana Project: `1219603572114432`)
- `davidpovarsky/anytype-swift` (Asana Project: `1219604672449660`)
- `davidpovarsky/onebusaway-ios` (Asana Project: `1219605677718919`)

---

## 1. Core Operating Principle: READ-ONLY unless explicitly authorized

Asana may be consulted proactively to understand current project state, tasks, blockers and evidence. **No Asana mutation whatsoever without an explicit user request to update or synchronize Asana.** This includes creating/editing tasks, comments, labels, assignments, due dates, sections, dependencies, status and completed=true. Earlier blanket authorization for autonomous writes is revoked by the owner's current instructions. An implementation request alone does not imply Asana-write permission.

When the user expressly requests Asana synchronization: verify live source-of-truth state, avoid duplicate tasks, preserve descriptions, cite exact branch/SHA/test evidence, and mark complete only if the task's acceptance criteria were actually verified. If evidence is incomplete, leave it open. Existing explicit release/merge/signing gates remain in force.

---

## 2. Logical Roles, Comment Attribution & Execution Modes

The 7 permanent roles are logical identities operating under the single authenticated user account:
- `[איתן | ARCH]` — Principal architect
- `[נועם | DEV]` — Engineering & implementation
- `[מיה | UX]` — Native UX, interactions, RTL
- `[רוני | QA]` — Independent verification & evidence
- `[תומר | INT]` — Integration, PRs, worktrees
- `[יעל | RES]` — Research, APIs, schemas
- `[דנה | SEC]` — Security, privacy, permissions

### אופן הביצוע (Execution Mode):
כל עדכון ב-Asana חייב להבחין בבירור בין **הזהות המקצועית** לבין **אופן הביצוע**:
1. **`[MAIN_SESSION]` (מצב NORMAL — ברירת מחדל):**
   - המשימה מבוצעת ישירות בסשן הראשי ע"י הסוכן הראשי, תוך טעינת הוראות התפקיד מ-`.agents/roles/<role>.md` ו-`docs/ai-team/PROJECT_ASSIGNMENTS.md`.
   - מתועד כפורמט: `[<Role> | <Specialty>] [MAIN_SESSION]` (לדוגמה: `[נועם | DEV] [MAIN_SESSION]`).
   - אין להפעיל סוכני משנה (`invoke_subagent`).
2. **`[SUBAGENT]` (מצב TEAM — רק לפי בקשה מפורשת):**
   - המשימה מואצלת לסוכן משנה אמיתי דרך `invoke_subagent` בעקבות בקשה מפורשת של המשתמש.
   - מתועד כפורמט: `[<Role> | <Specialty>] [SUBAGENT]` בצירוף מזהה השיחה (Conversation ID).
3. **איסור ייחוס מטעה:** אין לטעון שסוכן משנה הופעל אם העבודה בוצעה בסשן הראשי.

---

## 3. Task Lifecycle States

Tasks transition through explicit text-based states:
- `BACKLOG`: Scoped and awaiting start.
- `READY`: Blockers cleared, ready for active implementation.
- `IN_PROGRESS`: Actively worked on by the assigned role.
- `READY_FOR_QA`: Implementation committed, ready for verification by Roni.
- `VERIFIED`: Verification passed with documented evidence.
- `BLOCKED`: Blocked by external dependencies, missing hardware, or missing credentials.
- `AWAITING_OWNER_APPROVAL`: Awaiting explicit owner release/merge decision.
- `DONE`: Completed after meeting all verification criteria.

---

## 4. Acceptance Criteria & Completion Standard

To mark a task `completed=true`:
1. **Full Scope Verified**: Every item in the task's acceptance criteria must pass. Partial implementation is not completion.
2. **QA Verification Gate**:
   - במצב **NORMAL**, בדיקות מתבצעות ישירות ומתועדות כ-`[רוני | QA] [MAIN_SESSION]`. אם תנאי הקבלה מחייבים אימות עצמאי שלא בוצע ע"י סוכן נפרד, יש להשאיר את השער פתוח (`READY_FOR_QA`) ולדווח מה חסר; אין להפעיל סוכן משנה ללא בקשת המשתמש.
   - במצב **TEAM**, הבדיקה מבוצעת ומאומתת ע"י סוכן משנה ייעודי (`[רוני | QA] [SUBAGENT]`).
3. **Technical Proof**: Record the exact repository, branch, and commit SHA.
4. **Execution Evidence**: Record named test suites, assertion results, and CI run URLs or local logs.
5. **Physical Hardware Gate**: Tasks explicitly addressing physical iPad/iPhone behavior must remain open (`BLOCKED_DEVICE`) until verified on physical hardware. A green simulator build or unsigned IPA is never a substitute for hardware acceptance.
6. **Research Tasks**: A research-only task completes when its documented findings, schema, or RFC is verified and reviewed, without implying the overall software feature is done.

---

## 5. Cross-Role Handoff Envelope

When handing off work, post a concise coordination comment:
```
[<ActingRole> | <Action> -> <NextRole> | <NextAction>] <STATUS>
Execution Mode: MAIN_SESSION | SUBAGENT
Branch: <branch-name> | Commit: <commit-sha> | PR: <url>
Subagent Invocation: <Conversation ID or NONE (MAIN_SESSION)>
Tests: <test results summary>
Known Risks: <risks or remaining gaps>
Next Action: <what next reviewer should verify>
```

---

## 6. Operational Guardrails

- **No Continuous Polling**: Never run a background polling loop or webhook daemon. Read and update Asana on demand at task start, significant phase handoff, and completion only.
- **Rate Limit Handling**: Respect HTTP 429 with bounded exponential backoff.
- **Idempotency & Secret Protection**: Perform targeted field updates. Never overwrite entire task descriptions unnecessarily. Never log tokens, commit PATs, or store credentials in repository files.
- **Scope Discipline**: Do not invent new unrelated feature tasks or broaden project scope without explicit user authorization.
