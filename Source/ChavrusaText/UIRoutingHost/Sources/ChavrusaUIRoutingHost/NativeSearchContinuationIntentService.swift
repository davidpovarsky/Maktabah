import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// System metadata and reporting for an existing original Search. This layer
/// cannot submit a query, choose an offset, mint Core authority or select a row.
@MainActor
public final class NativeSearchContinuationIntentService {
    public typealias Kind = UIPublicSearchReferenceKindV2

    public struct Reference: Sendable, Equatable, Hashable {
        public let backend: ActionBackendID
        public let kind: Kind
        public let metadataID: UUID
        public init(backend: ActionBackendID, kind: Kind, metadataID: UUID) {
            self.backend = backend; self.kind = kind; self.metadataID = metadataID
        }
        public var identifier: String {
            "maktabah.search.\(kind.rawValue).v1.\(backend.rawValue).\(metadataID.uuidString.lowercased())"
        }
        public var publicIntent: PublicNavigationSpecV2 {
            .init(destination: kind.destination, backend: backend, presentation: .currentTab,
                  searchReference: metadataID.uuidString.lowercased())
        }
        public init(identifier: String) throws {
            guard identifier.utf8.count <= 160 else { throw UIRouteError(.failed, "invalid_search_reference") }
            let fields = identifier.split(separator: ".", omittingEmptySubsequences: false)
            guard fields.count == 6, fields[0] == "maktabah", fields[1] == "search", fields[3] == "v1",
                  let kind = Kind(rawValue: String(fields[2])),
                  let backend = ActionBackendID(rawValue: String(fields[4])),
                  let id = UUID(uuidString: String(fields[5])), id.uuidString.lowercased() == fields[5] else {
                throw UIRouteError(.failed, "invalid_search_reference")
            }
            self.init(backend: backend, kind: kind, metadataID: id)
            guard self.identifier == identifier else { throw UIRouteError(.failed, "invalid_search_reference") }
        }
        public init(publicIntent value: PublicNavigationSpecV2) throws {
            guard value.version == 2, let kind = Kind.allCases.first(where: { $0.destination == value.destination }),
                  let backend = value.backend, value.presentation == .currentTab,
                  value.content == nil, value.component == nil,
                  let string = value.searchReference, string.utf8.count == 36,
                  let id = UUID(uuidString: string), id.uuidString.lowercased() == string else {
                throw UIRouteError(.failed, "invalid_public_search_reference")
            }
            self.init(backend: backend, kind: kind, metadataID: id)
        }
    }

    /// Host-local original publication identity. It is not Codable and never
    /// enters an entity identifier or URL. There is no observation/claim token.
    public struct Source: Sendable, Equatable {
        public let sceneID: String
        public let snapshot: ActionBackendSnapshot
        public let sessionID: UUID
        public let modelID: UUID
        public let generation: UInt64
        public let sourceRevision: UInt64
        public let submissionRevision: Int
        public let cancellationRevision: Int
        public let paginationRevision: Int
        public let pageRevision: UInt64
        public let configuration: Data
        public init(sceneID: String, snapshot: ActionBackendSnapshot, sessionID: UUID, modelID: UUID,
                    generation: UInt64, sourceRevision: UInt64, submissionRevision: Int,
                    cancellationRevision: Int, paginationRevision: Int, pageRevision: UInt64, configuration: Data) {
            self.sceneID = sceneID; self.snapshot = snapshot; self.sessionID = sessionID; self.modelID = modelID
            self.generation = generation; self.sourceRevision = sourceRevision
            self.submissionRevision = submissionRevision; self.cancellationRevision = cancellationRevision
            self.paginationRevision = paginationRevision; self.pageRevision = pageRevision
            self.configuration = configuration
        }
        public func matches(_ source: ActionSearchContinuationSource) -> Bool {
            Data(sceneID.utf8) == Data(source.sceneID.utf8) && snapshot == source.snapshot
                && sessionID == source.sessionID && modelID == source.modelID && generation == source.generation
                && sourceRevision == source.sourceRevision && submissionRevision == source.submissionRevision
                && cancellationRevision == source.cancellationRevision && paginationRevision == source.paginationRevision
                && pageRevision == source.pageRevision && configuration == source.configuration
        }
    }

