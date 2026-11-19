# Full v32 Reader: identical-source compiler baselines, 19 November 2026

## Result and scope

Both runs passed the original full-source Reader checks: 36 cold/warm units, 18 navigation cases, and independent Python SQLite/ZSTD verification of 170,587 source-row appearances. The complete source database contains 7,876 books and 7,080,797 lines. These checks do not read every content row, run UIKit/TextKit, establish p95, measure first-visible latency, or certify a physical device.

Production source is unchanged at `6535d7bc5e3e38686efcf6db93112114dee2e917`. All 13 Swift input hashes and the driver hash match across runs. The only compiler-mode difference is explicit `-Onone` versus `-O`; both print the original Reader stage logs. Lower times in the second run are not attributed to a production code improvement.

| Case | Source-row appearances | -Onone cold / warm (s) | -O cold / warm (s) |
|---|---:|---:|---:|
| `5869-chapter-95380` | 110,196 | 17.625 / 13.655 | 7.145 / 6.586 |
| `6049-chapter-0` | 30,435 | 6.976 / 5.045 | 3.208 / 2.651 |
| `6050-chapter-45427` | 10,055 | 3.209 / 1.764 | 1.716 / 1.060 |
| `6050-chapter-0` | 10,703 | 3.227 / 1.715 | 1.634 / 1.328 |
| `6049-chapter-68098` | 7,519 | 3.053 / 1.009 | 1.331 / 0.902 |

Cold means the service caches were cleared. OS/disk caches were not flushed. Measurements were sequential on the same Windows host, same SHA-pinned database and same NTFS-compressed file. These are individual samples, not distribution or Apple-device claims.

## Source and restoration

Official source: `Otzaria/SeforimLibrary`, release `v32-20261010190601`, release ID `409213893`, asset ID `629048655` (`seforim-schema6.db.zst`). The archive was independently verified at 1,850,679,582 bytes / SHA256 `6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44`. The restored database is 3,821,240,320 bytes / SHA256 `2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765`.

Two restoration attempts stopped at the free-space guard; their failure receipts are preserved in `source/`. Recovery compared every byte of the retained prefix against the validated archive, verified the complete stream and its 331,579,392-byte tail, removed only the owned reproducible archive cache, appended the verified tail, and independently hashed the entire final file. Only the completed database was admitted to the Reader checks. Final database hashes are unchanged before and after both runs. No installed user database, WAL or SHM was touched. A separate receipt records removal of the owned, reproducible SDK compiler ModuleCache; SDK source and proof ZIP were preserved and hash-checked.

The verified database currently resides at `build/full-v32-performance-20261119/seforim.db`. Full raw book content remains in owned build fixtures and is not committed with these reports.

## Measurement evidence

- `baseline-none/RESULT.json`, `compile.log`, `tests.log`, `STAGE_REVIEW.json`: explicit `-Onone` run.
- `baseline-speed/RESULT.json`, `compile.log`, `tests.log`, `STAGE_REVIEW.json`: explicit `-O` run.
- `source/MANIFEST.json` and raw restoration/storage receipts: source provenance and recovery history.

Each result records the exact compiler command, toolchain, SQLite/ZSTD implementation, all input hashes, database pin, original test results and independent content oracle. Compile and execute exit codes are zero.

For the 110,196-row chapter with `-O`, the original cold stage log records 297 ms for summaries (including the nested 182 ms book index), 694 ms for source lines, and 7,145 ms total. Warm records 610 ms for source lines and 6,585 ms total. The remaining time includes materialization, normalization, UTF16 anchors and diagnostic grapheme counts. It has not been attributed solely to normalization. The nested book-index duration must not be added a second time.

## Reproduction

From the repository root, use the original `tools/hq-full-source-reader.py` with the pinned complete database, a new artifacts directory, `--optimization none` or `--optimization speed`, and `--log-stages`. The Windows runtime must provide the actual SQLite/ZSTD dependencies and Python `zstandard`. Do not accept a partial database or replace the 36 content / 18 navigation oracles with generated text.

PERF01, PERF03 and full installed-index/device acceptance remain open. These reports supply a reproducible baseline for a separately measured source change.
