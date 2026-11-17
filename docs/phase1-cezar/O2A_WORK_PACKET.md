# O2-A — bounded system URL and interruption repair

Read this first: these are the requirements, not permission to broaden scope. Follow `O2_EXECUTION_PLAN.md` global constraints. No nested agents.

## Goal

Correct the reproduced system-URL confirmation gap without weakening receipt/PID/security checks. Investigate the existing interruption boundary with a deterministic reproduction before changing it. Keep unresolved reader errors diagnostic-only.

## Frozen writable paths

1. `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift`
2. `Scripts/CI/runtime27.py`
3. `Scripts/CI/run-faithful-ipad-matrix.py`
4. `Scripts/CI/runtime27_interruption.py` — optional new reusable downstream helper, only if necessary to isolate tested interruption behavior.
5. `tools/test_runtime27_interruption.py` — new focused portable regression tests.
6. `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift` — bounded DEBUG diagnostics only; no semantic reader repair without a reproduced, separately documented defect.
7. `docs/phase1-cezar/O2A_IMPLEMENTATION_REPORT.md`

All other paths are read-only, including test assertions outside this one routing test file, `R27_CASES.json`, reader/search/sidebar UX, workflows, project files, package/lock files, shared HQ and `PROJECT_BOARD.md`. Do not create parallel URL parsers or authority/session systems.

## Required behavior

### Real URL transport and clean system confirmation

- Reuse the current owned `simctl openurl` request/ack sidecar. Preserve exact credential-free ack schema, nonce, UDID, same live app PID, foreground wait, actual History/error UI, exact scene and canonical receipt/replay assertions.
- Handle only the expected SpringBoard Open-in confirmation for this app, using the system **Open** action, never treating Cancel/dismissal as successful delivery. Bound waiting and fail closed for unexpected/ambiguous dialogs or failed delivery.
- Avoid cross-test contamination. Capture useful real system/app evidence on failure. Never bypass the OS by calling an app-internal handler or synthesize a receipt.
- No generic “tap the first button,” global gesture injection, or broad interruption monitor that approves unrelated dialogs.

### Existing runner interruption

- Inspect the existing SIGINT/SIGTERM handler and owned-process-group teardown first; these already exist.
- Demonstrate the precise missing boundedness/cleanup behavior with a failing focused test before implementation. Test real control flow with injected/mocked external commands; do not launch Xcode, simulators, CI, or generic process kills.
- Ensure interruption cannot advance to the next device or turn incomplete UI cases into a pass. Preserve interrupted evidence even if cleanup fails. Keep normal-path behavior unchanged.
- Bound interrupted diagnostics/cleanup and stop only owned subprocesses/UDIDs. Do not infer complete CoreSimulator agent cleanup from killing one Python group.
- If this cannot be safely reproduced and repaired within the frozen paths, report the specific blocker instead of speculative lifecycle rewrites.

### Unknown reader startup

- The generic adapter directly calls `service.readingUnit`; missing `getReadingUnit start` from another wrapper proves nothing about this path.
- Optional instrumentation must be DEBUG-only, bounded and content-free: fixed stage/error categories, not raw URLs, payloads, selected text, private content or credentials. Preserve cancellation/generation fences and error semantics.
- Do not “fix” `line:523`, replace the native reader, alter state restoration, or return fallback success without evidence.

## Tests and receipt

- [ ] Capture the routing failure's system-dialog evidence and enumerate expected vs unexpected dialog behavior without weakening existing assertions.
- [ ] Write focused interruption regressions in `tools/test_runtime27_interruption.py`: interruption stops device advancement; cleanup failure preserves an interrupted/non-PASS receipt; normal cleanup behavior stays unchanged; only owned targets are stopped.
- [ ] Run that file with the real Python executable and record a meaningful pre-repair failure, not merely a missing import.
- [ ] Implement the smallest supported changes inside the frozen paths; keep unknown reader causes diagnostic-only.
- [ ] Re-run the focused tests to GREEN, check the complete frozen-path diff, self-review, and commit.

- Load systematic-debugging, test-driven-development and apple-devtools as relevant. Use existing owner-approved design; resolve routine details conservatively without asking for new protected permission.
- Run the new focused portable Python tests with the real installed Python executable (not the silent `C:\Windows\system32\python` stub). Demonstrate RED then GREEN for the reproduced interruption defect. Use per-command timeouts, no installs or broad suite.
- Native routing tests cannot execute on this Windows host; explicitly mark NOT_RUN. Do not trigger paid CI, project builds, archives or distribution. Read-only SDK/API lookup is allowed if exact declarations need verification.
- Self-review cancellation, unexpected dialogs, refusal/replay, partial teardown failure and unchanged normal path. Report exact tests/results and limitations, not “all fixed” from mocks.
- Commit only frozen paths; provide full base/result SHAs, allowed-path diff, `git diff --check`, protected/hash-pinned unchanged evidence, and one concise Cezar result. Stop on quota/429/403 without retry, fallback or account change.
