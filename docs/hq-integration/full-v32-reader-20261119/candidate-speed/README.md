# First full candidate run: content PASS, timing regression retained

Candidate 7b2b6a1a7067496be2a2e2f232cf91f9cd8e2478 changes only two diagnostic log-size expressions in OtzariaReadingUnitService. The original normalizer and original test oracles are unchanged.

All 36 cold/warm units and 18 navigation cases passed against the complete SHA-pinned v32 database. Independent Python SQLite/ZSTD checked 170,587 source-row appearances. Every baseline unit record excluding timing is identical, including IDs, TOC, all source indices and UTF16 anchors; every full HTML file has the same SHA256. Database hashes are unchanged before/after.

The initial timing comparison was unfavorable: the 110,196-row chapter measured 13.055 s cold / 21.361 s warm, compared with 7.145 / 6.586 s in the earlier identical-compiler baseline. This result was not discarded or relabelled. The unchanged warm sourceLines stage increased from 0.610 to 11.150 s. HOST_OBSERVATION.json records the later resource observation without claiming a proven cause.

A separate AB/BA same-process diagnostic subsequently reduced the comparison's sensitivity to host changes. Its actual results and limited acceptance decision are in ../paired-diagnostic-ab/ and ../PERFORMANCE_DECISION.json. No Native/physical/p95/first-visible acceptance is claimed here.
