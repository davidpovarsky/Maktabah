# Native98 — actual observed results and publication limit

Run [44723902453](https://github.com/davidpovarsky/Maktabah/actions/runs/44723902453), attempt 1, is **completed / CANCELLED**. Checkout 60a57972acb28739ec738565083bf17fb7503028; application/tests 87b783ac3f0257e8461762e0ea9dfa5248dd06e8. The Simulator build actually passed. Complete XCresult leaves actually verified on the host give **31 unique cases: 22 PASS, 9 FAIL, 0 SKIP**, all on iPad.

This packet publishes the complete 98-case classification and the already retrieved API, build, summary, leaf and raw-log projections. **The full SHA/CRC-verified 35.9 MB ZIP and complete selected capture-range package remain on the disconnected Windows host and are not published in this packet.** No compressed or missing file is represented as uploaded.

## Exact scope

| Group | Selected | Complete XCresult leaves | PASS | FAIL | SKIP | Remaining evidence |
|---|---:|---:|---:|---:|---:|---|
|11|9|9|2|7|0|Complete group; failed acceptance|
|11-search|22|22|20|2|0|Complete group; failed acceptance|
|11-index|5|0|0|0|0|One raw completed failure, one raw start/unknown, three starts not observed|
|11-reader|35|0|0|0|0|No start observed|
|11-sidebar|5|0|0|0|0|No start observed|
|11-window / HID|2|0|0|0|0|No start observed; no HID acceptance|
|phone|20|0|0|0|0|No start observed; no iPhone acceptance|
|Total|98|31|22|9|0|67 without complete XCresult leaves|

INDEX's original corrupt-repair case failed in its raw log after 203.536 seconds; the healthy/cold case then started with no terminal result retained. These two are kept outside the 31 complete leaves. The other 65 cases have no observed start in the retained logs. This does not turn missing execution into PASS or establish zero skips across all 98.

Every selected ID is preserved in the exact frozen manifest. Per-case 600-second limits, original queries, books, route ownership, assertion sets and HID placement are unchanged. No result from an older or newer source is borrowed.

## Actual build and timing

The original build record reports SIMULATOR_BUILD_FOR_REAL_UI_PASS, 996 actual source inputs verified, Xcode 27.2 (27B52), Apple Swift 6.4.2 and iOS Simulator SDK 27.2. Its runtime NOT_RUN is a pre-UI stage field; it does not erase the later actual leaves.

Runtime job 136246398292 started 11:08:25 UTC and completed/cancelled 13:41:08 UTC. GitHub reports the runtime step from 11:09:34 through 13:29:03 UTC as cancelled. The watcher observed exit at 13:41:21.564231 UTC. The raw INDEX timeline continues after the API step timestamp; these observations are retained separately.

**The cancellation actor and cause remain unknown.** A cancelled step or elapsed duration is not a diagnosis of a specific timeout, user cancellation, compiler failure or app fault. This collector made no dispatch, retry or cancellation request.

## Verified failures and current repairs

- HanlinReaderConsumerAcceptanceTests/testOriginalIPadCurrentWorkReadConsentReopensAndRevokesWithoutSending: XCTAssertTrue failed
- HanlinReaderConsumerAcceptanceTests/testOriginalReaderChatReturnsToSameNativeWorkspace: XCTAssertTrue failed: throwing "NSInternalInconsistencyException: Invalid query - string identifier 'This conversation uses your messages and permitted catalog metadata. Book search is off unless you allow the displayed book. Selections are not shared.' exceeds maximum length of 128 characters. You can work around this limitation by constructing a query with a custom NSPredicate that specifies the property (label, title, value, placeholderValue, or identifier) to match against." - Opening the reader chat must not imply permission to read the current book
- NativeRoutingAcceptanceTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPad: XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The original TextKit text and exact source locator must both match independent SQL
- NativeRoutingAcceptanceTests/testCoreNoteDraftUsesOriginalUnsavedEditorAndCancelOnPad: XCTAssertEqual failed: ("Optional("cancelled")") is not equal to ("Optional("completed")")
- NativeRoutingAcceptanceTests/testCoreSearchOpenResultsUsesOriginalCompletedEngineOnPad: XCTAssertEqual failed: ("Optional("unavailable")") is not equal to ("Optional("completed")")
- StudyGroupStressNativeAcceptanceTests/testOneHundredConsecutiveOriginalGroupSwitchesPreserveDocumentsAndColdRestore: Test exceeded execution time allowance of 10 minutes
- StudyProfileNativeAcceptanceTests/testProfileColorSaveCancelAndColdRelaunchPreserveWorkspace: XCTAssertTrue failed
- GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit: Dynamic Type font sizes are partially unsupported
- R27NativePadTests/testNormalBootstrapGlobalHistoryUsesActualSubmit: XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The original Return submission must settle and persist in its own installation before relaunch

The first two Hanlin failures have narrow source repairs 8d42 and b371. The original Note editor witness has placement repair 19b68. ProfileColor now has interaction repair 0a493. INDEX has a separate original-metadata timestamp analysis and test-only repair d2f10 with 33 portable controls. These changes are pending actual Native rerun and do not convert this run's failures to success.

The normal-bootstrap History failure remains distinct from the canonical query/relaunch case that passed. Its initial unavailable label does not prove a missing database; an unreadable preference observation also does not by itself identify the writer failure. The Dynamic Type issue identifies a UILabel but no usable element. The 100-switch case actually exceeded 600 seconds before completing its original 100 transitions; newer process metrics are not acceptance.

## Evidence integrity and limitations

The full small artifact is ID 14632383919, 35,944,918 bytes, SHA256 1dec4baa131deaa5cfdb1f2f62b3dea6a84ee7713bccf67a2e62a41f1ff72310. Its 102 original ZIP members and all CRCs were actually checked before disconnection. This packet includes the verification receipt and retrieved projections, not the ZIP itself.

Capture artifact 14632274701 has 775,094,118 bytes. Its advertised SHA is preserved, but **its full archive hash was not verified** because only authenticated HTTP206 ranges and selected entries were downloaded. Complete range files and selected originals remain on Windows for later sealing.

Receipt summary/tree hashes use canonical sorted JSON, while the original pretty JSON bytes have different raw SHA values. The four distinctions were actually recomputed and are retained. New JSON projections in this packet are explicitly serialized representations; they are not labeled byte-identical raw archive files.

No task is closed by this report. All 98 required cases, including iPhone and HID, still need their original acceptance on the final selected source. Full raw publication remains an explicit follow-up when the host returns.
