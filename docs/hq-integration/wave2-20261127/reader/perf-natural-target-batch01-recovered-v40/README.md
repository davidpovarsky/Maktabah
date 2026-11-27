# Natural Inspector target discovery — bounded batch 01

This metadata-only batch completed with exit 0 in 18.37942755036056 seconds. All 40 selected base books completed; none reached a resource bound. It examined 887 complete natural Chapter candidates and 1023152 resolved anchor rows. The process's observed maximum resident memory was 64524288 bytes (Linux discovery process only, not app/PERF evidence).

One exact raw-unit-cache candidate has 500 relationships:

- Book 6, יהושע, raw unit title פרק ו.
- Chapter ID `toc:199`; exact source indices 104 through 131, 28 source rows.
- Source-index SHA256 `213cc336087603499e5b2d4a87c61688b44ae6b0aca47a1ce02532e398cbf152`.
- Full raw relationship membership SHA256 `16c0e819068590b1f97d9d3d76c8a6c912c2c8dab066e16c9311077df0e0e83d`.
- The full 500-member id/book/line set is retained in the original discovery JSON, without truncating a larger set.

No exact 100 or 2000 candidate was found in this batch. Those targets remain unresolved. Original Swift unit membership and adapter/cache cardinality, followed by actual native UI, must independently verify any selected candidate before it can close acceptance.

## Exact semantics and resource scope

The selection is the first 40 actual `isBaseBook=1` books, ordered by ID, with 100–10000 declared source lines, an actual TOC, and excluding the previously inspected 103/28/3152. The observed final selected ID is 80. This is a bounded subset of the full restored corpus, not a full-corpus exhaustive claim.

The original `OtzariaReadingUnitService` ordered line/TOC mappings, deepest level, held root headings, Chapter grouping and fallback lines guide exact source membership. Original `OtzariaLineSourcesService` uses both matched sides, coverage, per-side suppression and the id/linkedBookId/linkedLineId dedup key. The original unit Inspector adapter calls `getLinksMetadataForReadingUnit`, maps the complete array and caches that complete mapped array. Its generic single-line provider's additional locator/type/category dedup belongs to another route and is not substituted here. Cyclic/invalid or incomplete books would have been excluded entirely.

The authorized limits were 40 books, 20 seconds per book, 300 seconds total, 500000 rows per book, 3000000 rows total and 6000 units. A 512 MiB process virtual-memory guard additionally bounds the read-only discovery. The one connection uses `mode=ro&immutable=1`, query-only mode, an 8 MiB page cache and in-memory temporary data. No content decoding, full-file hash, global count scan, reindex or DB write occurred. Before/after file identity matches the independently verified recovered inode 5946339 on dev 2064; mode remains 0444. This does not claim continuity with the old missing inode or in-app installation.

## Original receipts

- `DISCOVERY.json`: 1000741 bytes; SHA256 `efd18aad0afa12b31355c5b449bc96cec3c2a0249bfa48e6286935859a73c01e`.
- Exact batch script SHA256 `413ff1e85767b371604acb0fbec6b45525802b0cc5ab0b229c03936431e1697e`.
- `SELECTED_BOOKS.json`, `selection.sql`, `relationships.sql`, all 40 `book-*.json` records, `RUN_RESULT.json` and the original `stdout.log` are retained.
- The script source binds commit `defb38bb159fbb156212169534a5ef75d01932bd` and verifies all four guide-source hashes against the earlier three-book receipt.

There was one actual batch process, launcher PID 3339408. It completed normally; no next batch was started.
