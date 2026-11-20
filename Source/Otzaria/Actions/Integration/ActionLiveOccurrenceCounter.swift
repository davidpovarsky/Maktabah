import Foundation
import OtzariaActionCore

/// Read-only app composition over the existing managed installation and cached
/// original engine. It never opens an engine, repairs an index, or downloads data.
enum ActionLiveOccurrenceCounter {
    private struct Capture: Equatable, Sendable {
        let databasePath: String
        let databaseGeneration: UInt64
        let databaseSelectionRevision: UInt64
        let profileID: String
        let searchRevision: UInt64
        let searchFingerprint: Data
        let source: OtzariaExactOccurrenceSource
        let coverage: ActionOccurrenceCoveragePolicy.Coverage
    }

    /// The facade separately requires the original search readiness proof, which
    /// observes the cached engine's actual document count. This additional proof
    /// authenticates complete coverage without running a discovery-time query.
    static func readiness(_ snapshot: ActionBackendSnapshot) async -> ActionReadinessEvidence {
        guard snapshot.backend == .otzaria, !Task.isCancelled else { return .unavailable }
        let task = Task.detached(priority: .utility) { try capture() }
        do {
            _ = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            return Task.isCancelled ? .unavailable : .ready
        } catch { return .unavailable }
    }

    static func count(_ query: ActionOccurrenceQuery,
                      invocation: ActionPortInvocation) async throws -> ActionExactOccurrenceCount {
        let task = Task.detached(priority: .userInitiated) {
            try await perform(query, invocation: invocation)
        }
        do {
            return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
        } catch let error as ActionOccurrenceFailure { throw error }
        catch is CancellationError { throw ActionOccurrenceFailure.cancelled }
        catch let error as OtzariaExactOccurrenceError { throw mapped(error) }
        catch { throw ActionPortError.unavailable }
    }

    private static func perform(_ query: ActionOccurrenceQuery,
                                invocation: ActionPortInvocation) async throws -> ActionExactOccurrenceCount {
        try check(invocation)
        guard invocation.snapshot.backend == .otzaria, query.backend == .otzaria else {
            throw ActionOccurrenceFailure.unsupportedQuery
        }
        let bookIDs = try ActionOccurrenceCoveragePolicy.bookIDs(for: query)
        let before = try capture()
        try check(invocation)
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < invocation.deadlineUptimeNanoseconds else { throw ActionOccurrenceFailure.deadlineExceeded }
        let remaining = (invocation.deadlineUptimeNanoseconds - now) / 1_000_000
        guard remaining > 0 else { throw ActionOccurrenceFailure.deadlineExceeded }
        let request = try OtzariaExactOccurrenceRequest(query: query.text, bookIds: bookIDs,
            timeoutMs: min(60_000, remaining),
            limits: .init(maxCandidateDocuments: 1_000_000, maxPositions: 10_000_000,
                          maxPositionsPerDocument: 262_144, maxSegments: 4_096))
        // This timed lease only consumes an already cached genuine engine. It
        // binds object identity, publication revision and metadata before/after.
        let result = try await OtzariaTantivySearchRepository.shared.countExactTokenOccurrences(
            databasePath: before.databasePath, request: request, expectedSource: before.source,
            expectedRevision: before.searchRevision, expectedFingerprint: before.searchFingerprint,
            deadlineUptimeNanoseconds: invocation.deadlineUptimeNanoseconds)
        try check(invocation)
        let after = try capture()
        guard after == before else { throw ActionOccurrenceFailure.staleIndex }
        guard result.proof.liveIndexDocuments == before.coverage.expectedDocuments else {
            throw ActionOccurrenceFailure.incompleteCoverage
        }
        let witness = SnapshotWitness(invocation: invocation, capture: before, proof: result.proof)
        let evidence = ActionOccurrenceEvidence(contract: ActionOccurrenceEvidence.requiredContract,
            engineRevision: result.proof.engineCommit,
            engineSnapshotSHA256: try ActionOccurrenceCoveragePolicy.digest(witness),
            artifactIdentity: before.coverage.artifactIdentity,
            // This is the authenticated release DB digest, bound to the original
            // verified managed installation and exact current file fingerprint.
            // No per-query full-database hash is asserted or performed.
            databaseSHA256: before.coverage.databaseSHA256,
            expectedIndexedDocuments: before.coverage.expectedDocuments,
            observedIndexedDocuments: result.proof.liveIndexDocuments,
            visitedDocuments: result.work.visitedCandidateDocuments,
            visitedPositions: result.work.inspectedPositions, completeManagedArtifact: true)
        try check(invocation)
        return .init(requestId: invocation.requestId, snapshot: invocation.snapshot, query: query,
            count: result.occurrences, matchingDocuments: result.matchingLiveDocuments,
            normalizedToken: result.proof.analyzedToken, evidence: evidence)
    }

