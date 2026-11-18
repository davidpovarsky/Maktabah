# Full v32 original Reader and exact normalization parity

The existing original Swift Reader, SQLite wrapper and native ZSTD dictionary decoder executed against the SHA-pinned official full v32 database (7,080,797 lines). This is source-service evidence on Windows, not Apple/UI/device acceptance.

## Source and boundaries

Baseline checkout: 470f7c78db2d6886a46da5c09cfce50c89b9994a.
Only production change: `Source/Otzaria/Core/String+OtzariaText.swift`, SHA256 `cedfea7dfaa72bab082831282bd90fd003aff487d6736a340f9d9b51176e3323`. Its existing HTML/entity/whitespace operations now run only when the corresponding ASCII trigger is present; transformation order, Unicode behavior, content, grouping, IDs and cache budgets are preserved. The file is downstream-only (absent from the checked official upstream d46af139b3a265399c16d87f5923acd8e3444024).

The entire original SQLite wrapper, original schema/capability compatibility and dictionary decoder, original ReadingUnitService, units and anchors were compiled. Existing native Git-for-Windows ZSTD 1.5.7 and actual Windows SQLite3.53.4 were used. Only logging/signpost methods are no-ops; the unused legacy compressed-column API fails if called. No database substitute or Python query boundary is used by the Swift Reader.

## Results

- Same 36 cold/warm units and 18 navigation checks passed before and after.
- Six real books include the three books with the greatest actual line counts.
- 170,587 source-row appearances independently matched original SQLite IDs, indices, heRefs and full decoded HTML, using Python SQLite/zstandard as a separate oracle.
- All 36 before/after unit IDs, TOC IDs, source indices, anchors, UTF16 ranges and full HTML bytes are identical.
- All 174,789 genuine content/TOC strings and 11 Unicode/HTML/entity-order edge cases exactly match the unchanged baseline normalizer; full output SHA256 `e05f364b25715166093a0b32a49bfa26690359d086f9bee7c14538aa59515170`.
- Full database SHA256 `2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765` is unchanged before/after every completed run.
- Original test fixture and driver checks remain identical between Reader runs; input source hashes and raw results are included.

## Performance observation, not product acceptance

One timing pass, unoptimized Swift6.3.3 Windows, without UIKit/TextKit or frame/CPU/memory profiling.
For the 110,196-row chapter, cold 47154.13ms -> 16391.68ms; warm 43416.07ms -> 17448.70ms.
Standalone exact text comparison: baseline 90291.14ms; current 15461.33ms.
These remain single observations, not p50/p95, and large chapters still need actual UI/device performance acceptance. Full-book metadata and complete chapter materialization remain observable costs; no source truncation or cache-budget increase was used.

The earlier three-pass normalization attempt hit its 300-second execution ceiling and is retained as INCOMPLETE_TIMEOUT_NO_PASS. The completed one-pass comparison retained every genuine string and every edge-case oracle. It is not counted as three passes.

## Reproduction

`py -3 -X utf8 tools/hq-full-source-reader.py --database <owned-full-v32-copy> --artifacts-dir <new-directory>`

`py -3 -X utf8 tools/hq-reader-plaintext-parity.py --database <same-copy> --reader-baseline-report <BEFORE.json-with-retained-owned-fixture> --baseline-source 470f7c78db2d6886a46da5c09cfce50c89b9994a --artifacts-dir <new-directory>`

The full raw owned fixtures remain under build and contain source text; they are not committed. Committed receipts contain digests, provenance and timings. No user database was altered. UI, real-device and full release gates remain open.
