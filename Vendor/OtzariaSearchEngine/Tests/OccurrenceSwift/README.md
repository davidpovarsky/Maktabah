# Exact occurrence Swift bridge — source and runtime acceptance

The original Bridge tranche below was committed as `9af79f40`. The current runner also includes the cached repository lease: **42/42 actual whole-Repository/Bridge/C/Rust cases**, with **25/25 separate portable readiness assertions** after an exact old-source baseline of **19 PASS / 6 FAIL**. See [REPOSITORY.md](REPOSITORY.md) and `evidence/repository/summary.json` for that additive tranche and its limits.

This tranche adds a typed asynchronous entry to the original `OtzariaSearchEngineBridge`. It calls the actual C occurrence API from Maktabah `99f7927e4da72f2463417f5c2de2c4d20c6aa168`, linked to the pristine owned-engine commit `d5d59d1269bdf87fb0a6901cf31941726a0c699b`. It does not implement another analyzer or count text in Swift.

## Scope and API

The production change consists of:

- `Source/Otzaria/Search/OtzariaSearchEngineBridge.swift`: the new asynchronous API, pending-operation ownership, cancellation before synchronous close, and own-queue deinitialization support.
- `Source/Otzaria/Search/OtzariaExactOccurrenceModels.swift`: immutable typed requests, limits, source identity, results, and response validation.
- `Source/Otzaria/Search/OtzariaExactOccurrenceOperation.swift`: one C request's continuation, timer, native token, bounded response decoding, and worker cleanup.

The entry is:

```swift
func countExactTokenOccurrences(
    request: OtzariaExactOccurrenceRequest,
    expectedSource: OtzariaExactOccurrenceSource
) async throws -> OtzariaExactOccurrenceResult
```

The request initializer takes `query`, `facets` (default `["/"]`), `bookIds`, `timeoutMs` (default 5,000, maximum 60,000), and the original bounded work limits. Zero work budgets remain valid requests and return a typed budget failure when work would exceed them. The original engine determines whether the query produces exactly one analyzed token. Empty and multiple-token queries return unsupported; no hit count is substituted.

The caller must supply the expected actual engine commit, repository, branch, original upstream base, schema version, and package version. A convenience initializer accepts actual `OtzariaSearchEngineBuildInfo` plus the expected original upstream base. This is source identity, not a declaration that a selected database or index covers a requested corpus. Managed database/index validation and capability publication belong to the separate app integration.

Success contains an exact occurrence scalar and a separate matching-live-document count, the native request token, exact analyzed token, requested facets, held-searcher generation/segment/deletion identity, live-index document count, engine identity, and measured work. Two positions in one live document remain two occurrences and one matching document.

## Ownership, deadline, and cancellation

The original serial Bridge queue remains the sole owner of `EngineHandle`. The operation object never retains a raw engine pointer. The worker captures the Bridge and operation strongly through native execution and cleanup.

The monotonic Swift deadline is captured before build-info validation and JSON encoding. C creates its own request/deadline before the operation can wait for the Bridge queue or the original engine mutex. A weakly owned Dispatch timer and the task cancellation handler deliver a fixed typed failure without waiting for either queue or mutex.

Registering a request and enqueueing its worker happen under the same short registry lock as beginning close. Close first marks the Bridge as closing, snapshots pending operations, and cancels them outside that lock. It then uses the original synchronous queue lifetime boundary to free the engine. Repeated/concurrent close sees a nil handle after the first free. If the worker owns the final Bridge retain, deinit can run on the queue itself; a queue-specific identity avoids synchronously dispatching to itself.

A cancellation or deadline resumes the awaiting continuation once, but does not release the native request or its capacity reservation. The queued/in-flight worker retains that reservation until cleanup. Thus repeatedly cancelling queued requests cannot evade the C limit of 64 live request owners. A rejected request that was never queued releases immediately. The timer has a weak event-handler capture, and the operation cancels/releases it outside its state lock.

A success is checked again for task cancellation, the original Swift deadline, and Bridge closure after await. The C API also checks its cancellation/deadline before and after locking/counting and after serialization. The final scalar cannot be published after a terminal state observed by those guards.

## Proof and error validation

The Swift decoder validates the exact request token and source fields, count kind and exact flag, raw UTF-8 facet identity, live-document/count/work inequalities, requested budgets, and segment count/unique IDs. It preserves all `UInt64` values through typed decoding, without converting through JSON floating-point numbers. Swift canonical String equivalence is not used for source or facet identity.

Request JSON is capped at 512 KiB and response decoding at 1 MiB. Native failure envelopes cannot contain a success value. Only the fixed error-code whitelist is exposed; arbitrary native messages are not decoded or returned as API errors. No partial numeric result accompanies cancellation, deadline, unsupported query, invalid proof, overflow, or budget failure.

The historical synchronous search/count/facet/indexing/semantic methods and their helper/hash implementations are unchanged. The only hash import change is conditional `CryptoKit` on Apple and the real official `Crypto` module in this Windows acceptance package. No application dependency or SDK setting is added here.

## Actual verification

