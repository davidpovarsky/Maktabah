# O2-A fix round 1 — timeout cleanup interrupted by first signal

Original implementer: `c5124cd6-3896-4554-9c83-adf3722f6050`, same conversation/worktree/model/profile. Reviewed head: `6fcae66429845fdddaff6a83a7e12671a22785bc`.

This is one narrowly scoped code correction, not a fresh task or quota retry. All original `O2A_WORK_PACKET.md` global constraints and seven writable paths remain binding. No nested workers, protected changes, installs, pushes, paid CI or unrelated changes.

## Original reviewer finding #5 (verbatim)

> `runtime27.run_logged` `TimeoutExpired` path leaves `controller.cleanup_active = False` during `stop_owned_process_group`.
>
> When `process.wait(timeout=timeout)` raises `subprocess.TimeoutExpired` (not `KeyboardInterrupt`), `controller.interrupted` is still `False` and `controller.cleanup_active` is not set until `main()`'s `finally:`.
>
> An external `SIGTERM` arriving during the 5-second `stop_owned_process_group` wait after a child timeout would raise `KeyboardInterrupt` out of `stop_owned_process_group` before `SIGKILL` runs (though `main()`'s `finally:` still writes `result.json`).

Manager reproduced this safely on the exact candidate; this is blocking against the packet's interruption/owned-cleanup requirement. See manager Assets `O2A_TIMEOUT_SIGNAL_REPRO.py`: Popen and process-group cleanup are mocked, and the installed handler is called directly. It starts/kills no process and sends no OS signal.

## Requirements

1. Add a meaningful RED regression in `tools/test_runtime27_interruption.py` covering the **actual main/controller/run_logged wiring**, not a standalone controller mock that the production caller never uses.
2. Exercise both timeout then first SIGTERM/SIGINT during cleanup and an already-interrupted path. Cleanup must reach its bounded escalation/result stage and preserve a non-PASS receipt; repeated signals must not abort that cleanup.
3. Ensure the controller is really propagated to the production cleanup boundary. Preserve/restore cleanup state correctly and retain truthful interruption metadata. Keep the original timeout/failure semantics non-PASS.
4. Keep the normal path and standalone helper compatibility unchanged; do not add global process kills, new authorities, broad refactoring or alter the native test/SpringBoard code in this round.
5. Re-run the focused interruption suite and existing result guard, with real Python 3.12 and bounded commands. Native/macOS behavior remains NOT_RUN.
6. Append this fix round's RED/GREEN commands, exact outcomes and new commit SHA to `O2A_IMPLEMENTATION_REPORT.md`. Commit only the narrow repair/test/report delta on top of `6fcae664`.
7. Return once, with the new full SHA and evidence. The manager will obtain scoped re-review from the original reviewer before any code merge.

Other review findings remain explicitly deferred for final review. Do not treat this message as permission to implement all suggested minor polish.
