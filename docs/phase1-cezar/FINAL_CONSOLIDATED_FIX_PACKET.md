# Final consolidated fix wave — eighth and last unique child

## Scope, authority and non-goals

Implement the complete findings list from `WHOLE_BRANCH_INDEPENDENT_REVIEW.md` at `207093515dd850f4cfd036273311dc2444921c8f`, not a new feature project. This is the **one** final fix wave; parent obtains one scoped re-review from the existing whole-branch reviewer afterward.

All prior global constraints apply: current Antigravity Hydrogen XHigh/profile, retry 0, one in flight, no nested agents or reviewer, no installs, account/model/provider changes, fallback/rotation, project CI/build, push/publication workaround, production/email/user DB or destructive operations. Stop on quota/429/403. Do not request new owner permission or invent a protected hook; report a real protected blocker.

All `Source/` (including downstream adapters/pager), `Vendor/`, project/workflow/package/lock files, approved three hooks, `R27_CASES.json`, and hash-pinned `R27NativeInteractionAcceptanceTests.swift` are read-only. Body paging and `invalidLocator` remain unresolved; do not claim they were fixed by this wave.

## Exact writable paths

| Path | Ownership / permitted change |
|---|---|
| `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift` | Downstream; confirmation settling/teardown helpers only. Keep original test selectors, PID/receipt/refusal/replay/security assertions. |
| `Scripts/CI/run-faithful-ipad-matrix.py` | Downstream; reviewed cleanup/receipt findings only. |
| `Scripts/CI/runtime27.py` | Downstream; only a minimal change required by the reviewed integration/propagation findings, otherwise untouched. |
| `Scripts/CI/runtime27_interruption.py` | Downstream; small reusable cleanup/atomic receipt helper if needed, no parallel lifecycle system. |
| `Scripts/CI/hq-stage2-focused-apple.inputs.json` | Downstream CI input, created `7f0ca571…`, absent at both upstream pins. **Only** `application_source_sha` and `application_trees.Source`. No other key/value changes. |
| `tools/test_runtime27_interruption.py` | Strengthen actual control-flow regressions; remove reviewed dead setup without weakening assertions. |
| `tools/test_o2b_native_ux.py` | Reviewed guard/restore/SDK helper correction and targeted regressions. |
| `tools/test_final_integration_contracts.py` | Optional new narrow test for pin consistency, drift rejection and routing-helper source contracts; label source-only limits. |
| `docs/phase1-cezar/FINAL_CONSOLIDATED_FIX_REPORT.md` | One complete per-finding report, RED/GREEN receipts, exact base/head, scope and unresolved gates. |

Other files, policies, `PROJECT_BOARD.md`, shared HQ and Asana are read-only. The parent owns ledger/final reporting.

## Findings and required observable outcomes

### F1 — Important: real current Source pin, unchanged drift enforcement

The actual manager `hq-stage2-focused-apple.py --preflight-only` run failed with `Application tree drift: Source`.

- Existing config pins `Source=431748950e3285e600aa9d98d0c252856b429262`, source commit `d9ab40fb…`.
- Current combined Source tree is `45a956ff63f48b641f07369064dbb960c7e254a8`; manager verified it also equals `a316f0167d62a57e505c0f99c2e8694414d6e0de:Source`.
- Because all Source is read-only here, reconcile only the two permitted config fields to an actual existing source commit with the exact final tree. Do not stamp an arbitrary/self-referential SHA.
- Preserve Vendor/project/engine/resource/artifact/overlay/rebuild inputs byte-for-value. Do not edit validator logic, disable checks or change the 27-case manifest.
- Run real `python3.12 Scripts/CI/hq-stage2-focused-apple.py --preflight-only` to PASS. Add a negative test proving wrong Source/checkout pins still fail closed; this is source/input validation, not app build or native acceptance.

### F2 — Important: bounded, fail-closed expected Open-button settling

`confirmSpringBoardOpenDialog` currently snapshots `Open.isHittable` immediately when an alert appears.

- Add a short bounded settling wait (review suggests 2 seconds) for the exact single expected Chavrusa Open-in alert and unique existing/hittable Open action.
- Revalidate expected title/uniqueness before tapping; unexpected, ambiguous or stuck dialogs must still fail closed with evidence.
- Keep real system delivery, credential-free exact sidecar ack, nonce/UDID, same PID, actual UI and canonical receipt/replay/refusal assertions unchanged. Do not approve unrelated prompts or replace transport with an internal call.
- Use existing Swift 6 actor-safe query patterns. Do not claim a native UI pass from syntax/source-contract checks.

