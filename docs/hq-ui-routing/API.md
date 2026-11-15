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

## Additive codec/registry tranche

The API checkpoint is `fd51ee3f26c35f48211d11b49a56198eb6916584`; subsequent public methods are additive. Public model/port signatures above remain unchanged. IDs now require a full-string match, including rejection of trailing newlines. A prepared `UISceneCommand` additionally requires an explicit backend; embedded invocations require the host's RPC epoch. These checks do not select a backend, scene or tab.

`UIRouteSchemas.privateRoute(version: Int = 1)` and `publicRoute()` project a strict ActionJSON schema using the Core reference/search definitions. `UIRouteCodec.decodePrivate(_:registry:) -> UIDecodedRoute`, `encodePrivate(_:registry:) -> Data`, `decodePublic(_:registry:) -> PublicRouteSpec` and `encodePublic(_:registry:) -> Data` throw on invalid/bounded input. Public encoding validates the same restricted shape as public decoding, rejects private ref revisions, and never converts private state into a public route. Only an already explicit public DTO is accepted. Registry normalization can fill a backend from existing qualified refs; it never guesses a locator or host target.

`UIDestinationRegistry.init(descriptors:migrations:)`, `descriptor(for:)`, `validate(_:) -> UIValidatedRoute`, and `discover(scene:context:invocation:core:host:clock:) async throws -> [UIDestinationDescriptor]` are available. Discovery reuses `ActionExecutor.advertisedActions` authorization and implementation/readiness decisions, then host variant/scene eligibility; no parallel origin/scope policy exists here. The trusted host assessment is pinned to the same scene/revision/backend snapshot, with cancellation/deadline checks on both sides of the await. This is metadata discovery, not an action executor or native commit.

Fixture/inventory descriptors remain structurally inspectable for planning/tests but are never live discovery results. A production host must not commit them as implemented surfaces. Missing/ambiguous scenes/tabs/workspaces/profiles/content and unsupported variants require explicit host outcomes; structural validation cannot prove they exist. All untrusted wire paths must use the codec rather than direct JSONDecoder, and URL writers must use the public codec plus separate host shareability approval. The contract deliberately implements no URL parser, publisher, platform adapter, orchestration, Hanlin hook, authorization grant or persistent mutation.

The added `legacy-reader-v0.json` is a synthetic versioned rename fixture, not a claim of an existing app persistence format. Final portable results are recorded in RESULTS.md. G1 independent interface/security review and accepted SDK03/07 shared host contracts remain pending before shared native writers rely on final acceptance.

Consumer update: `HANLIN_HOST_BOUNDARY.md` records the delivered preview357d review and corrected08b disposition, distinct SDK UUID vs Core/UI scene/revision lifetimes, complete route receipt binding and exact typed-number adaptation. Independent Hanlin source QA cleared the reported freshness/revocation P1 at `08b5d6f31153063c31be321fbd35c7301f302fc1`; the dispatcher verified six public contract/manifest blobs unchanged. Typed-port review can proceed against that input. Distribution/ChatUI, accepted semantic/scene ports and actual Apple/native graph proof still gate live SDK use. The reported SDK iOS27/tools6.2 requirements apply to the future adapter graph; this independent contract package's metadata and public API are unchanged.
