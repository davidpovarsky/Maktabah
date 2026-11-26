# Otzaria core acceptance on Scaleway Mac

The Oracle worktree started from `705097a9834736944261f79b087e6fbe39dbedbf`. The running app integration is bound separately to checkout `afb719bff27178b391638c94d6bdbd90ecd87f23`, application `59f48fa80884904f11c2fabaeca13c3a18241d6b`. The original worktree still contains independent MiniApps work. Component results below used Xcode 27.0 on the requested Mac and do not satisfy app-level or device gates.

## Full v40 source and installation component

- SeforimLibrary release `455390662`, tag `v40-20261123094345`. The 589-byte manifest, both official parts and the combined 2,129,902,636-byte archive matched the release digests. Archive SHA-256 `39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587`.
- Read-only SQLite `quick_check` returned `ok`. The database contains 8,259 books, 7,925,185 lines and 7,001,824 links. Size 4,355,063,808 bytes and SHA-256 `8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01`.
- The original installer upgraded an isolated copy of the verified full v32 database to v40. The v32 database stayed readable through extraction and validation and remained available as the rollback copy until activation. The original access controller opened v40, the committed manifest recorded the official archive identity, and the old copy and stage were removed. Extraction took 6.67 s and SQLite validation took 16.04 s. The installed database matched the v40 SHA-256. An earlier attempt with a read-only filesystem clone failed promotion. The successful rerun used a writable private clone matching the managed install permissions.
- Swift cancellation of an active, stalled `URLSession` stopped the candidate request. The unmodified downloader timed out waiting for the owned request to stop. An induced filesystem failure writing the pending manifest caused the candidate to restore both old data and old manifest bytes. The baseline had reported success with no usable new manifest. The focused controls compiled the production files on the Mac with explicit transport or app-bridge boundaries.
- Raw evidence under `/Users/m1/builds/otzaria-core-20261126` in `v40-fixture/V40_FIXTURE.json`, `bootstrap-cancel`, and `bootstrap-promotion/full-v40-upgrade-retry/run.log`.

## Reader and Inspector on the full corpus

- `RenderTests` passed exact display/mapping parity, Hebrew/Arabic/Unicode boundaries and cancellation before and during preprocessing. Source `00612813b5dda017a61f5a5b8c37efb10d750fbc`.
- Real SQLite/ZSTD Reader component results were 36 cold/warm cases and 18 previous/next descriptor checks from six v40 books, with exact warm content and UTF-16 anchor checks. A 52,332-row chapter still took 5.00 s cold and 7.40 s warm in this run. These are component timings with the OS file cache left intact.
- The original stress fixture passed 121 actual outputs across 113,474 row appearances. It exercised 96 shared reads, 24 independent reads and a genuine oversized unit, generation fences, cache bounds and cancellation. The active cancellation returned after 354 rows with no partial result. The queued cancellation took 12.40 ms while another real read was active.
- The original SQLite/ZSTD relationship and source-prefetch methods passed three v40 windows. Their 10,342, 8,319 and 4,603 ordered unique relationships matched the independent SQLite identity sets. The test exercised and checked snippet text for the first 100, 500 and 2,000 relationships in each window. The recorded first metadata calls took 183.78–537.61 ms. UI responsiveness and full-viewport behavior require native execution.
- Raw Apple results under `/Users/m1/builds/otzaria-core-20261126/full-reader` in `v40-acceptance/RESULT.json`, `v40-stress/RESULT.json`, and `v40-inspector-three-levels/RESULT.json`. The older stress and Inspector binaries label their status strings v32; the verified read-only URI and all SQL inputs in these executions point at the v40 fixture above.

The exact original full-v32 UI case configuration and Groups100 case configuration passed source admission against `afb719bf`. The original v32 corpus is available on the Mac, with the verified DB SHA-256 `2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765`. The source-only receipts are under `/Users/m1/builds/otzaria-core-20261126/native-binding`. Actual execution awaits the integrated app and qualified build receipts. The Settings update case, app v40 install and interruption/relaunch checks, and the device scenarios in `DEVICE_ACCEPTANCE.md` remain open.

## Hebrew highlight cost on a full v40 chapter

The Apple Swift 6 `-O` comparison used the same 52,332-row chapter, with 8,307,947 input UTF-16 units. Both variants returned the same ordered 49,065 ranges, SHA-256 `7523844d78a9c5e3fa21128a3cab2d141528d54b73163c0de75c301ae76cdf8f`. The original range loop took 10.23 and 10.40 s. Searching the normalized NSString with UTF-16 positions and a set for duplicate ranges took 1.77 and 1.80 s. A separate 30,000-range synthetic fixture retained identical exact offsets and decreased from about 656 ms to 69–71 ms. All 15 existing Unicode and source-position controls produced identical result bytes. These measurements cover Foundation search and range mapping, with UIKit and the physical iPad cases pending.

Raw Apple run logs are under `/Users/m1/builds/otzaria-core-20261126/highlight` in `benchmark-baseline-*.log`, `benchmark-utf16-*.log`, and `utf16-controls.json`.

## Full v40 Zayit pagination

The pinned Rust builder ran on Oracle over the verified v40 database. The index contains all 8,259 books, 7,920,224 lines with indexable chunks, and 7,930,286 documents. The builder skips lines without indexable chunks, so the line count differs from the total source rows. The original index metadata SHA-256 is `de424710eab0f4cdd87b0b8c909925cada16de4753e5faa97ed4f4374c658217`.

The real engine returned 50 results at offsets 0, 50 and 100 for `בראשית`, total 111,380 on each page. All 150 ordered identities were distinct. The test joined each line ID against the verified SQLite database and checked book ID, source line index and nonempty stable book identity. The raw query receipt has SHA-256 `6514d109e2c7415dcc7fc0c28c92504318fafcee89b236e60733ba4ef18f0994`. The test source is `Tests/HQ/search/ZayitFullCorpusPagination.rs`, based on the example target run in an isolated copy of the locked `Vendor/ZayitSearchPort/Rust` crate.

Oracle raw evidence under `/mnt/development/projects/worktrees/Maktabah-core-final-20261126/build/zayit-v40-source` includes `full-index.log`, `full-index.exit` and `pagination-150.json`. Packaging uses a separate index copy bound to the official remote manifest digest. The original builder output is preserved. The native search UI cases remain open.
