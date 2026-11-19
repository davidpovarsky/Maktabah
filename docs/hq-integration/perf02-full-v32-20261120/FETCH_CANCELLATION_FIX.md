# Narrow SQLite fetch cancellation fix

## Decision and source

The actual full-v32 baseline exposed a 4,484 ms cancellation wait behind another Reader's naturally running SQLite/ZSTD fetch. Baseline correctness still passed; a canceled waiter eventually threw without returning content. The baseline is preserved in commit `559d38080b02d909c4eef2510d337073c2750ad3` and `baseline/` and is not rewritten by this follow-up.

The narrow source fix is `92e7cd3e2bf57f8c2a290afa0aaac26e5f094241`. It changes one upstream file, `Source/Core/Database/SQLiteDatabase.swift`, in one method: `fetch`. The diff has nine added lines and one removed line. The existing `NSRecursiveLock`, public signature, statement cache, database handle, binding, stepping, decoder ownership and row mapping remain in place. There is no new application module, pool, connection, UI, database schema or source data change.

The method checks task cancellation before attempting acquisition, waits for the same lock in attempts with a 10 ms deadline, and checks cancellation after each unsuccessful attempt. After successful acquisition it installs `defer { lock.unlock() }` before a final cancellation check. A cancellation that wins as the lock becomes available therefore releases exactly the acquired recursion level before any statement preparation. Once admitted, `_fetchNoLock` and mapping still run within the original serialized scope. A cancellation observed by the original row mapper continues to reset the active statement and release the lock through the existing defers.

The 10 ms interval is a wait granularity, not a hard response-time guarantee under scheduling. A non-cancelled caller still waits until the original owner releases the same lock. Running SQL is not interrupted and a canceled waiter cannot interrupt another owner's query. This change does not remove synchronous database work from MainActor, make active `sqlite3_step` cancellable, or rewrite unrelated repository lifecycle paths.

Apple documents recursive same-thread acquisition and the timed `lock(before:)` API on [NSRecursiveLock](https://developer.apple.com/documentation/foundation/nsrecursivelock). The actual Apple SDK/compiler/runtime gate for this new source remains separate; portable Windows evidence is not substituted for it.

## Actual SQLite red/green

Five focused cases were added to the existing `Tests/HQ/sqlite/SQLiteDatabaseAcceptance.swift`; the original driver and original existing cases were retained. The new tests commit is `b3ae11f7c04b6e0af0b55d192ed4a212f9bafeb0`.

| Check | Original source | Fixed source |
|---|---|---|
| Recursive fetch preserves owner and result | PASS | PASS |
| Pre-cancelled direct fetch maps no rows and leaks no lock | FAIL: returned rows | PASS |
| Canceled contender completes while the unrelated holder is still blocked | FAIL: waited, then returned rows | PASS |
| Cancellation wins as the original lock becomes available | FAIL: returned rows | PASS across 32 controlled interleavings |
| Cancellation from the row mapper resets the statement and unlocks | PASS | PASS |

The baseline actual-SQLite run compiled and executed: **23 PASS / 3 FAIL**, not a compiler failure. The unchanged tests against the fixed source passed **26/26**, including the existing step, bind, schema, interrupt, writer lock, transaction, serialization and actual read-only full-v32 source cases. Test-only holder barriers establish lock ownership and make the regression deterministic; these fixture barriers are not used in the full-v32 latency measurement. The fixture writes only its own UUID databases. The full source database is opened read-only.

After each successful cancellation test, the main test thread checks the actual private recursive lock with `try()` after the worker has joined, then performs an actual subsequent query. This makes a leaked recursion level or poisoned statement a failure. There is no replacement SQLite API or lock implementation.

## Same-workload full-v32 comparison

The fixed-source run completed at 2026-11-19 23:37:39 UTC, SentinelX job `job_020e8969e4cd`, with compile/execute/oracle exit codes zero. The worktree and all recorded source hashes remained unchanged through execution.

| Measurement/check | Baseline `54ea8990` | Fixed source `92e7cd3e` |
|---|---:|---:|
| Exact Reader outputs / independently verified source-row appearances | 121 / 113,608 | 121 / 113,608 |
| Queued cancellation with no injected query delay | 4,484 ms | **16 ms** |
| Maximum overlapping shared / independent Reader calls | 8 / 4 | 8 / 4 |
| Active cancellation after actual source rows | 381 rows; no partial return | 381 rows; no partial return |
| Actual oversized side-cache unit | 122,373,172 estimated bytes; not retained | Same payload; not retained |
| Retained side-cache / statement counts | 50 / 100 | 50 / 100 |
| Largest observed index / summary entry counts | 20 / 50 | 20 / 50 |
| Harness peak working set | 336,572,416 bytes | 343,764,992 bytes |

The active-cancellation clock recorded 0 ms in both runs; this means no resolvable elapsed interval with this Windows clock, not zero cost. The candidate fixture process ran for 13.562 seconds and the complete driver for 107.578 seconds, compared with 39.172/254.094 seconds in the baseline. Those total/compile/large-chapter timing differences are **not** attributed to the patch: the shared host and OS/disk caches were not controlled as a throughput experiment. The narrow conclusion comes from the held-lock red/green regression and the genuine queued-cancellation observation.

The working-set observation includes harness/output allocations and increased slightly; no memory improvement is claimed. Both runs retained all required text and refused only oversized cache retention. No WAL/SHM file was created.

The fixture, driver, native libraries, compile mode and all other original Reader inputs are the same as the baseline; only the SQLite source input changes. Both full DB hashes before/after match the official pin. All 121 independent output hashes and row counts are compared between runs as well as against the actual source.

These are individual instrumented Windows observations. They are not a native/physical latency distribution, p50/p95, whole-application memory acceptance, or a claim that all 7,080,797 source lines were rendered. The unchanged large chapter still reaches the caller in full, while the side cache declines to retain its estimated 122,373,172-byte payload.

## Independent review and remaining gates

A separate read-only review of the exact nine-line change found no exception/lifetime or non-cancelled serialization defect: failed acquisition owns no lock, successful acquisition installs cleanup before the cancellation check, and recursion/row mapping remain in the original owner scope. The reviewer performed no additional test run or mutation; only the recorded executions are counted.

**PERF-02 remains open.** Before application integration acceptance, run the new source with the actual Apple toolchain and existing Native validation. The application still needs full-production competition among Reader/search/Inspector, rapid DB/backend/tab/unit changes, actual annotation-write and Sefaria parity, main-thread responsiveness, lifecycle cancellation, memory warnings and long-lived RSS measurements. Physical iPad timing/rendering/scrolling/relaunch remain unexecuted by this tranche. `BookPageCache` page-count accounting and the separate repository queue's cancellation/close behavior remain explicitly outside the fix, as documented in the frozen baseline source review.

## Reproduction and evidence

```text
python tools/hq-sqlite-acceptance.py --artifacts-dir <new-sqlite-results> \
  --source-db <verified-full-v32.db>
python tools/hq-full-source-reader.py --database <verified-full-v32.db> \
  --artifacts-dir <new-reader-results> --optimization speed --stress-only
```

Use the recorded toolchain/library inputs. `sqlite-red/` and `sqlite-green/` preserve all focused logs and source fingerprints. `candidate/` preserves the actual full-source run; `COMPARISON.json` records the exact input/output equality checks and measurements. Earlier preparation/compilation failures remain under `source/` and `failed-compile/`.
