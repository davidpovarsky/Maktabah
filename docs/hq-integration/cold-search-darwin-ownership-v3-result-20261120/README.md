# Actual Darwin ownership gate — 32/32 PASS

Run [44772413131](https://github.com/davidpovarsky/Maktabah/actions/runs/44772413131), attempt 1, executed immutable source `8ad0dd4e0ca69d347ef0a4c200189665941b751d`. Job `136413226417` completed successfully at 16:22:25 UTC on 20 November 2026. All **32 unique candidate cases passed**, with normal exit 0 and no skipped or missing case. The separate pre-guard case produced exactly `stale_constructor_performed_more_native_work`, exit 1, and qualified as the intended regression RED. Both Swift compilations exited 0 without compiler diagnostics. Eight original Python qualifier controls also passed on the Apple runner.

The selected toolchain was Xcode 27.2 build 27B52, Apple Swift 6.4.2, arm64 macOS. Candidate execution took 2.102264625 seconds; this is the component suite duration, not application or corpus performance.

## What actually ran

The original whole Repository/Bridge/model inputs and source-extracted storage locks ran with actual Apple Foundation, filesystem, synchronization and cross-process `flock`. The native constructor and metadata boundary are explicit doubles. The driver records **zero real C/Rust-engine executions and zero Native UI executions**. The positive cold-open/cache path, lock-order release, recursive ownership, cancellation/deadline, generation/ABA/profile refusal and post-constructor publication guards all retain their original assertions.

The v3 missing-index case supplied the manager's actual missing-path URL before invocation. It observed `filesystem_or_boundary_error`, one of the unchanged allowed refusals, and passed the original no-directory-creation/no-native-open/cache assertions. The original product's exact URL identity check was not relaxed. Actual metadata also confirms the earlier before/after directory-hint mismatch and the second-attempt cache barrier with all three outer storage owners released.

The earlier runs remain failures: run44765987116 completed18PASS/14FAIL with an unqualified baseline cause; run44770208643 completed31PASS/1FAIL with a qualified baseline RED. Their complete artifacts and source-specific explanations remain in the frozen ancestor commits. No rerun overwrote either source or result.

## Independent evidence verification

Artifact `14647278403` is retained in full: **1,226,088 bytes**, SHA-256 `8e900dd588e592636635dd9ee1ab3ab0a405bcf6c243aefb25ca9eab96f2c5c2`. Root verified all253 ZIP members and CRCs, matched every extracted byte, bound all16 source-archive inputs to actual Git tree `954cd239731026797b8d48ded22f3f3f879ec632`, checked original and generated source hashes before/after, and reran the unchanged result qualifier over the authentic raw cases/process records. This review executed no additional Swift or Native tests.

`GITHUB_RECEIPTS.json.gz`, the complete Git tree, raw job log, original artifact, `ROOT_REPLAY.py` and source proof make the verification reproducible. The first local review projection incorrectly compared a comma-separated allowed refusal set as one string; its script/report are retained under `raw/review-projection-initial`. The corrected projection tests membership in the allowed set. Both the original acceptance qualifier and all actual test results were unchanged.

Run `python3 docs/hq-integration/cold-search-darwin-ownership-v3-result-20261120/VERIFY_PACKET.py` to verify this packet in an isolated temporary directory. It makes no network call and does not compile or run tests.

## Integration scope

The separate Core run44765478132 executed194/194 cases on798d3186, including the ten-line UTF16 boundary correction. Its full result is retained in commit3e42ad49. These are different suites and are not combined into a Native count.

The prepared Root merge overlays the exact Core source and ownership fixtures/evidence onto `dfa3fdd1e788fa74e89782f6dd189a3f9a63676d`. All ten modified product files at that Root still equal their common19b68 originals; all added paths are disjoint. The retained merge proof documents that comparison. The subsequent integration commit must still pass the original full-application, actual-engine and Native gates. This packet grants no Release, TestFlight, physical-device or complete task acceptance.
