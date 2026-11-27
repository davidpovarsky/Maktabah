# Original component wiring and retained-source lifetime

Base: 1557749e0587b7e895e7d22c7c43486a9f44bd28.
Current upstream observed independently by integration: 4203de5fd77beb119e5826e039be1a61325f7be0. This is not an upstream sync.

## Change and original contracts

The existing scene owns one factory each for Settings, the original Library, and the original Table of Contents. The existing registry and public binding now admit only the six fixed Library/TOC anchors implemented in peer94e5b08c, in addition to the fifteen Settings anchors. Original destination, presentation, source identity and exact visible witness remain required. Component tokens never execute a button or edit feature data.

NativeComponentSourceObservation records the first actual Observation publication synchronously using withObservationTracking and Synchronization.Mutex. Restoring a value or model cannot rescue a captured request. There is no reset, rearm, queued invalidation task or fresh canonical grant. Explicit invalidation is one-way and is used only by original source publishers.

The application wrapper subscribes to the actual BackendCoordinator.objectWillChange publisher and retains its AnyCancellable. BackendCoordinator is @Published, not an Observation model. Exact coordinator identity, active backend, monotonic generation and transition readiness are checked in addition to the latch. An aborted backend transition therefore cannot disappear from captured source history.

Settings retains its original shared model, original migration owner, backend lifetime, bundle-mode value, relevant conditional/control fields and collision alert state before the first Core await. Its original local FTS overlay setters synchronously retire presentation ownership. A monotonic local presentation revision also invalidates a source retained before begin(). This handles a complete local overlay open/close cycle without claiming that SwiftUI State is Observation or relying on coalesced onChange delivery.

Peer688ed61e9db646795a28c771bdebc3ee8b70bdad uses this wrapper over verified Library/TOC read sets and preserves exact object/node/backend snapshots. Integrate it with this API. Non-Observable TOC node fields remain snapshot-checked; Observation is not claimed to detect arbitrary in-place edits to non-Observable objects.

## Ownership and protected delta

| Files | Ownership and origin | Change and reason | Alternative / verification |
|---|---|---|---|
| Source/Features/Setting/SettingsView.swift | UPSTREAM_OWNED; pinned upstream blob96b116fe791d46a4c940e5ad3f0c5a21420de020 | Three hooks immediately before original FTS overlay assignments; actions/values unchanged. | Downstream helper owns cancellation. A later onChange can miss a cycle. Diff reviewed; native runtime pending. |
| Integration MaktabahNativeComponentBinding.swift and MaktabahNativeSettingsComponents.swift | DOWNSTREAM_OWNED; absent at pinned upstream | Original Observation/Combine lifetime bridge and Settings source capture. | Existing models/publishers/controls retained; syntax passed, Apple SDK pending. |
| Integration MaktabahNativeSceneSession.swift, MaktabahNativeRoutingComposition.swift, MaktabahNativePublicBindingAdapter.swift | SHARED_INTEGRATION_SEAM; downstream paths absent at pinned upstream | Two actual factories and finite six-anchor catalogs in existing routing. | No new executor/grant/wildcard; root Notes selection and annotations reobservation preserved. |
| Portable NativeComponentSourceObservation.swift and NativeComponentRevealOwner.swift | DOWNSTREAM_OWNED | One-shot invalidation and original-view presentation revision. | Nine actual Observation controls plus one local overlay control authored; execution stopped for measured capacity. |
| Portable owner/observation tests and this evidence | DOWNSTREAM_OWNED | Preserve earlier controls; add true value/model A→B→A, publisher, pre-begin overlay and completed-source checks. | No Native116/Release114 selectors/counts/timeouts/pass criteria changed. |

No localization, project membership, dependency version, owner signature, gate implementation, Notes binding or source-port file is changed. The new portable file uses existing SwiftPM discovery. Integration files were registered in the base.

The protected SettingsView delta needs fresh authentic source-bound attestation in the final workflow. Historical signatures are untouched. Native/physical/VoiceOver/production and original criteria stay open until executed.

## Verification

- Six application files passed active-iOS27 syntax parsing; this does not typecheck UIKit/SwiftUI/Combine against Apple SDK.
- Planned46 portable cases:11 reveal-owner,9 actual Observation,26 existing intent-service. The attempt stopped only its own process group after7.053seconds because free space was90,517,504bytes, below128MiB guard. No cases executed: **BLOCKED_CAPACITY**, not pass or product test failure.
- Supplemental cache-only typecheck could not locate OtzariaUIRouting through assumed legacy layout; actual prior cache uses out/Intermediates.noindex. Raw diagnostic retained. No compilation success inferred. Only the new failed-attempt module-cache subtree was removed after all timestamps matched that attempt; compatible prior cache preserved.
- Historical24f880be had36 portable passes on its earlier source; those do not qualify this change.
- Apple SDK compilation and new native cases are **NOT_RUN** here. Integration manager owns the combined build.

Exact source hashes and raw receipts are in VALIDATION.json and validation/. Rollback is the inverse scoped commit plus its dependent peer adapter ABA delta. Existing controls/data and earlier evidence remain preserved.


## Verified retry after restored capacity

Executed source809e35fdbcbd38ad6b04e771266d6f361c13b7ce passed all46 distinct portable cases:11 owner,9 actual Observation and26 intent service;0 failures,0 skipped,0.080seconds execution,25.762seconds build/run. Inputs were hash-verified unchanged before/after. Raw successful log SHA256:70338edfab2a2e90002626c57896f3e6f5e177fcbb067c241cc43c5985926542.

The first capacity-recovered retry on a2a8af49 reached the actual compiler, which rejected the two nested private test fixtures because Observation expands their conformances at file scope. Test-only809 changes those two access modifiers to fileprivate. All test behavior/assertions remain intact. The full Source tree therefore differs from a2; application and portable implementation files are unchanged. No earlier source run is retrospectively marked successful.

VERIFIED_RETRY.json records all46 actual case names, source differences and exact hashes. Both compiler-failure and passing raw logs are preserved losslessly as gzip artifacts alongside their original receipts/snapshots. Initial stopped attempt and earlier failed supplemental path check remain untouched. This portable result does not establish Apple SDK, UIKit, production backend, Siri/Shortcuts, VoiceOver or physical acceptance. Root’s independently frozen app build remains bound to its own source/control SHAs.
