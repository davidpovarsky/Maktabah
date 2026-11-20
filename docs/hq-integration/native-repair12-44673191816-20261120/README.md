# Native repair12 — exact old-source result collection

Run [44673191816](https://github.com/davidpovarsky/Maktabah/actions/runs/44673191816) completed **FAILURE**. Its 12 selected Native cases all have finalized XCTest results: **3 passed, 9 failed, 0 skipped, 0 not run**. This package records those results; it does not execute tests or transfer a pass to a later source.

## Source and execution identity

- Checkout: `6030087e27f75b26d9a9bb144ba9ba71eaddadc5`.
- Original app/tests: `461de9aaee620d4275a1676ce8e1c230eb8e27ad`.
- Exact selected manifest SHA-256: `de9a8d6853290f818621f38ef86338c2d323050fd562146159e17d691474b841`.
- Independent review found zero provenance/count errors; all **35 original build source-input/tree checks** matched the bound Git source.
- Devices in the original exports: iPad Pro 11-inch (M5) and iPhone 18 Pro, iOS Simulator 27.2 (24B8117), arm64. Full device identifiers are retained in the original summaries.
- The finite observer completed naturally on 2026-11-20 at 07:19:40 UTC. Its nonzero exit reflects the workflow's actual failure; it was not a watchdog timeout.

## Finalized results

| Original execution group | Passed | Failed | Skipped | Not run |
|---|---:|---:|---:|---:|
| 11 / Hanlin consent | 0 | 1 | 0 | 0 |
| 11-search / accessibility | 0 | 1 | 0 | 0 |
| 11-reader / routing | 0 | 5 | 0 | 0 |
| 11-sidebar / book-history scope | 1 | 0 | 0 | 0 |
| phone | 2 | 2 | 0 | 0 |
| **Total** | **3** | **9** | **0** | **0** |

The passes are the original book-search controls/history-scope case and the phone public Inspector and public new-tab cases. [CASE_TABLE.md](CASE_TABLE.md) gives all 12 exact identities, finalized failures, locations and original group membership. The independent counts are derived from the original `.tests.json` leaves and cross-checked against `.summary.json`, manifest and driver declarations; they do not count declarations or raw starts as execution.

## First observed failure buckets

| Cases | Original evidence | Interpretation and remaining work |
|---|---|---|
| iPad Hanlin consent | `HanlinConsumerAcceptanceTests.swift:234`; selected AX explicitly contains the unavailable read-offer text, and the expected Switch is absent. | Read-consent ownership/source diagnosis is assigned separately. An offscreen Switch is not established by the evidence. |
| Phone Hanlin consent | `HanlinConsumerAcceptanceTests.swift:210`; the active pushed Reader's selected AX lacks the expected global launch control. | Review the original Reader action, toolbar/overflow and source ownership. No permission or provider gate is bypassed here. |
| Search accessibility | `GlobalSearchNativeAcceptanceTests.swift:482`; the unfiltered issue identifies the static description `הקלידו מילים ולחצו על חיפוש.` at (137.8,524.5,238.5,24.0). | This is the `ContentUnavailableView` description in `GlobalSearchHistoryContent.swift:13–14`, not the previously repaired history-heading UILabel. The selected element crop visibly shows gray text on the cream background. The complete production file and audit file are byte-identical from the tested source through c612. A production contrast repair is still needed; no system issue is filtered or accepted. |
| iPad public Inspector | `NativeRoutingAcceptanceTests.swift:1523`, actual panel hittability failed. | Preserve the original visible panel/text/receipt evidence and investigate current source. No model-only visible claim is accepted. |
| Inspector requires Reader | `NativeRoutingAcceptanceTests.swift:735`, initial Library actual visible receipt timed out. | Later request-bound geometry polling may be relevant, but this package does not claim that it fixes the observed case. |
| Two iPad public new-tab cases | `NativeRoutingAcceptanceTests.swift:641`, return to the old tab failed after the new-tab route. | The bounded original tab-return helper changed later. Current-source acceptance remains required. |
| System Inspector intents on iPad and phone | `NativeRoutingAcceptanceTests.swift:1586/1622`, actual UIRouteError1. | Later Intent admission/mapping source differs. Exact cause and any residual gap are under a separate source-bound investigation. |

These are first observed assertions, not an assumption that all failures share a cause. No expected book count, receipt, locator, timeout, accessibility issue or user query was weakened during collection.

## Capture and archive integrity

The complete small evidence ZIP was downloaded once and SHA-256 verified:

- Artifact `14609861460`, 63,017,123 bytes.
- SHA-256 `5ff46397642ad94f64c351bbc2dfd5dd97f902602994e8b5354996ac4e00d958`.

The capture artifact `14609343962` is 435,989,487 bytes. It was **not downloaded or whole-archive hash-verified**. The collector read its central directory and exactly selected 17 original entries using authenticated exact HTTP206 ranges, then checked each entry's ZIP CRC and SHA-256. `captures/RANGE_EVIDENCE.json` records 3,403,436 transferred bytes for the selection operation, full range hashes and per-entry proofs. The separate initial central-directory operation transferred 915,716 bytes. No signed artifact URL or token is published.

The 17 selected entries contain the consent iPad/phone final AX and PNG; Inspector AX/PNG/receipt; new-tab AX/PNG/workspace/receipt; and the unfiltered contrast issue, description, element crop and whole-screen PNG. The two new-tab PNG entries have identical image bytes, which is preserved without assigning a stronger product-state meaning to that identity.

Original finalized trees, summaries, driver/build result, actual-source inputs and full five XCTest logs are retained under `raw/`. Logs use deterministic lossless gzip. `ORIGINAL_ENTRY_HASHES.json` binds them to exact ZIP bytes. The complete ZIP remains in the owned build directory and is not duplicated in Git. `COLLECTION_COPY_RECEIPTS.json` records collector-file copies; where Windows CRLF is normalized for readability, an exact original gzip is retained separately. Selected original capture bytes are preserved.

## Comparison and limits

`SOURCE_COMPARISON.json` and `source-comparison/` compare selected Git blobs against immutable app/tests `c61213d9fcc8b80a8606ba00a1562215312ca2ed`. They are source evidence only. `GlobalSearchHistoryContent.swift`, its complete accessibility test file and `HanlinConsumerAcceptanceTests.swift` are unchanged. Native routing tests, scene session and composition differ. The comparison does not infer Native success from those differences.

This documentation commit changes no production source, XCTest, case manifest, workflow or acceptance gate. It records **zero new Native executions**. The independently dispatched current-source diagnostic remains a separate run with its own head and outcome.
