import Foundation

/// A count request has no pagination: a page total is never an occurrence count.
/// Query analysis remains owned by the original engine; this DTO cannot certify
/// that arbitrary source text analyzes to a single token.
public struct ActionOccurrenceQuery: Sendable, Equatable, Codable {
    public enum Unit: String, Sendable, Codable {
        case matchingOccurrences = "matching_occurrences"
        case matchingSegments = "matching_segments"
        case matchingDocuments = "matching_documents"
    }
    public let backend: ActionBackendID
    public let text: String
    public let scopeWorkRefs: [ActionWorkRef]
    public let matchMode: ActionSearchQuery.Match
    public let countUnit: Unit

    public init(backend: ActionBackendID, text: String, scopeWorkRefs: [ActionWorkRef] = [],
                matchMode: ActionSearchQuery.Match = .exact, countUnit: Unit = .matchingOccurrences) {
        self.backend = backend; self.text = text; self.scopeWorkRefs = scopeWorkRefs
        self.matchMode = matchMode; self.countUnit = countUnit
    }

    public static func arguments(_ arguments: ActionObject, backend: ActionBackendID) throws -> Self {
        guard let text = arguments["text"]?.string, ActionValidation.nonempty(text, max: 1_000),
              let rawUnit = arguments["countUnit"]?.string, let unit = Unit(rawValue: rawUnit) else {
            throw ActionContractError.invalid("occurrence_query")
        }
        let refs = try (arguments["scopeWorkRefs"] ?? .array([])).decoded(as: [ActionWorkRef].self)
        guard refs.count <= 200, Set(refs.map(\.workKey)).count == refs.count else {
            throw ActionContractError.invalid("scopeWorkRefs")
        }
        for ref in refs { try ActionValidation.work(ref, backend: backend) }
        let match: ActionSearchQuery.Match
        if let raw = arguments["matchMode"] {
            guard let string = raw.string, let value = ActionSearchQuery.Match(rawValue: string) else {
                throw ActionContractError.invalid("matchMode")
            }
            match = value
        } else { match = .exact }
        return .init(backend: backend, text: text, scopeWorkRefs: refs, matchMode: match, countUnit: unit)
    }

    public var unsupportedReason: String? {
        if backend != .otzaria { return "exact_count_unavailable" }
        if matchMode != .exact { return "occurrence_match_mode_unavailable" }
        if countUnit != .matchingOccurrences { return "occurrence_unit_unavailable" }
        return nil
    }

    var permissionQuery: ActionSearchQuery {
        .init(backend: backend, text: text, scopeWorkRefs: scopeWorkRefs, matchMode: matchMode)
    }
}

/// Evidence supplied by the trusted app adapter after actual original-engine
/// execution and independent managed-artifact coverage checks. Formatting these
/// fields is not a proof: the app must bind the immutable artifact, open engine,
/// source generation and before/after resource witness. Custom/partial indexes
/// have no qualified coverage contract in this version.
public struct ActionOccurrenceEvidence: Sendable, Equatable, Codable {
    public static let requiredContract = "otzaria-exact-token-positions-v1"
    public static let requiredEngineRevision = "d5d59d1269bdf87fb0a6901cf31941726a0c699b"
    public let contract: String
    public let engineRevision: String
    public let engineSnapshotSHA256: String
    public let artifactIdentity: String
    public let databaseSHA256: String
    public let expectedIndexedDocuments: UInt64
    public let observedIndexedDocuments: UInt64
    public let visitedDocuments: UInt64
    public let visitedPositions: UInt64
    public let completeManagedArtifact: Bool

    public init(contract: String, engineRevision: String, engineSnapshotSHA256: String,
                artifactIdentity: String, databaseSHA256: String,
                expectedIndexedDocuments: UInt64, observedIndexedDocuments: UInt64,
                visitedDocuments: UInt64, visitedPositions: UInt64, completeManagedArtifact: Bool) {
        self.contract = contract; self.engineRevision = engineRevision
        self.engineSnapshotSHA256 = engineSnapshotSHA256; self.artifactIdentity = artifactIdentity
        self.databaseSHA256 = databaseSHA256; self.expectedIndexedDocuments = expectedIndexedDocuments
        self.observedIndexedDocuments = observedIndexedDocuments
        self.visitedDocuments = visitedDocuments; self.visitedPositions = visitedPositions
        self.completeManagedArtifact = completeManagedArtifact
    }
}

public struct ActionExactOccurrenceCount: Sendable, Equatable, Codable {
    public let requestId: UUID
    public let snapshot: ActionBackendSnapshot
    public let query: ActionOccurrenceQuery
    public let count: UInt64
    public let matchingDocuments: UInt64
    public let normalizedToken: String
    public let evidence: ActionOccurrenceEvidence

    public init(requestId: UUID, snapshot: ActionBackendSnapshot, query: ActionOccurrenceQuery,
                count: UInt64, matchingDocuments: UInt64, normalizedToken: String,
                evidence: ActionOccurrenceEvidence) {
        self.requestId = requestId; self.snapshot = snapshot; self.query = query
        self.count = count; self.matchingDocuments = matchingDocuments
        self.normalizedToken = normalizedToken; self.evidence = evidence
    }

    func validate(query expected: ActionOccurrenceQuery, invocation: ActionPortInvocation) throws {
        guard requestId == invocation.requestId, snapshot == invocation.snapshot,
              query == expected, Array(query.text.utf8) == Array(expected.text.utf8),
              expected.unsupportedReason == nil,
              ActionValidation.nonempty(normalizedToken, max: 1_000),
              !normalizedToken.contains(where: \.isWhitespace),
              evidence.contract == ActionOccurrenceEvidence.requiredContract,
              evidence.engineRevision == ActionOccurrenceEvidence.requiredEngineRevision,
              evidence.completeManagedArtifact,
              evidence.expectedIndexedDocuments > 0,
              evidence.expectedIndexedDocuments == evidence.observedIndexedDocuments,
              evidence.visitedDocuments <= 1_000_000, evidence.visitedPositions <= 10_000_000,
              matchingDocuments <= evidence.visitedDocuments,
              matchingDocuments <= evidence.observedIndexedDocuments,
              count <= evidence.visitedPositions, matchingDocuments <= count,
              (count == 0) == (matchingDocuments == 0),
              [evidence.engineSnapshotSHA256, evidence.artifactIdentity, evidence.databaseSHA256].allSatisfy({
                  $0.utf8.count == 64 && $0.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
              }) else { throw ActionPortError.invalidResponse }
    }
}

/// Optional, deliberately separate from search-page totals. The original search
/// provider remains unchanged unless an app composition supplies this contract.
public protocol ActionOccurrenceCountPort: Sendable {
    func countOccurrences(_ query: ActionOccurrenceQuery,
                          invocation: ActionPortInvocation) async throws -> ActionExactOccurrenceCount
}

/// Stable failures carry no numeric partial result and cannot leak provider text.
public enum ActionOccurrenceFailure: Error, Sendable, Equatable {
    case unsupportedQuery, incompleteCoverage, budgetExceeded, cancelled, deadlineExceeded, staleIndex
}
