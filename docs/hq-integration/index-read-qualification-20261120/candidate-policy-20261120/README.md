# Exact qualified read policy — candidate source verification

The isolated candidate enables only `original265ToExactOccurrencesD5`, following the complete Windows runtime qualification reviewed at immutable commit `df3b894cef2c8ea3dd50ccb31394635aa8fe4077`. The candidate source was committed and clean before execution. This package records the actual next policy and original regression run; it does not claim a merge into the main branch or Apple/Native success.

## Executed source and result

- Source: `e332b02c089cd0f068a7fe9e5c9dde40b5729ea1`.
- Branch: `codex/otzaria-qualified-read-candidate-20261120`.
- SentinelX job: `job_8bfa116dcbe3`, started 2026-11-20 05:20:26 UTC, succeeded 05:22:24 UTC, exit 0.
- Windows Swift 6.3.3, `x86_64-unknown-windows-msvc`, assertions enabled. Compilation used one worker.

| Actual verification | Result |
| --- | ---: |
| Policy / install / recovery / writer cases | 99 / 99 PASS |
| Failed or skipped policy cases | 0 / 0 |
| Original portable search assertions | 191 PASS |
| Original cached repository readiness assertions | 14 PASS |

The latter two numbers are assertions, not XCTest case counts. The policy suite compiles the complete policy and exact original flow methods against explicit provider/FFI/storage controls. It does not load a real index. The 191-assertion fixture uses the real models/wrapper/session and fake FFI/Combine. The 14-assertion fixture uses the real repository and FFI/storage doubles. The unchanged original driver reported its existing redundant `SearchResultItem: Sendable` conformance warning; the complete log is retained.

## Narrow candidate change

After the owner reviewed the complete independent qualification, the source registry changed from empty to the single exact `original265ToExactOccurrencesD5` case. It does not allow arbitrary descendants, schema-only matches, other upstream repositories, or untrusted identities. The underlying original producer identity, exact writer / checkpoint / seed comparisons, original manifest gates, and required runtime-resource projection remain unchanged.

The fixture-specific candidate-admission override was removed. Flow fixtures now call the complete ordinary production `validate` implementation. Five state expectations changed to reflect the qualified exact contract; their exact old/new names and guards are listed in `RESULT.json`. Recovery and readiness continue to exercise explicit unknown-consumer rejection, byte preservation, and balanced handles. The bare untrusted identity case and all other existing negative guards remain.

The runner checked the exact source hashes before and after execution. The original search driver was unchanged. Its only execution scheduling adjustment was `swiftc -j1`, performed by the retained wrapper. Exact writer methods were inverse-checked against the original source and remain unchanged.

## Evidence chain and physical representations

The original qualification report is retained as two explicitly distinguished physical representations:

| Representation | Bytes | SHA-256 |
| --- | ---: | --- |
| Original raw Windows report, preserved by `../raw/QUALIFICATION_REVIEW.json.gz` | 28,174 | 56fead3a78281ea6a1ba68d21806d5fa7505f2ba32b709fd03c1ce831c8fa3ca |
| Immutable Git LF blob at df3, `../QUALIFICATION_REVIEW.json` | 27,739 | 3ccd704a831f4a96ec06a691bdc17e7a8988168659bad766815018c9106983a1 |

Only CRLF versus LF physical line endings differ. Exact conversion and decoded JSON equality were verified. All 211 historical gzip evidence files remain byte-identical. Neither the original OFF result nor a failed prior attempt was rewritten.

Every entry under `raw/` is deterministic gzip of the exact captured bytes, with both compressed and uncompressed hashes in `SHA256SUMS.json`. `RESULT.json` is a new UTF-8 LF summary. Raw Windows source snapshots also include their immutable Git blob hashes in the summary, so newline conversion cannot be mistaken for a source change.

## Remaining integration boundary

This run establishes the candidate production policy behavior and preservation of the original portable regressions. Actual Windows original-index runtime qualification is linked from the prior immutable package. The whole app qualified count fixture belongs to a separate run. Apple SDK, full Apple v32 count/installer/reopen validation, and Native acceptance are separate gates and receive no PASS from this portable suite.

No database, index payload, archive, or large executable was copied into Git. No user index was opened. The compiler process tree had exited before the next agent received the single-worker slot. Post-run C: free space was 1,639,895,040 bytes; the nine owned policy scratch builds totaled only 6,484,648 bytes and were retained.
