# Hanlin preview357d consumer boundary — documentation only

Reviewed at the next UI02 checkpoint: HQ `docs/otzaria/ui-routing/HANLIN_CONTRACT_REVIEW_357D_20261115.md`, delivered by the existing dispatcher. This records the consumer implications of that review; it is not an independent SDK source review or live integration acceptance.

Original reviewed input was HanlinAgentSDK 0.1.0-preview.1 / HostAPI major 1 at `357d0042809c2c71bc6725466994b2adbaadf3da`, whose SDK-owned freshness/revocation P1 blocked live dispatch. That specific source hold is now cleared at corrected `08b5d6f31153063c31be321fbd35c7301f302fc1` as described below. The actual distributable dependency graph/approved ChatUI entry, accepted semantic/scene ports and Apple/native proof remain required before live integration. No host-side workaround, SDK/Platform copy or duplicate dispatcher is introduced here.

## Corrected source disposition: 08b5d6f3

Read the exact delivered `HANLIN_CONTRACT_08B_MANIFEST.json` and corrected disposition in the HQ review. Hanlin independent source QA accepted the reported revocation-await P1 correction at `08b5d6f31153063c31be321fbd35c7301f302fc1`, parent357d. The dispatcher reports it reviewed the exact correction and verified six public contract/manifest blobs unchanged. This permits typed-port review against the corrected input; it does not activate live UI06 or certify the native host graph.

The reported 32 portable passes belong to the Hanlin writer; independent Hanlin QA matched 28 actual inputs to corrected Git bytes. No SDK tests were executed or reattributed by UI02. Existing host-owned identity/lifetime, complete receipt, exact-number and non-success-status boundaries below are unchanged. Canonical Hanlin UI entry/product, package distribution, accepted semantic/scene ports and actual Apple SDK/native UI proof remain open gates. The UI02 source/API and deployment metadata are unchanged; prior 24/0 UI02 and focused Core 1/0 evidence is retained, not rerun.

## Separate identities and lifetimes

The SDK's scene ID and presentation generation are UUIDs. UI02/Core scene IDs are host-supplied strings (`UIStableID` at the UI boundary); Core backend generation is UInt64, RPC epoch is a separate optional UInt64, and UI scene revision is another UInt64. These represent distinct authorities and lifetimes. Do not parse UIKit session identifiers as UUIDs, derive UUIDs from counters, merge generations or reinterpret one revision as another.

The future host adapter owns a bounded one-to-one association with the real native scene/session plus a separately issued presentation-generation UUID. It invalidates the association on the actual auth/profile/workspace/backend/scene/document/selection/permission lifetime change. Keep the original namespace and target pinned through awaits; SDK freshness checks do not replace native/Core pre-commit validation. No additional public UI02 ID, counter, namespace or permission mechanism is required for this adaptation.

## Complete route acknowledgement

`UISceneCommand` already retains the complete `UIValidatedRoute`, invocation and trusted pre-commit `UISceneSnapshot`. `UISceneReceipt.validate(for:observed:)` compares the full normalized route, request, backend snapshot, scene, prior/applied revision and trusted observed visible route. This includes the prepared presentation/tab, component visibility/expansion, sheet/sidebar/inspector, selected item, focus/UTF-16 selection, workspace/profile state and qualified content. Content also requires an exact Core receipt. SDK object/block equality alone cannot establish that the requested UI was presented.

For a non-content surface, a future host may expose an opaque, scoped, revocable handle to that immutable authorized registry route. It must keep the complete route behind the handle, bind it to the exact invocation/namespace/lifetime and enforce size/expiry/restart behavior. Do not invent a book/line, put private state in an SDK object/block string or public URL, or introduce persistent duplicate business identities. The current package supplies no such handle store or SDK adapter.

Queue-only stays queued. Missing/ambiguous/unready/unsupported/stale/confirmation-required outcomes remain structured non-success; never translate them to SDK completed/presented. Check the actual native receipt before acknowledging presented. Cancellation/revocation after native dispatch must preserve truthful effect uncertainty rather than assert rollback or no effect.

## Numbers, authority and discovery

Adapt Hanlin's integer and number cases directly to the corresponding Core `ActionJSON` cases. Do not encode a Double to JSON and decode it back as an integer: even an integral-looking Double cannot restore the original exact integer provenance. Reject number/fraction/overflow for integer fields before any lossy conversion. UI02's raw codecs already reuse Core's exact-number parser/schema, and existing portable tests cover fractional integer rejection and UInt64.max scene/backend revisions. They do not certify an unwritten typed SDK adapter.

The adapter must use the single Core actor/validator and the actual authorized/readiness-filtered Core/UI discovery. Context, namespace, scene generation/revision and rights are trusted host data, never model parameters or authority restored from RouteSpec. An opaque selection reference is not a content-read grant. SDK sourceRevision is freshness metadata, not CAS or durable idempotency. No persistent mutation is enabled by this contract.

## Platform and acceptance limits

The reviewed SDK preview is reported to require iOS27/macOS26/tools6.2, with a local HanlinPlatform edge and pinned SwiftAISDK dependency; its root distribution and approved ChatUI product remain absent. This supersedes any inference that an SDK consumer can use the earlier Platform-only iOS26 minimum. A future accepted SDK adapter/host graph must satisfy the SDK's actual requirements. UI02 remains SDK-independent with iOS26 package metadata and no Apple framework calls; no target fallback, deployment change, machine-specific dependency path or SDK import was made.

This documentation update leaves the implementation at `0c502e107f7d9f90611672f55fb0d65ff0ee61b2` unchanged. All 18 source/fixture/manifest hashes and their committed Git blobs in `results/summary.json` are checked unchanged; existing UI02 24/0 portable and focused Core 1/0 evidence is retained, not rerun or extended to SDK behavior. Full SDK adapter/native/device tests remain NOT_RUN. Future shared adapter tests must use the corrected frozen SDK and accepted UI ports, including wrong route/presentation/selection with the same UUID, invalidation across awaits, integer/Double boundaries, queued results and post-dispatch revocation. T/Q's existing R27 app tests cannot certify this unwired package or the SDK.
