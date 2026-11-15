# Final backend-await completion race — 15 November 2026

P primary `01a1df8a-23b0-77a0-bd90-c1dbfac06c2a`, worktree `C:/Users/DAVID/Code/Maktabah-hq-actions-core-20261115`, branch `codex/otzaria-ui-registry-20261115`, baseline `996a7ba0f32948f55485a89a1f9f2a98cc968364`.

The manager identified a real ordering gap after bedd754d. The reader ACK branch checked native authority completion, then the common tail awaited `state.snapshot()` again. Native permission/lifetime could revoke during that last backend await while the backend snapshot remained identical.

## Reproduced before correction

The real Core actor executes reader.open through the actual resolver/sink ports. A synthetic MainActor authority consumes its genuine Core preparation, records one synthetic UI effect and returns an exact ACK. Its first post-ACK backend snapshot returns normally. The second (shared final) snapshot suspends on a cancellation-cooperative finite gate. The test revokes only native active authority, releases the gate, and returns the SAME backend snapshot.

At the baseline the test executed **1 XCTest method with 2 failed assertions**: Core returned `completed` and no authority error. The backend stayed equal, the synthetic effect count was1, the gate did not use its finite safety release and had no pending continuation. This is an actual portable control-flow reproduction, not a native incident. The baseline Engine Git blob `8653a846965f54aac37ae0376d79e0788f140787` is exactly identical in manager coherent source `10a93f99818925db39e1844c4a97055e8551c08f`.

## Narrow correction and verification

Retain the acknowledged reader preparation until the common final backend recheck completes. Then invoke its synchronous MainActor `validateCompletion()` (which reads BOTH the exact Core backend authority and trusted native context/lifetime) immediately before returning the result. There is no later backend/readiness await in perform. Queue-only outcomes and unconfigured legacy sinks do not receive a completion grant/check; their existing behavior remains.

Final focused strict Swift6.3.3 Windows execution: **20 NavigationAuthorizationTests / 0 failures / 0 warnings**, including the new race regression, plus **2 legacy Core EngineTests / 0 failures / 0 warnings**. The red and green runs are separate executions of overlapping coverage, not additional independent scenarios. Raw logs and all exact source/Git/log hashes are in `results/completion-final-await-summary.json` and the three `completion-final-await-*.log` files.

The failure still follows an already observed synthetic effect; refusing completion is not rollback/no-effect proof. This last observation is not an atomic barrier across actors or a promise the authority can never change after it. N must keep the admitted native context/lifetime active through the entire Core action result, not retire it on the sink ACK before Core's final validation; this requires no await-held lock. There are no public API/schema/resource/deployment changes, no S/I/R/upstream/project/workflow edits, and no native/physical execution by P. Public-v2 work is separate and was not mixed into this priority correction.
