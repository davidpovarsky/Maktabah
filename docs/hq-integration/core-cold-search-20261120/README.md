# Explicit cold search execution — candidate and validation contract

## Status and provenance

This is an unqualified candidate based on `19b68b8b0085a3e44e519835194398486273aaa4`.
It is not a Native repair result, and no new Apple Swift compile or XCTest run
has completed at preparation time. The prior Windows job
`job_ed394b183ed4` was reported orphaned after 912 seconds with no exit code or
output. Its actual execution outcome is **UNKNOWN**, not a failed test run.
Its uncommitted twenty-test source is not recoverable from the available local
artifacts or retained tool state while that host is offline.

`ColdSearchExecutionOfflineTests.swift` therefore explicitly defines a separate
set of twenty controls. Byte equivalence to the Windows twenty is
**NOT_VERIFIED**. All 174 pre-existing Core cases, in twelve original test files,
remain byte-identical to Git `19b68b8b`. The standalone package has no external
package dependency. Its original external fixture
`docs/hq-actions-bridge/embedded-handler-fixtures.json` is included with Git blob
`86ab7654efc5317afffbbe5a0cbbb98f646ab775`.

The demonstrated old Native symptom is an explicit `search.openResults` result
of `unavailable/backend_unavailable` before the original search session submitted
anything. The existing readiness observer inspected only an already-open engine;
the explicit Core operation had no means to acquire an installed cold engine.
This does not prove that every historical Search or History failure shares that
cause. No test is changed to submit a preliminary UI query or warm a cache.

## Candidate execution boundary

Core invokes a new optional preparation port only for explicitly executed
`search.query` or `search.openResults`, after the original action and work-scope
policy and only when the existing operation is registered, supported, and not
currently available. It then rechecks the same backend snapshot, obtains a fresh
original assessment, and rechecks the snapshot again. A successful preparation
return cannot itself satisfy capability admission or create an empty result.

The port returns no grant, count, query result or receipt. The original search,
original UI command/admission, original receipt validation and caller authority
remain in force. Discovery, backend reports, metadata actions and occurrence
counting do not use this hook. An absent protocol, or a facade whose optional
preparation closure is nil, retains the original path without a new await.

The app supplies the hook only for an already selected `managedInternal`
database at its canonical profile path. It captures the original atomic
selection/revision, bridge generation, profile, repository publication revision,
and exact source metadata. It requires the original ready catalog, registration,
authenticated database/index installation manifests, canonical identity,
compatible engine metadata, nonzero manifest document count and exact bundled
dictionary hashes. Custom, missing, malformed, legacy-repair-needed, building,
installing, or mismatched sources are unavailable.

The repository uses its original cache, handle owner, dictionary configuration
and actual `documentCount`. It does not invoke installation, recovery, rebuild,
download or a search query. No C/Rust source, binary, SDK pin or public tool is
changed. The original d5 C constructor is still writer-capable and uses its
original open-or-create implementation; the guarantee is cooperative app
existing-only admission, **not a globally read-only filesystem guarantee**.
An external writer that ignores the app's locks remains outside that guarantee.

## Ownership and lock order

The new synchronous acquisition order is:

`migration-profile → database-mutation-profile → otzaria-search-mutation-profile → original repository NSRecursiveLock`.

Every acquisition uses the original per-name lock owner. The new storage
`tryWithLock` also uses the original Darwin lock file with `LOCK_NB`; it does not
modify the existing blocking `withLock` behavior. A busy inner owner releases all
previously acquired locks on the same thread before the bounded async retry.
No await occurs while these locks are held.

The original bridge `openIfNeeded` holds its recursive lock while restoration
may wait on `migration-profile`. Consequently, a callback already under storage
locks must not call the original blocking `generationSnapshot`. The new
`tryGenerationSnapshot` reads that same generation under a nonblocking attempt;
busy observation unwinds every storage/cache lock before retry. Selection reads
hold only the original short selection lock; its publishers release that lock
before filesystem mutation.

Existing `IndexManager.recoverTrustedManagedIndex` holds the search mutation
lock while invalidating the repository, so search → cache is an existing order.
It is not wrapped recursively. The original repository stamp/path helpers do
not acquire the search or database mutation locks. Artifact promotion and
interrupted-install recovery are now serialized database → search before their
existing repository invalidation and original move/rollback code. Download,
streaming and staging remain outside those locks. Legacy migration retains its
original own lock; the new cold path participates in it rather than changing
migration's old behavior.

The independent source review found no additional reverse edge in the inspected
original callers and validators. It is not runtime deadlock proof or a Darwin
`flock` result. Native construction, native dictionary configuration, and optional
lexical resource work are synchronous: cancellation/deadline checks reject late
publication, but cannot interrupt a native synchronous call. No hard duration
guarantee is claimed for those calls.

## Exact Apple Core validation prepared for Root activation

The isolated workflow is restricted to
`codex/otzaria-cold-search-core-apple-20261120`, has read-only permissions and a
finite 50-minute job. Root alone creates/activates that immutable validation ref.
It uses the repository's unchanged `select-runtime27-toolchain.py`, one SwiftPM
job, a single owned build cache, and no SDK/corpus downloads or Native dispatch.

`Tests/HQ/cold-search/CORE_INPUTS.json` pins all 48 compiled-source/resource and
external-fixture inputs, all nine reviewed product inputs, the driver, the
original selector, the original twelve test sources, the 174+20 declarations and
the original Executor19b bytes. The workflow pins that manifest's SHA256.
The driver checks committed Git blobs and records complete before/after hashes.

Two actual executions are required:

1. Original Executor19b plus the shared protocol declarations and independent
   twenty controls: exactly the declared eleven passing leaves and nine failing
   leaves, each started and completed once. A compiler failure, zero leaves,
   timeout, different failing case, unexpected exception or arbitrary nonzero
   exit does not qualify as baseline RED.
2. Candidate whole Core: all 194 declared leaves pass, with no skips, missing or
   duplicate cases, and no altered original test source. This proves Core policy,
   reassessment, snapshot, cancellation, deadline and old-path behavior with
   explicit provider/UI doubles only.

Raw logs, per-case outcomes, process exit/timeout information, source archives,
Git/Actions identity and toolchain observations are retained even on failure.
The locally executed Python verifier controls and source-contract checks are
separate from Swift execution. App integration compilation, Darwin ownership,
actual d5 cold opening and the original Native failing cases remain distinct
pending gates; Core194 cannot stand in for any of them.
