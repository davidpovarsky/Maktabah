# BookPageCache bounded payload retention

The original cache priced every page as one unit, regardless of its text or
rendered metadata. The same public-API fixture compiled and executed against
baseline bd5142ca5da7c7fe6b658dba2323ac0b463b6672 and this production source:
baseline 16 PASS / 10 FAIL; candidate 26 PASS / 0 FAIL. These are Windows
Swift 6.3.3 component executions, with the actual NSCache, Mutex and data models.

## Production change

Both original caches remain NSCache. Each has a 32 MiB retained-payload estimate
budget, at most 200 books and 5,000 entries. Since NSCache cost limits are advisory,
a separate book LRU/cost ledger enforces those accounting limits after insertion.
It stores only identities and costs, never payload references. Autonomous cache
purges can cause conservative over-accounting; a miss or subsequent write to the
purged book removes that stale account. No delegate callback reenters the Mutex.

Cost includes source/display strings, reference and locator strings, all four
range arrays, replacement events and both delta arrays. Arithmetic saturates on
overflow, so an unrepresentable cost is rejected. Existing render flags and the
already-present textHash stay in the processed key. An oversized replacement
evicts that disposable book entry, preventing stale content at the same identity.
Eviction changes no source data, original Reader, renderer, database or engine.
Per-book/global removal clears both stores and their ledgers; the original iOS
memory-warning hook still calls the same global removal method.

The estimate includes UTF-8 plus possible UTF-16 representation and array-growth/
entry allowances. It is not an allocator accounting API or a hard process-RSS
ceiling. Caller-held values, concurrent rendering, Foundation overhead and
transient allocation remain outside this cache-retention bound. Estimation runs
before taking the cache mutex on the calling thread; no MainActor responsiveness
or physical performance improvement is claimed. No database generation/epoch
publication API is changed by this tranche.

## Actual evidence

The identical 26-case fixture checks lossless raw metadata and rendered fields,
16 render-key variants, book isolation, replacements, large text/reference/
locator/range/event payloads, aggregate retention across and within books,
original book/page limits, clear and weak-value release, capacity reuse, and
4,000 concurrent read/write/remove iterations (eight workers, 500 each).
Iterations are one concurrency case, not 4,000 independent acceptance passes.
NSCache is permitted to evict values; a miss is not treated as wrong content.

RESULT JSON files bind complete input bytes and the generated source. Raw logs
are compressed without text rewriting. OSLog is an explicit no-op boundary on
Windows; UIKit/memory-pressure notification delivery is not simulated. Only the
unchanged model declarations needed by this isolated fixture are extracted from
the original source, never replaced by alternate data or a cache implementation.

An independent source review found no blocking accounting/ownership defect;
it contributes zero additional executed tests. The same driver is added to the
existing Apple SDK source-regression aggregate and receives the existing
--artifacts-dir option as an alias for --out. Those two CI/CLI wiring changes
received Python AST checks after the recorded Windows run; Apple execution and
app Native/physical/RSS acceptance remain NOT_RUN at this commit.
