# Native98: exact Hanlin consent-label lookup

The actual Native98 run44723902453, attempt1, F60a57972acb28739ec738565083bf17fb7503028 / M87b783ac3f0257e8461762e0ea9dfa5248dd06e8, reached the original Reader chat and failed HanlinReaderConsumerAcceptanceTests/testOriginalReaderChatReturnsToSameNativeWorkspace at HanlinConsumerAcceptanceTests.swift:179. XCTest raised NSInternalInconsistencyException because the string-identifier subscript exceeded its128-character maximum. The complete explanatory label is151characters. The original error explicitly directs callers to a predicate against label/title/value/placeholderValue/identifier.

The runtime evidence ZIP14632383919 was completely downloaded and verified:35,944,918bytes, SHA2561dec4baa131deaa5cfdb1f2f62b3dea6a84ee7713bccf67a2e62a41f1ff72310, all102CRC checks passed. The original case log excerpt and xcresult summary are retained. Other failures in that summary are not attributed to or repaired by this hunk.

## Narrow fix

Base9adf4a5b9a4f26929620e7b73b553700d3598b84. Only one existing assertion expression changes: staticTexts[string] becomes staticTexts.matching(NSPredicate(format:label equality, same complete string)).element.exists. The label is passed as a predicate argument, not an identifier or interpolated format. Exact text matching, element uniqueness, the assertion message, current-book permissionOFF, same reader/workspace/owner,20-second model field wait, close/cancel, and all other case bodies remain unchanged. There is no firstMatch, substring matching, retry, timeout extension, production UI, source action, permission or localization edit.

The entire original file in this branch is byte-identical to the file compiled in F60a before this one replacement. Its provenance is downstream Native acceptance. The canonical source inverse restores the whole original file byte for byte. No upstream application/engine/SDK file is touched.

## Verification and limits

Exact inverse and Git diff checks passed. One actual Windows Swift6.3.3 frontend syntax parse of the complete file exited0 at13:49:59UTC; this is not Apple typecheck or an XCTest execution. Independent source review found no concrete blocker and confirmed the full label is an argument, unique element semantics remain, and all existing acceptance gates are preserved.

AppleSDK and Native verification of the correction remain **NOT_RUN**. The original Native failure remainsFAIL. No permission, source ownership or global completion is inferred from this prepared fixture correction.

ARTIFACTS.json seals all raw source/proof/log evidence as deterministic gzip, with compressed and exact uncompressed SHA-256 and sizes. Source-before/source-after are canonical Git LF; the active run and frozen ref remain unchanged.
