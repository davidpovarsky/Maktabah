import Foundation

/// A retained observation of one ORIGINAL, already submitted UI search. This
/// is deliberately separate from ActionSearchResultsQuery and cannot start a
/// query, supply an offset, replace a provider, or open a reader.
public struct ActionSearchContinuationSource: Sendable, Equatable {
    public let observationID: UUID
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

    public init(observationID: UUID, sceneID: String, snapshot: ActionBackendSnapshot,
                sessionID: UUID, modelID: UUID, generation: UInt64, sourceRevision: UInt64,
                submissionRevision: Int, cancellationRevision: Int, paginationRevision: Int,
                pageRevision: UInt64, configuration: Data) {
        self.observationID = observationID; self.sceneID = sceneID; self.snapshot = snapshot
        self.sessionID = sessionID; self.modelID = modelID; self.generation = generation
        self.sourceRevision = sourceRevision; self.submissionRevision = submissionRevision
        self.cancellationRevision = cancellationRevision; self.paginationRevision = paginationRevision
        self.pageRevision = pageRevision; self.configuration = configuration
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.observationID == rhs.observationID && Data(lhs.sceneID.utf8) == Data(rhs.sceneID.utf8)
            && lhs.snapshot == rhs.snapshot && lhs.sessionID == rhs.sessionID && lhs.modelID == rhs.modelID
            && lhs.generation == rhs.generation && lhs.sourceRevision == rhs.sourceRevision
            && lhs.submissionRevision == rhs.submissionRevision && lhs.cancellationRevision == rhs.cancellationRevision
            && lhs.paginationRevision == rhs.paginationRevision && lhs.pageRevision == rhs.pageRevision
            && lhs.configuration == rhs.configuration
    }
}

/// Metadata comes from the current original result, not by decoding the token.
/// The token resolves only in its retained original scene/list observation.
public struct ActionLoadedSearchHit: Sendable, Equatable {
    public let token: UUID
    public let stableID: String
    public let locator: String?
    public let versionTitle: String?
    public let language: String?
    public let identity: Data

    public init(token: UUID, stableID: String, locator: String?, versionTitle: String?,
                language: String?, identity: Data) {
        self.token = token; self.stableID = stableID; self.locator = locator
        self.versionTitle = versionTitle; self.language = language; self.identity = identity
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        func bytes(_ value: String?) -> Data? { value.map { Data($0.utf8) } }
        return lhs.token == rhs.token && Data(lhs.stableID.utf8) == Data(rhs.stableID.utf8)
            && bytes(lhs.locator) == bytes(rhs.locator) && bytes(lhs.versionTitle) == bytes(rhs.versionTitle)
            && bytes(lhs.language) == bytes(rhs.language) && lhs.identity == rhs.identity
    }
}

public struct ActionSearchContinuationObservation: Sendable, Equatable {
    public let source: ActionSearchContinuationSource
    public let loadedHits: [ActionLoadedSearchHit]
    public let nextPageToken: UUID?
    public init(source: ActionSearchContinuationSource, loadedHits: [ActionLoadedSearchHit], nextPageToken: UUID?) {
        self.source = source; self.loadedHits = loadedHits; self.nextPageToken = nextPageToken
    }
}

public enum ActionSearchContinuationOperation: Sendable, Equatable {
    case revealLoadedHit(token: UUID)
    case nextOriginalPage(token: UUID)
}

public struct ActionSearchContinuationCommand: Sendable, Equatable {
    public let source: ActionSearchContinuationSource
    public let operation: ActionSearchContinuationOperation
    public let invocation: ActionPortInvocation
    public init(source: ActionSearchContinuationSource, operation: ActionSearchContinuationOperation,
                invocation: ActionPortInvocation) {
        self.source = source; self.operation = operation; self.invocation = invocation
    }
}

/// Accepted by the original backend commit path. Raw rows/cursors deliberately
/// remain distinct from mapped/displayed rows and normalized continuation.
public struct ActionSearchOriginalPageReceipt: Sendable, Equatable {
    public let attemptID: UUID
    public let modelID: UUID
    public let generation: UInt64
    public let pageRevision: UInt64
    public let request: Data
    public let requestOffset: Int
    public let requestLimit: Int
    public let rawRowCount: Int
    public let mappedRowCount: Int
    public let consumedBefore: Int
    public let consumedAfter: Int
    public let cursorBefore: Int?
    public let rawNextOffset: Int?
    public let normalizedNextOffset: Int?
    public let hasMore: Bool
    public let sourceEvidence: Data?
    public init(attemptID: UUID, modelID: UUID, generation: UInt64, pageRevision: UInt64,
                request: Data, requestOffset: Int, requestLimit: Int, rawRowCount: Int,
                mappedRowCount: Int, consumedBefore: Int, consumedAfter: Int, cursorBefore: Int?,
                rawNextOffset: Int?, normalizedNextOffset: Int?, hasMore: Bool, sourceEvidence: Data?) {
        self.attemptID = attemptID; self.modelID = modelID; self.generation = generation
        self.pageRevision = pageRevision; self.request = request; self.requestOffset = requestOffset
        self.requestLimit = requestLimit; self.rawRowCount = rawRowCount; self.mappedRowCount = mappedRowCount
        self.consumedBefore = consumedBefore; self.consumedAfter = consumedAfter; self.cursorBefore = cursorBefore
        self.rawNextOffset = rawNextOffset; self.normalizedNextOffset = normalizedNextOffset
        self.hasMore = hasMore; self.sourceEvidence = sourceEvidence
    }
}

