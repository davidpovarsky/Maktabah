# Original held-read Owner + local SQLite follow-up

This is a separate two-case packet. The published six-case packet `8894bd50` remains byte-frozen, including every indexed source/evidence file. No previous assertion is rerun.

The exact original Owner.withExclusiveRead installs a native read scope. Its performSynchronousOperation defaults to mutation via requiresEditing:true, so that default cannot be nested under the held read. The future local identity persistence callback must use the explicit original requiresEditing:false scope and add no native RPC privilege. Native identity/schema/body authority remains a separate prerequisite.

The two new cases execute the actual original methods:
- The positive case enters real withExclusiveRead, preserves TaskLocal lineage through MainActor.run, acquires the actual SQLite serialized lock, then admits an explicit synchronous read child and performs a true outer SQLite COMMIT while the original capture remains held, observes the committed row through another connection, and releases the barrier only after the child drains.
- The negative case acquires the same actual SQLite serialized lock under the held read, then deliberately uses the original default mutation scope before opening any SQL transaction. It requires rejected(unqualifiedDispatch) before the fixture body/SQL begins, zero rows, and the parent's original failedWrite latch even after the inner error is caught. No current success may be published.

Both cases assert the exact event order. There is no await while the SQLite serialized lock or transaction is held. The original six-case admittedCommit helper remains in the borrowed prefix but is not invoked by these two cases; its standalone admission-before-DB-lock scope is not transferred to this seam.

A separate process reopens only these two disposable databases and checks rows 1/0. There is no native ObjectShow RPC, engine, native receipt, production identity writer, ACK or product schema change.

## Exact reuse without changing the six-case packet

The runner reuses all nine already-verified original dependency files from ../original-owner-sqlite/inputs and its unchanged PRODUCTION_INPUTS.json. The full original Owner, Lifetime, Operation, Binding and SQLite implementations are unchanged. It hashes the frozen original six-case fixture source f922db58646a0c7f5714d487df8f31bef70acdbf49902843c2ddb954a6fef7ea, selects only the exact prefix preceding its @main marker, and concatenates that prefix with the new two-case source fragment. This prefix contains the disposable document/SQLite fixture helpers, CaseResult and JSON output only. No old-six entrypoint or assertion body is compiled by the follow-up.

The exact prefix byte range/hash, new fragment hash and combined compiler-input hash are recorded. The full closure is 13 source inputs; 10 source files are compiled. The generated control file is derived from two explicitly bound source parts and verified unchanged after execution. Windows uses the existing Windows SDK winsqlite3, while the driver has a separate Apple SDK SQLite branch without a replacement Apple module map.

Current status: prepared source only; no execution result is claimed until a retained RESULT and distinct-process receipt pass. The previous six-case result remains Windows-specific primitive evidence, and this new packet does not grant production receipt authority or qualify initial object creation without an actual account/Space capability.

Run run-exclusive-owner-sqlite-controls.py with a fresh --result-dir. This driver selects only these two new controls and their one fresh-process readback.

## Prior packet compiler evidence qualification

The independently reviewed six-case packet records the compiler executable path and reported version, source/input hashes, and the executed binary hash. It does not record a hash of the compiler executable itself. This corrects the earlier README phrase “compiler and binary hashes” without changing any indexed historical byte or rerunning its six assertions. The same precise qualification applies to this runner.
