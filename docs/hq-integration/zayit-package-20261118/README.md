# Zayit package observation and active transfer protection

The same production Swift methods were exercised before and after the change against an independently downloaded, SHA256-verified official miniTest10-v6 Zayit package. The actual index bytes and manifest were not synthesized or relabelled.

## Reproduced defects and repairs

- Read-only status called orphan cleanup, deleting staging belonging to a suspended installation. Status and discovery now observe without creating directories or recovering/deleting files.
- Discovery could report ready from a manifest identity and directory alone. Both status and discovery now validate the declared contiguous output files, exact lengths, safe paths, bounded JSON metadata, index schema, source identity and document count.
- The unused URLSessionDataTask field never owned the async URLSession download. The service now admits one owned installation task, propagates explicit and caller cancellation to it, and rejects overlapping install/remove before touching files. Orphan recovery belongs to the admitted installation. Cancellation is checked again before promotion.

## Executed evidence

- Package status/discovery: baseline 5 PASS / 14 FAIL; repaired source 19 PASS / 0 FAIL with the identical Swift test fixture.
- Active HTTP transfer: baseline 2 PASS / 5 FAIL; repaired source 7 PASS / 0 FAIL with the identical Swift test fixture. A real loopback HTTP response remained held until after the cancellation assertion. Cancellation completed in about 46 ms on this Windows host. The original installed metadata survived; no second download or promotion occurred.
- The harness compiles exact production method bodies under Swift 6 strict concurrency. Real filesystem and Foundation URLSession are used. Provider discovery/DB compatibility/storage-lock/platform-capacity boundaries are explicit doubles; compression/checksum/promotion are not credited as exercised by the cancellation harness.
- These are component proofs, not a Native UI, real Tantivy query, full-production installation or physical-device acceptance claim. The current queued Native run uses the earlier immutable source and cannot be credited to this later fix.

The original search engines, schemas, provider release assets and installed user data are unchanged. All destructive fixture actions apply only to new owned copies under the continuation worktree build directory. The previous failed evidence is retained beside the passing evidence.
