# Whole-branch source review — Phase 1 local repair candidate

## Identity, authority and range

Original source baseline: `4065feef11bd5a8997ea34364516468105778688`.

Combined O2 source checkpoint: `84b533700c6f6401750e3f4f45d89123b55751fb`. The dispatch names the exact subsequent review tip, which adds only this packet/ledger documentation. Full frozen range/diff and verification receipts are in the manager Assets package named in that dispatch.

Authority: original Cezar Phase 1 brief, `O2_EXECUTION_PLAN.md` global constraints/rulings, `O2A_WORK_PACKET.md`, `O2A_FIX_ROUND1.md`, `O2B_WORK_PACKET.md`, `O2B_FIX_ROUND1.md`, repository upstream policy, and latest owner local-only/no-push/no-manual-paid-CI directive.

This is a fresh read-only **whole-branch** review, not another implementation task or native acceptance substitute.

## What was integrated

- O1-A historical CI evidence was checked against recovered source-qualified artifacts; O1-B independently reviewed source and corrected attribution/contamination.
- O2-A `285510ef…` integrated at `9c484269…`: actual system Open-in confirmation handling, focused owned interruption/receipt changes, and DEBUG-only content-free adapter diagnostics. Initial review `5e3d8b74…`; timeout/first-signal fix re-review `fb950740…`.
- O2-B `4763202b…` integrated at `84b53370…`: semantic History heading foreground and bounded DEBUG-only sidebar diagnostics; non-trapping numeric formatting with actual production-path regressions. Initial review `bb69d98e…`; scoped re-review `38913f88…`.
- **Not fixed:** Contents-to-Library body swipe; RTL/state/reader startup causes remain unverified or blocked. No speculative gesture, reader, protected UI, authority/parser, workflow or full-matrix rewrite is authorized.

## Required review lenses

1. Verify all changed code and new tests against the frozen packets and original source, not just the implementation reports or unit-test counts.
2. Look for cross-task integration regressions: runtime source/slice extraction, source pin/provenance enforcement, signal/cleanup ordering and time budgets, result integrity, fail-closed real URL/PID/scene/receipt/replay assertions, and DEBUG/Release behavior.
3. Reassess privacy, content-free diagnostic bounds/numeric safety, framework isolation and real vs modeled test coverage. Exact Apple SDK compilation was not performed; separate source defects from unavailable native evidence.
4. Manually verify ownership/frozen-path integrity, especially `Source/UI/`, `Source/Features/`, original project/workflows, the approved three hooks, native assertion files outside the permitted routing test and the unchanged 27-case manifest. A path checker does not grant owner approval.
5. Triage every deferred item below. Historic “Minor” labels are not binding if current evidence establishes a more serious defect. Give an explicit disposition rather than silently dropping them.
6. Detect any false-readiness claim or attempt to pool old-source CI with new-source portable checks. All current native cases remain unexecuted on this candidate.

## Deferred findings requiring explicit final triage

From `O2A_INDEPENDENT_REVIEW.md`:

- #1 single-shot Open-button hittability check may be transiently flaky.
- #2 teardown ignores a reduction timeout and can overcount cancellations/retry one alert.
- #3 normal cleanup retains helper handles before possible late interruption.
- #4 short post-UDID/pre-inner-try interval may skip that owned simulator's cleanup if interrupted there.
- #6 dead test stub/coverage omissions.

From `O2B_INDEPENDENT_REVIEW.md`:

- #3 conservative DEBUG-guard test parsing, missing restore-marker enumeration and machine-specific SDK fallback.

Previously blocking A #5 and B #1 have targeted fixes and separate scoped reviews; assess their current integration normally. B report wording #2 was corrected.

## Verification already performed

On the actual combined manager branch after B integration, with real Python 3.12:

- `tools/test_runtime27_interruption.py -v`: **9/9 PASS**, 11.429s.
- `tools/test_verify_xcresult_zero_skips.py -v`: **10/10 PASS**, 0.628s.
- `tools/test_o2b_native_ux.py -v`: **5/5 PASS**, 5.980s.
- `tools/hq-sidebar-check.py`: **55 actual compiled portable policy assertions + syntax checks PASS**.
- `git diff --check`: PASS.

The earlier exact B candidate also passed `tools/global-search-presentation-tests.py` (42 + 18 assertions). Windows's installed SDKROOT must be set per command for the legacy standalone policy checker; the environment correction is not a source fix. Do not rerun whole suites redundantly without a concrete reason; focused experiments for findings are appropriate.

## Native/owner gates — do not bypass

- Read `NATIVE_EXECUTION_GATE.md`. The repository workflow needs an exact remotely available SHA; local repaired O2-A commit lookup returned HTTP 422. No push or alternate source publication was authorized.
- SDK-info/API query runs in public `apple-devtools` are not app builds, UI runs or the full runtime27 matrix.
- Actual Apple SDK app/typecheck, iOS 27 History AX, real warm/refusal/replay/PID receipts, body paging, alert-free reader6, phone/window/HID and live macOS process groups are **NOT_RUN / OPEN**.
- Old native run `43891893650` on **4065feef** recorded 9 PASS / 13 FAIL / 1 interrupted / 4 NOT_RUN and was cancelled. Those are not passes for the repaired branch.
- Distinguish local source-integration approval from full original Phase 1 acceptance, which is **NOT READY**.

## Output and frozen reviewer scope

Only tracked writable path: `docs/phase1-cezar/WHOLE_BRANCH_INDEPENDENT_REVIEW.md`. All product/tests/scripts/policies, shared HQ, Asana and `PROJECT_BOARD.md` are read-only.

Return source/spec and quality verdicts, every actionable finding with severity/file/line/reproducer/consequence/minimal correction, explicit deferred-item dispositions, actual checks and remaining native/owner gates. Do not implement fixes or spawn helpers/reviewers.

No installs, new account/provider/model, quota retry, rotation, paid CI/project build/push, production/email/user DB or destructive operation. Stop on quota/429/403. Read-only SDK/API inspection is allowed when a concrete unresolved declaration requires it; do not substitute it for the repository app workflow.
