# Focused Native result: three passed, consent diagnostic failed

The actual GitHub run **44980625976** completed **FAILURE** at **2026-11-22 04:22:33 UTC**. All four selected methods executed: **3 PASS, 1 FAIL, 0 SKIP, 0 NOT_RUN**. The application and original UI test runner built successfully.

- Run: https://github.com/davidpovarsky/Maktabah/actions/runs/44980625976
- Immutable workflow checkout: c107c8ac600de6bbe6d92571fbbbdc6349cd143a
- Application and test source: 385ee84a8acb3fbc3c013c0977417b61fd3d8a17
- Job: 137080119677; attempt 1.
- Actual environment: iPad Pro 11-inch (M5), iOS Simulator 27.2, Xcode 27.2 build 27B52, Debug, miniTest10.

| Original XCTest method | Actual result | Case duration |
| --- | --- | --- |
| FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchLandscapeMatchesOriginalNavigation | PASS | 57.100 s |
| FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchPortraitMatchesOriginalNavigation | PASS | 50.500 s |
| R27NativePadTests/testNormalBootstrapPaletteKeyboardDispatchCalibration | PASS | 112.481 s |
| HanlinReaderConsumerAcceptanceTests/testOriginalIPadCurrentWorkConsentToggleWithoutConnection | FAIL | 62.962 s |

Both original search comparisons retain their original geometry assertions and tolerance. Their current-source success verifies the initial saved-tab repair in f5d53f3928e8a2319de19373103dcbe3f3153e3c. Keyboard calibration verifies actual Down/Up selection using the original unique row identities, without changing keyboard dispatch.

The consent diagnostic failed at HanlinConsumerAcceptanceTests.swift:233: after one real tap, the original switch did not become ON within the unchanged ten-second wait. This case supplied no provider key, performed no Connect or Send, and provides no Live provider acceptance. Root owns the continuing source/AX diagnosis.

## Evidence and independent checks

The original primary artifact14738269812 was downloaded once: 20,760,679 bytes, SHA256 effdd13e0f58704248552c85339a39d56a921d53ff55ac55f9719893432c4440. All97 ZIP members passed CRC. Selected raw results, three xcresult summaries/test trees, original verifier outputs, original build and post-UI audits, binary hashes, fixture/source/toolchain bindings, case logs, and exact terminal GitHub metadata are retained here.

INDEPENDENT_VERIFICATION.json binds the actual four product trees to both the immutable checkout and application source. All275 declared execution-input Git blobs, byte counts and SHA256 values were independently verified. Each xcresult summary/test tree matches the original verifier's canonical JSON digest. The original post-UI auditor verified1012 source inputs; all compiled images remained unchanged and all three owned simulators were cleaned up successfully. The post-UI report appends its exact Hanlin verify-only command and a duplicate identical CocoaPods privacy receipt; these are observations, not source drift.

CAPTURES_DOWNLOAD.json and CAPTURES_EXTRACTED.json record the separately retained original capture artifact and exact exported files. The full original xcresult bundles remain in that verified archive; selected unmodified AX and screenshots are included for review.

## Scope preserved

These three successes belong to application385ee84a only. Later Ledger/source changes and documentation commits do not retroactively change this run. None of these four diagnostic selectors constitutes Native116 acceptance. The two search methods are separately required in Release114's 11-inch and 13-inch configurations. Full Native116, Release114 plus two prototype oracles, original-editor StageB, actual Live provider, physical-device and distribution acceptance remain separate.

The previous three passes from44969361774 were excluded from this run and were not executed again. The three newly passing cases should now also be preserved without an unrelated retry. No workflow, component suite, UI case or Host48 suite was rerun while collecting and verifying this proof. All tasks remain open until their complete acceptance requirements are genuinely satisfied.
