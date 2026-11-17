# O2 Bounded Repair Implementation Plan

> For Cezar workers: use the existing subagent-driven execution method, with no nested agents. Follow the frozen packet for your task.

**Goal:** Repair reproduced downstream Phase 1 gaps without changing approved upstream UI or claiming unexecuted native acceptance.

**Architecture:** Keep actual OS URL delivery and canonical Core/scene receipts. Reuse the existing runner's owned-process teardown; isolate only a minimal, testable interruption boundary if reproduction warrants it. Keep UX work in the separate B scope.

**Tech stack:** Existing Swift/XCTest, SwiftUI/UIKit, Python standard-library runner/tests; no dependency changes.

**Spec:** Existing Cezar root brief and `C:\Users\DAVID\Code\Codex-Agent-HQ\docs\otzaria\single-agent-three-phases-20261116\05_CEZAR_PHASE1_RESUME_PLAN_20261117.md`, qualified by the latest owner no-push/no-manual-paid-CI directive.

Authority: original Phase 1 brief and owner continuation; O1-A/O1-B evidence, current manager corrections. Product baseline remains `4065feef11bd5a8997ea34364516468105778688`. The Cezar tree orders/reports and rolling handoff remain the native execution ledger; do not create a parallel agent tree.

## Global constraints

- Manager coordinates/reviews/local merges only. Workers use Cezar, `antigravity` / `gemini-4-hydrogen-xhigh`, current profile, retry 0; one in flight, eight total maximum including reviews. Two audits have already consumed two tasks.
- No new provider/account, paid fallback, rotation, nested agents, dependency installs, pushes, manual paid CI, production, emails, release actions or user DB access.
- All `Source/UI/`, `Source/Features/`, project/manifest/lock/workflow files, approved protected hunks and hash-pinned `R27NativeInteractionAcceptanceTests.swift` are read-only. No reinterpretation of old divergence as approval.
- Only evidence-supported downstream changes. Test first where locally executable; real UI acceptance remains NOT_RUN without real native execution. No assertion weakening, fake fixtures, synthetic URL entry or invented native receipts.
- Native counts remain 9 PASS / 13 FAIL / 1 interrupted / 4 NOT_RUN on cancelled run `43891893650`. Rotation failures are contaminated, not proven source regressions. A focused subset can never replace final 27-case acceptance.

## Review focus

1. Unexpected or ambiguous system dialogs must never be accepted as successful URL delivery; preserve original refusal and replay assertions.
2. An interrupt during cleanup must not start the next simulator or erase incomplete-result evidence.
3. Failed cleanup and agents outside the owned process group must remain explicitly unverified.
4. Reader cancellation/generation fences and existing error semantics must survive diagnostic instrumentation.
5. Portable test success must not be promoted to an iOS/SwiftUI/system-URL pass.

## Preflight conflict scan and rulings

| Task / pair | Producer or requirement vs consumer | Finding / ruling |
|---|---|---|
| O2-A self | Confirm real OS URL delivery; preserve original assertions | Agree: repair the system-confirmation boundary, not app navigation semantics. No model/API probe. |
| O2-A self | Existing interruption code vs suggested new process groups | Ruling: reproduce signal/cleanup failure first; reuse existing groups and teardown. Do not add duplicate `killpg` or indiscriminate process termination. |
| O2-A self | Unknown `invalidLocator` vs proposed backend fix | Ruling: absent wrapper logs are not a call-path exclusion. Diagnostic-only source changes unless a separate reproducible defect supports a minimal repair. |
| O2-B self | Known AX failure vs inferred gesture cause | Contrast has a concrete failing AX observation; gesture mutation needs a reproduced cause. Diagnostics alone must not be reported as a fixed swipe. |
| O2-A / O2-B | Real URL delivery and clean foreground vs rotation/paging evidence | Behavioral dependency, no shared writer paths. Serialize A before B; do not repair a contaminated rotation result as a confirmed layout regression. |
| Implementers / reviewers | Same source diff vs independent acceptance | Reviewers are read-only and separate Cezar tasks. Manager verifies claimed commands and frozen paths before any local merge. |
| O2 / O3 | Source corrections vs actual native acceptance | Manual paid CI/push is forbidden by the latest owner instruction. Prepare and verify source candidates locally; leave native gate blocked unless an authorized, non-conflicting execution path becomes available. |
| Native subset / final matrix | Diagnostic convenience vs frozen 27-case contract | No `R27_CASES.json` edits in O2-A/B. Any later focused run must preserve full-matrix provenance and cannot claim READY. |

