# Phase 1 local source result — NOT READY for native acceptance

## Outcome and exact source

Reviewed local source corrections are integrated at **`4671b0c91354a19d3f1c981e6ebf9c25209a8d01`**, branch `cez/f51775d6`, manager run `f51775d6-ad62-41ad-82b3-fe225d71cd05`. Later documentation commits change no code.

Final child correction `977a02a1a6c6167188d99f0ef5eba51b6c70b784` is now an ancestor of the manager branch. Its scoped review `401a96eebaa7572e22ce628f22b036038f57f153` approves the source/spec and quality/integration scope, with F1–F8 ADDRESSED and no new blockers. Review merged at `0ff0ac89c45e3ac158025ee0530942ec754861d7` before code integration.

**Original Phase 1 remains incomplete / NOT READY.** Source approval is not native functional QA.

## Actual merged-source verification

Real Python 3.12, bounded commands, on the actual merged branch:

| Check | Result | Limit |
|---|---|---|
| `tools/test_runtime27_interruption.py -v` | 13/13 PASS, 13.857s | Portable/external-command boundaries |
| `tools/test_o2b_native_ux.py -v` | 7/7 PASS, 8.598s | Source/numeric/SDK-helper/portable Swift |
| `tools/test_final_integration_contracts.py -v` | 6/6 PASS, 3.080s | Input closure, negative guards, source contracts/parse |
| `tools/test_verify_xcresult_zero_skips.py -v` | 10/10 PASS, 0.663s | Evidence guard fixtures |
| `Scripts/CI/test-runtime27-release-gate.py` | 17/17 PASS, 0.845s | Guard fixtures, no release |
| Real `hq-stage2-focused-apple.py --preflight-only` | PASS | No SDK/download/app build/runtime |
| Git code-tree identity with `977`, protected baseline integrity, merge whitespace | PASS | Git/input checks only |

Merged preflight receipt: manager Assets `FINAL_PREFLIGHT_MERGED.json`. Source commit/tree: `a316f0167d62a57e505c0f99c2e8694414d6e0de` / `45a956ff63f48b641f07369064dbb960c7e254a8`.

## Ownership and integration footprint

**New upstream-owned file/hunk modifications: none.** `Source/UI/`, `Source/Features/`, `Source/Core/`, `Source/Extensions/`, project/workflows, Vendor and full 27-case manifest remain unchanged from `4065feef…`. The already approved three hook files retain their exact hashes; do not request those approvals again.

Downstream modified:

- `Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift`
- `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift`
- `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift`
- `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift`
- `Scripts/CI/runtime27.py` and `Scripts/CI/run-faithful-ipad-matrix.py`
- `Scripts/CI/hq-stage2-focused-apple.inputs.json` (only two Source-pin values)
- `tools/test_native_sidebar_policy.swift`

Downstream added:

- `Scripts/CI/runtime27_interruption.py`
- `tools/test_runtime27_interruption.py`
- `tools/test_o2b_native_ux.py`
- `tools/test_final_integration_contracts.py`
- Phase evidence/packets/reports under `docs/phase1-cezar/`; existing `PROJECT_BOARD.md` has a concise discovery note.

No new app framework, engine, dependency, alternative UI or canonical authority/parser was introduced. Future upstream merge risk remains at existing integration contracts, not a new upstream patch; Apple runtime behavior still requires real validation.

## Lifecycle, gates and retained evidence

The final reviewer committed the actual scoped approval but Cezar marked its recovery continuation FAILED with a quota error. **FAILED remains FAILED** in receipts; artifact verification does not repair that lifecycle. With no live reviewer process and no remaining review work, only its redundant future auto-resume timer was cancelled through the supported per-task off switch. No worker/session ID, branch, history, account, global setting or unrelated process was replaced.

All eight unique children were used. No ninth, fallback, account rotation, push, paid app CI, source-upload workaround, main/base merge, archive/release, production/email or user-DB migration was performed. SDK-info/API lookups in public `apple-devtools` were not Maktabah builds/tests.

Repaired source native cases: **0 PASS / 0 FAIL / 0 interrupted / 27 NOT_RUN**. Historical `4065feef…` / `43891893650`: 9 PASS / 13 FAIL / 1 interrupted / 4 NOT_RUN, cancelled; never pooled with repaired source. All 27 selectors and qualifications are in the HQ matrix.

Still open: LTR Contents-to-Library paging #21 (unfixed), `invalidLocator` #22/#23 diagnosis, Apple Xcode 27 SDK/app builds, actual iOS 27 AX/URL/PID/scene/receipt/reader6/phone/window/HID cases, live macOS POSIX cleanup, physical/release acceptance. Exact GitHub lookup of merged `4671b0c9…` returned HTTP 422; the owner local-only/no-push and no-manual-paid-CI constraints stand.

HQ result/matrix/ledger/receipts/cancellation reconciliation supersede the old pending-hook approval statement while preserving historical records. All six primary and two parent Asana tasks remain OPEN; completed privacy remains DONE.

## Rulings made and their costs

1. Reused existing process groups/teardown instead of adding duplicate kill logic; later native cleanup evidence is still required.
2. Kept unknown reader/gesture causes diagnostic-only and treated prompt-contaminated rotation cases as unverified; those product issues remain open rather than receiving speculative fixes.
3. Required the reproduced timeout/first-signal and numeric-conversion fixes before local A/B merges; cost was one scoped fix/re-review round for each existing task.
4. Reconciled only proven downstream input-pin fields, preserving drift checks and other inputs; source closure does not establish app build/runtime success.
5. Held final correction unmerged while scoped evidence was absent, then accepted the actual verified committed report despite FAILED process bookkeeping; cost is a separately preserved lifecycle failure, not false native readiness.
6. Retired only the completed review's redundant future recovery timer; no further review runs automatically, and no ninth task may be used.
7. Preserved no-push/native exact-checkout/owner release gates; all native execution and unresolved product behavior remain blockers. No Phase 2 starts.

Rollback is preserved by ancestry: original `4065feef…`, pre-code `1472fdea…`, and each no-ff child merge remain available. No destructive rollback/reset was run; use an explicitly authorized separate worktree if selecting an earlier checkpoint.
