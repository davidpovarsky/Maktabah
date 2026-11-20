import Foundation

/// Fixed, source-independent failures. Native diagnostic message strings are
/// deliberately not exposed through this API.
enum OtzariaExactOccurrenceError: String, Error, LocalizedError, Sendable {
    case invalidRequest = "invalid_request"
    case requestTooLarge = "request_too_large"
    case unsupportedQuery = "unsupported_query"
    case invalidLimits = "invalid_limits"
    case requestCapacity = "request_capacity"
    case requestIDExhausted = "request_id_exhausted"
    case unknownRequest = "unknown_request"
    case requestAlreadyExecuted = "request_already_executed"
    case engineUnavailable = "engine_unavailable"
    case engineClosed = "engine_closed"
    case cancelled
    case deadlineExceeded = "deadline_exceeded"
    case budgetExceeded = "budget_exceeded"
    case positionsUnavailable = "positions_unavailable"
    case invalidPositions = "invalid_positions"
    case countOverflow = "count_overflow"
    case engineFailure = "engine_error"
    case responseTooLarge = "response_too_large"
    case internalError = "internal_error"
    case invalidResponse = "invalid_response"
    case sourceMismatch = "source_mismatch"

    var errorDescription: String? { "Occurrence count failed (\(rawValue))." }

    static func nativeCode(_ code: String) -> Self {
        if code == "invalid_engine" { return .engineUnavailable }
        return Self(rawValue: code) ?? .invalidResponse
    }
}

struct OtzariaExactOccurrenceLimits: Encodable, Equatable, Sendable {
    let maxCandidateDocuments: UInt64
    let maxPositions: UInt64
    let maxPositionsPerDocument: UInt32
    let maxSegments: UInt32

    init(
        maxCandidateDocuments: UInt64 = 100_000,
        maxPositions: UInt64 = 1_000_000,
        maxPositionsPerDocument: UInt32 = 65_536,
        maxSegments: UInt32 = 1_024
    ) {
        self.maxCandidateDocuments = maxCandidateDocuments
        self.maxPositions = maxPositions
        self.maxPositionsPerDocument = maxPositionsPerDocument
        self.maxSegments = maxSegments
    }

    func validate() throws {
        guard maxCandidateDocuments <= 1_000_000,
              maxPositions <= 10_000_000,
              maxPositionsPerDocument <= 262_144,
              maxSegments <= 4_096 else {
            throw OtzariaExactOccurrenceError.invalidLimits
        }
    }
}

/// Only original mark-free exact-token semantics are represented. Tokenization
/// stays in the original engine; multi-token/empty queries are rejected there.
struct OtzariaExactOccurrenceRequest: Encodable, Equatable, Sendable {
    private let version = 1
    private let mode = "exact"
    let query: String
    let facets: [String]
    let bookIds: [UInt64]
    let timeoutMs: UInt64
    let limits: OtzariaExactOccurrenceLimits

    init(
        query: String,
        facets: [String] = ["/"],
        bookIds: [UInt64] = [],
        timeoutMs: UInt64 = 5_000,
        limits: OtzariaExactOccurrenceLimits = .init()
    ) throws {
        self.query = query
        self.facets = facets
        self.bookIds = bookIds
        self.timeoutMs = timeoutMs
        self.limits = limits
        guard query.unicodeScalars.count <= 1_000,
              facets.count <= 200, bookIds.count <= 200,
              facets.allSatisfy({ !$0.isEmpty && $0.unicodeScalars.count <= 512 }),
              resolvedFacetBytes.count <= 200 else {
            throw OtzariaExactOccurrenceError.invalidRequest
        }
        guard timeoutMs <= 60_000 else { throw OtzariaExactOccurrenceError.invalidLimits }
        try limits.validate()
    }

