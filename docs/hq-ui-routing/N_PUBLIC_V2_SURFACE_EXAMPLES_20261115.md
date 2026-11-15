# Independent actual-shaped examples for P's local binding tests

`N-public-v2-local-surface-examples.json` contains **12 synthetic examples** generated and checked by `NActualSurfaceShapeExamplesTests.swift`: History root, Settings root, reader/currentTab with inspector closed, and reader/currentTab with inspector already open, on each of otzaria/sefaria/sefariaEmbedded. These mirror the exact existing `MaktabahNativeSceneProjection.surface` state/presentation shape from frozen source `13e40d1d`; they are not captured device results, installed v2 routes, receipts or grants.

| Existing native surface shape | Private presentation/tab | Private state beyond default empty arrays | Focus |
| --- | --- | --- | --- |
| History | currentTab, no target tab | actual workspaceID/profileID | nil |
| Settings | sheet, no target tab | actual workspaceID/profileID | nil |
| Reader, inspector closed | currentTab, exact actual tabID | actual workspaceID/profileID, **inspectorVisible=false** | nil |
| Reader, inspector open | currentTab, exact actual tabID | actual workspaceID/profileID, **inspectorVisible=true** | nil |

Important distinctions for the corrected narrow mapping:

* The two reader examples for each backend have **identical public v2 bytes**. Their actual local inspector state differs and must be preserved independently. It cannot be derived from the public intent or filled with a default nil.
* Actual `surface(.reader)` currently reports presentation **currentTab**, even when `readerInspectorVisible` is true. That is not an installed `.inspector` presentation witness. A future explicit inspector intent must target/observe true and the actual inspector presentation/component through its own accepted native bridge; this file does not fabricate an existing inspector/newTab/sheet reader implementation.
* `surface(.history/.settings/.reader)` currently omits `sidebarVisible` and `state.sheet`. The separate `identity()` includes broader window/sidebar/sheet information for freshness. Copying all of that identity state into the immutable route would create additional mismatches. Preserve only the agreed exact semantic surface fields, with narrow typed observations, and keep broader identity for lifecycle/freshness checks.
* Reader examples use Core's qualified canonical `ActionReaderDestination` shape: otzaria legacyLine, sefaria/sefariaEmbedded canonicalRef, exact same backend/work, no focus locator and sameTab content mode. Embedded has a qualified real-shaped nonnil RPC epoch in the synthetic local preconditions.
* Workspace/profile/tab UUIDs, opaque scene strings, generation/epoch and local correlation in this artifact are **test identities**, never actual user data. P's tests should issue their own fresh local correlation/admission and bind their real test-source scene/snapshot; only transport metadata may be adapted. Do not replace the independently supplied expected private state with the resulting command's requested state.

The generator constructs an independent `NativeSurfaceState` first, passes through actual v2/Core codecs and registry structural validation, projects using the actual `NativeSurfaceState.observedRoute` helper, and asserts exact equality plus correct optional/false field presence. No authorization, native mutation, visibility or completion result is claimed by this projection test. The earlier `NPublicV2ConsumerReviewTests` separately demonstrated that the old binder's nil workspace/profile state cannot acknowledge these actual-shaped state fields.

Execution: one focused portable XCTest method, twelve shape examples, zero failures, zero compiler warnings. Exact input/log/artifact hashes and command: `N-public-v2-local-shapes-report.json`. This isolated sandbox combines exact N host13e40, P983 UIRouting/Core945 and the single new projection test; N production/current handler/frozen run remain unchanged. Corrected P binder tests and eventual real native acceptance remain required.
