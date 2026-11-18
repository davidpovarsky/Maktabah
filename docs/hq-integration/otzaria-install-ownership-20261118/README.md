# Otzaria index installation ownership and cancellation

Baseline: dcdf1ebe044f2c3ba268111c88ddae235772c1bb.
These are source/control regressions, not the 27 Native acceptance cases.

## Product changes

The original artifact service admits one install operation, propagates cancellation to its owned task, and lets status recovery await that owner instead of deleting active staging. Availability observation no longer deletes partial downloads. Streaming capacity is recalculated after the admitted operation prepares its workspace.

The original URLSession delegate cancels the exact request when the Swift caller is cancelled and retains terminal completion even if it arrives before continuation registration. Delegate callbacks retain the existing serial queue; the cross-thread completion state uses a lock.

The installer freezes the admitted destination, validates the original service profile/database fingerprint across asynchronous downloads and immediately before promotion, and closes opened engines on count errors before rollback. Existing manifest, checksum, extraction, compatibility and document-count validation remains in place.

## Executed evidence

| Scope | Same baseline assertions | Corrected assertions |
| --- | --- | --- |
| Original service / controlled transfer / actual filesystem | 4 PASS, 4 FAIL | 8 PASS |
| Original delegate / actual held HTTP plus explicit ordering injection | 1 PASS, 5 FAIL | 6 PASS |
| Whole original installer / actual file moves / injected dependency failures | 20 PASS, 7 FAIL | 27 PASS |
| Existing full VM / repository regression harness | Existing baseline proof retained elsewhere | 191 + 14 PASS |

Actual held HTTP cancellation completed in approximately 35 ms before any response body was released. Terminal-before-registration is an explicitly injected ordering case. The same six oracles were used before and after. The downloader comparison runs Windows FoundationNetworking in Swift 5 language mode; service and installer checks use Swift 6 strict concurrency. They do not replace the Apple app build.

The installer regressions expose replacement of the unrelated profile destination and acceptance after a database fingerprint change in the baseline. Corrected code aborts before extraction, preserves both original fixture directories, and closes every opened engine on injected count failures. Archive extraction, database fingerprint source, and the engine are named test doubles: no real index/search result is claimed.

The official unmodified otzaria-miniTest10-v6 manifest is committed as metadata only, with its verified SHA-256 pinned by the drivers. No payload was downloaded for these checks and no user index/database was touched. The first ownership harness attempt failed to compile because of an optional fixture value; that attempt remains in canonical evidence, and the corrected harness executed both baseline and corrected source without changing assertions.

All raw logs and result JSON remain in the canonical evidence directory. Repository log copies normalize trailing whitespace only; REVIEW.json records both raw and copied hashes. Native multiwindow, real index installation/query, device, and release acceptance remain open.