All following records are preserved under `evidence/`.

| Run | Actual outcome | Meaning |
| --- | --- | --- |
| Windows CryptoKit import probe | Failed: module unavailable | Retained environment fact, not an occurrence test |
| Official pinned Crypto dependency build | Exit 0; 0 runtime cases | Built the real dependency, no hash stub |
| DTO/operation strict-concurrency typecheck | Exit 0; 0 runtime cases | Swift 6 compile check only |
| Whole-Bridge attempt 1 | Compile/link/runtime exit 0; 17/17 | Initial subset, before 11 lifecycle additions |
| Whole-Bridge attempt 2 | Compile/link/runtime exit 0; **28/28** | Complete current runtime suite; includes the same initial 17 |
| Final driver pin enforcement | Syntax and existing exact lock comparison passed | Driver-only reproducibility tightening after attempt 2; runtime production bytes unchanged |

Attempt 2 was SentinelX job `job_64c8a4e98004`, 2026-11-20 02:56:16–03:01:52 UTC. Attempt 1 was `job_4f44790f62d8`. There are **28 unique Bridge-tranche cases**, not 45; they are included in the expanded 42-case repository run.

The complete suite covers actual legacy Bridge calls, two positions versus one document, original Hebrew normalization and prefix exclusion, original book/facet scopes, byte-distinct Unicode scopes, actual deleted postings and snapshot proof, zero matches, unsupported query shapes, all work budgets, expired deadlines, mismatched source, oversized JSON, and strict typed bounds. Adversarial decoder cases are separately labelled and do not count as independent engine or corpus oracles.

The lifecycle cases exercise cancellation before continuation installation, an already-cancelled task, cancellation and deadline while the original queue is held, cancellation isolated from another request, all 64 queued reservations retained after cancellation and recovered after cleanup, close cancelling before queue synchronization, four concurrent closes after the real native count but before publication, own-queue close, final engine retain release on that queue, and 128 timer owners without a retain cycle.

The conditional `OTZARIA_OCCURRENCE_TESTING` hooks only schedule work on the original queue, observe pending/closing state, or pause after a real native count and validated proof. They expose no pointer and substitute no provider, query, or result. Queue holds have bounded waits and cleanup releases. Runtime tests create their own UUID temporary indices with an ownership marker and remove them; the executable accepts no user index path. The unsafe original user-path diagnostics were not run.

### Exact compiled identities

- Actual engine: `d5d59d1269bdf87fb0a6901cf31941726a0c699b`, clean before and after.
- Original upstream base: `265a14ea54f959a3e266d6e8acfa3a3b98101d68`.
- Windows static library: 560,900,320 bytes, SHA-256 `7f23e3e87aa604b410f9cd21f1b56aab2d30596c697d46c8fb19ad160e34c7a0`.
- Attempt 2 executable SHA-256: `1722ac11650c83dc899def285cf69ba7c38362a11d334e19c21ac0140e900e06`.
- Official swift-crypto (4.5.0 tag): `1b6b2e274e85105bfa155183145a1dcfd63331f1`.
- Official swift-asn1 (1.7.4): `917b472dbe53ba699cbb0495f9a95a084bc6364d`.

The committed `Package.resolved` is the exact lock used in both runtime runs. Both official dependency checkouts were clean. Whole production files were copied byte-for-byte to the test package, with gzip snapshots and raw/LF hashes recorded in each run. They were not sliced, transformed, or supplied with a hash stub. Both runtime runs compiled the same three production-file contents.

The final driver seeds that exact committed lock for a fresh package directory, verifies both official immutable revisions, and refuses a different existing lock. It runs SwiftPM with automatic resolution disabled. The precise earlier driver used by attempts 1 and 2 is retained as `evidence/driver-used-for-attempts-1-2.py.gz`; tightening the lock did not change production or test sources and was not presented as another runtime run.

## Reproduction

Use the existing real C static-library build record from `Tests/OccurrenceFFI` and the Rust toolchain's actual native Windows library directory:

```text
python Vendor/OtzariaSearchEngine/Tests/OccurrenceSwift/run-swift-acceptance.py \
  --build-record <actual-staticlib-build.json> \
  --native-library-dir <windows_x86_64_msvc-0.52.6/lib> \
  --output <owned-evidence-directory> --expected-cases 42
```

The driver verifies the real library hash, truthful source manifest, pristine engine checkout, exact source copies, immutable dependency pins, runtime exit/case count, and unchanged source/library/checkouts after execution. It preserves compile/runtime logs and result JSON. The test-only MSVC link excludes clang's injected static CRT `libcmt` while using the actual Rust-emitted native libraries and `msvcrt`; this is the same verified link arrangement as the external C consumer.

## Remaining integration gates

Apple SDK typechecking/runtime, Native UI, application managed-source/corpus coverage, artifact installation and old-producer-index qualification are **not** proved by this Windows suite. This tranche does not advertise an app/Core capability, change index policy, alter application project registration, or claim compatibility with an existing v32 index. Those gates remain separately owned and must pass on their actual combined source before task completion.
