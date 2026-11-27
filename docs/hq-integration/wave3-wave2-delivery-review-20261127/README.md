# Wave 2 delivery review at 2c23de71

## Decision and scope

**Hold the per-book measurement runner pending an ownership correction.** Two concrete subprocess lifetime defects remain in `Scripts/CI/reader-v40-perbook-mode-performance.py` at the reviewed donor. The independent offline, trace-export and pending-fetch sources have no additional demonstrated blocker in this review, but the final composed controller names the per-book helper in its source inventory. Do not treat the entire donor branch as one accepted runtime delivery.

This is an independent **read-only source and retained-evidence review** by Wave 3 `ui_acceptance`. It does not rerun a controller or suite, spawn a test child, send a signal, exercise network denial, compile with Apple tools, launch an app, or execute a native selector. No ownership approval, full-profile freeze, performance acceptance, physical-device result, or release readiness is created here.

The immutable review inputs are:

| Role | Commit |
| --- | --- |
| Wave 2 delivery | `2c23de7138c002cfa4476c40303d4d6973b4b6d5` |
| Last donor point already covered by root intake | `a1c32faca292e0ce1d7cbe2948fefc9a29cc7a72` |
| Root comparison | `bdfb717340464fb41ed07294503abe83bd5a1124` |
| Root prior natural/offline intake receipt | `95a8e41c69da9add6e260d6b5afb20fe316fcfe4` |

The donor application `Source` tree is unchanged throughout the reviewed range: `7d87a5e03b9e4661bbcbc5df9f4bd957a837c7a1`. These are controller/helper/test additions. Root has advanced independently; the comparisons in this packet remain bound to the explicit root reference above.

## Findings requiring action

### 1. A created native/exporter process can be absent from the ownership ledger

Final source: `Scripts/CI/reader-v40-perbook-mode-performance.py`, 55,721 bytes, SHA-256 `72db1997353022621398819a8bc8a50267f9ac5cf4da59376813ce776d7a9d59`.

`BudgetedOriginalRunner.command` creates its child at lines 476–477, computes the deadline at 478, and enters `try` at 479. `bounded` has the same sequence at 507–510. The ledger begins empty at 449 and receives its first row only inside `finish_process`, at 454–458. Consequently, interruption while spawning or between the returned handle and the protected block can leave an actual child without a ledger entry or finalizer.

The outer `stop_owned_runtime` checks only recorded native/exporter groups at 592–598. An empty list satisfies `all(...)`; if the separately tracked observer/trace/URL producers stop, the state can become verified despite the untracked native/exporter child. `retain_only_after_runtime_cleanup` then calls the original Simulator retention helper at 603–606.

This is a source-visible missing ownership boundary, **not a reproduced native process leak**. The existing 74 source controls remain valid for their tested boundaries; they do not establish this unprotected interval.

Required correction belongs to the Wave 2 owner: record an attempted spawn before `Popen`, retain the returned original handle inside a protected lifetime, account for interruption before caller assignment, and keep unknown creation or exit unverified. Simulator retention must not be authorized by an empty completed-only ledger.

### 2. Per-book cleanup can signal an unverified reused process group

The same runner calls `stop_owned_process_group(process)` at line 460 without a guarded signal callback or a retained kernel identity. Its actual original callee is `Scripts/CI/runtime27_interruption.py`, 7,650 bytes, SHA-256 `4f41dfe0175d4da2983cf4c9df1e126e63eb00d3418dcf89149de81b350e488c`.

That original helper selects `killpg_fn or os.killpg` at 101 and sends SIGINT at 138 **before its first liveness probe**. The per-book caller commonly reaches this finalizer after `communicate`, `wait` or `poll` has reaped the leader. A retained `Popen` integer alone does not establish the current process-group owner's identity. The final per-book verified predicate also does not reject recorded `probe_errors`.

The correction should use original PID/parent/start/group identity at every signal boundary, permit an absent leader only an absence probe, and refuse cleanup when a surviving/replaced group cannot be tied to the original owner. Unknown or errored probes must remain unverified. The newer trace/offline/pending wrappers in this delivery contain scoped versions of these stronger boundaries; the per-book runner still lacks them.

**No process was started or signalled during this review.** No shared interruption helper was modified. Root returned both findings to the Wave 2 owner in Asana comment `1220949998485543` on task `1220939536336523`.

### 3. Preserve root's production workspace fix when appending the Faithful cases

