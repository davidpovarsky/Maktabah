import Foundation

public struct ActionBackendSnapshot: Codable, Sendable, Equatable, Hashable {
    public let backend: ActionBackendID
    public let generation: UInt64
    public let rpcEpoch: UInt64?
    public init(backend: ActionBackendID, generation: UInt64, rpcEpoch: UInt64? = nil) {
        self.backend = backend; self.generation = generation; self.rpcEpoch = rpcEpoch
    }
}
public struct ActionPortInvocation: Sendable, Equatable {
    public let requestId: UUID
    public let snapshot: ActionBackendSnapshot
    public let deadlineUptimeNanoseconds: UInt64
    public init(requestId: UUID, snapshot: ActionBackendSnapshot, deadlineUptimeNanoseconds: UInt64) {
        self.requestId = requestId; self.snapshot = snapshot; self.deadlineUptimeNanoseconds = deadlineUptimeNanoseconds
    }
}
public struct ActionCapabilityAssessment: Sendable, Equatable, Codable {
    public let registered: Bool
    public let supported: Bool
    public let availableNow: Bool
    public let reasonCode: String?
    public init(registered: Bool, supported: Bool, availableNow: Bool, reasonCode: String? = nil) {
        self.registered = registered; self.supported = supported; self.availableNow = availableNow; self.reasonCode = reasonCode
    }
}
public struct ActionBackendReport: Sendable, Equatable, Codable {
    public let id: ActionBackendID
    public let operations: [String: ActionCapabilityAssessment]
    public init(id: ActionBackendID, operations: [String: ActionCapabilityAssessment]) { self.id = id; self.operations = operations }
}

/// A production MainActor facade may conform using async methods. It must not
/// perform heavy work on MainActor or turn missing assets/RPC errors into [].
public protocol ActionBackendStatePort: Sendable {
    func snapshot() async throws -> ActionBackendSnapshot
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment
}
public protocol ActionResolverPort: Sendable {
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef>
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef>
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination
}
/// Optional data-source seam for the shared resolver owner; no duplicate index.
public protocol ActionResolverDataPort: Sendable {
    func catalog(for backend: ActionBackendID, invocation: ActionPortInvocation) async throws -> [ActionCatalogEntry]
    func referenceCandidates(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef>
    func validate(_ ref: ActionTextRef, invocation: ActionPortInvocation) async throws -> ActionTextRef
}
/// Reads the default table of contents from the active library provider.
public protocol ActionTableOfContentsPort: Sendable {
    /// Returns up to the requested number of entries in source order.
    func tableOfContents(for work: ActionWorkRef, maximumEntries: Int,
                         invocation: ActionPortInvocation) async throws -> [ActionSourceSectionEntry]
}

/// Bounded source-text access through the same active provider as the reader.
public protocol ActionSourceTextPort: Sendable {
    func section(at locator: ActionTextRef, maximumSegments: Int,
                 invocation: ActionPortInvocation) async throws -> ActionSourceTextSection
}

/// Reads edition metadata from the active work's original version provider.
public protocol ActionVersionListPort: Sendable {
    func versions(for work: ActionWorkRef, invocation: ActionPortInvocation) async throws -> [ActionTextVersion]
}

public protocol ActionSearchPort: Sendable {
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage
}

/// Optional execution-only acquisition of an existing source's physical search
/// readiness. Discovery never calls this port. It returns no grant, result or
/// capability; Core always rechecks its original snapshot and assessment.
public protocol ActionSearchExecutionPreparationPort: Sendable {
    /// Hook configuration only, never capability or read authorization. The
    /// synchronous value lets an unconfigured facade keep its original path.
    var hasSearchExecutionPreparation: Bool { get }
    func prepareSearchExecution(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws
}
public extension ActionSearchExecutionPreparationPort {
    var hasSearchExecutionPreparation: Bool { true }
}

/// A read-only observation of an already installed source which explicit
/// execution may prepare. It is deliberately separate from availableNow and
/// carries no read grant, query result or promise that native opening succeeds.
public enum ActionExistingSearchPreparationObservation: Sendable, Equatable {
    case unavailable
    case eligible(invocation: ActionPortInvocation)
}

/// Opt-in companion to the original execution-only port. Implementations must
/// validate existing source identity, metadata, compatibility and required
/// resources without constructing an engine, fetching, repairing or preparing.
public protocol ActionSearchPreparationObservationPort: ActionSearchExecutionPreparationPort {
    func observeExistingSearchPreparation(invocation: ActionPortInvocation) async throws
        -> ActionExistingSearchPreparationObservation
}

public struct ActionOpenReaderCommand: Sendable, Equatable {
    public let destination: ActionReaderDestination
    public let sceneID: String
    public let invocation: ActionPortInvocation
    public let navigationAuthorization: ActionNavigationPreparation?
    public init(destination: ActionReaderDestination, sceneID: String, invocation: ActionPortInvocation,
                navigationAuthorization: ActionNavigationPreparation? = nil) {
        self.destination = destination; self.sceneID = sceneID; self.invocation = invocation
        self.navigationAuthorization = navigationAuthorization
    }
}
public struct ActionUIReceipt: Sendable, Equatable {
    public let requestId: UUID
    public let snapshot: ActionBackendSnapshot
    public let sceneID: String
    public let destination: ActionReaderDestination
    public init(requestId: UUID, snapshot: ActionBackendSnapshot, sceneID: String, destination: ActionReaderDestination) {
        self.requestId = requestId; self.snapshot = snapshot; self.sceneID = sceneID; self.destination = destination
    }
}
public enum ActionUIAcknowledgement: Sendable, Equatable {
    case acknowledged(ActionUIReceipt), queued(handle: String), requiresForeground
}
public protocol ActionUICommandSink: Sendable {
    /// Sink must recheck generation/epoch/cancellation/deadline immediately before
    /// synchronous native commit. Enqueueing is never an acknowledgement.
    @MainActor func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement
}
public enum ActionPortError: Error, Sendable, Equatable {
    case unavailable, notSupported, notFound, staleState, invalidResponse
}
