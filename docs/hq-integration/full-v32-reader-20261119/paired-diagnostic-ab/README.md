# Paired timing after an inconsistent full-suite sample

The initial candidate full-suite run passed every original content/navigation oracle and exact baseline output comparison, but its largest-unit timings regressed to 13.055 s cold / 21.361 s warm. That result remains unchanged in candidate-speed/. In that run, the unchanged warm sourceLines stage alone took 11.150 s versus 0.610 s in baseline-speed. A subsequent host observation found 85% memory use and about 416 MB free disk. These observations are not a continuous profile and do not establish causality.

To resolve the timing concern, both implementations were compiled into one -O process and run against the same complete actual database. The archived baseline file is the exact original Git source with only its class/error-enum names changed to coexist with the production candidate; reversal of those two substitutions was verified byte for byte. The rest of the actual database/schema/ZSTD/Reader inputs are unchanged. The first round runs baseline then candidate; the second reverses the order. Each sample measures service-cache cold and warm reads of the same entire 110,196-row chapter. Each cold/warm pair asserts full original reading-unit equality. No full HTML or anchor JSON is written inside this timed loop.

| Round/order | Baseline cold (s) | Candidate cold (s) | Baseline warm (s) | Candidate warm (s) |
|---|---:|---:|---:|---:|
| 1 (A then B) | 8.411 | 4.317 | 7.082 | 4.493 |
| 2 (B then A) | 7.233 | 4.592 | 6.137 | 4.577 |

The candidate is faster in both orders for cold and warm service reads. The prior isolated profile measured 1.799-2.243 seconds just enumerating original grapheme counts for the log; explicit UTF8 byte-size reads measured below 0.002 ms at this timer resolution. These are scoped diagnostic samples, not p95, UI first-visible time, a representative Apple-device benchmark or a full PERF01 acceptance.

Before this diagnostic, only the three completed generated Reader fixture/output directories were losslessly NTFS-compressed to relieve storage pressure. All 243 file hashes remained exact. The original source database and production sources were not changed by compression. The receipt is in candidate-speed/STORAGE_COMPRESSION.json.

The complete original 36-unit/18-navigation full-source oracle and independent SQLite/ZSTD comparisons already passed on the candidate. COMPARISON.json verifies every unit ID, TOC identity, source-index list, UTF16 anchor and full HTML against the identical -O baseline. PERFORMANCE_DECISION.json accepts the narrow diagnostic logging change while keeping the full performance tasks open.
