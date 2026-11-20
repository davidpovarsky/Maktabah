# Native repair12 original finalized outcomes

Run 44673191816; checkout 6030087e27f75b26d9a9bb144ba9ba71eaddadc5; app/tests 461de9aaee620d4275a1676ce8e1c230eb8e27ad.

| Group | Original case | Actual result | First finalized failure |
|---|---|---|---|
| 11 | `HanlinReaderConsumerAcceptanceTests/testOriginalIPadCurrentWorkReadConsentReopensAndRevokesWithoutSending` | **Failed** | XCTAssertTrue failed HanlinConsumerAcceptanceTests.swift:234 |
| 11-search | `GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit` | **Failed** | Contrast failed GlobalSearchNativeAcceptanceTests.swift:482 |
| 11-reader | `NativeRoutingAcceptanceTests/testPublicV2InspectorPreservesOriginalReaderAndWorkspace` | **Failed** | XCTAssertTrue failed - A hidden panel or model flag is not visible presentation NativeRoutingAcceptanceTests.swift:1523 |
| 11-reader | `NativeRoutingAcceptanceTests/testPublicV2InspectorRequiresVisibleOriginalReader` | **Failed** | XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Root opening needs one canonical actual visible receipt NativeRoutingAcceptanceTests.swift:735 |
| 11-reader | `NativeRoutingAcceptanceTests/testPublicV2NewTabOpensOtherBookAndPreservesOriginalReader` | **Failed** | XCTAssertTrue failed NativeRoutingAcceptanceTests.swift:641 |
| 11-reader | `NativeRoutingAcceptanceTests/testPublicV2NewTabSameBookCreatesDistinctOriginalReaderTab` | **Failed** | XCTAssertTrue failed NativeRoutingAcceptanceTests.swift:641 |
| 11-reader | `NativeRoutingAcceptanceTests/testSystemAppIntentShowsOriginalReaderInspector` | **Failed** | failed: caught error: "Error Domain=OtzariaUIRouting.UIRouteError Code=1 "The operation couldn’t be completed. (OtzariaUIRouting.UIRouteError error 1.)" UserInfo={NSLocalizedDescription=The operation couldn’t be completed. (OtzariaUIRouting.UIRouteError error 1.)}" NativeRoutingAcceptanceTests.swift:1586 |
| 11-sidebar | `BookHistoryScopeAcceptanceTests/testBookSearchRetainsControlsWithoutGlobalHistory` | **Passed** |  |
| phone | `HanlinReaderConsumerAcceptanceTests/testOriginalPhoneCurrentWorkReadConsentReopensAndRevokesWithoutSending` | **Failed** | XCTAssertTrue failed HanlinConsumerAcceptanceTests.swift:210 |
| phone | `NativeRoutingPhoneAcceptanceTests/testPhonePublicV2InspectorPreservesOriginalReaderAndWorkspace` | **Passed** |  |
| phone | `NativeRoutingPhoneAcceptanceTests/testPhonePublicV2NewTabPreservesOriginalReader` | **Passed** |  |
| phone | `NativeRoutingPhoneAcceptanceTests/testPhoneSystemAppIntentShowsOriginalReaderInspector` | **Failed** | failed: caught error: "Error Domain=OtzariaUIRouting.UIRouteError Code=1 "The operation couldn’t be completed. (OtzariaUIRouting.UIRouteError error 1.)" UserInfo={NSLocalizedDescription=The operation couldn’t be completed. (OtzariaUIRouting.UIRouteError error 1.)}" NativeRoutingAcceptanceTests.swift:1622 |
