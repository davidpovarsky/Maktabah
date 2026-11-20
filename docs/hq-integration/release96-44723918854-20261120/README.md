# Actual Release96 run 44723918854 — preserved failure

This is a read-only evidence review of the original **attempt1**, checkout `60a57972acb28739ec738565083bf17fb7503028`, application/tests `87b783ac3f0257e8461762e0ea9dfa5248dd06e8`. [Original run](https://github.com/davidpovarsky/Maktabah/actions/runs/44723918854). It does not execute or qualify the newer source `7733f3557bd98aee063a74fb838a7cf82ebf2b30`.

## Actual outcome

The build job **136246453842 succeeded**. Native job **136270631605 failed**, completed 16:28:16 UTC. Production job **136417779842 was skipped**; API timestamps are retained verbatim. The outer native matrix reached its original **16,200-second** limit during the iPad13 lane. Its interrupted-process receipt is preserved. No timeout, individual600-second allowance, test assertion or source was changed here.

The manifest contains **96 application cases and2 prototype-oracle cases across five configurations**, not96 cases on each device.

| Configuration | Required app + oracle cases | Evidence |
| --- | ---: | --- |
| iPad11 | 54 +1 | Complete authenticated xcresult projection: **31 app PASS,23 app FAIL,1 oracle PASS,0SKIP**. All55 unique selected leaves match the manifest exactly. |
| iPad13 | 34 +1 | Interrupted; no final xcresult projection. Stdout has34 unique starts,29 terminal lines (15 passed/14 failed), four600-second issues without ordinary terminal lines, then the started prototype oracle interrupted. ProfileColor never started. These are observations, not qualified lane totals. |
| iPad13 largest text | 1 | Not reached. |
| iPhone | 6 | Not reached. |
| iPad13 production Release | 1 | Production stage skipped. |

The original run-level result correctly retains null aggregate UI counts and `full_release_acceptance=false`. Do not replace them with iPad11 totals, infer the unverified iPad13 results, or credit newer repairs.

## Authentication and raw retention

Both original downloaded ZIPs are retained in full. GitHub artifact metadata binds each to this run/head. All member CRCs and SHA256 values were checked locally and are replayed by `VERIFY_PACKET.py`.

| Artifact | Bytes | SHA256 | Members |
| --- | ---: | --- | ---: |
| Native evidence14647558906 | 10,170,377 | `fb87af0c12fc727d682419c19cc04833ed6825f1732708f1803ab0ae1328cf19` | 59 |
| Build evidence14626257677 | 1,618,660 | `42978dc266c442eae2023c01b6ff944d752f052a5cf60b76588b441d9c16447a` | 82 |

The original verified11 summary/tests canonical digests were independently recomputed using the original verifier serialization: `76dce7cb444210a4a47f3f5eeea5b2f959eaddf2e27c359332af3e78aae037cf` and `70ef344ebb44cd8e62552f2bbbeee85bfd9bf3852b3ae70781504ddef6d901c3`. Full GitHub run/jobs/artifact JSON and authenticated connector-decoded build/native job logs are retained. Log text preserves the returned BOM and final newline; no signed download URL is included.

The3.27GB captures artifact14647594631 was **not downloaded or independently full-hash verified here**. Its API metadata is retained. The341MB build handoff14625024766 was validated by the actual CI importer; this packet retains that receipt, but does not claim an independent second download/hash of its binary payload.

## Verified iPad11 failures

Every failure below is an actual original xcresult leaf. The table quotes only the first recorded issue; `VERIFIED_IPAD11_CASES.json` preserves all failure children and durations. Pass leaves are retained in the same JSON.

| Case | First original issue |
| --- | --- |
| `Build8401SevenDefectsAcceptanceTests/testA3_OrdinaryReaderHasNoClearSearchHighlightButton` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The original RTL close gesture must remove this exact document (line163) |
| `FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchLandscapeMatchesOriginalNavigation` | XCTAssertEqualWithAccuracy failed: ("86.0") is not equal to ("106.0") +/- ("1.0") - A viewer-only document strip must not shift another global tab's native navigation (line1721) |
| `FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchPortraitMatchesOriginalNavigation` | XCTAssertEqualWithAccuracy failed: ("86.0") is not equal to ("106.0") +/- ("1.0") - A viewer-only document strip must not shift another global tab's native navigation (line1721) |
| `FaithfulReaderUIAcceptanceTests/testCandidateTrimmedOriginalInspectorLandscape` | XCTAssertEqualWithAccuracy failed: ("1210.0") is not equal to ("802.0") +/- ("1.0") - FloatingPanel must overlay Reader without reserving an opaque column (line1744) |
| `FaithfulReaderUIAcceptanceTests/testCandidateTrimmedOriginalInspectorPortrait` | XCTAssertEqualWithAccuracy failed: ("834.0") is not equal to ("426.0") +/- ("1.0") - FloatingPanel must overlay Reader without reserving an opaque column (line1744) |
| `FaithfulReaderUIAcceptanceTests/testCandidateWindowResizePreservesOriginalReaderAndSearch` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Capture only after native rotation and the original bottom toolbar settle inside the window (line454) |
| `FaithfulReaderUIAcceptanceTests/testEnglishReaderAndOriginalPaletteInLeftToRightLayout` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Capture only after native rotation and the original bottom toolbar settle inside the window (line454) |
| `FaithfulReaderUIAcceptanceTests/testGroupCopyMoveRenameAndDeleteThroughRealMenus` | Test exceeded execution time allowance of 10 minutes |
| `FaithfulReaderUIAcceptanceTests/testHistoryRemainsGlobalAndIsAbsentFromBookSearch` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The original Return submission must settle and persist in its own installation before relaunch (line1014) |
| `FaithfulReaderUIAcceptanceTests/testOriginalLibraryMenusSelectionSettingsAndBookInfoRemainUsable` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The original overflow must expose Library Options or its actual actions (line1249) |
| `FaithfulReaderUIAcceptanceTests/testPointerHoverClickAndHardwareKeyboardDismissal` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The original palette's Escape handler must dismiss through keyboard focus (line1472) |
| `FaithfulReaderUIAcceptanceTests/testReaderDocumentAndGlobalBarsCollapseAndRestoreOnManualScroll` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - A deliberate downward reader scroll must collapse the document strip (line1953) |
| `FaithfulReaderUIAcceptanceTests/testSameBookRetainsIndependentLocationsAcrossGroupsAndRelaunch` | Test exceeded execution time allowance of 10 minutes |
| `FaithfulReaderUIAcceptanceTests/testSidebarPreservesOriginalTextKitViewport` | Test exceeded execution time allowance of 10 minutes |
| `FaithfulReaderUIAcceptanceTests/testSourceToolbarPaletteAndOverview` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Capture only after native rotation and the original bottom toolbar settle inside the window (line454) |
| `FaithfulReaderUIAcceptanceTests/testSystemReduceMotionKeepsOriginalPaletteUsable` | failed - The original switch tap must stay inside its finite visible native window (line1590) |
| `FaithfulReaderUIAcceptanceTests/testTwentyGlobalTabRoundTripsKeepOriginalReaderAndBottomBar` | Test exceeded execution time allowance of 10 minutes |
| `FaithfulReaderVisualBaselineTests/testOriginalGlobalSearchHistoryThroughNativeControls` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The original Return submission must settle and persist in its own installation before relaunch (line1014) |
| `R27NativePadTests/testNormalBootstrapGlobalHistoryUsesActualSubmit` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The original Return submission must settle and persist in its own installation before relaunch (line1014) |
| `R27NativePadTests/testNormalBootstrapNativeWindowResizePaletteAndInspector` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Opening the actual native overflow must reveal the original Study Tools action (line382) |
| `Sidebar11201AcceptanceTests/testSidebarBodyPagingLTR` | XCTAssertTrue failed (line202) |
| `Sidebar11201AcceptanceTests/testSidebarBodyPagingRTL` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") (line325) |
| `StudyProfileNativeAcceptanceTests/testProfileColorSaveCancelAndColdRelaunchPreserveWorkspace` | XCTAssertTrue failed (line2485) |

## Source comparison and current work

Eight source snapshots were fetched at exact Git commits and independently checked against Git blob IDs; their unmodified bytes are retained as gzip under `raw/source`. The full diffs are in `source-deltas`.

- `Build8401SevenDefectsAcceptanceTests.swift` and `Sidebar11201AcceptanceTests.swift` are **whole-file byte-identical** from failed M87 to7733.
- The R27 file changed only to propagate the existing additional launch arguments into its override for the later History diagnostic.
- Faithful changes after M87 are the History diagnostic, the Profile Picker current-value selector, and appended groups100/metrics work. History instrumentation is **not a persistence repair**. Profile selector is source-qualified but has no new Native result here.
- Earlier Window, Motion and Escape changes already existed in failed M87. They must not be presented as unexecuted future fixes for this run.
- Concrete remaining original failures include global-navigation minY **86 vs106**, Inspector reader-width change **408pt** after close, unchanged Escape dismissal, and the new Motion finite-window guard itself. These need source/evidence diagnosis; this packet supplies no speculative patch.

This review performs **0 new app/Native tests**. The failed run and all partial observations remain unchanged. Final Release114 and Native116 acceptance remain separate, pending exact-source execution.

## Replay

From the repository root:

```bash
python docs/hq-integration/release96-44723918854-20261120/VERIFY_PACKET.py
```

The verifier reads local sealed bytes, checks the two complete archives and141 members, recomputes the original xcresult hashes, checks all55 selected iPad11 leaves and eight source Git blobs, and refuses scope widening. It does not run the app, XCTest, Xcode, install anything or contact a network service.
