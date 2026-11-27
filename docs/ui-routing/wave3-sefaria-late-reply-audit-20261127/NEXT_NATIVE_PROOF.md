# Smallest legitimate future live late-reply proof

This is a design proposal following a read-only audit, not an implemented hook, reserved file lease, or executed test.

## Existing behavior must remain authoritative

The original native bridge assigns the request ID, records the in-flight continuation, dispatches through the original RN NativeEventEmitter, and consumes the original facade response through deliverResponse. Original epoch reset cancels/removes in-flight requests. A real old reply then reaches the existing missing-request discard branch. A test must preserve that behavior; it must not keep a cancelled request artificially alive merely to force STALE_GENERATION.

The real diagnostic.echo facade currently has no delay/hold option. Passing a new unused JSON field, sleeping only in Swift, swapping setJSExecutor/transport, using RuntimeFixtureTransport, invoking handleIncomingResponse with a fabricated response, or changing generation privately would not establish a live Hermes delayed-reply result.

## Exact evidence required

1. A bounded diagnostic request is actually received by the existing original JS facade on the current native request ID and epoch. Observe the real JS receive boundary before causing reset; Swift enqueue alone is insufficient.
2. Original runtime reset or another already-authorized original lifecycle transition advances the epoch and cancels the original pending continuation. Preserve the actual cancellation code/outcome.
3. The very same original JS operation completes later and delivers its original response through ChavrusaSefariaBridgeModule. Observe the exact request/old-generation metadata at the actual actor response-disposition boundary.
4. The actual bridge discards it through its original no-in-flight/stale path, without a second continuation resume, fresh authority, or changes to the new runtime's source state.
5. A new ordinary echo through the same live transport/current epoch succeeds with matching ID/backend/generation. Completion of that echo alone cannot replace evidence that the old response actually arrived and was discarded.

Every wait must be structured and deadline-bound; timeout/failure/cancellation remains failure/NOT_RUN. All source/bundle/App/execution identities and raw observations must be retained. A read-only source control can prove logic but cannot close this live result.

## Narrow prospective source lease

If root elects to implement a deterministic native test, the smallest faithful extension is bounded support inside the existing downstream diagnostic.echo handler itself, plus strictly observational request/response-disposition metadata at the existing original bridge. The request must still traverse the normal NativeEventEmitter/Hermes/facade/native response path. There should be no alternate transport, fabricated response, fake ready event, replacement ReaderApp, or upstream pin edit.

A JS diagnostic started observation and actual actor discarded-response observation are needed to remove scheduler guesses. They must carry only request identity/epoch/nonce/disposition, not user content, and have exact per-run cleanup. The observation must never become source authority or change dispatch/cancellation behavior. Delay must be explicitly bounded by the original request deadline and restricted to diagnostics, rather than leaking an unbounded production operation.

Likely files, subject to explicit root/Wave2 coordination: Vendor/SefariaMobile/Integration/JS/chavrusaRPCFacade.js; original SefariaJSRPCBridge observational hooks; downstream SefariaEmbeddedAcceptanceDiagnosticRunner; original acceptance selector/negative controls. Original upstream2fd173a5 and all existing native assertions remain fixed.

Using surface.awaitVisible instead may be legitimate only when a genuine current native-owned mount naturally has a pending observation and its exact actual lifecycle can be controlled. The current registry does not provide a general diagnostic hold controller, and a synthetic never-mounted identity cannot satisfy the original surface requirement.

## Original requirement mapping

UI-03 requires the Embedded RN surface through bridge/epoch/ready. UI-07 requires invalid/stale identity, Hermes ready/reset/no transport, cancellation and exact UI acknowledgements. The original native full-acceptance test separately names lateGenerationRejected as a mandatory report stage. This audit found no exact lateGenerationRejected literal in the bounded Asana source notes; the exact quoted clauses and task IDs are recorded separately.