### F3 — Minor: truthful, bounded teardown cancellation progress

Do not ignore a reduction wait timeout and increment a fictional cancellation count.

- Stop/reassess on no confirmed progress rather than repeatedly counting one stuck alert.
- Preserve unconditional test failure whenever leftover system prompts were present.
- Account conservatively for identical prompts appearing sequentially: count can remain one. Do not claim successful dismissal from a tap attempt alone or approve unrelated dialogs.

### F4 — Minor: idempotent late-interruption cleanup

- Clear each normal-path helper handle immediately after successful stop/close.
- Preserve an already recorded palette diagnostic result instead of replacing it with `SKIPPED_ON_INTERRUPTION`.
- Do not repeat shutdown/delete or turn successful owned cleanup into failure after the UDID has already been deleted.
- Test interruption during late normal teardown, while preserving original normal-path behavior and truthful non-PASS interrupted status.

### F5 — Minor: known-UDID post-return/pre-inner-try cleanup window

- Guard ownership/cleanup immediately once `create_compatible_ipad` returns a known owned UDID, including interruption during device setup before the current inner try.
- Initialize helper/ownership state before use and protect cleanup with the actual controller scope. Never shutdown/delete when the owned UDID is unknown.
- Test this exact gap with actual matrix control flow. Do not scan/delete user/default simulators or claim the unobservable internals of interrupted creation are fully solved.

### F6 — Minor: genuine interruption regression coverage, no dead/no-op fixture

- Remove the reviewed dead Test 6 setup.
- Make the recording timeout fixture actually reach its timeout/kill path on the tested platform; assert the expected kill event and cleanup-error details rather than a fixture flag.
- Add focused coverage for an unsignaled supervisor receiving matrix exit 130 plus `INTERRUPTED_UI_UNVERIFIED`.
- Preserve all existing assertions and execute the actual production control flow with only external commands stubbed.

### F7 — Minor: conservative DEBUG guard and portable SDK helper

- A plain non-DEBUG `#else` must never become proof of DEBUG-only compilation. Handle exact DEBUG/negated DEBUG correctly; unknown/compound alternatives must be conservative, not a pretend full Swift preprocessor.
- Add targeted positive/negative fixtures (non-DEBUG else, !DEBUG else, DEBUG-or-feature, false-and-DEBUG, nesting) and require the `restore ` marker.
- Remove the hardcoded personal account/compiler path. Honor explicit SDKROOT or discover a compatible **existing** Windows SDK under the current installation without installing/upgrading anything or changing persistent environment.
- Preserve explicit source-contract/syntax/portable-vs-native claim limits.

### F8 — Minor: atomic matrix receipt writes

- Write to a temporary sibling and atomically replace the owned matrix JSON. Keep the previous complete JSON valid if interrupted before replacement.
- Use existing project atomic-write patterns where suitable; no cross-filesystem temp target.
- Test interruption/write failure and ensure receipt-write trouble cannot silently promote PASS or bypass owned cleanup.

## Test cycle, receipts and return

1. Record meaningful pre-fix failures for the reviewed gaps where executable; do not use missing imports or mocked copies as the only RED proof.
2. Implement the smallest cohesive corrections, without unrelated refactors or weakening negative tests.
3. Run focused interruption/source-contract tests, the actual `--preflight-only` command, B harness/policy/syntax checks and existing result guard. Use real installed Python 3.12 and per-command verified Windows SDKROOT; each command bounded to 60 seconds.
4. Native Apple SDK/app builds, live SpringBoard confirmation, actual macOS POSIX cleanup, AX, body paging and all 27 cases remain **NOT_RUN / OPEN**.
5. Commit only exact writable paths, provide one per-F1…F8 disposition and exact RED/GREEN commands/results in the report, full source/base/head SHAs, and protected/other-input integrity evidence. Report partial/blockers honestly if a finding cannot be safely corrected; no fake READY.
6. Parent sends the entire fix delta to the existing whole-branch reviewer for **one scoped re-review**. You do not self-approve or spawn another worker.
