# PERF-02 source review and acceptance boundaries

This review is bound to production source at `7d05dd0bb25a7df307b35174e49e18d0f22eecee`. The stress harness commit changes no production source. Historical Asana statements were checked against the current files before choosing the workload.

## Connection and decoder ownership

The Maktabah Reader path uses `OtzariaMaktabahBridge` → `OtzariaReadingUnitService` → `SQLiteDatabase`. The separate `OtzariaSQLiteConnection.read` queue used by `OtzariaAppContainer` repositories is not this Reader connection and is not substituted for it in these checks.

`SQLiteDatabase` opens the stress fixture with `SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX`, sets connection `query_only`, and configures a 5,000 ms SQLite busy timeout. Its `NSRecursiveLock` covers statement preparation, binding, stepping, row mapping and the original dictionary decode inside that mapping. `_fetchNoLock` resets and clears its statement on every exit and requires `SQLITE_DONE`; a failure cannot be accepted as a complete partial result. The shared prepared-statement LRU holds at most 100 statements. The SQLite busy timeout does not make waiting for the Swift lock cancellable.

The original `OtzariaLineContentDecoder` owns one `ZSTD_DCtx` and dictionary handles loaded from the actual `zstd_dict` table. The Reader's same-connection fetch lock serializes use of a shared cached decoder. Different Reader/connection owners create different decoder contexts. The decoder itself does not add an independent mutex; these results do not license arbitrary direct concurrent calls to one decoder. A concurrent `clearCaches` cannot release an in-use decoder because the read keeps its local strong reference. Compressed frames must advertise at most 16 MiB; unknown/error sizes, missing dictionaries, decompression failures and invalid UTF-8 produce errors. The TEXT branch does not enforce that frame bound. This is not a chapter or process memory limit.

`OtzariaReadingUnitService` checks task cancellation before work, at row mapping, during index/summary processing and while constructing anchors. It does not interrupt an active `sqlite3_step` or wake a thread blocked on `SQLiteDatabase`'s lock. The stress workload observes this distinction. A valid `CancellationError` without partial content is a correctness result; prompt cancellation and MainActor responsiveness remain separate acceptance questions.

## Current retention limits

| Component | Current implementation | Interpretation |
|---|---|---|
| Reader book indexes | At most 20 entries; aggregate cost at most 100,000 | Cost sums structure counts and UTF16 title units, not bytes or RSS. Over-budget indexes are used for the current request without being retained. |
| Reader summaries | At most 50 entries; aggregate cost at most 200,000 | Cost includes summaries, source indices and UTF16 title units. Cache generation is checked before publishing work started earlier. |
| Reading-unit side cache | LRU at most 50 units and 20 MiB estimated retained payload | Key includes generation/book/start/mode; hits check actual source-index membership. Oversized units can reach the Reader but are not retained. |
| SQLite statement cache | LRU at most 100 prepared statements | Eviction finalizes the previous handle. Each reused statement has bindings cleared/reset. |
| `BookPageCache` | Both caches configure `countLimit = 200`, `totalCostLimit = 5000`; cost is the retained dictionary's page count | The processed key includes `textHash`. The current file does **not** implement the historical Asana comment's 100-book/50-MB byte estimate. This cache is outside this portable Reader stress execution. |

Relevant files: `Source/Core/Database/SQLiteDatabase.swift`, `Source/Otzaria/Data/OtzariaBookSchemaCompatibility.swift`, `Source/Otzaria/Reading/OtzariaReadingUnitService.swift`, `Source/Otzaria/Reading/OtzariaMaktabahBridge+LineAnchors.swift`, `Source/Features/Reader/Cache/BookPageCache.swift`.

## Bridge and UI limits

`withReadingUnitService`, `withCachedReadingUnit` and `withDatabase` take a short bridge lock to retain the service/connection and generation, perform work outside that bridge lock, and validate generation before returning or publishing. This is more advanced than the task's original description of those methods. The original SQLite fetch lock remains separate and long-lived.

Other bridge methods still hold the bridge lock while doing SQL, including `fetchBook`, `fetchBookInfo`, `getTOCEntries` and the legacy `search` implementation. Their actual UI call paths were not run by this portable fixture. `OtzariaSQLiteConnection.read` uses a serial DispatchQueue and a continuation without a task-cancellation handler; `close` synchronously drains that queue. A claim that every repository/database lifecycle path is asynchronous and cancellation-aware would therefore be unsupported.

The portable tests do not execute `OtzariaAppContainer`, the bridge's UI lifecycle, Reader view models, Inspector loading, Sefaria, actual annotation writes, TextKit, native rendering, tab/window switching, UIKit memory warnings, or device interactions. Those gates remain open. They must be exercised through the existing application and canonical backend/scene ownership; this harness supplies no replacement application layer.

## Instrumentation boundaries

The existing full-source Reader driver compiles the actual SQLite/Reader/schema/decoder files. The stress mode compiles the original complete side-cache class as unchanged source text, normalized to UTF-8/LF, up to the app-bridge extension boundary; it does not compile or simulate that extension. Only existing logging/signpost boundaries are no-ops, and the unrelated legacy compressed-column helper continues to fail if accidentally invoked.

The stress fixture's unchecked-Sendable owner is test-only and deliberately sends calls to the original service so its own synchronization is exercised. No production conformance or isolation rule is changed. Cache reflection is read-only and occurs only after participating tasks join, except a deliberate cache clear through the original thread-safe public method while a SQLite progress barrier holds a worker. The barrier is disclosed as test coordination, not a measured UI delay. The queued-cancellation measurement adds no pause to the active source query.

Every returned source unit is checked for exact source-index/anchor correspondence and UTF16 anchor text. The Python oracle independently queries the same immutable full database, decodes actual dictionary frames with Python zstandard, and compares all returned HTML bytes. This covers the executed samples; it does not claim all 7,080,797 content rows were decoded. Working-set samples include the test harness and output serialization, and cannot establish an application or physical-device memory budget. No sanitizer or exhaustive scheduling proof is implied.
