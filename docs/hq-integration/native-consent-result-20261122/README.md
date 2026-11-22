# Original iPad consent: verified Native acceptance

Run [44987561349](https://github.com/davidpovarsky/Maktabah/actions/runs/44987561349), attempt 1, completed successfully on 2026-11-22 at 05:56:40 UTC. Exactly one original XCTest case passed; zero failed, skipped, or not-run cases were reported. This packet retains the actual run evidence and an independent source/xcresult audit. Packaging did not execute tests.

## Immutable scope

| Item | Exact binding |
| --- | --- |
| Workflow checkout | `64112a15b9fd1fb63d54b21b5d60cfc8bc96ba0b` |
| Application and UI test source | `0ea7218331d1441d37d06d43333e579f267056e3` |
| Case | `HanlinReaderConsumerAcceptanceTests/testOriginalIPadCurrentWorkConsentToggleWithoutConnection` |
| Result | 1 PASS, 0 FAIL, 0 SKIP, 0 NOT_RUN |
| Actual case duration | 99.83200895786285 seconds |
| Device | iPad Pro 11-inch (M5), iOS Simulator 27.2 (24B8117), arm64 |
| Simulator | `CC708E22-FBF9-46B8-99BF-B31EB2FC4853` |
| Toolchain | Xcode 27.2 (27B52); Apple Swift 6.4.2 |
| Owned simulator cleanup | PASS |

The case opened the original book reader and chat, verified initial consent OFF and the original book/workspace identity, tapped the exact original switch child, observed ON, revoked with a second native tap, observed OFF, and closed chat back to the original reader. Raw accessibility trees show both the outer row and its native switch at 0, then 1, then 0. Screenshots and the final reader hierarchy are retained in `raw/captures/visual-11-reader`; `AX_STATE_REVIEW.json` maps each stage to its original exports. The test uses no credentials, provider connection, Connect or Send action. It does not establish Live-provider acceptance.

The preceding failure identified selection of the outer switch row. Its actual injected event coordinate was not captured. The earlier immutable wrapper packet's phrase “row-center tap” is therefore too specific; the supported description is “outer-row target observed, actual event coordinate unmeasured.” This packet preserves that distinction and does not alter the preceding raw evidence.

## Source and binary proof

`provenance/INDEPENDENT_VERIFICATION.json` records independent verification of all 276 execution input Git blobs and raw SHA-256 values against the frozen source. The original post-UI auditor verified 1,012 actual source inputs. All four product trees match application source 0ea72183; their exact tree IDs are in `FILE_HASHES.json`.

The app and UI runner were built successfully. Native binary/code image hashes remained unchanged during UI execution. Build and post-UI source fields match exactly, apart from the original additional Hanlin verify-only command and one repeated byte-identical privacy-aggregation receipt. The strict xcresult proof admits the one declared case and actual device; canonical summary/tests digests are retained with the original JSON.

The original Host48 proof was reused from run 44940208007/artifact 14724450161 after exact checks of 35 local source inputs and 29 SDK inputs. It records 48 historical PASS cases and zero newly executed Host48 tests. The three selectors that had already passed in Native4—landscape search, portrait search and keyboard dispatch calibration—were absent from this run.

## Installation recovery and actual timing

The GitHub execution wrapper step began at 05:34:40 UTC. That step includes simulator setup, installation, fixtures and Xcode startup. Its elapsed duration is not the XCTest case duration.

The first application installation's subsequent `simctl get_app_container` verification timed out after 45 seconds. The existing install-only recovery collected diagnostics, restarted the owned simulator, and completed its second installation/container verification. This was not an XCTest retry. The matrix entered its RUNNING_NATIVE_XCTEST phase at 05:46:53.379206 UTC. The xcresult session began at 05:52:35.229; the raw test suite began at 05:53:00.194 and passed at 05:54:40.064. The sole case ran once for 99.832 seconds, within the unchanged 600-second per-case timeout. The original matrix receipt retains both install attempts and final cleanup.

## Retained raw evidence

All 60 primary artifact files (31,583,236 uncompressed bytes) and all nine exported visual files are copied byte-for-byte. Full original archive downloads remain in the owned checkout's `build/native-consent-result-44987561349` directory. The captures archive includes the original xcresult and video; these are not duplicated in Git. The GitHub artifact IDs, download metadata, CRC inventories and full archive hashes are retained.

| Artifact | ID | Archive bytes | SHA-256 |
| --- | --- | ---: | --- |
| completion-focused-native-evidence | 14742146824 | 6,363,659 | `096c6d6b92744e246de0b4092d6df82369d5c4369a939dbaf27b881aeb86faff` |
| completion-focused-native-captures | 14742311290 | 28,485,905 | `a7ea12c937ce782bd76176b61ab28180142688cba3545f3497e1fb33c61492a0` |

Primary entry points:

- `raw/artifacts/continuation-focused/result.json`: final outcome and source after UI.
- `raw/artifacts/continuation-focused/source-before.json` and `built-binaries.json`: frozen inputs and native images.
- `raw/artifacts/runtime27/verified-11-reader.json`, `.summary.json` and `.tests.json`: strict receipt and original xcresult exports.
- `raw/artifacts/faithful-ipad-matrix.json`: installation attempts, actual phases and owned cleanup.
- `raw/artifacts/test-simulator-11-reader.log`: actual single-case execution.
- `raw/hq-stage2/result.json` and `actual-source-inputs.json`: original source/build audit.
- `provenance/INDEPENDENT_VERIFICATION.json`: independent 276-input and one-case verification.
- `COPY_RECEIPT.json` and `FILE_HASHES.json`: byte-preserving copy and complete packet index.

The sole finite Native observer, both sole artifact downloads and the independent verification are terminal. No Native watcher remains. This result closes the focused no-key consent diagnostic on source 0ea72183. Full Native116, Release114, original-editor admission and Hanlin Live remain separate acceptance scopes; this packet does not mark them complete.

## Packaging bookkeeping

The first packaging attempt stopped before staging or committing: its derived AX review expected integer frame text, while the original export writes the same coordinates with `.0`. The continuation compares numeric coordinates and preserves all original raw bytes. The failed packaging receipt and original script are retained under `provenance`; no source gate or test was repeated.

The next packaging attempt completed the raw AX review but Git refused to stage the new documentation path outside this worktree's sparse rules. The final packaging uses Git's explicit add --sparse for this packet only. That staging failure is retained in provenance/PACKAGING_SPARSE_ATTEMPT.json; existing sparse checkout rules and all raw evidence remain unchanged.

The first staged byte comparison caught the regenerated file index including its own prior version. The retained failed receipt and prior index show that bookkeeping error. The final index excludes itself as declared; every indexed payload plus the final index is verified against the exact staged Git blob before the documentation commit. No runtime evidence or product input was changed.