    private static func capture() throws -> Capture {
        try Task.checkCancellation()
        let bridge = OtzariaMaktabahBridge.shared
        let access = OtzariaDatabaseAccessController.shared
        let selection = access.selectionObservation()
        let generation = bridge.generationSnapshot()
        let profile = OtzariaDataProfileRegistry.activeProfileID
        guard selection.source == .managedInternal, let path = selection.url?.path,
              path == bridge.databasePath else {
            throw ActionOccurrenceFailure.incompleteCoverage
        }
        let storage = try OtzariaDatabaseStorage(profileID: profile)
        let canonicalURL = storage.finalDatabaseURL.standardizedFileURL
        guard URL(fileURLWithPath: path).standardizedFileURL == canonicalURL,
              selection.url?.standardizedFileURL == canonicalURL else {
            throw ActionOccurrenceFailure.incompleteCoverage
        }
        let manager = OtzariaSearchIndexManager.shared
        let repository = OtzariaTantivySearchRepository.shared
        let observation = repository.resourceObservation(databasePath: path)
        guard let fingerprint = observation.fingerprint else { throw ActionOccurrenceFailure.incompleteCoverage }
        let indexURL = manager.indexURL(for: path)
        let manifest = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
            from: smallMetadata(at: indexURL.appendingPathComponent("otzaria_prebuilt_installation.json")))
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let database = try decoder.decode(OtzariaDatabaseInstallationManifest.self,
            from: smallMetadata(at: storage.installationManifestURL))
        let identity = try JSONDecoder().decode(OtzariaIndexBuildIdentity.self,
            from: smallMetadata(at: manager.identityURL(indexURL: indexURL)))
        let current = try manager.currentFingerprint(databasePath: path)
        let build = try OtzariaSearchEngineBridge.buildInfo()
        let coverage = try ActionOccurrenceCoveragePolicy.validate(manifest: manifest, database: database,
            current: current, identity: identity, build: build, profileID: profile)
        let source = try OtzariaExactOccurrenceSource(buildInfo: build,
            originalUpstreamBase: "265a14ea54f959a3e266d6e8acfa3a3b98101d68")
        let finalObservation = repository.resourceObservation(databasePath: path)
        guard selection == access.selectionObservation(),
              generation == bridge.generationSnapshot(), path == bridge.databasePath,
              profile == OtzariaDataProfileRegistry.activeProfileID,
              observation.revision == finalObservation.revision,
              fingerprint == finalObservation.fingerprint else { throw ActionOccurrenceFailure.staleIndex }
        try Task.checkCancellation()
        return Capture(databasePath: path, databaseGeneration: generation,
            databaseSelectionRevision: selection.revision, profileID: profile,
            searchRevision: observation.revision, searchFingerprint: fingerprint,
            source: source, coverage: coverage)
    }

    private static func smallMetadata(at url: URL) throws -> Data {
        let maximum = 1_048_576
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.uint64Value <= UInt64(maximum),
              attributes[.type] as? FileAttributeType == .typeRegular else {
            throw ActionOccurrenceFailure.incompleteCoverage
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var bytes = Data()
        while bytes.count <= maximum {
            guard let chunk = try handle.read(upToCount: maximum + 1 - bytes.count), !chunk.isEmpty else {
                guard !bytes.isEmpty else { throw ActionOccurrenceFailure.incompleteCoverage }
                return bytes
            }
            bytes.append(chunk)
        }
        throw ActionOccurrenceFailure.incompleteCoverage
    }

    private static func check(_ invocation: ActionPortInvocation) throws {
        guard !Task.isCancelled else { throw ActionOccurrenceFailure.cancelled }
        guard DispatchTime.now().uptimeNanoseconds < invocation.deadlineUptimeNanoseconds else {
            throw ActionOccurrenceFailure.deadlineExceeded
        }
    }

    private static func mapped(_ error: OtzariaExactOccurrenceError) -> Error {
        switch error {
        case .cancelled: return ActionOccurrenceFailure.cancelled
        case .deadlineExceeded: return ActionOccurrenceFailure.deadlineExceeded
        case .budgetExceeded, .requestCapacity: return ActionOccurrenceFailure.budgetExceeded
        case .invalidRequest, .requestTooLarge, .unsupportedQuery: return ActionOccurrenceFailure.unsupportedQuery
        case .sourceMismatch, .engineClosed: return ActionOccurrenceFailure.staleIndex
        case .engineUnavailable, .positionsUnavailable: return ActionOccurrenceFailure.incompleteCoverage
        default: return ActionPortError.invalidResponse
        }
    }

    /// Integer fields stay UInt64 throughout encoding; no Double conversion can
    /// lose a segment/delete/generation identity above the JSON safe-int range.
    private struct SnapshotWitness: Encodable {
        struct Segment: Encodable {
            let id: String
            let deleteOpstamp: UInt64?
        }
        let version = 1
        let actionSnapshot: ActionBackendSnapshot
        let databaseGeneration: UInt64
        let databaseSelectionRevision: UInt64
        let searchRevision: UInt64
        let searchFingerprintSHA256: String
        let typedManifestSHA256: String
        let artifactIdentity: String
        let databaseSHA256: String
        let engineRevision: String
        let searcherGeneration: UInt64
        let liveDocuments: UInt64
        let segments: [Segment]

        init(invocation: ActionPortInvocation, capture: Capture, proof: OtzariaExactOccurrenceResult.Proof) {
            actionSnapshot = invocation.snapshot
            databaseGeneration = capture.databaseGeneration
            databaseSelectionRevision = capture.databaseSelectionRevision
            searchRevision = capture.searchRevision
            searchFingerprintSHA256 = ActionOccurrenceCoveragePolicy.sha256(capture.searchFingerprint)
            typedManifestSHA256 = capture.coverage.typedManifestSHA256
            artifactIdentity = capture.coverage.artifactIdentity
            databaseSHA256 = capture.coverage.databaseSHA256
            engineRevision = proof.engineCommit
            searcherGeneration = proof.searcherGeneration.generationId
            liveDocuments = proof.liveIndexDocuments
            segments = proof.searcherGeneration.segments.map { .init(id: $0.segmentId, deleteOpstamp: $0.deleteOpstamp) }
        }
    }
}