    public struct Hit: Sendable, Equatable {
        public let stableID: String
        public let locator: String?
        public let versionTitle: String?
        public let language: String?
        public let identity: Data
        public init(stableID: String, locator: String?, versionTitle: String?, language: String?, identity: Data) {
            self.stableID = stableID; self.locator = locator; self.versionTitle = versionTitle
            self.language = language; self.identity = identity
        }
        public func matches(_ hit: ActionLoadedSearchHit) -> Bool {
            func bytes(_ string: String?) -> Data? { string.map { Data($0.utf8) } }
            return Data(stableID.utf8) == Data(hit.stableID.utf8) && bytes(locator) == bytes(hit.locator)
                && bytes(versionTitle) == bytes(hit.versionTitle) && bytes(language) == bytes(hit.language)
                && identity == hit.identity
        }
    }

    /// A title and a reference to an actual publication, never a stored result
    /// model. Its private source/hit metadata supplements the original live
    /// owner's final validation; it cannot substitute for that validation.
    public struct Target: Sendable, Equatable {
        public let reference: Reference
        public let title: String
        public let source: Source
        public let hit: Hit?
        public init(reference: Reference, title: String, source: Source, hit: Hit?) {
            self.reference = reference; self.title = title; self.source = source; self.hit = hit
        }
        public var id: String { reference.identifier }
    }
    public struct Query: Sendable {
        public let snapshot: ActionBackendSnapshot
        public let kind: Kind?
        public let references: [Reference]?
        public let matching: String?
        public let maximumResults: Int
        init(snapshot: ActionBackendSnapshot, kind: Kind?, references: [Reference]?, matching: String?) {
            self.snapshot = snapshot; self.kind = kind; self.references = references
            self.matching = matching; maximumResults = 64
        }
    }
    public enum Origin: Sendable, Equatable {
        case appIntent
        /// Supplied by the actual existing URL handler's native scene, never
        /// by the public URL payload or an entity's display text.
        case deepLink(receivingSceneID: UIStableID)
    }
    public struct OpenRequest: Sendable {
        public let target: Target
        public let invocation: ActionPortInvocation
        public let origin: Origin
        init(target: Target, invocation: ActionPortInvocation, origin: Origin) {
            self.target = target; self.invocation = invocation; self.origin = origin
        }
    }
    /// The actual command and return from the same original Core invocation.
    /// Keep an unqualified/partial response intact even when reporting fails.
    public struct Execution: Sendable {
        public let command: ActionSearchContinuationCommand
        public let outcome: ActionSearchContinuationOutcome
        public init(command: ActionSearchContinuationCommand, outcome: ActionSearchContinuationOutcome) {
            self.command = command; self.outcome = outcome
        }
    }
    public struct Failure: Error, LocalizedError, Sendable {
        public let execution: Execution
        public let status: ActionStatus
        public let code: String
        public var errorDescription: String? { NativeIntentOutcome(status: status, code: code).errorDescription }
        public init(execution: Execution, status: ActionStatus, code: String) {
            self.execution = execution; self.status = status; self.code = code
        }
    }

    public typealias Snapshot = @MainActor @Sendable () throws -> ActionBackendSnapshot
    public typealias Catalog = @MainActor @Sendable (Query) throws -> [Target]
    public typealias Navigate = @MainActor @Sendable (OpenRequest) async throws -> Execution
    private let snapshot: Snapshot
    private let catalog: Catalog
    private let navigate: Navigate
    private let registry: UIDestinationRegistry
    private let urlScheme: String
    private let now: @MainActor @Sendable () -> UInt64
    private var dispatched: [UUID: UInt64] = [:]

