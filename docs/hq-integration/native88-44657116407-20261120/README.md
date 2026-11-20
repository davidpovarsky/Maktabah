# Native88 — original run 44657116407

**The workflow failed. There are 70 finalized, independently reconciled iPad Test Case leaves: 46 passed, 24 failed, zero skipped. Eighteen selected phone cases have no finalized xcresult export.** The driver labels these eighteen `NOT_RUN`; that label must not be interpreted as proof they never executed. The original phone log records sixteen starts and fifteen terminal outcomes (seven `passed`, eight `failed`), one interrupted case, and two selected cases without a start. Those partial log observations are retained separately and are not promoted to verified leaf results.

Run: https://github.com/davidpovarsky/Maktabah/actions/runs/44657116407

| Provenance | Exact source |
|---|---|
| Workflow checkout | `fe4df7c39aec242d00046bc454c81963ba4285a0` |
| Application and test source | `7e777509d486a17bec5b4bd437a9ac7f51d3a43a` |
| Original selected manifest | 88 cases: 70 iPad and 18 iPhone |
| Manifest SHA-256 | `c26cf3277e8827f8f0509d1c962dd6830c97caad02922f4a91f0456822a93960` |
| Complete evidence artifact | 14606041723; 87,098,508 bytes |
| Verified complete artifact SHA-256 | `ced48935baf6c27a7df229b1e438ae30113fcad7939ccfa5783ad4262723872c` |
| Separate captures artifact | 14605489369; 2,169,151,077 bytes; selected HTTP206 ranges only |

The original runtime report records an outer `run-faithful-ipad-matrix.py` timeout after **12,600 seconds**. The final phone log stops while `testNormalBootstrapGlobalHistoryUsesActualSubmit` is relaunching. The two no-start observations are `testNormalBootstrapLegacyGenesisAndRotation` and `testNormalBootstrapOtzariaBackgroundAndColdRestoration`. This is not an eighteen-case phone setup failure. The workflow Native step failed at06:01:29UTC; artifact retention completed and the workflow concluded failure at06:06:18UTC. The sole finite watcher ended naturally at06:06:41UTC. No GitHub workflow was cancelled by this review.

## Finalized leaf reconciliation

| Original group | Selected | Passed | Failed | Skipped | No finalized leaves |
|---|---:|---:|---:|---:|---:|
| 11 | 7 | 3 | 4 | 0 | 0 |
| 11-search | 22 | 20 | 2 | 0 | 0 |
| 11-reader | 34 | 20 | 14 | 0 | 0 |
| 11-sidebar | 5 | 3 | 2 | 0 | 0 |
| 11-window | 2 | 0 | 2 | 0 | 0 |
| phone | 18 | 0 | 0 | 0 | 18 |

`VERIFIED_CASES.json` compares each named Test Case leaf with its original group summary, the original requested88 manifest, and the driver's named outcomes. There are **zero provenance or count discrepancies**. Its `not_run:18` field is preserved exactly as the existing evidence verifier classifies missing exports; `PHONE_PARTIAL_LOG_OBSERVATION.json` supplies the necessary actual execution distinction. No per-assertion counter exists. No source test was executed by this review.

## Concrete new failures and source boundaries

- Core search.openResults fails before app launch because `GLOBAL_SEARCH_TEST_QUERY` is absent. The original group11 oracle explicitly records `search_query_source_evidence:null`; the partial phone log shows the same missing variable. The Core/engine action was not reached in either case.
- Profile color fails because the unspecific Hebrew Edit selector matches both the profile navigation bar and the profile action menu. The original AX tree and screenshot are retained. This does not prove a color transaction or persistence failure.
- Notes reaches the production Core outcome and reports `cancelled`, not `completed`. The actual outcome JSON and final AX are retained; the success/draft/cancel/store assertions after that failing point were not reached.
- Commentary fails the independent TextKit/source-locator precondition after opening its public source URL, before triggering Core.openCommentary. It is not evidence that the commentary action ran and failed.
- The restored original global-history-submit case fails to find exactly one submitted history row. The original query and UI evidence remain intact; the oracle was not loosened.
- The two real window/HID cases again fail to find `reader-study-toggle` after the actual compact-window and palette/HID interactions. Currentb07 still contains that exact test selector; diagnosis and any repair are separate work.

