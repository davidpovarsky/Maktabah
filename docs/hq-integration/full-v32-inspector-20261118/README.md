# Full v32 original Inspector source acceptance

Original source at 85d41aa08d73f1b83f5939d45cd0d793be694b90; no product code changed for this proof.
Actual SQLite 3.53.4, native ZSTD 1.5.7, Swift6.3.3 Windows, strict concurrency.

## Executed scope

The original relationship service, SQLite wrapper, schema and dictionary decoder, source model, category-path resolver, classifier and grouping logic execute over the actual readonly v32 database. The service's sole framework import is omitted and its two data-only boundary DTOs are provided by the harness. The host bridge injects the actual readonly SQLiteDatabase; this does not test original app connection ownership. Telemetry/logging are no-ops. The unused legacy compressed-column helper fails if called.

Three real source windows:
- Berakhot first500 actual lines:10361 relationships.
- Berakhot401 sparse actual indices:8247 relationships.
- Tehillim first100 actual lines:4608 relationships.

All23216 relationship appearances exactly match an independent Python set-based oracle for forward/inverse links, ranges and side suppression. Every resulting original lineID/bookID/lineIndex/heRef/category path/book title/order and full decoded content is checked using separate Python SQLite/zstandard reads. Grouping preserves book identity and all results.

Actual SQLite tracing proves metadata queries use exact400-line chunks (2/2/1 statements), exclude content joins and dictionary reads. All six500/2000relationship prefetch cases produce the same original text at every requested identity, with one query per book/chunk instead of per result. Cancellation before admission executes zero SQL.

Database SHA256 2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765 is unchanged before/after. Original full data and raw outputs remain in owned build fixtures; public receipts contain provenance/hashes/timings, not book contents.

## Honest limits and retained failure

This is source-service evidence, not UIKit, TorahInspectorCore UI, MainActor composition, real-device, p95 or release acceptance. All host timings are single unoptimized observations. The task remains open for actual UI/cancel/back/state/note/VoiceOver and device checks.

The initial harness failed at NSDictionary.isEqual(to:). A separate actual Windows Foundation reproduction returns false even when comparing a dictionary to itself. The fixture now compares canonical JSON bytes, retaining every same field and exact array order. Initial failure, unchanged production hashes and the isolated reproduction are retained; no product bug or product fix is inferred from that harness issue.

## Reproduce

`py -3 -X utf8 tools/hq-full-source-inspector.py --database <owned-official-v32-copy> --artifacts-dir <new-directory>`