    public init(snapshot: @escaping Snapshot, catalog: @escaping Catalog, navigate: @escaping Navigate,
                registry: UIDestinationRegistry, urlScheme: String = "maktabah",
                now: @escaping @MainActor @Sendable () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }) {
        self.snapshot = snapshot; self.catalog = catalog; self.navigate = navigate
        self.registry = registry; self.urlScheme = urlScheme; self.now = now
    }

    public func targets(kind: Kind? = nil, identifiers: [String]? = nil, matching: String? = nil) throws -> [Target] {
        try Task.checkCancellation()
        guard identifiers == nil || (identifiers!.count <= 64 && Set(identifiers!).count == identifiers!.count),
              matching == nil || matching!.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_search_entity_query")
        }
        let references = try identifiers.map { try $0.map { try Reference(identifier: $0) } }
        let source = try snapshot()
        let query = Query(snapshot: source, kind: kind, references: references, matching: matching)
        let values = try catalog(query)
        guard values.count <= query.maximumResults, Set(values.map(\.id)).count == values.count else {
            throw UIRouteError(.failed, "invalid_live_search_catalog")
        }
        for value in values {
            try validate(value, snapshot: source)
            guard kind == nil || value.reference.kind == kind,
                  references == nil || references!.contains(value.reference),
                  matching == nil || matching!.isEmpty || value.title.localizedCaseInsensitiveContains(matching!) else {
                throw UIRouteError(.failed, "invalid_live_search_catalog")
            }
        }
        try Task.checkCancellation()
        guard try snapshot() == source else { throw UIRouteError(.staleState, "intent_source_generation_changed") }
        return values
    }

    /// A genuine discovered target can be shared without exporting its private
    /// query/configuration/source or a navigation/continuation authority.
    public func link(identifier: String) throws -> URL {
        let reference = try Reference(identifier: identifier)
        let target = try resolve(reference)
        let url = try NativePublicNavigationURLV2.encode(target.reference.publicIntent, scheme: urlScheme, registry: registry)
        guard try resolve(reference) == target else { throw UIRouteError(.staleState, "native_search_reference_changed") }
        return url
    }

    public func open(identifier: String, kind: Kind) async throws -> ActionSearchContinuationReceipt {
        let reference = try Reference(identifier: identifier)
        guard reference.kind == kind else { throw UIRouteError(.failed, "native_search_reference_kind_mismatch") }
        return try await execute(reference, origin: .appIntent)
    }

    /// Called only after the original URL codec/registry, with the native
    /// receiving scene. Revalidate the public shape; decoding grants nothing.
    public func open(public intent: PublicNavigationSpecV2, receivingSceneID: UIStableID) async throws
        -> ActionSearchContinuationReceipt {
        _ = try UIRouteCodec.encodePublicV2(intent, registry: registry)
        return try await execute(Reference(publicIntent: intent), origin: .deepLink(receivingSceneID: receivingSceneID))
    }

    private func execute(_ reference: Reference, origin: Origin) async throws -> ActionSearchContinuationReceipt {
        try Task.checkCancellation()
        let start = now(), budget: UInt64 = 5_000_000_000
        guard start <= .max - budget else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        let target = try resolve(reference)
        if case .deepLink(let scene) = origin, Data(scene.rawValue.utf8) != Data(target.source.sceneID.utf8) {
            throw UIRouteError(.staleState, "native_search_reference_scene_mismatch")
        }
        let request = OpenRequest(target: target, invocation: .init(requestId: UUID(), snapshot: target.source.snapshot,
            deadlineUptimeNanoseconds: start + budget), origin: origin)
        try Task.checkCancellation()
        guard now() < request.invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        // The host retains and consumes the exact catalog selection BEFORE its
        // first await. A public metadata reference cannot be re-resolved to a
        // different source after foreground activation or another callback.
        dispatched = dispatched.filter { $0.value > now() }
        guard dispatched.count < 128, dispatched[request.invocation.requestId] == nil else {
            throw UIRouteError(.unavailable, "native_search_continuation_busy")
        }
        dispatched[request.invocation.requestId] = request.invocation.deadlineUptimeNanoseconds
        let observed = try await navigate(request)
        return try qualify(observed, request: request)
    }

    private func resolve(_ reference: Reference) throws -> Target {
        let source = try snapshot()
        guard reference.backend == source.backend else {
            throw UIRouteError(.requiresBackendSwitch, "intent_search_reference_backend_mismatch")
        }
        let values = try targets(kind: reference.kind, identifiers: [reference.identifier])
        guard values.count == 1, let value = values.first, value.reference == reference,
              value.source.snapshot == source, try snapshot() == source else {
            throw UIRouteError(.staleState, "native_search_reference_no_longer_available")
        }
        return value
    }

    private func validate(_ target: Target, snapshot: ActionBackendSnapshot) throws {
        let source = target.source
        guard target.reference.backend == snapshot.backend, source.snapshot == snapshot,
              !source.sceneID.isEmpty, source.sceneID.utf8.count <= 256,
              source.submissionRevision > 0, source.cancellationRevision >= 0,
              source.paginationRevision >= 0, source.pageRevision > 0,
              !source.configuration.isEmpty, source.configuration.count <= 65_536,
              !target.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              target.title.utf8.count <= 2_048,
              (target.reference.kind == .result) == (target.hit != nil),
              target.hit.map({ !$0.stableID.isEmpty && !$0.identity.isEmpty }) ?? true else {
            throw UIRouteError(.failed, "invalid_live_search_catalog")
        }
        _ = try UIRouteCodec.encodePublicV2(target.reference.publicIntent, registry: registry)
    }

    private func qualify(_ observed: Execution, request: OpenRequest) throws -> ActionSearchContinuationReceipt {
        func refuse(_ status: ActionStatus, _ code: String) -> Failure { .init(execution: observed, status: status, code: code) }
        let command = observed.command
        guard command.invocation == request.invocation, request.target.source.matches(command.source) else {
            throw refuse(.failed, "native_effect_uncertain")
        }
        switch (request.target.reference.kind, command.operation) {
        case (.result, .revealLoadedHit), (.nextPage, .nextOriginalPage): break
        default: throw refuse(.failed, "native_effect_uncertain")
        }
        switch observed.outcome {
        case .unqualified: throw refuse(.failed, "native_effect_uncertain")
        case .refused(let failure):
            guard failure.requestID == command.invocation.requestId, failure.source == command.source,
                  failure.operation == command.operation else { throw refuse(.failed, "native_effect_uncertain") }
            let status: ActionStatus = failure.reason == .cancelled || failure.reason == .deadlineExceeded ? .cancelled
                : failure.reason == .staleSource || failure.reason == .duplicateToken ? .staleState : .unavailable
            throw refuse(status, "native_search_continuation_" + failure.reason.rawValue)
        case .acknowledged(let receipt):
            do { try NativeSearchContinuationService.validateShape(command, receipt) }
            catch { throw refuse(.failed, "native_effect_uncertain") }
            if let selected = request.target.hit {
                guard receipt.effects.count == 1, case .hitSelectionApplied(let hit) = receipt.effects[0],
                      selected.matches(hit) else { throw refuse(.failed, "native_effect_uncertain") }
            }
            // Preserve the ACTUAL receipt/effects if the system handoff is late
            // or cancelled; never replace them with a fabricated empty refusal.
            if Task.isCancelled { throw refuse(.cancelled, "native_effect_uncertain") }
            guard now() < request.invocation.deadlineUptimeNanoseconds else {
                throw refuse(.cancelled, "native_effect_uncertain")
            }
            guard (try? snapshot()) == request.invocation.snapshot else {
                throw refuse(.staleState, "intent_source_generation_changed")
            }
            return receipt
        }
    }
}
