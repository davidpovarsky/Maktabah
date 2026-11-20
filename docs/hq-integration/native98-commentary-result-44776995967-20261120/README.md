# Verified historical Commentary evidence extraction

The evidence-only processor succeeded in run [44776995967](https://github.com/davidpovarsky/Maktabah/actions/runs/44776995967), attempt 1, job 136429340664, at source `d749a2222ff06ae723d14bb174ead19331004e91` / tree `b93fe8b365e93840b6e84234c8a16a75340de66d`. Job ran 16:48:13–16:48:35 UTC on 2026-11-20. All 40 synthetic Python controls actually passed on its Linux runner.

## What was verified

CI downloaded all 775,094,118 bytes of original artifact 14632274701, checked SHA-256 `7ce28dc10dbdfb6a52fe15e0eb0ec4bfaef746f8165974d060367cf61594a69d` before and after reading, and checked CRC/SHA records for all 3,686 members. It retained exactly the three originally mapped capture files, with no basename fallback or image editing. Original run 44723902453, attempt 1, F60/M87 and original job remain **cancelled**; original upload step 17 was **success**. Cancellation actor/cause remains unknown.

Root independently downloaded the small output artifact 14650267648, verified all 683,830 bytes against SHA-256 `f2772aa98ca34e31029eecd6b7e3f7a1ff5681c46ab09718d448167ca3b094bf`, all 16 ZIP CRCs, exact four processor inputs against the actual Git tree, before/after metadata using the unchanged original validator, and selected payload bytes against the complete archive receipt. Root did not separately download the large original ZIP.

## Captures and limits

The untouched screenshot visibly contains an **Unable to open link** alert and an empty detail surface with a Tehillim tab chip. The separately captured AX hierarchy contains a Sefer Hachinuch header and a `reader-text` node. These captures must not be assumed simultaneous. The independent metadata attachment confirms the installed canonical fixture SHA-256 `c6ca39044f6a62728f8f7e40e86d4080c89dc8927ced5ae6d724079efb5f896b`. These observations narrow the reader/routing investigation; they do not prove a specific root cause or Commentary action success. The original failed predicate occurred in reader setup before the Commentary action was called.

This processor executed **0 Native tests, 0 application tests and 0 Commentary actions**. It changed no product or original test source, original run, assertion, timeout or acceptance status.

## Replay

Run `python3 docs/hq-integration/native98-commentary-result-44776995967-20261120/VERIFY_PACKET.py --root .` in this source tree. It rechecks retained results and provenance only and performs no network or Native execution. The original source ZIP is not committed. Signed download URLs and tokens are excluded. The first Root review attempt compared input lists in differing path order; the exact same records were subsequently checked by unique path with all fields intact. Its projection error is retained under raw and did not change the original processor result.
