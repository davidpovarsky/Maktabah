# SQLite correctness — actual failure reproduction, proposed fix blocked

The original complete SQLiteDatabase.swift compiled with Swift6.3.3 and ran against installed Windows SQLite3.53.4. It returned success for actual step errors, interruption, writer lock, invalidated cached schema and out-of-range bindings. A read error also allowed the owned fixture transaction to commit.21 named cases:9 passed,12 failed; the later concurrent-read failure is a consequence of that incorrectly committed row, not an independently established concurrency defect.

All failure injections use new UUID-owned disposable fixture databases. One genuine miniTest10 read was opened read-only and immutable and matched independent source identity. No live user database was modified. An unrelated ZSTD compiler-only boundary aborts if invoked, and was never invoked. These are actual SQLite checks, not app/UI/device acceptance.

The automatic approval reviewer rejected applying the two upstream-owned hunks because the repository requires exact file/hunk owner approval. The current broad phase authorization was not accepted for this change. The upstream file and exception register remain unmodified. PENDING_OWNER_SQLITE_ERROR_PROPAGATION.diff is a proposal only. It returns the existing typed errors when step does not finish with SQLITE_DONE or a binding does not return SQLITE_OK. Existing successful rows/order/zero and transaction/cache policy remain. No database library, schema, or provider change.

A wrapper cannot recover errors already swallowed in private methods; copying a second database engine was rejected. Exact patch hash, provenance, test evidence, required approval and rollback are in PENDING_OWNER_REVIEW.json. The correct response remains OPEN until the actual approved implementation and its tests pass.

## 2026-11-18 — reviewed proposal applied

After the concrete two-hunk proposal was presented, the owner instructed continuation; the exact diff was accepted and applied. The owner subsequently explicitly authorized all required changes/builds/uploads. Historical rejection and proposal records remain intact. APPLIED_REVIEW.json records these instructions without claiming a different exact quotation. The identical21 real-SQLite regression cases now pass (baseline9 pass/12 fail), including original miniTest10 read-only identity. ACTUAL_SQLITE_AFTER.json contains actual evidence. Apple macOS SQLite repetition is added to the existing SDK gate; Native/full-database/device acceptance remains open.
