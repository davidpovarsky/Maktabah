# Full-v32 Reader concurrency, cancellation and cache evidence

Task: [PERF-02](https://app.asana.com/1/1219597879016953/project/1219602719070493/task/1219613714507780). This tranche contributes actual source-level Windows evidence. The full task remains open for the application's MainActor, backend/DB/tab lifecycle, annotation/Sefaria parity and native/physical device acceptance.

## Scope and source

Production input is exactly `7d05dd0bb25a7df307b35174e49e18d0f22eecee`. Harness commit `e39b4f5f75d4410b7a4de3e349d437be4cbb5b2c` adds a stress mode to the existing `tools/hq-full-source-reader.py` and one Swift fixture. Commit `54ea8990f8ffb025815bf6b4dc158ed705e98326` makes the test observation predicates explicitly Sendable. No production file, application UI, dependency pin, project file or database schema changed. The existing 36-unit/18-navigation/170,587-row baseline and AB/BA performance experiment were not repeated.

The original SQLiteDatabase, Reader service, schema/TOC projections, plain-text conversion, unit/descriptor/anchor types and ZSTD dictionary decoder are compiled together. The side-cache class is extracted as unchanged source text, with normal UTF-8/LF serialization, before its app-bridge extension. The source and extracted hashes are recorded. Existing no-op logging/signpost boundaries and the fail-if-called unrelated legacy decompressor boundary remain explicit.

## Database preparation

The historical retained DB path was absent. A bounded parent inspection found no retained full `seforim.db` or official archive in the relevant worktrees. Exactly one isolated fixture was restored from the official `Otzaria/SeforimLibrary` release `v32-20261010190601`, release ID `409213893`, asset `629048655`. Live GitHub metadata, the checked-in seed and the downloaded archive agreed:

| Object | Bytes | SHA256 |
|---|---:|---|
| Official archive | 1,850,679,582 | `6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44` |
| Restored full database | 3,821,240,320 | `2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765` |

Preparation used the existing native zstd executable and an owned Python dependency directory containing `zstandard==0.23.0`. The first preparation stopped before downloading because Python's Windows default cp1252 could not read the Hebrew UTF-8 seed; the failure receipt is retained. Explicit UTF-8 fixed preparation. The production/user database, WAL and SHM were not touched. The owned fixture is `C:/Users/DAVID/Code/Maktabah-perf02-completion-20261120/build/perf02-20261120/full-v32/seforim.db`.

## Execution evidence

Executed at clean commit `54ea8990f8ffb025815bf6b4dc158ed705e98326`, Swift 6.3.3, `-O`, strict concurrency. SentinelX job `job_29f72b547b5f` completed on 2026-11-19 at 23:26:43 UTC. Compile, Swift execution and independent oracle exited zero. The complete driver took 254.094 seconds; the instrumented Swift child ran for 39.172 seconds.

| Executed check | Observed result |
|---|---|
| Shared connection/service/decoder | 96 genuine Reader outputs; maximum 8 overlapping Reader calls; 24 concurrent-task cache-clear requests |
| Independent connection owners | 24 genuine outputs from 4 connection/decoder owners; maximum 4 overlapping Reader calls |
| Exact source content | 121 output units / 113,608 source-row appearances independently verified; includes one 110,196-row chapter used for retention/lock contention |
| Service caches | 122 quiescent snapshots; high-water 20 index entries / 50 summary entries; maximum observed structural costs 21,125 / 16,138; all declared budgets respected |
| In-flight generation clear | Deliberate actual SQLite VM barrier; generation 0 → 1; old work did not repopulate index/summary caches |
| Pre-start / active cancellation | `CancellationError`, no content/partial content; active source fetch had produced 381 rows before cancellation; connection reused successfully |
| Queued cancellation | **4,484 ms** from cancel to `CancellationError` behind a natural large source decode; no artificial delay in that case |
| Side-cache LRU / payload budget | Retained 50 real line units / 16,638 estimated bytes; evicted oldest and retained newest; rejected the actual large unit estimated at 122,373,172 bytes |
| Prepared-statement LRU | 140 genuine read-only query variants; exactly 100 retained; an evicted query rebuilt and used the new binding correctly |
| Harness memory | 336,572,416-byte peak working set across 1,441 observations; includes harness, retained return values and output serialization |
| Preservation | All recorded input hashes unchanged after execution; complete DB SHA256 unchanged before/after; no WAL or SHM files created |

The active-cancellation clock recorded 0 ms at this Windows clock's resolution. This is not a zero-cost or sub-millisecond latency claim. Shared overlap means concurrent Reader requests, including calls waiting for the original connection lock; it does not mean one connection executed eight SQL statements simultaneously. No SQLite error, deadlock or output corruption occurred in this bounded run; that is not an exhaustive scheduling proof.

The optimized first attempt compiled no executable: Swift's later isolation checking rejected a non-Sendable test predicate sent from MainActor to the observation helper. Its earlier typecheck had passed. No runtime checks or content oracles are attributed to that failed attempt; its complete compile log, result and execution receipt are retained. The fix is the fixture's explicit `@Sendable` predicate, whose captured probes own their synchronization.

The independent oracle uses Python SQLite 3.45.3 and Python zstandard 0.23.0 / ZSTD 1.5.6. The original Swift SQLite boundary uses Windows SQLite 3.53.4, verified with `sqlite3_threadsafe() == 1`; native ZSTD identity is in the run result. Each output is matched against actual source row IDs, indices and references, and every HTML byte is compared to an independent dictionary decode. No full book text is committed.

## Acceptance decision

**The source-level correctness tranche passes; PERF-02 remains open.** The baseline demonstrates a real remaining cancellation-delay problem: an otherwise correct canceled request waits for an unrelated in-progress fetch to release `SQLiteDatabase`'s recursive lock. The observed 4.484-second wait was measured with the original implementation and no injected query pause. It is sufficient evidence to investigate a narrow cancellation-aware acquisition hook; it does not justify changing statement/decoder ownership or claiming main-thread/device performance.

The measured peak is an observed instrumented harness footprint, not proof of bounded application RSS. Likewise, the side cache's estimated payload cap does not bound the returned large chapter, text rendering, other caches, concurrent requests or process memory. No production optimization is included in this baseline commit.

Source review found that historical notes must not be read as current acceptance: `BookPageCache` currently accounts pages, not a 50-MB byte budget; the separate async repository connection lacks task-cancellation bridging and drains synchronously on close; several legacy bridge methods still hold its lock through SQL. These are documented source facts, separate from this harness's executed Reader checks. See `SOURCE_REVIEW.md` and `SOURCE_REVIEW.json` for implementation boundaries and exact hashes.

Still required through the existing application: rapid tab/backend/DB/unit swaps without stale publication; actual Inspector/search competition and main-thread scheduling; annotation-write and Sefaria parity; cancellation during database lifecycle changes; UIKit/TextKit rendering, responsiveness, memory warnings, scrolling and relaunch; long-lived process RSS and physical iPad measurements. This Windows harness does not close those gates. No broad pool, cache or UI rewrite was made from an unmeasured hypothesis.

## Reproduction

Run the existing driver with the pinned complete database and a new output directory:

```text
python tools/hq-full-source-reader.py --database <verified-full-v32.db> \
  --artifacts-dir <new-owned-directory> --optimization speed --stress-only
```

Use the recorded Swift 6.3.3 Windows toolchain/runtime, native SQLite/ZSTD dependencies and Python zstandard. The driver validates the DB size/hash before opening `mode=ro&immutable=1`, compiles original source, runs the bounded workload, verifies the source-byte oracle, and hashes the DB again. Do not substitute synthetic rows, a partial database, a generated decoder or a different source and retain this run's acceptance label.