## Comparison with Native78 and current source

Of the prior thirteen failures, the iPad History URL after background case now has an actual passing leaf on7e. Ten prior iPad failures recur. The two prior phone failures have no finalized88 leaves; both have failing terminal observations in the partial phone log. The full per-case comparison is `NATIVE78_COMPARISON.json`.

Later sourceb07 includes Inspector witness8457e48f, background intent metadata39ba01a0, Library/TOC polling46c702b9, current book-search/header4fee5615, native wait/tab-returnf94e830d/9642de60 and ACK diagnosticsce39223a. These source changes are potential resolutions for their scoped failures, **not Native PASS**. The separate92-case run must establish its own outcome. The source defects newly demonstrated here are assigned separately; no source, oracle, runtime timeout, manifest or capability was changed by this evidence package.

## All24 finalized failures

| Original case | Original failing assertion/message (short excerpt) |
|---|---|
| `NativeRoutingAcceptanceTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPad` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The original TextKit text and exact source locator must both match independent SQL |
| `NativeRoutingAcceptanceTests/testCoreNoteDraftUsesOriginalUnsavedEditorAndCancelOnPad` | XCTAssertEqual failed: ("Optional("cancelled")") is not equal to ("Optional("completed")") |
| `NativeRoutingAcceptanceTests/testCoreSearchOpenResultsUsesOriginalCompletedEngineOnPad` | XCTUnwrap failed: expected non-nil value of type "String" |
| `StudyProfileNativeAcceptanceTests/testProfileColorSaveCancelAndColdRelaunchPreserveWorkspace` | Failed to get matching snapshot: Find single matching element. Multiple matching elements found for <XCUIElementQuery: 0x10b13e5d0>. Sparse tree of matches: →Application, pid: 19490, label: 'ChavrusaText'   ↳Wi |
| `GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit` | XCTAssertGreaterThanOrEqual failed: ("0.0") is less than ("15.0") |
| `R27NativePadTests/testNormalBootstrapGlobalHistoryUsesActualSubmit` | XCTAssertEqual failed: ("0") is not equal to ("1") - The exact genuine submitted history query must occur once |
| `NativeRoutingAcceptanceTests/testAnnotationsPublicRootShowsOriginalScreenAndNativeReceipt` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Root opening needs one canonical actual visible receipt |
| `NativeRoutingAcceptanceTests/testColdHistoryURLWaitsForActualSceneMount` | Failed to terminate com.davidpovarsky.chavrusatext:28023: Failed to terminate com.davidpovarsky.chavrusatext:0 |
| `NativeRoutingAcceptanceTests/testGlobalSearchPublicRootPreservesOriginalPrivateQuery` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Owned system URL transport must acknowledge the exact request |
| `NativeRoutingAcceptanceTests/testPublicV2InspectorPreservesOriginalReaderAndWorkspace` | XCTAssertTrue failed - A hidden panel or model flag is not visible presentation |
| `NativeRoutingAcceptanceTests/testPublicV2InspectorRequiresVisibleOriginalReader` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Root opening needs one canonical actual visible receipt |
| `NativeRoutingAcceptanceTests/testPublicV2LibraryPreservesPrivateQueryAndOriginalReader` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Actual canonical native receipt did not reach the app's real reader log |
| `NativeRoutingAcceptanceTests/testPublicV2NewTabSameBookCreatesDistinctOriginalReaderTab` | XCTAssertTrue failed |
| `NativeRoutingAcceptanceTests/testPublicV2SearchQueryFocusUsesOriginalFirstResponder` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Root opening needs one canonical actual visible receipt |
| `NativeRoutingAcceptanceTests/testPublicV2TOCPreservesPrivateFilterAndOriginalReader` | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The actual original UIKit surface must acknowledge through Core |
| `NativeRoutingAcceptanceTests/testSystemAppIntentShowsOriginalReaderInspector` | failed: caught error: "Error Domain=OtzariaUIRouting.UIRouteError Code=1 "The operation couldn’t be completed. (OtzariaUIRouting.UIRouteError error 1.)" UserInfo={NSLocalizedDescription=The operation couldn’t b |
| `NativeRoutingAcceptanceTests/testSystemBookIntentCachedSourceReturnsFromBackgroundAndPreservesReader` | failed: caught error: "Error Domain=OtzariaUIRouting.UIRouteError Code=1 "The operation couldn’t be completed. (OtzariaUIRouting.UIRouteError error 1.)" UserInfo={NSLocalizedDescription=The operation couldn’t b |
| `NativeRoutingAcceptanceTests/testSystemBookIntentRejectsDifferentBookLocationWithoutMutation` | failed: caught error: "Error Domain=OtzariaUIRouting.UIRouteError Code=1 "The operation couldn’t be completed. (OtzariaUIRouting.UIRouteError error 1.)" UserInfo={NSLocalizedDescription=The operation couldn’t b |
| `NativeRoutingAcceptanceTests/testSystemBookIntentRejectsMissingSourceWithoutMutation` | failed: caught error: "Error Domain=OtzariaUIRouting.UIRouteError Code=1 "The operation couldn’t be completed. (OtzariaUIRouting.UIRouteError error 1.)" UserInfo={NSLocalizedDescription=The operation couldn’t b |
| `NativeRoutingAcceptanceTests/testSystemBookIntentResolvesNamedChapterThroughOriginalCore` | failed: caught error: "Error Domain=OtzariaUIRouting.UIRouteError Code=1 "The operation couldn’t be completed. (OtzariaUIRouting.UIRouteError error 1.)" UserInfo={NSLocalizedDescription=The operation couldn’t b |
| `BookHistoryScopeAcceptanceTests/testBookSearchRetainsControlsWithoutGlobalHistory` | XCTAssertTrue failed |
| `Sidebar11201AcceptanceTests/testSidebarBodyPagingLTR` | Test exceeded execution time allowance of 10 minutes |
| `R27NativePadTests/testNormalBootstrapNativeWindowResizePaletteAndInspector` | XCTAssertTrue failed |
| `R27NativePadTests/testNormalBootstrapPaletteHIDComparison` | XCTAssertTrue failed |

## Evidence reproduction and preservation

Run `review-native-evidence.py` with the original ZIP and `original-R27_CASES.json`, supplying the exact source/digest above. It reads original results only. `EVIDENCE_LEDGER.json` records raw entry lengths and SHA-256; each retained original entry is a deterministic gzip whose decompressed bytes must match those values. The complete phone log and matrix driver are included losslessly. All24 failing activity spans are retained in `failure-timelines/`.

The separate captures ZIP was not fully downloaded or hash-verified. `captures/RANGE_EVIDENCE.json` records its GitHub-advertised digest, exact validated HTTP206 ranges, and selected-entry CRC/SHA values. Original compressed ranges are retained so selected PNG data can be reconstructed without claiming a full-archive digest. Selected original AX/result JSON and manifests are preserved losslessly as gzip. Signed artifact URLs and GitHub credentials are never stored in this package.

The earlier watcher finite timeout is a watcher observation, not a failed workflow result. Native92 and later repaired sources remain distinct; no prior-source success is transferred to them. Physical-device acceptance, Release acceptance, the new d5 occurrence feature and current source readiness are not established by this old265-engine Native88 run.
