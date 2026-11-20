# Cached original-engine occurrence lease

The repository extension uses only an `OtzariaSearchEngineBridge` already held in the original `engineCache`. It cannot call `engine(databasePath:)`, construct an engine, open/recover an index, install an artifact, or reindex. It does not modify the public historical synchronous search path.

## API

```swift
func countExactTokenOccurrences(
    databasePath: String,
    request: OtzariaExactOccurrenceRequest,
    expectedSource: OtzariaExactOccurrenceSource,
    expectedRevision: UInt64,
    expectedFingerprint: Data,
    deadlineUptimeNanoseconds: UInt64
) async throws -> OtzariaExactOccurrenceResult
```

The caller binds a validated managed database/index installation to an exact `resourceObservation` revision and fingerprint. The source identity is the actual expected compiled engine identity. The supplied monotonic deadline is an absolute bound, not a duration to restart after waiting for the cache. The method also honors the request's own duration, using the earlier deadline.

## Ownership and synchronization

A synchronous helper attempts the original `NSRecursiveLock.try()`. It acquires and releases on the same thread and returns a busy result immediately if another query/index operation holds the lock. The asynchronous caller checks cancellation and monotonic time between attempts and sleeps at most one millisecond. No repository or revision lock is retained across an await.

Capture requires an existing genuine cached engine, its original cached `OpenIndexStamp`, a matching live stamp, an exact sorted-JSON resource fingerprint, the expected publication revision, and both installation manifests. The lease retains the same Bridge object strongly.

Immediately before calling the actual asynchronous Bridge, the method recomputes and floors the remaining milliseconds. After the native result returns, it reacquires the cache through the same bounded mechanism and verifies the exact engine object, exact cached stamp, live stamp, expected fingerprint, publication revision, cancellation and original absolute deadline before returning the scalar.

The existing invalidation/close/exclusive-indexing paths remain unchanged: they advance publication revision and close the actual Bridge under the original cache lock. The new Bridge cancels pending operations before its queue synchronization. Worker cleanup needs no repository lock, so a close waiting for the original engine queue does not wait for repository post-validation. Supported A→B→A invalidations remain visible even when final disk bytes are the same. The implementation is not a watcher for every unsupported external filesystem change.

The revision lock protects only reads/increments of the revision. No filesystem read, native operation, or await runs under it. The legacy `observedOpenIndexDocumentCount` method remains unchanged and may wait for a synchronous legacy query; the new count path never calls it.

## Resource witness

The existing stamp retains profile, database fingerprint, resolved index path, original `meta.json`, and original identity bytes. It adds optional raw bytes from:

- resolved index directory / `otzaria_prebuilt_installation.json`
- parent of the requested database / `seforim-installation.json`

Those are the original managed installation locations. No storage initializer, prepare call, migration, or write is used to resolve them.

Optional absence preserves the original/custom-index observation behavior and synthesized encoding omits nil fields. A previously observed manifest's addition, replacement or removal changes the stamp. Existing but unreadable, nonregular, or oversized metadata fails closed; it is not silently treated as absent. Count requires both manifests to be present, while the app integration separately validates their complete typed semantics, managed source/profile/path, expected document count, and corpus coverage.

All four small metadata readers are capped at 1 MiB per file. A pre-read size check is followed by a bounded FileHandle read of at most the cap plus one sentinel byte, closing the size-check/file-growth race. This is a byte and allocation bound, not a hard I/O latency guarantee for a stalled filesystem.

## Verification design and scope

The added runtime cases compile the entire unchanged repository source and all original Bridge files against the actual C static library and pristine owned original-engine checkout. Temporary fixtures are owned UUID directories. Filesystem/profile/path resolution and unused UI result types are explicitly labelled boundary doubles. Actual engines are created through the original constructor only during explicit fixture preparation and ordinary repository opening; count receives no injected engine or result.

The fixtures supply actual original `dictionary.json` and `Acronyms.json` bytes beside the executable so the original required-dictionary configuration executes. Source files, resources, engine checkout and library hashes are captured by the driver.

The fixture database/installation bytes are an isolated raw filesystem-witness test, not a real managed SQLite corpus or trusted release. The actual C/Rust engine indexes and counts owned test content. Root's separate app integration and original-index qualification must establish production corpus/artifact compatibility.

The 14 new cases cover unopened-cache rejection, actual original cached count, stale revision/fingerprint, optional-manifest compatibility, both manifest identities, oversized metadata, four source changes after a real count, cancellation through actual invalidation, pre-capture cancellation/deadline, elapsed cache wait reducing the native deadline, post-count cancellation/deadline while the real cache lock is held, and supported ABA invalidation. The original 28 Bridge/DTO/lifetime cases are retained.

The original portable cached-readiness fixture retains its 14 original assertions and adds 11 manifest assertions. It compiles the whole repository but uses explicit FFI/storage doubles. It is reported separately from actual C/Rust runtime acceptance. Its baseline option compiles the entire original repository from an exact Git ref to demonstrate the new raw-manifest witness gap without changing assertions.

The `OTZARIA_OCCURRENCE_TESTING` cache hook only holds the actual existing lock for a bounded scheduling barrier; it does not substitute a cache entry, engine, source or result.

Actual run results and failure attempts are recorded in the accompanying evidence. Apple SDK, Native UI, production managed coverage, compatibility qualification, and app capability publication remain separate gates.

## Actual results recorded 2026-11-20

- SentinelX `job_19b951256e21`: compile/link/runtime exit 0, **42 PASS / 0 FAIL**. This includes the original 28 Bridge cases plus 14 new whole-repository cases. Runtime source, original dictionaries, static library and pristine engine checkout remained unchanged.
- SentinelX `job_d3e7e5f11843`: exact baseline `9af79f40`, **19 PASS / 6 FAIL** out of 25 executed assertions; candidate **25 PASS / 0 FAIL**. The six actual baseline failures concern index/DB manifest addition, same-sized replacement, either removal, and oversized metadata. The original 14 assertions passed and remain in the fixture.
- The actual C/Rust runtime uses source `d5d59d1269bdf87fb0a6901cf31941726a0c699b` and static-library SHA-256 `7f23e3e87aa604b410f9cd21f1b56aab2d30596c697d46c8fb19ad160e34c7a0`.
- Exact logs, JSON results, test/production source snapshots, dependency lock, original resource hashes and SentinelX job records are retained under `evidence/repository`. The initial 17 and 28 case Bridge runs are subsets of the 42 case run, not additional unique cases.
- Source review independently found no concrete ownership/lock blocker. That review performed no runtime testing. The actual runtime gates above were run separately.
- Apple SDK: **NOT_RUN** for this repository tranche. Native UI: **NOT_RUN**. Managed application coverage and capability connection: **NOT_CONNECTED** in these fixtures.