## Sequence

1. **O2-A implementation:** `O2A_WORK_PACKET.md`; URL confirmation, focused interruption investigation/repair, bounded adapter diagnostics only if justified.
2. **O2-A independent review:** frozen A diff + packet + report; spec and quality verdicts required; no native success inferred from portable tests.
3. **O2-B implementation:** separate future packet; only `GlobalSearchHistoryContent.swift`, `ReaderSidebarPager.swift`, and `ReaderSidebarPageCoordinator.swift`, plus explicitly frozen tests/report paths. No A files.
4. **O2-B independent review**, then one whole-branch review within the eight-task cap. If rework consumes the remaining allowance, record the gate rather than spawning a ninth task.
5. **O3:** actual coherent native matrix remains an explicit gate; do not dispatch forbidden paid CI or push to make it available.

## Progress

- O1-A report retained locally, lifecycle failed/cancelled recovery preserved.
- O1-B completed successfully; all 23 fingerprint rows independently checked. Two report inferences corrected by the manager before O2.
- O2-A initial candidate `6fcae66429845fdddaff6a83a7e12671a22785bc`, base `1472fdea2aa61f4c4c830822758ea75a8c76e08b`: parent portable interruption 7/7 and result-guard 10/10 PASS; held unmerged until the fix/re-review below.
- Independent O2-A review `5e3d8b74d200314acbf4a77b92554b5709918dc2`: source/portable spec PASS, quality PASS with six Minor findings, no Apple/native acceptance.
- **Ruling — O2-A finding #5 is load-bearing for this task:** the manager safely reproduced first-SIGTERM interruption of timeout cleanup on exact `6fcae664`. `O2A_TIMEOUT_SIGNAL_REPRO.py` in manager Assets starts no process or real signal and records only `cleanup_started`, never `cleanup_completed`. Treat this as an Important gap against the owned-cleanup requirement; fix round 1 returns to the original implementer, then scoped re-review. This is code rework, not a provider retry. No A code merge before that gate.
- O2-A deferred Minor findings for the final whole-branch reviewer: #1 immediate Open hittability check; #2 teardown retry/count on timeout; #3 repeated normal-cleanup handles; #4 tiny post-UDID pre-inner-try interval; #6 dead test setup/coverage omissions. Preserve the independent report and reassess these explicitly; do not silently discard or expand this fix into unrelated polish.
- **O2-A fix round 1 complete:** commits `6fcae664..285510ef2627a5d1d570f04ff1c23c803d91593d`, review `fb950740d69da9d1642a34d79311c69199846b6a`: finding #5 ADDRESSED, 0 new findings; spec and quality PASS for portable/source scope. Review retained at merge `1b8ebe627bdeaabe46776e1dc1a438e8e37ad3ae`; implementation locally merged at `9c4842691ecd86087867698fc2eeb9a374d05b7f`.
- Parent re-ran on the actual merged branch: interruption 9/9 PASS (10.437s), existing result-guard 10/10 PASS (0.446s), merge diff whitespace PASS. This clears the local source gate, **not** Apple SDK/UI/live macOS acceptance.
- O2-B: next frozen packet `O2B_WORK_PACKET.md`; implementer is the fifth unique task, followed by review sixth and whole-branch review seventh, reserving the eighth slot.
- Native acceptance and deferred findings: still open.
- Read-only native source-availability check: GitHub returned HTTP 422 for locally merged O2-A `9c484269…`; the existing runtime27 workflow requires checkout of the exact requested SHA. `NATIVE_EXECUTION_GATE.md` records why old-source runs, SDK lookups, a push, or an alternate source-upload route cannot be silently substituted under the current constraints.
