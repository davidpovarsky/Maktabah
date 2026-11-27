# Native feature App Intents — Wave 3

The original generic native destination action is retained. This change adds three semantic actions in the original ChavrusaUIRoutingHost package: OpenSettingsSectionIntent, OpenReaderContentsIntent and OpenReadingHistoryIntent. The Settings action exposes the existing fifteen finite Settings anchors; contents exposes the existing TOC root and its three finite anchors; history exposes the existing history root. Entity identifiers retain the original backend, scene and component identities.

All three actions resolve the complete original metadata catalog, validate it, narrow it to their own feature, and call the original NativeIntentService.open. Fresh foreground discovery, the original permission/route orchestrator and NativeIntentOutcome.requireVisibleAcknowledgement remain authoritative. Metadata, queued work, foreground requests, backend-switch requests and cancellation do not become successful visible acknowledgements. Feature filtering happens before the original exact-title query so an unrelated exact title cannot hide a relevant feature control.

The original 6,186-byte NativeIntentService implementation is byte-preserved before the additive extension. Existing App Shortcuts and phrases are unchanged. SwiftPM includes the new file through the existing package source layout; no app PBX membership is needed for this package file. The string catalog adds ten Hebrew/English entries, including the separately coordinated Open query input title; all 693 existing entries remain unchanged.

## Verification

- Actual SwiftPM on Oracle compiled the original Actions, UIRouting and UIRoutingHost packages and ran 9 new NativeFeatureIntentServiceTests plus 26 original NativeIntentServiceTests: 35 passed, 0 failed. No replacement Core/routing modules or model doubles were used; injected host discovery/navigation closures are the original service test boundary.
- Actual Apple SwiftPM compiled the complete Host target and original local package dependencies for arm64-apple-ios27.0-simulator against Xcode 27.0 SDK. Build exit 0, empty compiler stderr. The new NativeFeatureIntents.o is a real arm64 Mach-O object with IOSSIMULATOR build metadata and compiled symbols for all three actions.
- xcstringstool compiled the full 703-entry catalog successfully. This verifies syntax and compilation, not in-app locale presentation.
- Exact 156-file Apple input manifest was verified before and after compilation. All transported evidence members were checked by SHA-256.
- Raw original results and logs are retained under evidence. The original Apple result's Modules glob did not match SwiftPM 27's actual out/Products layout; a separate ARTIFACT_OBSERVATION.json records the real modules and object without rewriting that original receipt.

Original Linux RESULT SHA-256: 13d750b3ab19037e0c54239a923944407743efef04be48f5723e9d2b7aba596f.
Original Apple RESULT SHA-256: b5b93aadec62edf67efa9be28fa0b8c1a8a81ea5d76679c7ad6c202ba93a6f2b.
Apple artifact observation SHA-256: ac95cb3b89899d25350b79c6f70d1ad0f6a7b32314ebab6ccb34989f802a858a.

## Acceptance still required

These are source/component checks. This packet does not claim a full Maktabah build, native UI execution, Siri speech recognition, Shortcuts installation/invocation, physical-device verification or release approval. Those must run on the integrated qualified candidate. Final owner signatures and provenance checks must bind the changed source.

The actions cover only these already implemented finite destinations. They do not implement search results/cursors, bookmarks, arbitrary record selection or a new permission/backend path. The remaining original UI-03/UI-04 requirements remain open in the integration inventory.
