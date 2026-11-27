# Passive fetch-lock companion contract

## Original request and descriptor

The original app resolves `CHAVRUSA_READER_VIEWPORT_REPORT` to its current Documents directory. With DEBUG and `CHAVRUSA_FULL_V32_SOURCE_OBSERVATION=1`, a fresh valid UUID request produces the existing `.viewport.json` and optional `.sqlite-fetch-wait.json` companion at that same prefix. This hook is inside the existing source-observation branch. The host schedules it after its measurement epoch; the observer itself does not invent an epoch or classify performance.

`viewport.sqliteFetchWaitObservation` has schema 1, status `AVAILABLE` or `UNAVAILABLE`, requestID and processID. An available descriptor also has snapshotPath, bytes, sha256, completeLifetimeCoverage, activeCount, completedRetainedCount, lifetimeDropped, lifetimeOverwritten and scope. Read only the actual same-container path selected by the original request, require a regular non-symlink file, at most 1,048,576 bytes, matching actual length/hash, same fresh UUID and actual process. An unavailable descriptor is not recoverable by reading an older companion.

## Snapshot

Top-level fields: schema 1; status `PASSIVE_FETCH_LOCK_OBSERVATION_NOT_PERFORMANCE_ACCEPTANCE`; requestID; processID; `clock=DispatchTime.uptimeNanoseconds`; snapshotNanoseconds; observedUptime; scope; completedCapacity=1024; activeCapacity=64; connectionCapacity=64; lifetimeStarted; lifetimeFinished; lifetimeDropped; lifetimeOverwritten; lifetimeDroppedForActiveCapacity; lifetimeDroppedForConnectionCapacity; lifetimeUnmatchedCompletions; counterOverflowed; completeLifetimeCoverage; activeCount; completedRetainedCount; connections; active; completed.

`connections[]`: connectionID; capturedNanoseconds; identityStatus; optional openedFile with path/device/inode/bytes/modifiedNanoseconds. Qualified status is `VFS_CONFIRMED_OPENED_FILE_IDENTITY_AT_CONNECTION_OPEN`, describing only the captured open-time identity. Other statuses are explicitly unavailable. Connection identity is immutable and lifetime bounded; no handle is consulted during export.

`active[]`: sequence; operationID; connectionID; beginNanoseconds; nativeThreadID (or null when unavailable); mainThread. These operations are incomplete, with no invented acquire or terminal timestamp.

`completed[]` adds waitStartNanoseconds/acquiredNanoseconds (each may be null), terminalNanoseconds, returnedNormally, taskCancelledAtTerminal. If actually acquired, `lockAcquisitionWaitSeconds = (acquired - waitStart)/1e9`. Otherwise, only if a wait began, `unacquiredWaitObservedThroughTerminalSeconds = (terminal - waitStart)/1e9`. Already cancelled operations can have neither wait field. Terminal is sampled after this fetch's deferred unlock and before the recorder lock; an outer recursive owner may remain. This is not the SQLite engine's busy wait, query runtime or a main-thread responsiveness metric.

## Epoch coverage must be proven

An available file is not a complete measurement. Preserve the original bounds/sequence/counter evidence and actual clock mapping. For a desired epoch, require the host's admitted source/build/corpus/PID, valid thread and connection identities, ordered finite timestamps, and enough original records to account for every operation admitted in that epoch. Detect sequence gaps, drop-counter changes, pending/spanning operations and overwritten records intersecting the interval. A drop before an epoch or overwritten older history is distinct from a loss inside it, but that distinction needs actual baseline/end snapshots and time/sequence coverage; it cannot be assumed from the current ring alone. Counter overflow or unexplained coverage remains not measured. Never silently filter unknown records and call the remainder complete.

No performance threshold or overall PERF pass is defined by this schema. Raw observations must remain attributable to the exact build that produced them.