The donor `FaithfulReaderUIAcceptanceTests.swift` preserves its own 351,920-byte base prefix. Root's prefix is 351,993 bytes because it already conditionally supplies the testing namespace:

```swift
let workspaceArguments = isolatesStudyWorkspace
    ? ["-studyWorkspaceTestingNamespace", workspaceNamespace] : []
launchWithTier(... extraArgs: backendArguments + workspaceArguments + [
```

The donor still has the older unconditional `-studyWorkspaceTestingNamespace` entry. Replacing the whole file would discard root's prior production correction. Preserve root's existing prefix and append only the new PERF-01 section through a reviewed three-way intake.

This is an **integration hazard**, not a claim that the new donor test intentionally removes the correction. The exact base/root/donor lengths and hashes are retained in `SWIFT_PRESERVATION.json`.

## Preservation verified independently

`CONTROLLER_PRESERVATION.json` was produced by literal-only AST/source comparison, without importing or executing the controller.

- All **11 original phase definitions** retain their exact selectors, order within each phase, allowances, input sets and payload budgets.
- The only added phases are `offline-zayit`, `offline-otzaria` and `reader-pending-sql`.
- Fourteen original helper definitions remain byte-identical. The changed definitions are explicitly recorded.
- The original native verifier's **10-statement suffix** is AST-identical after extraction into `verify_original_case`: actual xcodebuild exit, original zero-skip verifier, actual declared selector and attachment export remain required.
- Ordinary host timeout remains original allowance plus 600 seconds. An offline window can supply only a smaller positive remaining budget; it cannot extend the original allowance.
- The original `reader-full-v32-ui-observation.py`, `faithful-runtime27-native.py` and `reader-full-v40-ui-observation.py` are unchanged across the donor range.
- `Build8401SevenDefectsAcceptanceTests.swift` retains its entire original **102,598-byte prefix** (SHA-256 `ca66d554b22f340366f0a68a7d3e43a4210eb143cbe2550fcdbabbead768b53c`) and appends 40,090 bytes.
- Removing only the two optional measurement input fields and the separate 100-line branch from `FullV40ObservationCatalog.swift` restores the original catalog bytes exactly. Existing target/default/preview behavior is preserved structurally; this comparison is not a compiler or database execution.
- The profile remains explicitly unfinalized with no source-hash map. Nothing here freezes it for the final integrated candidate.

## Reviewed new paths and limits

| Family | Reviewed behavior | Acceptance still required |
| --- | --- | --- |
| Offline exercises and Oracle relay | Pre-spawn ownership, exact original kernel identity, bounded streams, immutable checkout and source joins, three original no-denial watchdog exercises, live coordinator protocol, original restoration/receipt checks | Actual no-denial exercises, actual qualified offline window and both original native search cases on a fresh integrated source |
| Stopped-trace export | Source/trace/clock/PID/schema checks, exact table XPath, pre-spawn ledger and per-signal identity fence, preserved earlier failed trace attempts | Real stopped original trace exports, qualified schema/timebase/thread attribution and metric interpretation; source controls do not prove performance |
| Pending fetch | Three declared cohorts; complete original source catalog and all-anchor identity; real pending-operation/changed-UIKit correlation; exact request file lifetime; observer/writer join before source probing; strict retained evidence replay and native completion | Actual original compiler/catalog, production v40, pending-operation observations, all three cohorts and exact native zero-skip completion |
| Composed controller | Original 11 stages retained; new stages use original native runner/verifier and require strict source/build/corpus/owner joins; cleanup remains distinct from acceptance | Corrected per-book dependency, fresh complete source freeze and original full gate execution |
| Per-book mode matrix | Exact three books × three modes, first/middle/last and reverse cold/warm measurements, source/TOC/unit-mode/epoch identity; scope explicitly excludes unmeasured metrics | Both ownership findings above, real original native runs and qualified trace metrics; 108 opens/54 pairs/216 epochs/9 traces are planned workloads, not executed results |

The pending gate intentionally does not prove the SQL statement or book responsible for every observed operation, MainActor timing, mapping latency, FPS, or physical-memory performance. A cancellation flag is not substituted for an exception classification. The existing requirements remain open where the current instrumentation cannot establish them.

The retained historical trace failure is honestly scoped: its recorded subject was a seven-second host Python program, not Maktabah. The driver failed during readback, its RESULT is absent, and later export attempts stopped for another owner's build and ENOSPC. No saved trace directory is promoted into a successful app or performance result.