/// The host retains the actual original UIKit view/window and revalidates this
/// witness synchronously. A scroll request, onAppear, or query echo is not one.
public struct ActionSearchVisibleReceipt: Sendable, Equatable {
    public let witnessID: UUID
    public let listID: UUID
    public let rowID: UUID?
    public let layoutRevision: UInt64
    public let identity: Data?
    public init(witnessID: UUID, listID: UUID, rowID: UUID?, layoutRevision: UInt64, identity: Data?) {
        self.witnessID = witnessID; self.listID = listID; self.rowID = rowID
        self.layoutRevision = layoutRevision; self.identity = identity
    }
}

/// Preserve an actual earlier effect even if a later completion/layout/authority
/// check refuses. No failure implies that a provider request or UI write rolled back.
public enum ActionSearchContinuationEffect: Sendable, Equatable {
    case pageRequested(attemptID: UUID)
    case pageCommitted(ActionSearchOriginalPageReceipt)
    case hitSelectionApplied(ActionLoadedSearchHit)
}
public struct ActionSearchContinuationReceipt: Sendable, Equatable {
    public let requestID: UUID
    public let before: ActionSearchContinuationSource
    public let after: ActionSearchContinuationSource
    public let operation: ActionSearchContinuationOperation
    public let effects: [ActionSearchContinuationEffect]
    public let visible: ActionSearchVisibleReceipt
    public init(requestID: UUID, before: ActionSearchContinuationSource, after: ActionSearchContinuationSource,
                operation: ActionSearchContinuationOperation, effects: [ActionSearchContinuationEffect],
                visible: ActionSearchVisibleReceipt) {
        self.requestID = requestID; self.before = before; self.after = after; self.operation = operation
        self.effects = effects; self.visible = visible
    }
}
public enum ActionSearchContinuationRefusal: String, Sendable, Equatable {
    case unavailable, staleSource, duplicateToken, ambiguousHit, filteredHit, exhausted
    case cancelled, deadlineExceeded, providerFailed, invalidCompletion
}
public struct ActionSearchContinuationFailure: Sendable, Equatable {
    public let requestID: UUID
    /// Nil is an unattested origin, never permission to attribute these effects
    /// to a command that happens to carry the same request UUID.
    public let source: ActionSearchContinuationSource?
    public let operation: ActionSearchContinuationOperation?
    public let reason: ActionSearchContinuationRefusal
    public let effects: [ActionSearchContinuationEffect]
    public init(requestID: UUID, reason: ActionSearchContinuationRefusal, effects: [ActionSearchContinuationEffect],
                source: ActionSearchContinuationSource? = nil, operation: ActionSearchContinuationOperation? = nil) {
        self.requestID = requestID; self.source = source; self.operation = operation
        self.reason = reason; self.effects = effects
    }
}
public enum ActionSearchContinuationOutcome: Sendable, Equatable {
    case acknowledged(ActionSearchContinuationReceipt)
    case refused(ActionSearchContinuationFailure)
    /// The returned response cannot be joined to the attempted command. Retain
    /// it unchanged with its own provenance, including nested unqualified
    /// responses. This neither attributes its effects to `command` nor asserts
    /// that the attempted operation had no effects. It is never completion.
    indirect case unqualified(command: ActionSearchContinuationCommand, originalResponse: ActionSearchContinuationOutcome)
}

/// Additive host seam. Registry/Scene/Core wiring remains with its original UI
/// owner. Until that wiring is qualified, the existing first-page intent still
/// rejects selectedHit/cursor parameters and returns no continuation handle.
public protocol ActionSearchContinuationUICommandSink: ActionUICommandSink {
    @MainActor func observeSearchContinuation(in sceneID: String, invocation: ActionPortInvocation) throws
        -> ActionSearchContinuationObservation
    @MainActor func performSearchContinuation(_ command: ActionSearchContinuationCommand) async
        -> ActionSearchContinuationOutcome
    @MainActor func validateSearchContinuationCompletion(_ command: ActionSearchContinuationCommand,
                                                         receipt: ActionSearchContinuationReceipt) throws
}
