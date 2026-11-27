# Final first-page Search guard handoff

This is the final delivery record. `README.md`, `PRESERVATION.json`, `SOURCE.patch`, `candidate.swift`, `RESULT.json` and `oracle-syntax/` are retained unchanged as evidence of the **superseded, uncommitted** first attempt with source SHA256 `70d64d593d22dbfb512b74bd8d6ed9d259c9404b8a47072ced30f5bc18d989a2`. They do not validate the final source. `FINDINGS.md` retains the original source trace and its initial correction proposal; the narrower final implementation below supersedes that proposal while addressing the same gap.

## Final implementation

Base: `15d283aa0ccbbfe6966f26a2c182810cb39fdafa`.

Only `MaktabahNativeSearchResultsBinding` in `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneBindings.swift` changes:

1. Add `session.paginationRevision == initialPagination` to the existing post-submission query guard. The original common guard and pre-submission branch remain byte-for-byte unchanged. Both phases therefore require the captured revision while preserving the pre-submission refusal code and guard priority. A post-submission pagination mismatch uses the existing `native_search_query_changed` error.
2. Require `!session.isLoadingMore` in `validateCompleted()`, with its existing `native_search_results_not_ready` error.

No other function or production file changes. This is a two-hunk source patch, with no new provider, resubmission, state reset or continuation API. Existing scene/source/receipt authority remains in its original owners.

| Final artifact | Exact identity |
| --- | --- |
| `candidate-final.swift` and the production file | 36,861 bytes; SHA256 `b18518dbf450cf5e923632df17f660169bca3e86b029790645da1f5aaf69e81f` |
| `SOURCE_FINAL.patch` | SHA256 `e71a9e963dcf8efa4d3b529e71f48daf75fcc78111c73c6e2def835246e7dc25` |
| `PRESERVATION_FINAL.json` | Verifies unchanged common/pre-submit guards and reversal of exactly two textual replacements to reproduce the complete baseline. |
| `oracle-syntax-final/RESULT.json` | Actual final-source parse at `2026-11-27 10:08:13 UTC`, exit 0; source hash and compiler hash are recorded. |
| `FINAL_RESULT.json` | Final artifact witnesses, exact production diff scope and verification limits. |

## Validation and attribution

The actual final syntax run used the installed Linux ELF Swift frontend 6.4.3, SHA256 `d98470fed50d4efc0075bcbd45ba1f908382dc9222c2b8213d1ff074efaa2083`, with `-parse -parse-as-library -swift-version 6 -target arm64-apple-ios27.0-simulator`. It supplied no SDK and created no app or package build. The earlier 10:02:55 parse is retained solely for its different first-attempt bytes.

The 20 retained original source files and their exact Git blobs/SHA256 values remain the evidence for the complete call-chain review. Actual upstream provenance and the root/Wave3 reservation remain in `PROVENANCE.json`. Existing Core fixture assertions were inspected for scope and were not rerun or credited as app-binding validation.

Original app-binding behavioral tests, Apple SDK typechecking and native/UI acceptance are **NOT_RUN**. The source-traced manual/automatic paging, active load-more and completed loading-roundtrip cases still require qualified integrated app execution.

The first commit attempt failed with unknown author identity and left HEAD on the original base. Its exact failure is retained. The successful commit uses the already observed identity of this lane's previous commit (`Codex`, `codex@openai.com`) as command-local options; it changes no shared Git configuration. Root owns publication and direct Wave3 intake.

Byte-exact raw source evidence is preserved, including the original controller's final blank line. The production diff and authored documentation pass the scoped whitespace check. The all-file raw-copy whitespace warning is retained separately and is not removed by changing original evidence.
