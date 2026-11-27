# Passive SQLite fetch-lock observation — source checkpoint

This checkpoint adds an opt-in passive observation of the existing `SQLiteDatabase.fetch` serialization lock. It does **not** record application performance acceptance, execute the production corpus, run Simulator UI, or establish an SLA. Native source/build/SDK/corpus qualification and the remaining PERF metrics still belong to the integrated run.

## Product changes and limits

Only `Source/Core/Database/SQLiteDatabase.swift` and `Source/ChavrusaText/Testing/ReaderViewportAcceptanceObserver.swift` change. The recorder is compiled only in DEBUG and enabled only by the existing `CHAVRUSA_FULL_V32_SOURCE_OBSERVATION=1` environment opt-in. No new default or Release observation path is enabled.

The original timed recursive-lock retry, initial/in-loop/post-acquisition cancellation checks and deferred unlock remain in their original order. Transaction, execution, statement preparation, mapping/decompression, busy timeout, and serialized-access policies are unchanged. The observation finish defer is registered before the original unlock defer, so its bounded in-memory completion executes after this fetch's unlock. An outer recursive owner may still hold the same SQLite lock; the recorder never calls SQLite, a bridge, a logger, or file/JSON work while holding its own lock.

A completed record retains actual monotonic begin/wait-start/acquired/terminal timestamps, actual process/native-thread/main-thread identity, immutable connection/operation IDs, normal-return and task-cancellation flags. It contains no SQL, parameters, result text or error strings. Cancellation state is not treated as an exception classification. Acquired-lock wait and elapsed wait that ended without acquisition are separate fields. Neither is SQLite's engine busy-handler wait or query duration.

The limits are 1,024 completed records, 64 active records and 64 connection identities. Lifetime overwritten history, active-capacity drops, connection-capacity drops, unmatched completions, and counter overflow have distinct explicit fields. In-flight work is incomplete. These limits do not create a passing performance outcome: a host must prove coverage for each real epoch from actual sequences, timestamps and counters or report that metric unqualified.

Opened file identity is captured once, immediately after the actual successful SQLite open, outside recorder ownership and fetch critical sections. An actual filename, regular-file stat before/after, and `SQLITE_FCNTL_HAS_MOVED == 0` must agree. The identity is explicitly **at connection open**; it is not a later file-content hash, corpus-version assertion, or proof against subsequent in-place mutation. Unsupported VFS, non-file databases, invalid paths and unavailable identity remain unqualified. The integrated host must separately bind this opened identity to its admitted installed corpus and before/after source/file witnesses. No later SQLite-handle access is attempted by the exporter.

The existing fresh viewport request, after the resource epoch, obtains a copied snapshot, releases recorder ownership, then writes a single atomic companion file capped at 1 MiB. Its inline descriptor is capped at 2 KiB. Original viewport/source/selection bounds stay intact. The descriptor binds request ID, PID, exact companion path, bytes and SHA-256; invalid requests or failed/oversized exports report unavailable. A previous companion cannot qualify another request.

## Actual Apple verification

The original SQLite source blob was `a7d7180ef1b7ba77a40a98d32592365206c1e41f`, SHA-256 `05889b3166b046c6204e216c6ff27464c3dd3cc7cc3749f8242323a07043c1a3`. The original observer blob was `cd819b520e9c7d279855a88d88f3e2a7cc3ca30b`, SHA-256 `742d3e9dec8c432c8bfebea5f6e8d31b0188202f786501d24057556fb93f9bd2`. Both match the reserved source read at the reader checkout and root checkout before edits.

The successful run used actual Xcode 27.0 (27A266a), Apple Swift 6.4 and the installed macOS/iOS Simulator 27 SDKs. `run02/actual-apple-files/RESULT.json` retains exact commands, opt-ins, exits, timings and all input hashes. Its actual Mac directory is `/Users/m1/builds/otzaria-wave2-reader-controls-20261127/sqlite-fetch-wait-20261127T052034Z`.

All **25 commands exited zero**, including **20 component executions**:

- Six unchanged-source baselines check actual SQL values, recursive mapping/outer transaction, held-lock waiting, cancellation while the holder remains blocked, prior cancellation, and original preparation/mapping errors.
- Twelve candidate executions cover the same operations plus the completed ring bound, genuine connection-capacity bound, non-file identity, absent/false opt-in, and one explicitly **synthetic recorder active-capacity admission** case. That synthetic case is not an SQL operation or timing measurement.
- One Release execution confirms the original SQL result with the opt-in present; the DEBUG recorder is excluded from that compilation.
- One actual Mac Catalyst component execution checks the companion's real bytes/hash/request, descriptor bound, invalid request refusal and actual write failure.

The full candidate observer plus SQLite also typechecked against the actual iOS 27 UIKit SDK and compiled for Catalyst. The already documented application dependency boundaries are used only to link/typecheck the unrelated view/controller types; no replacement database, lock, native thread identity or exporter was used. The existing `UnusedZstdBoundary.swift` deliberately traps if called; these integer-only SQLite controls never decode compressed content.

The baseline `recursive` raw label also contains the string `outer-serialization-snapshot-no-deadlock` because labels are shared by the harness. The unchanged baseline has no recorder or snapshot call; its credit is only original recursive SQL/transaction behavior. The candidate executes the snapshot while an outer recursive owner remains. No run deterministically forces the narrow cancellation-after-acquire race; the original check and unlock ordering are preserved byte-for-byte in that boundary, while the genuine before-acquire and queued-cancellation paths were executed.

The initial `run01` failed to compile the control harness because the current SDK disallows `Thread.isMainThread` directly in an async context. The harness now obtains that actual value through a synchronous function immediately before the synchronous fetch, with no executor hop. Both product candidate files were identical between attempts. The failed receipt and source bytes are retained rather than erased. Its whole-observer UIKit typecheck already passed.

`TRANSFER.json` in each run binds every raw source/log/snapshot file copied from the actual Mac directory. The compiled binaries remain on the Mac and their exact hashes are recorded. No module cache or other agent artifact was copied/deleted. Original raw source fragments retain their original blank EOF lines; whitespace checks apply to edited product code, not rewritten evidence.

## Remaining integrated work

The host still needs to retain each fresh companion alongside its source request, bind real PID/executable, installed corpus and epoch, and reject lost/unknown coverage. Scheduler/main-thread intervals, layout/scroll hitch events, sampled RSS/CPU, actual UI correctness during pending work, and the exact natural Inspector scales remain separately qualified requirements. Component results here close only this instrument's focused source validation.
