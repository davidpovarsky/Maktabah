# Positive-only continuation of the held-read SQLite proof

The initial packet `../original-owner-exclusive-sqlite` is retained unchanged at `d8b0b6ae2a69eb0049bbfa524a2f34f878109dbf`. Its actual source `f81213dc` compiled successfully; the negative default-mutation control passed; the positive control failed while constructing its disposable database, before any Owner event. The positive filename had 253 characters and its initial journal candidate 261; the negative had 249/257 and produced a 20,480-byte database. The Windows path diagnosis is an inference supported by that concrete difference, to be checked by the unchanged positive assertion at a shorter owned path.

This continuation selects only the unresolved positive assertion. It borrows the exact 6,694-byte shared helper prefix, the exact observation class and the complete positive assertion method from the frozen sources. No assertion line, original Owner implementation, original SQLite implementation or dependency is modified. The new entrypoint does not compile or execute the passing negative assertion or the six earlier controls.

The positive assertion preserves the intended ordering: actual original exclusive read, then original SQLite serialized lock, then synchronous child read with `requiresEditing:false`, then a real outer transaction and COMMIT. The original capture remains held through COMMIT and child drain; the database lock returns before the parent read releases. There is no await inside the SQLite lock or transaction.

The new runner uses `validation/p2`, making this worktree's positive SQLite filename 227 characters and its journal candidate 235. It refuses to invoke SQLite when the selected journal path exceeds the conservative 240-character fixture bound. This is a test-path guard; no product path logic is changed.

One new process reopens the positive database and verifies its committed row. Another process opens the original passing negative database read-only and verifies that it still has zero rows. The negative control's original raw events, source/body hashes, process ID and database hash are retained; the successful assertion is not replayed. The runner verifies every historical source/receipt input against committed Git and checks that the original negative database remains byte-identical after readback.

The closure contains 15 source/verification files, five historical receipt inputs and one original fixture database. Ten Swift files are compiled: nine unchanged original dependencies plus a generated composition whose exact selected byte ranges and hash are recorded. Compiler evidence is the executable path and reported version, source/input hashes and executed binary hash; no compiler-executable hash is claimed.

Current status: source prepared for review; no positive PASS or combined completion is claimed until actual execution and both process readbacks succeed.

This remains Windows fixture evidence. It does not execute native ObjectShow, create an Anytype object, mint a native identity or applied-body receipt, enable a production ledger writer, or ACK a delivery. It does not establish the held-read retirement/failed-COMMIT combinations covered only by the separate standalone six-case packet. The original SDK and actual account/Space capability remain separate prerequisites.