    /// Mirrors only the existing C transport's resolve_facets, not search or
    /// token semantics. UTF-8 equality preserves Rust's byte-exact facet IDs;
    /// Swift's canonically equivalent String equality must not merge scopes.
    private var resolvedFacetBytes: [Data] {
        var resolved = facets.map { Data($0.utf8) }
        guard !bookIds.isEmpty else { return resolved }
        let books = bookIds.map { Data("/book/\($0)".utf8) }
        if resolved.isEmpty || resolved == [Data("/".utf8)] { return books }
        for book in books where !resolved.contains(book) { resolved.append(book) }
        return resolved
    }

    var expectedProofFacets: [Data] {
        Array(Set(resolvedFacetBytes)).sorted { $0.lexicographicallyPrecedes($1) }
    }
}

/// The caller supplies its expected compiled source. This is not a corpus,
/// catalogue or application capability witness.
struct OtzariaExactOccurrenceSource: Equatable, Sendable {
    let engineCommit: String
    let engineRepository: String
    let engineBranch: String
    let originalUpstreamBase: String
    let indexSchemaVersion: UInt32
    let enginePackageVersion: String

    init(
        engineCommit: String,
        engineRepository: String,
        engineBranch: String,
        originalUpstreamBase: String,
        indexSchemaVersion: UInt32,
        enginePackageVersion: String
    ) throws {
        guard Self.isLowerHex(engineCommit, length: 40),
              Self.isLowerHex(originalUpstreamBase, length: 40),
              !engineRepository.isEmpty, engineRepository.utf8.count <= 256,
              !engineBranch.isEmpty, engineBranch.utf8.count <= 256,
              indexSchemaVersion > 0,
              !enginePackageVersion.isEmpty, enginePackageVersion.utf8.count <= 64 else {
            throw OtzariaExactOccurrenceError.sourceMismatch
        }
        self.engineCommit = engineCommit
        self.engineRepository = engineRepository
        self.engineBranch = engineBranch
        self.originalUpstreamBase = originalUpstreamBase
        self.indexSchemaVersion = indexSchemaVersion
        self.enginePackageVersion = enginePackageVersion
    }

    init(buildInfo: OtzariaSearchEngineBuildInfo, originalUpstreamBase: String) throws {
        try self.init(
            engineCommit: buildInfo.upstreamCommit,
            engineRepository: buildInfo.upstreamRepository,
            engineBranch: buildInfo.upstreamBranch,
            originalUpstreamBase: originalUpstreamBase,
            indexSchemaVersion: buildInfo.indexSchemaVersion,
            enginePackageVersion: buildInfo.engineVersion
        )
    }

    func validate(buildInfo: OtzariaSearchEngineBuildInfo) throws {
        guard Self.sameBytes(engineCommit, buildInfo.upstreamCommit),
              Self.sameBytes(engineRepository, buildInfo.upstreamRepository),
              Self.sameBytes(engineBranch, buildInfo.upstreamBranch),
              indexSchemaVersion == buildInfo.indexSchemaVersion,
              Self.sameBytes(enginePackageVersion, buildInfo.engineVersion) else {
            throw OtzariaExactOccurrenceError.sourceMismatch
        }
    }

    static func sameBytes(_ left: String, _ right: String) -> Bool {
        left.utf8.elementsEqual(right.utf8)
    }

    static func isLowerHex(_ value: String, length: Int) -> Bool {
        value.utf8.count == length && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }
}

struct OtzariaExactOccurrenceResult: Decodable, Equatable, Sendable {
    struct Segment: Decodable, Equatable, Sendable {
        let segmentId: String
        let deleteOpstamp: UInt64?
    }

    struct Snapshot: Decodable, Equatable, Sendable {
        let generationId: UInt64
        let segments: [Segment]
    }

    struct Proof: Decodable, Equatable, Sendable {
        let requestToken: UInt64
        let countKind: String
        let exact: Bool
        let analyzedToken: String
        let requestedFacets: [String]
        let searcherGeneration: Snapshot
        let liveIndexDocuments: UInt64
        let indexSchemaVersion: UInt32
        let enginePackageVersion: String
        let engineCommit: String
        let originalUpstreamBase: String
        let engineRepository: String
        let engineBranch: String
    }

