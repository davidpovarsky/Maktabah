# UI02 compiled API checkpoint

Owner: independent top-level chat `01a1dc89-87bb-7521-b249-ed383392e940`. Branch `codex/otzaria-ui-registry-20261115`, base `2918825be8c5cc8ecee53d57e1f48ca51779cab4`. Scope: Contracts, Registry, Codec, Ports and fixtures only. No native surfaces or orchestration implementation.

## Public boundary available to UI03

Import `OtzariaUIRouting` and `OtzariaActionCore` through the local Swift package. Reuse Core IDs, refs, `ActionReaderDestination`, backend snapshots, invocation deadlines and non-Codable `ActionExecutionContext`. Do not derive context or eligibility from serialized state.

* `RouteSpec`: version, requestId, destination, optional backend/content, presentation, versioned state, optional focus, scene and expectedBackendSnapshot.
* `PresentationSpec`: currentTab/newTab/newWindow/sheet/popover/inspector/sidebar with optional prepared tabID.
* `SceneTarget`: current/specific/newWindow with optional sceneID and expectedRevision. A specific target requires its ID.
* `UIStateSpec`: workspace/profile/selected item, visible/expanded components, sidebar/inspector visibility, sheet, scroll anchor and explicitly private search/note/selection state.
* `FocusSpec`: content/component/selection; content locators reuse Core refs, selection offsets are UTF-16.
* `UIDestinationDescriptor`: stable semantic ID, inventoryOnly/fixture/implemented stage, backends/presentations/anchors, required Core actions, risk/data-change flags and state/public capabilities.
* `UISceneSnapshot`: trusted sceneID, revision, backendSnapshot and optional complete visibleRoute.
* `UISceneNavigationPort`: `@MainActor snapshot(target: SceneTarget, context: ActionExecutionContext) async throws -> UISceneSnapshot` and `@MainActor commit(_ command: UISceneCommand, context: ActionExecutionContext) async throws -> UISceneAcknowledgement`.
* `UIDestinationEligibilityPort.assess(_:scene:context:invocation:) async throws -> UIRouteEligibility`: trusted additional host support/readiness/permission assessment, never a substitute for Core policy.
* `UISceneCommand`: structurally validated route, Core invocation and trusted pre-commit scene. `validateCurrent(_:now:)` verifies cancellation, deadline, revision, scene and backend generation immediately before synchronous native commit; host also performs Core authorization there.
* `UISceneReceipt.validate(for:observed:)`: binds the complete prepared route, request, backend snapshot, scene and increasing revision to a trusted observed visible route. Content routes also require the exact Core UI receipt. Queued/requiresForeground/requiresBackendSwitch/etc. acknowledgements are explicit and are not completed navigation.

Public DTOs and port signatures are in the package source. They are Sendable; trust-bearing scene/context/receipt types intentionally are not Codable. The host owns scene/tab selection, semantic resolution, capability/readiness checks and UI commit; UI03 must not treat a decoded route as authorization.

## Wire fixtures and evidence

`Tests/OtzariaUIRoutingTests/Contracts/Fixtures/private-reader-v1.json` includes prepared tab and private restoration envelope. `public-reader-v1.json` contains navigation only, with no scene/tab/workspace/profile/search/note/selection restoration state. Both use fake destination `fixture.reader` and Otzaria book 103; they are test input, not native acceptance evidence.

Windows portable command: `swift test --package-path Source/Otzaria/UIRouting -j 1 -Xswiftc -strict-concurrency=complete`. Initial checkpoint: 2 XCTest cases passed, 0 failures; log `results/ui-api-tests.log`. This run compiled RouteSpec, SceneNavigationPort, UIDestinationDescriptor and golden tests. The subsequent codec/registry implementation was not part of that run and remains under implementation/negative testing.

Core additive seam: `ActionWireCodec.decodeObject(_:) -> ActionObject` reuses the sole existing bounded parser, duplicate-key rejection and exact number handling. Focused `WireSecurityTests/testBoundedGenericObjectIngressReusesExactParser`: 1 passed, 0 failures; `results/core-object-ingress.log`. Existing Core26 and independent62 evidence was not rerun. Neither run is an Apple SDK, simulator or physical iPad result.

SDK03/07 accepted shared host contract remains pending. Keep all Hanlin model/chat/composer/tool/skill/MCP/store ownership upstream; an actual thin host adapter remains separate work. Package metadata follows existing HanlinPlatform iOS26 minimum, no 17–25 fallback, and makes no iOS27-only SDK claim.
