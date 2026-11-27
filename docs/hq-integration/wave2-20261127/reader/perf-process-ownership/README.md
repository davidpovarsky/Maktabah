# PERF01 host process ownership repair

## Outcome and scope

The v40 per-book/mode host now records an attempted process creation before allocating its `Popen` object, retains that exact object before entering its constructor, and requires source-bound cleanup receipts before the host may retain/shut down the owned simulator. An interrupted constructor with no observable original child remains explicitly unverified. Every process-group probe and signal issued by the unchanged original interruption helper passes through a fresh original-handle/PID/parent/start/group check.

This is a source and synthetic lifecycle checkpoint. The final driver passed **39/39 focused controls**. Six baseline counterexamples reproduce the original defects across both the ordinary command and XCTest command paths. No Apple tool, app, simulator, real child process, real signal, database query or performance workload ran in these controls. UI and PERF acceptance remain pending their actual qualified execution.

The exact starting commit is `2c23de7138c002cfa4476c40303d4d6973b4b6d5`. Only `Scripts/CI/reader-v40-perbook-mode-performance.py` changes outside this evidence directory. The application Source tree, test selectors, original shared/v32 host, interruption helper, nine measurement cells, corpus/metadata/source checks, original verifier and storage/time allowances are preserved.

## Why the change is needed

The original driver called `Popen(...)` before entering either command's `try/finally`. It registered a process only inside `finish_process`. An interruption after child creation but before constructor return could therefore leave a child without a retained handle or cleanup row. The outer `all([])` aggregation could report that native/exporter cleanup was complete despite that unrecorded attempt.

The original `finish_process` also forwarded the handle directly to `stop_owned_process_group`. That helper deliberately treats group liveness separately from leader liveness and sends SIGINT before probing. After the leader was reaped, a reused PID/group could therefore receive a signal unless the caller verified ownership at every helper callback.

The repair keeps the original helper and its cleanup timing policy unchanged:

- Each creation has a conservative in-memory attempt counter and row before allocation/initialization. The actual `Popen.__new__` object is retained before `Popen.__init__` can create a child or be interrupted. The original argv, cwd, environment, stream configuration and new-session setting are preserved.
- The original cleanup helper is loaded successfully before any child creation, then its actual function dictionary is retained per attempt. Cleanup does not depend on a later import or source-file read succeeding.
- A known original live child is bound to its direct handle, PID, parent, creation time and process group. The identity-only `ps` call uses `LC_ALL=C` and `TZ=UTC`; launched native/export commands retain their original environments. Normal `xcrun` exec transitions are permitted while identity is unchanged.
- After the leader has exited/reaped, the wrapper permits only a signal-0 absence probe. If a group survives or the PID has been reused, it refuses nonzero signals and leaves cleanup unverified. The identity fence runs before every probe/signal, including fallback cleanup.
- A once-only sweep covers known handles even if the caller never received the constructor result. An unobservable partial constructor, missing row, interrupted cleanup, ambiguous ownership or failed receipt write cannot authorize simulator retention.
- Final admission rereads the bounded original cleanup JSON, checks its immutable path/byte-count/SHA256 witness, compares every field with the retained row, and checks attempt/row/handle consistency. A return code or a bare empty list is insufficient.

The existing observer, trace and URL transport cleanup branches are byte-identical. Their scope and prior evidence are not reclassified by this fix.

## Exact source and validation

| Item | SHA256 | Scope |
|---|---|---|
| Baseline driver, 55,721 bytes | `72db1997353022621398819a8bc8a50267f9ac5cf4da59376813ce776d7a9d59` | Exact Git blob at starting commit |
| Final driver, 65,732 bytes | `02aea7270400acfab92f2d474a7367f6412e349d909f9eec3da746e2bb247100` | Final source checked by the 39 controls |
| Original interruption helper | `4f41dfe0175d4da2983cf4c9df1e126e63eb00d3418dcf89149de81b350e488c` | Unchanged source executed with model kernel/time boundaries |
| Original common/v32 host | `75e1f2a609d1807c481fd8a28110940e68d8c9e97a2eb0092750db2107765d49` | Exact dependency; witness shape is path/bytes/SHA256 |

`evidence/control-attempt2/RESULT.json` and `evidence/EXECUTION_FINAL.json` retain the final source/control hashes, actual Python invocation, observed exit 0, logs and all assertions. The harness executes the real driver methods and the original helper's full stop algorithm/defaults. `Popen`, process/kernel reads, process groups, signals, blocking waits and clock advancement are explicit deterministic doubles. The ordinary-file evidence writes are real local writes; they are not application files.

The controls cover interruption before observable PID, interruption after PID but before child-created proof, interruption after child creation but before constructor return, the caller assignment gap, direct-child cleanup, reaped/reused PID, surviving leaderless groups, replacement after the first signal, parent/start/group changes, permitted exec transitions, signal/probe errors, receipt ENOSPC, altered/missing receipts, an attempt counter without its row, and preservation of cleanup-helper import order on both command paths. A verified cleanup after an operation failure is only permission to finish the owned runtime; it does not turn that failed operation into test acceptance.

`evidence/PRESERVATION_FINAL.json` mechanically verifies the entire prefix before `BudgetedOriginalRunner`, the entire suffix after `stop_owned_runtime`, the unchanged observer/trace/URL cleanup block, and both original command wait loops and signatures. This retains all original workload, catalog, source, verifier, resource and capacity logic. `evidence/CANDIDATE_FINAL.patch` is the complete driver patch.

## Preserved earlier source checkpoint

The first candidate `462a4cc96b8f8182398cf495207eda01c1be44180cd7794fb03a4397aa3001ee` passed 38 source controls. Its complete source, exact executed harness, raw 38-control result and logs remain under `evidence/`. It was superseded after review identified that moving the helper import into cleanup changed the original pre-spawn dependency ordering. The final small correction is retained in `ORIGINAL_HELPER_ORDER_FOLLOWUP.patch`; the final 39-control receipt belongs only to `02aea727…`. Neither result is reassigned to another source or to native acceptance. There were no failed control executions in this repair; all baseline failures are intentionally retained modeled counterexamples.

## Provenance, storage and handoff

`evidence/BASELINE.json`, `ORIGINAL_SOURCE_READBACK.json` and `ROOTFS_SETUP.json` bind the source to the actual Oracle Git objects. The driver originated in downstream commits `b0fae4b4b2812b5a4b6dbb2070b1498cee957148` and `fe017f463738342784e6e71dd1b65a7824d5f547`; it is absent from the previously pinned original Maktabah tree `4203de5fd77beb119e5826e039be1a61325f7be0`. No upstream application or shared helper was edited.

The isolated Oracle repository uses its own rootfs Git directory, refs, index and objects, with only a read-only alternate pointing to the existing shared object store. All new remote writes are in its owned `/tmp/otzaria-perf-process-ownership-2224f98e04f2457a9c7b1c992297074b` directory. No Data-volume source, ref, artifact or foreign worktree was modified. The integration owner publishes and transfers the exact commit to Wave3; the next real runtime run must qualify its own source/build/SDK and keep unresolved cleanup explicitly unverified.
