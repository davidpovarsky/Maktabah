# Phone TOC local-state retirement and original presentation correlation

This follow-up changes exactly two app sources after dd2e7bf73b1716cdb9723a7de3e5bf51681a9d85. It preserves that original packet and its 19 setter, 26 lifecycle and 12 SQL/TOC controls independently.

## Change and source scope

The original Notes annotation setter now synchronously retires the existing phone TOC source before its unchanged body. All four existing note-error set/clear sites use an identical-write helper with the same retirement. This closes local SwiftUI State A-to-B-to-A histories that final-value getters or Reader Observation cannot prove. The original Notes host/callback/UUID behavior stays unchanged. The source read-set audit mechanically recovers the previous workspace byte-for-byte by removing only this follow-up.

A read-only isContinuingOriginalReaderPresentation(requestID:) facet correlates the pending request with its exact active source in presented phase and validates that original proof. It allows Session to wait for its own original Reader push after the exact selectedBook transition, before the apply flag is set. It does not call the Session admission validator, alter source/permission, or relax the existing first-mount applied requirement.

## Executed controls

The final attempt-4 compiles actual original setter fragments, the entire final phone class, and actual shared Observation/contracts with explicit domain/local-State storage boundaries under Swift 6 strict concurrency on Oracle. Five controls pass. Removing only the two new source-retirement hooks leaves two passes and causes the three expected failures, exit 1. These are actual source/component controls, not SwiftUI or Apple SDK execution.

Both final app files parse for arm64-apple-ios27.0-simulator. This is syntax only. Required app acceptance remains iOS/iPadOS 27; there is no legacy-runtime acceptance requirement.

Attempt-1 timed out in the outer command wrapper and has no fabricated result. Attempt-2 passed the three local-State controls before the correlation facet. Attempt-3 exposed an incorrectly discarded harness attachment owner: its real deinit correctly revoked the source. The fixture now retains that owner with withExtendedLifetime; product bytes were unchanged, and both failed logs remain. The final attempt-4 records the corrected fixture and all exact source hashes.

No app, simulator, physical device, signing or upload ran in this follow-up. Native and physical counts remain zero.

## Integration and peer review

Apply only this follow-up after dd2e. Shared Session/routing files, project membership, localization, original acceptance tests and all peer sources are untouched. The shared UI owner requested and reviewed the read-only facet and will consume it in its separate phone routing packet. Its subsequently reported 29-case integrated setter run is separate evidence and is not counted in this packet.

The adjacent wave3-wave2-intake-review-20261127 report records read-only review of Inspector and Reader-observer deliveries against root 0de27555. Its generation-cache repair and bounded DEBUG observation are recommended for selective intake with native acceptance pending. The existing parent-owned preferredMode question was sent through the established Wave2 inbox as a pending native case, not as a reproduced regression.

See SOURCE_AND_ACCEPTANCE.json, SOURCE_READ_SET.json, FINAL_IOS27_SYNTAX.json and the immutable per-attempt files for exact bindings.
