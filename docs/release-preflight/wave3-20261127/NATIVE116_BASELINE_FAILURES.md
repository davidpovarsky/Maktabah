# Native116 historical baseline: exact failures

This is a transcription of original Apple summary evidence, not a new test run or a claim that every old failure remains at the current candidate. Source application `f2e3fecbd3e6f36d8a8b7edd7c95e6015acb48fb`; control checkout `ec14460748dc79818b1a7a3f269a54e3a1ddfaa9`. Original baseline digest `0754ec183a78623bd2392a8250bb32e7e1e922d9c181584f0992da5090066c64`.

All destinations used arm64 iOS Simulator 27.0 (24A434). No physical-device credit.

| Group | Passed | Failed | Skipped | Device |
| --- | ---: | ---: | ---: | --- |
| 11-index | 5 | 0 | 0 | iPad Pro 11-inch (M5) |
| 11-reader | 33 | 8 | 0 | iPad Pro 11-inch (M5) |
| 11-search | 19 | 3 | 0 | iPad Pro 11-inch (M5) |
| 11-sidebar | 5 | 0 | 0 | iPad Pro 11-inch (M5) |
| 11-window | 0 | 2 | 0 | iPad Pro 11-inch (M5) |
| 11 | 7 | 5 | 0 | iPad Pro 11-inch (M5) |
| phone | 13 | 16 | 0 | iPhone 18 Pro |

Total: **82 passed, 34 failed, 0 skipped, 116 selected cases**. The JSON file contains exact messages and per-summary SHA-256. Existing passing/failing evidence remains bound to its original source.

## 11-reader

Summary SHA-256: `9bf25c00d91339eca15167ea86e1a19667a84030f892f8eb926464e056089d32`.

- `NativeRoutingAcceptanceTests/testAnnotationsPublicRootShowsOriginalScreenAndNativeReceipt()`

  XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Root opening needs one canonical actual visible receipt

- `SefariaTOCLocalizationPadAcceptanceTests/testEmbeddedEnglishChapterAndComplexTOC()`

  XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Require one actual visible, hittable original control: toc-expand--16525

- `SefariaTOCLocalizationPadAcceptanceTests/testEmbeddedEnglishTalmudTOCAndCanonicalNavigation()`

  XCTAssertEqual failed: ("0") is not equal to ("1") - Require the original localized structure label

- `SefariaTOCLocalizationPadAcceptanceTests/testEmbeddedHebrewChapterAndComplexTOC()`

  XCTAssertEqual failed: ("הרחב את ⁨פרק ב׳⁩") is not equal to ("הרחב את פרק ב׳")

- `SefariaTOCLocalizationPadAcceptanceTests/testEmbeddedHebrewTalmudTOCAndCanonicalNavigation()`

  XCTAssertEqual failed: ("Optional("ב")") is not equal to ("Optional("ברכות")")

- `NativeRoutingAcceptanceTests/testPublicV2TOCWithoutOriginalReaderCannotAcknowledge()`

  XCTAssertTrue failed

- `SefariaTOCLocalizationPadAcceptanceTests/testRemoteEnglishLoadingFailureAndOriginalRetry()`

  XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Require one actual visible, hittable original control: toc-loading

- `SefariaTOCLocalizationPadAcceptanceTests/testRemoteHebrewLoadingFailureAndOriginalRetry()`

  XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Require one actual visible, hittable original control: toc-loading

## 11-search

Summary SHA-256: `fd908e0993f2ddc4574f1f6645887a32b0a49a3a58d9e62c4a7947ea6a04726c`.

- `GlobalSearchNativeAcceptanceTests/testExactAndFuzzyHideAdvancedOtzariaBindings()`

  Failed to get matching snapshots: Application com.davidpovarsky.chavrusatext is not running

- `GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit()`

  Dynamic Type font sizes are partially unsupported

- `R27NativePadTests/testNormalBootstrapGlobalHistoryUsesActualSubmit()`

  XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The original Return submission must settle and persist in its own installation before relaunch

## 11-window

Summary SHA-256: `1e5561265e255fa2a48f333e1dcda37f34128d9db4693c2f440d62eacbecacf3`.

- `R27NativePadTests/testNormalBootstrapNativeWindowResizePaletteAndInspector()`

  XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The actual window must expose the original Study Tools action or its native top overflow

- `R27NativePadTests/testNormalBootstrapPaletteHIDComparison()`

  XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The actual window must expose the original Study Tools action or its native top overflow

## 11

Summary SHA-256: `b6824da9ac87eb6961e48c405f06a8c67c140150f27805b9b932b62f908de69b`.

- `NativeRoutingAcceptanceTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPad()`

  XCTAssertTrue failed

- `NativeRoutingAcceptanceTests/testCoreNoteDraftUsesOriginalUnsavedEditorAndCancelOnPad()`

  XCTAssertEqual failed: ("Optional("cancelled")") is not equal to ("Optional("completed")")

- `HanlinReaderConsumerAcceptanceTests/testOriginalIPadCurrentWorkReadConsentReopensAndRevokesWithoutSending()`

  XCTAssertTrue failed

- `NativeRoutingAcceptanceTests/testSemanticCommentaryThenDraftPreservesLocatorAndBaseOnPad()`

  XCTAssertNil failed: "semantic_commentary_draft_failed" - ["errorType": CommentaryDraftFailure, "probeError": semantic_commentary_draft_failed]

- `NativeRoutingAcceptanceTests/testSemanticCountThenOpenResultsKeepsExactWorkScopeOnPad()`

  XCTAssertEqual failed: ("Optional(false)") is not equal to ("Optional(true)")

## phone

Summary SHA-256: `3f4c72012a2504064fdec58a0c6176412accd2d9894aa7201e6ac823b6c1a7df`.

- `NativeRoutingPhoneAcceptanceTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPhone()`

  XCTAssertTrue failed

- `NativeRoutingPhoneAcceptanceTests/testCoreExactTokenCountUsesOriginalManagedCorpusWithoutNavigationOnPhone()`

  XCTAssertTrue failed

- `NativeRoutingPhoneAcceptanceTests/testCoreNoteDraftUsesOriginalUnsavedEditorAndCancelOnPhone()`

  XCTAssertEqual failed: ("Optional("cancelled")") is not equal to ("Optional("completed")")

- `NativeRoutingPhoneAcceptanceTests/testCoreSearchOpenResultsUsesOriginalCompletedEngineOnPhone()`

  XCTAssertTrue failed

- `SefariaTOCLocalizationPhoneAcceptanceTests/testEmbeddedEnglishChapterAndComplexTOCOnPhone()`

  Failed to determine hittability of "toc-content-list" CollectionView: Activation point invalid and no suggested hit points based on element frame

- `SefariaTOCLocalizationPhoneAcceptanceTests/testEmbeddedEnglishTalmudTOCAndCanonicalNavigationOnPhone()`

  XCTAssertTrue failed

- `SefariaTOCLocalizationPhoneAcceptanceTests/testEmbeddedHebrewChapterAndComplexTOCOnPhone()`

  Failed to determine hittability of "toc-content-list" CollectionView: Activation point invalid and no suggested hit points based on element frame

- `SefariaTOCLocalizationPhoneAcceptanceTests/testEmbeddedHebrewTalmudTOCAndCanonicalNavigationOnPhone()`

  XCTAssertTrue failed

- `R27NativePhoneTests/testNormalBootstrapGlobalHistoryUsesActualSubmit()`

  XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The original Return submission must settle and persist in its own installation before relaunch

- `R27NativePhoneTests/testNormalBootstrapOtzariaBackgroundAndColdRestoration()`

  Failed to determine hittability of "reader-text" TextView: Activation point invalid and no suggested hit points based on element frame

- `HanlinReaderConsumerAcceptanceTests/testOriginalPhoneCurrentWorkReadConsentReopensAndRevokesWithoutSending()`

  XCTAssertTrue failed

- `NativeRoutingPhoneAcceptanceTests/testPhoneColdHistoryWaitsForActualSceneMount()`

  XCTAssertTrue failed

- `SefariaTOCLocalizationPhoneAcceptanceTests/testRemoteEnglishLoadingFailureAndOriginalRetryOnPhone()`

  Failed to determine hittability of "toc-content-list" CollectionView: Activation point invalid and no suggested hit points based on element frame

- `SefariaTOCLocalizationPhoneAcceptanceTests/testRemoteHebrewLoadingFailureAndOriginalRetryOnPhone()`

  Failed to determine hittability of "toc-content-list" CollectionView: Activation point invalid and no suggested hit points based on element frame

- `NativeRoutingPhoneAcceptanceTests/testSemanticCommentaryThenDraftPreservesLocatorAndBaseOnPhone()`

  XCTAssertNil failed: "semantic_commentary_draft_failed" - ["probeError": semantic_commentary_draft_failed, "errorType": CommentaryDraftFailure]

- `NativeRoutingPhoneAcceptanceTests/testSemanticCountThenOpenResultsKeepsExactWorkScopeOnPhone()`

  XCTAssertTrue failed
