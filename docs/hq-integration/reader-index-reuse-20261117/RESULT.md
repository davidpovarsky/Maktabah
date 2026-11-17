# Oversized reading index reuse — 2026-11-17

The paragraph/chapter callers already load the current book metadata index.
When its cost exceeds the existing retention budget, loading it again inside
tocSummaries performs a second complete metadata query. Pass the caller's same
immutable BookIndex into that function. Cache budgets, line ordering, chapter
identity, decoding, cancellation and fallback behavior remain unchanged.

## Executed evidence

The new assertions first FAILED on the original production source:
oversized paragraph and chapter each queried the metadata index twice.
With the production correction, the same suite compiled and PASSED in
12.798 seconds on Windows Swift 6.3.3. It also retained the existing sparse
10,000-line checks: four selected metadata rows across seven requests, no
content fetch or whole-book summary retention.

Command: python tools/hq-reader-checks.py --suite service --artifacts-dir <evidence>/reader-index-reuse/green

The harness compiles the actual production service with explicit SQLite and
decoder doubles. This is a regression proof, not native rendering or physical
device performance acceptance. RED/GREEN logs, source hashes and summary are
retained in the canonical phase evidence directory.

A separate read-only audit of the retained v32 database (SHA256
2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765)
found 7,080,797 lines and a 190,760-line largest book. Its full quick_check passed
and its before/after SHA256 matched. That audit explains why oversized metadata
is a real workload; it does not substitute for this Swift regression or the
required native full-database run. SQLite PRAGMA user_version is 0; the release's
schema version label must not be confused with this observed pragma.
