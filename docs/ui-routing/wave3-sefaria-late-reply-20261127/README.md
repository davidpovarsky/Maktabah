# Original Sefaria late-reply diagnostic — source packet

## Status and exact source

Product/source commit: f03802af54b36bed1a326c6c0b197f60a6a04d34, based on root052d2a7f6d26da935a6d7847477e53d981f428cb. The source branch is codex/otzaria-wave3-sefaria-late-reply-20261127.

This packet implements the missing real-transport diagnostic path. It does not certify that the current app or Hermes has executed it. Native116, Release114+2, matching rebuilt Metro bundle, qualified app build, physical acceptance and TestFlight remain separate gates.

## Original path and observed sequence

The existing diagnostic.echo accepts an explicitly requested, bounded1–3000ms diagnostic delay, capped below the original request timeout (maximum10000ms). It emits a nonce/request/epoch receipt only when that real JS handler receives the request. Its actual response still returns through unchanged ChavrusaRoot and ChavrusaSefariaBridgeModule.

Stage4 retains one exact original bridge transport/epoch and observes: actual dispatch → actual JS receipt → original RuntimeManager.reset/cancelAll → actual old response reaches the original no-in-flight discard branch → fresh normal current-epoch echo. It also preserves the old-generation upfront rejection as a separate actual invocation. Missing, early, replayed, mismatched, expired or cancelled proof fails. Elapsed time alone never marks a stage passed.

The reset does not replace the RN transport/JS instance, so the original JS operation can really complete later. RuntimeManager.reset and ensureReady are unchanged; Stage5 still performs original initialization after reset. No private generation mutation, fabricated response, alternate transport or replacement UI was added to the application.

Observation only records this diagnostic request. It cannot grant authority, cancel or resume an RPC, change readiness, alter source epochs, or admit a native action. The existing handler retains all original response/cancellation behavior. Native metadata retires after the structured child RPC drains; the one bounded JS timer clears on completion/failure. A retired token cannot close a newer observer.

## Files and provenance

Three existing downstream product files change: the original bridge (observational metadata/hooks), original diagnostic runner (Stage4 plus optional evidence), and downstream JS facade (only diagnostic.echo). Existing runtime, RPC models, RN forwarding, native reader provider, surface provider, corpus checks and other diagnostic stages remain intact. Original Sefaria-Mobile upstream2fd173a5 is unchanged.

The original portable component harness now captures the actual current epoch after installing each test transport. Its five hardcoded generation arguments were the concrete reason the original protocol/backend/concurrency assertions could not reach their intended checks. The original assertions remain byte-identical.

Two focused source-control tools are added. No new application PBX membership is required; all product declarations live in existing app member files. The final app MUST rebuild/bind its original Metro bundle from the changed facade. An old bundle cannot satisfy the new real JS-start/late-response stage.

OWNERSHIP_PRE_EDIT.json records the live upstream SHA, merge base, file addition origins and exact pre-edit bytes. PRESERVATION_AND_FINAL_PINS.json proves the old entire bridge/facade/runner become byte-identical after removing only the declared additions/hooks, and that original harness bytes match after removing only the epoch substitutions.

## Executed source verification

| Group | Final result | Real boundary |
|---|---|---|
| Original Swift bridge/runtime/full diagnostic helper |31/31 PASS, Swift6.4.3 strict concurrency, empty final compiler stderr|Actual complete product sources; explicit controlled transport/library/native-domain doubles|
| Actual JS facade plus unchanged original RN forwarding function|26/26 PASS|Node24.22.0; explicit native-module/timer/engine doubles|
| Original JS baseline against same final controls|3PASS/23FAIL|Preserved negative baseline, not a product regression result|
| Original Suite36–38 bodies with old hardcoded epoch|5PASS/4FAIL|Actual current bridge, original test expectations|
| Exact same original bodies with captured active epochs|30PASS/0FAIL|Actual current bridge and original negative expectations|
| Hermes/app/native/Apple SDK acceptance|NOT_RUN|No Mac/build/simulator run in this packet|

Earlier attempt1 Swift26/26 and JS22/22 are retained historical iterations, not added to the final counts. The intermediate source-edit script assertion stopped before modifying the old harness; its failure and correction are retained. The original attempt1 control source was preserved from the exact executed write payload after its final additions; no historical PASS was relabeled to new source.

The final31 controls include exact nonce/request/backend/epoch/delay matching; absent/duplicate started events; early/wrong/duplicate/error/missing late responses; missing original reset; double reset; foreign transport; observation deadline; cancellation and child drain; helper failure cleanup; original lifecycle admission; one live observer; retired-token lifetime. The actual helper's source is compiled completely, with only a same-file test-access extension appended. Source control results do not stand in for Hermes.

Every compiler command, raw stdout/stderr, input copy/hash and first/final attempt is retained under evidence. Compiled binaries remain in the owned Oracle evidence path and are hashed in RETAINED_BINARIES.json rather than committed as payloads.

## Independent review

The UI routing sibling independently read the four-file source diff at f038 and found no blocker in passive metadata, original reset/cancellation/transport identity, nonce/request lifetime, structured child cleanup, bounded JS timer and preserved original component assertions. That is source review only; it did not rerun tests or certify Hermes/native behavior.

## Next actual gate

Run the existing unchanged SefariaEmbeddedAcceptanceTests/testEmbeddedSefariaFullAcceptanceDiagnostic in the final qualified app with matching newly rebuilt JS. Its existing mandatory stage list and assertions remain unchanged. Stage4 must return its actual lateReplyEvidence; all original corpus/search/native-reader/RN-surface/runtime/backend checks still have to pass. A failure stays a failure and physical-device acceptance remains unexecuted until the owner performs it.

## Raw-byte preservation format

Five original raw evidence files contain pre-existing trailing whitespace or valid diff context spaces. Their exact bytes are stored losslessly as gzip, with raw and stored hashes in LOSSLESS_RAW_EVIDENCE.json; the original uncompressed files remain in the owned execution evidence directory. The documentation whitespace-check failure is preserved. No product check or assertion was disabled, and no raw evidence was normalized.