    struct Work: Decodable, Equatable, Sendable {
        let visitedCandidateDocuments: UInt64
        let inspectedPositions: UInt64
        let visitedSegments: UInt32
    }

    let occurrences: UInt64
    let matchingLiveDocuments: UInt64
    let proof: Proof
    let work: Work

    func validate(
        request: OtzariaExactOccurrenceRequest,
        token: UInt64,
        source: OtzariaExactOccurrenceSource
    ) throws {
        let same = OtzariaExactOccurrenceSource.sameBytes
        guard same(proof.engineCommit, source.engineCommit),
              same(proof.originalUpstreamBase, source.originalUpstreamBase),
              same(proof.engineRepository, source.engineRepository),
              same(proof.engineBranch, source.engineBranch),
              proof.indexSchemaVersion == source.indexSchemaVersion,
              same(proof.enginePackageVersion, source.enginePackageVersion) else {
            throw OtzariaExactOccurrenceError.sourceMismatch
        }
        let segments = proof.searcherGeneration.segments
        guard token != 0, proof.requestToken == token,
              same(proof.countKind, "distinctTokenPositions"), proof.exact,
              !proof.analyzedToken.isEmpty,
              proof.analyzedToken.unicodeScalars.count <= 1_000,
              proof.requestedFacets.map({ Data($0.utf8) }) == request.expectedProofFacets,
              matchingLiveDocuments <= occurrences,
              (occurrences == 0) == (matchingLiveDocuments == 0),
              matchingLiveDocuments <= proof.liveIndexDocuments,
              matchingLiveDocuments <= work.visitedCandidateDocuments,
              occurrences <= work.inspectedPositions,
              work.visitedCandidateDocuments <= request.limits.maxCandidateDocuments,
              work.inspectedPositions <= request.limits.maxPositions,
              work.visitedSegments <= request.limits.maxSegments,
              segments.count == Int(work.visitedSegments),
              Set(segments.map(\.segmentId)).count == segments.count,
              segments.allSatisfy({
                  OtzariaExactOccurrenceSource.isLowerHex($0.segmentId, length: 32)
              }) else {
            throw OtzariaExactOccurrenceError.invalidResponse
        }
    }
}

/// A distinct envelope is necessary because the old search ABI has string
/// errors. Only the whitelisted code is decoded; native message text is ignored.
enum OtzariaExactOccurrenceWire {
    private struct Failure: Decodable { let code: String }
    private struct Envelope: Decodable {
        let ok: Bool
        let value: OtzariaExactOccurrenceResult?
        let error: Failure?
    }

    static func decode(
        _ data: Data,
        request: OtzariaExactOccurrenceRequest,
        token: UInt64,
        source: OtzariaExactOccurrenceSource
    ) throws -> OtzariaExactOccurrenceResult {
        guard data.count <= 1_024 * 1_024 else {
            throw OtzariaExactOccurrenceError.responseTooLarge
        }
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw OtzariaExactOccurrenceError.invalidResponse }
        guard envelope.ok else {
            guard envelope.value == nil, let error = envelope.error else {
                throw OtzariaExactOccurrenceError.invalidResponse
            }
            throw OtzariaExactOccurrenceError.nativeCode(error.code)
        }
        guard envelope.error == nil, let result = envelope.value else {
            throw OtzariaExactOccurrenceError.invalidResponse
        }
        try result.validate(request: request, token: token, source: source)
        return result
    }

    static func creationFailure(_ data: Data) -> OtzariaExactOccurrenceError {
        guard data.count <= 1_024 * 1_024,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              !envelope.ok, envelope.value == nil, let error = envelope.error else {
            return .invalidResponse
        }
        return OtzariaExactOccurrenceError.nativeCode(error.code)
    }
}
