# G1 public DTO / port checkpoint

[נועם | DEV] [MAIN_SESSION], primary `01a1dc89-87bb-7521-b249-ed383392e940`.
Base `07d1cafa6c6bc27aaf299aa826d28a4c02090cb5`; branch `codex/otzaria-actions-core-20261115`.

Executed: `swift build --package-path Source/Otzaria/Actions -j 1 -Xswiftc -strict-concurrency=complete`; then `swift test` with identical package/options. Swift6.3.3 Windows; two DTO tests PASS, no failures. The checkpoint commit contains these tested public contracts, ports, frozen resources and registry/schema/codec definitions; uncommitted engine/policy work is not checkpoint acceptance.

Exact types and public initializers: `Source/Otzaria/Actions/Sources/OtzariaActionCore/Contracts/*.swift`, `Policy/ActionExecutionContext.swift`, `Ports/ActionPorts.swift`. All query/ref/result/port payloads are Sendable. Context is intentionally not Codable. Frozen wire is `position:{kind,value}` and canonical three IDs, distinct from app persistence.

```swift
public protocol ActionBackendStatePort: Sendable {
    func snapshot() async throws -> ActionBackendSnapshot
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport
    func assess(action: String, arguments: ActionObject,
                invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment
}
public protocol ActionResolverPort: Sendable {
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef>
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef>
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination
}
public protocol ActionResolverDataPort: Sendable {
    func catalog(for backend: ActionBackendID, invocation: ActionPortInvocation) async throws -> [ActionCatalogEntry]
    func referenceCandidates(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef>
    func validate(_ ref: ActionTextRef, invocation: ActionPortInvocation) async throws -> ActionTextRef
}
public protocol ActionSearchPort: Sendable {
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage
}
public protocol ActionUICommandSink: Sendable {
    @MainActor func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement
}
```

- `ActionBackendSnapshot(backend:generation:rpcEpoch:)` is Equatable and Hashable; `ActionPortInvocation(requestId:snapshot:deadlineUptimeNanoseconds:)` binds every provider request. Ports recheck it, not only the executor.
- `ActionCapabilityAssessment(registered:supported:availableNow:reasonCode:)` keeps support separate from readiness; `ActionBackendReport(id:operations:)` retains per-operation differences. Unknown/missing assessment fails closed.
- `ActionResolution<Value>` cases: `.unique(Value)`, `.ambiguous([ActionCandidate])`, `.notFound`. A trimmed string is not a valid resolution proof. `validateDestination` must validate exact supplied section/focus identities, without substitution.
- `ActionSearchQuery` carries backend/text/scopeWorkRefs/searchMode/matchMode/wordDistance/sortOrder/offset/limit. Return the actual `ActionSearchPage.nextOffset`, truthful total precision and segment/document units; no occurrence count type exists in this page.
- `ActionUIAcknowledgement` cases: `.acknowledged(ActionUIReceipt)`, `.queued(handle:)`, `.requiresForeground`. Receipt contains exact requestId/snapshot/sceneID AND canonical `destination: ActionReaderDestination` (owner-reviewed G1 correction after initial API checkpoint). Required initializer: `ActionUIReceipt(requestId:snapshot:sceneID:destination:)`. Executor compares the whole destination, including focus and presentation mode. Recheck cancellation/deadline/snapshot immediately before real commit on the UI actor. No implicit queued-to-completed conversion.
- `ActionPortError` cases: unavailable, notSupported, notFound, staleState, invalidResponse. External errors are mapped to safe codes; never emit raw SQL/paths/credentials.

Only P owns Contracts/Registry/Policy/Engine/Ports/Resources. Resolver/** and Integration/** are reserved for separately assigned owners; no one edits the shared API without coordination. Future additive DTO conveniences are possible; no signature break is planned. Actual Apple/backend/native UI, broad research116 cases and adversarial engine acceptance remain NOT_RUN at this checkpoint.

## Native navigation authorization addition (15 November)

Current additive API and authority limitations: [CONTRACT_NAVIGATION_AUTHORIZATION_20261115.md](../hq-ui-routing/CONTRACT_NAVIGATION_AUTHORIZATION_20261115.md). Core adds a synchronous facet for its exact existing state object and a separately injected trusted native context/scene/lifetime authority; canonical ActionPolicy remains the single permission implementation. UI-only metadata is not a grant. Content preparations only attach inside the validated reader.open resolver/sink path. Source-compatible initializer labels remain, while native guarded execution fails closed without actual synchronous authority. No SharedSnapshot field, Resolver, Bridge, reader engine or second backend authority is added.
