# Independent evidence-join review: study phase composition

Reviewed `2c23de7138c002cfa4476c40303d4d6973b4b6d5`, restricted to the published provenance and receipt joins under `docs/hq-integration/wave2-20261127/reader/study-phase-composition`. No controller was edited and no test or native run was repeated by this reviewer.

`ROOT_RESULT.json` is 15,964 bytes, SHA256 `17c9a0f8e75c3ce40a9f5ba9a8b37666b462c26e2fb926c2ac9eb0d810c9f83d`. All 34 referenced root evidence files matched their stored byte lengths and digests. The declared source tree is `7d87a5e03b9e4661bbcbc5df9f4bd957a837c7a1`.

Four `SOURCE_TRANSFER` entries join the exact before blobs at `81b54a5ed333b23b0e19ccf3efa346b2d8861a91` to the after blobs at `2c23de71`: the production UI driver, Reader v40 input profile, pending-execution controller and prerequisite controller. Ten local-control inputs agree across the declared before/after records and the immutable source. Seven syntax input pins and both materialized-HEAD inputs also matched.

The actual retained local logs show 22 and 23 controls passing, respectively, with exit0. They exercise synthetic process, kernel, device and UI boundaries and small genuine receipt files. The logs report 0.069s and 0.074s; they are not full device workloads. The original Oracle offline-Zayit and Reader pending-SQL checks have their exact successful raw logs bound to the 09:35:45 run.

The original `Build8401SevenDefectsAcceptanceTests.swift` prefix is preserved byte-for-byte: 102,598 bytes, SHA256 `ca66d554b22f340366f0a68a7d3e43a4210eb143cbe2550fcdbabbead768b53c`. The reviewed file has 142,688 bytes, including 40,090 additive bytes. Existing assertions are not removed by that append.

No mismatch was found in these provenance joins. This conclusion does not approve every controller lifecycle branch. The separately reported pre-spawn process-ledger and reaped-leader signal-fence findings remain independent semantic issues for the controller owner and root to resolve.

The source receipts explicitly retain Apple/native/corpus execution at zero and the full profile as unfrozen. These controls cannot establish live OS signal ownership, actual offline intervals, RSS or latency budgets, production row counts, or final paired acceptance. Final profiles must be bound to the finalized source and app through the original driver before original native acceptance.

`study-phase/INDEPENDENT_EVIDENCE_JOINS.json.gz` preserves the actual read-only check result. Its stored and uncompressed digests appear in the accompanying review manifest.