## Retained control provenance

`EVIDENCE_BINDINGS.json` separates historical controls from final-source checks. Counts are not added together into a fictitious final suite.

| Retained control family | Exact scope |
| --- | --- |
| Per-book 74/74 | Final helper `72db1997`; synthetic parser/admission/owned-process boundaries and tiny local allocations. Does not cover findings 1–2. |
| Trace 49/49 plus 20/20 ownership | Final `8a548083`; synthetic export/process boundaries. The two original baseline counterexamples remain retained. Actual children/signals/Apple/native/corpus: zero. |
| Offline 26/26 | Final `14cdb114` Oracle and `d0431a3a` exercises; actual Oracle execution of source controls with explicit process/kernel/SSH doubles. Actual SSH, network denial, Mac, native and signals: zero. |
| Pending 75/75 | Historical host `20859d77` and native source `732c90f4`; not relabelled as a final `a8df46b5` rerun. The earlier 61/66 failed attempt is retained. |
| Pending interrupted-start 12/12; file lifetime 10/10 | Their precise intermediate source hashes and declared domain boundaries are retained. |
| Pending retained-artifact 27/27 | Historical `5a2077a1` with final native source `ef11b311`; the earlier 26/27 failed attempt remains preserved. |
| Pending compiler-driver 7/7 | Final `a8df46b5`; source/argv controls only, no compiler execution. |
| Composed controller 22/22 and pending execution 23/23 | Exact final source inputs and raw logs joined independently by `release_preflight`; explicit synthetic process/kernel/device/UI boundaries. Actual Oracle source-check commands and seven Python syntax inputs are separately retained. |

The committed pending archive is **977,176 bytes**, SHA-256 `1637f4b219268eecf2c6078f2c46cfcf556cfff9db70dafc0a647fe89a73e7e2`. Every one of its **1,540 regular members** matches the declared index name, size and digest. Its two candidate source files are byte-identical to donor HEAD. Archive contents were read in memory; no extraction, control execution or symlink following occurred. The five declared synthetic-control symlinks are not archive members and are not claimed as production evidence.

The independent peer evidence join checks all 34 root evidence files, all four before/after source-transfer pairs, all ten control input joins, both raw final control logs, both actual Oracle source-check logs, seven syntax inputs and two materialized HEAD inputs. It reports no hash mismatch and no native/Apple/performance acceptance.

## Minimal selective intake plan

The exact chronological 17-commit range is in `DEPENDENCIES.json`. Already-covered donor commits through `a1c32fac` should not be replayed.

1. Preserve all existing evidence, including failed/partial attempts and the root's production workspace correction.
2. Independently usable helper packets are offline exercises/relay (`ce13b532`, `0cab128c`, `a43aa1d4`, `d8e1e764`, `81b54a5e`, with their intake evidence) and stopped-trace exports (`1f788fee`, `72ae2474`, `141c4135`). Their source review is not permission to claim actual offline or trace acceptance.
3. Hold the unsafe per-book matrix packet (`b0fae4b4` + `fe017f46`) until the owner supplies the narrow corrected final helper and meaningful original-baseline/negative controls. Do not weaken the retention gate or modify the shared original helper without coordination.
4. The pending source packet `b18ef555` + syntax evidence `e942b06a` requires the catalog and the per-book compiler-only API. That API does not execute the unsafe matrix runner, but the final controller inventories the whole helper. Keep source dependencies explicit; do not invent an alternate compiler or silently omit its pin.
5. After the corrected helper is reviewed, apply the coherent pending/offline composition `2c23de71` against root with a narrow three-way test merge. Freeze the resulting current source and all original production inputs through the real workflow before executing any acceptance.
6. Run original final Debug/Release/native/full-production acceptance only under root's designated resource and ownership plan. This packet does not replace those gates.

## Artifacts

- `REVIEW.json`: decision, exact findings and scope.
- `DEPENDENCIES.json`: chronological donor commits and unchanged application-source tree.
- `CONTROLLER_PRESERVATION.json`: original phase and verifier comparisons.
- `SWIFT_PRESERVATION.json`: exact original/source-prefix hashes.
- `EVIDENCE_BINDINGS.json`: archive verification and versioned retained control results.
- `READ_INPUTS.json`: reviewed Git input manifests.
- `SOURCE_FRAGMENTS.json`: line-numbered source for the two process-ownership findings.
