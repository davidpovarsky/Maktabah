import Foundation

final class OtzariaSearchIndexManager {
    static let shared = OtzariaSearchIndexManager()

    private let identityFileName = "otzaria_search_identity.json"
    private let checkpointFileName = "otzaria_search_checkpoint.json"
    private let failureLedgerFileName = "otzaria_search_failures.json"
    private let pdfFreshnessFileName = "otzaria_pdf_freshness.json"
    private let semanticArtifactFileName = "otzaria_semantic_artifact.json"
    private let sentinelFileName = ".otzaria_index_building"

    private init() {}

    var indexRootURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Otzaria/TantivySearchIndex", isDirectory: true)
    }

    func indexURL(for databasePath: String) -> URL {
        if OtzariaDatabaseAccessController.shared.source == .managedInternal {
            return indexRootURL.appendingPathComponent("managed-library", isDirectory: true)
        }
        indexRootURL.appendingPathComponent(stablePathHash(databasePath), isDirectory: true)
    }

    func buildingIndexURL(for databasePath: String) -> URL {
        indexURL(for: databasePath).appendingPathExtension("building")
    }

    func previousIndexURL(for databasePath: String) -> URL {
        indexURL(for: databasePath).appendingPathExtension("previous")
    }

    func sentinelURL(for databasePath: String) -> URL {
        indexRootURL.appendingPathComponent("\(sentinelFileName).\(stablePathHash(databasePath))")
    }

    func checkpointURL(indexURL: URL) -> URL { indexURL.appendingPathComponent(checkpointFileName) }
    func identityURL(indexURL: URL) -> URL { indexURL.appendingPathComponent(identityFileName) }
    func failureLedgerURL(indexURL: URL) -> URL { indexURL.appendingPathComponent(failureLedgerFileName) }
    func pdfFreshnessURL(indexURL: URL) -> URL { indexURL.appendingPathComponent(pdfFreshnessFileName) }
    func semanticArtifactURL(for databasePath: String) -> URL {
        indexRootURL.appendingPathComponent("\(stablePathHash(databasePath)).\(semanticArtifactFileName)")
    }

    func currentFingerprint(databasePath: String) throws -> OtzariaIndexFingerprint {
        let url = URL(fileURLWithPath: databasePath)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return OtzariaIndexFingerprint(
            databasePath: databasePath,
            fileSize: UInt64(values.fileSize ?? 0),
            modificationTime: values.contentModificationDate?.timeIntervalSince1970 ?? 0
        )
    }

    func makeIdentity(databasePath: String, catalogueHash: String) throws -> OtzariaIndexBuildIdentity {
        let build = try OtzariaSearchEngineBridge.buildInfo()
        let fingerprint = try currentFingerprint(databasePath: databasePath)
        let semantic = decode(
            OtzariaSemanticArtifactIdentity.self,
            at: semanticArtifactURL(for: databasePath)
        )
        let expectedCorpus = semanticCorpusIdentity(database: fingerprint, catalogueHash: catalogueHash)
        let validatedSemantic = semantic.flatMap {
            build.semanticEnabled
                && $0.sidecarRevision == build.semanticSidecarRevision
                && $0.corpusIdentity == expectedCorpus ? $0 : nil
        }
        return OtzariaIndexBuildIdentity(
            database: fingerprint,
            upstreamCommit: build.upstreamCommit,
            engineVersion: build.engineVersion,
            indexSchemaVersion: build.indexSchemaVersion,
            defaultGenerationOrder: build.defaultGenerationOrder,
            adapterVersion: build.adapterVersion,
            resourceHashes: build.resourceHashes,
            catalogueHash: catalogueHash,
            semanticArtifactIdentity: validatedSemantic
        )
    }

    func registerSemanticArtifact(
        _ identity: OtzariaSemanticArtifactIdentity,
        databasePath: String
    ) throws {
        let build = try OtzariaSearchEngineBridge.buildInfo()
        guard build.semanticEnabled,
              identity.sidecarRevision == build.semanticSidecarRevision else {
            throw OtzariaSearchError.invalidEngineResponse(
                "Semantic artifact sidecar identity does not match this build"
            )
        }
        try atomicWrite(identity, to: semanticArtifactURL(for: databasePath))
    }

    func storedIdentity(indexURL: URL) -> OtzariaIndexBuildIdentity? {
        decode(OtzariaIndexBuildIdentity.self, at: identityURL(indexURL: indexURL))
    }

    func writeIdentity(_ identity: OtzariaIndexBuildIdentity, indexURL: URL) throws {
        try atomicWrite(identity, to: identityURL(indexURL: indexURL))
    }

    func checkpoint(indexURL: URL) -> OtzariaIndexCheckpoint? {
        decode(OtzariaIndexCheckpoint.self, at: checkpointURL(indexURL: indexURL))
    }

    func writeCheckpoint(_ checkpoint: OtzariaIndexCheckpoint, indexURL: URL) throws {
        try atomicWrite(checkpoint, to: checkpointURL(indexURL: indexURL))
    }

    func failureLedger(indexURL: URL) -> OtzariaBookFailureLedger {
        decode(OtzariaBookFailureLedger.self, at: failureLedgerURL(indexURL: indexURL))
            ?? OtzariaBookFailureLedger(records: [])
    }

    func recordFailure(_ record: OtzariaBookFailureRecord, indexURL: URL) throws {
        var ledger = failureLedger(indexURL: indexURL)
        ledger.records.removeAll { $0.sourceKey == record.sourceKey }
        ledger.records.append(record)
        try atomicWrite(ledger, to: failureLedgerURL(indexURL: indexURL))
    }

    func pdfFreshness(indexURL: URL) -> OtzariaPDFFreshnessManifest {
        decode(OtzariaPDFFreshnessManifest.self, at: pdfFreshnessURL(indexURL: indexURL))
            ?? OtzariaPDFFreshnessManifest(sourceIdentities: [:])
    }

    func writePDFFreshness(_ manifest: OtzariaPDFFreshnessManifest, indexURL: URL) throws {
        try atomicWrite(manifest, to: pdfFreshnessURL(indexURL: indexURL))
    }

    /// A stale sentinel means the previous process stopped; it does not imply
    /// the committed partial Tantivy index is corrupt.
    func recoverInterruptedBuild(databasePath: String) -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: sentinelURL(for: databasePath).path)
            && fileManager.fileExists(atPath: buildingIndexURL(for: databasePath).path)
    }

    func prepareOrResumeBuildingIndex(
        databasePath: String,
        identity: OtzariaIndexBuildIdentity
    ) throws -> (url: URL, checkpoint: OtzariaIndexCheckpoint?) {
        let fileManager = FileManager.default
        let buildingURL = buildingIndexURL(for: databasePath)
        try fileManager.createDirectory(at: indexRootURL, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: buildingURL.path) {
            let checkpoint = checkpoint(indexURL: buildingURL)
            let storedIdentity = storedIdentity(indexURL: buildingURL) ?? checkpoint?.identity
            let compatibility = try? OtzariaSearchEngineBridge.checkCompatibility(indexURL: buildingURL)
            let canResume = storedIdentity == identity
                && checkpoint?.identity == identity
                && compatibility?.compatible == true
            if canResume {
                try preflightStorage(databasePath: databasePath)
                try Data(databasePath.utf8).write(to: sentinelURL(for: databasePath), options: .atomic)
                return (buildingURL, checkpoint)
            }

            // Exact targets were resolved above: only an incompatible or
            // identity-mismatched replacement build is discarded.
            try fileManager.removeItem(at: buildingURL)
        }

        try preflightStorage(databasePath: databasePath)

        let finalURL = indexURL(for: databasePath)
        if canSeedBuildingIndex(from: finalURL, for: identity) {
            do {
                try fileManager.copyItem(at: finalURL, to: buildingURL)
                try? fileManager.removeItem(at: checkpointURL(indexURL: buildingURL))
                OtzariaIndexFileLogger.log("incremental build seeded from compatible final index")
            } catch {
                if fileManager.fileExists(atPath: buildingURL.path) {
                    try? fileManager.removeItem(at: buildingURL)
                }
                try fileManager.createDirectory(at: buildingURL, withIntermediateDirectories: true)
                OtzariaIndexFileLogger.logError("incremental seed failed; starting empty build", error: error)
            }
        } else {
            try fileManager.createDirectory(at: buildingURL, withIntermediateDirectories: true)
        }
        try writeIdentity(identity, indexURL: buildingURL)
        try Data(databasePath.utf8).write(to: sentinelURL(for: databasePath), options: .atomic)
        return (buildingURL, nil)
    }

    func markPaused(databasePath: String) {
        // Keep both sentinel and building directory. They are the resume signal.
        OtzariaIndexFileLogger.log("index build paused; committed building index retained")
    }

    func isIndexCurrent(databasePath: String) -> Bool {
        if OtzariaDatabaseAccessController.shared.source == .managedInternal {
            _ = try? recoverTrustedManagedIndex(databasePath: databasePath)
        }
        let finalURL = indexURL(for: databasePath)
        guard let currentBuild = try? OtzariaSearchEngineBridge.buildInfo() else { return false }
        let registeredSemantic = decode(
            OtzariaSemanticArtifactIdentity.self,
            at: semanticArtifactURL(for: databasePath)
        ).flatMap {
            currentBuild.semanticEnabled && $0.sidecarRevision == currentBuild.semanticSidecarRevision ? $0 : nil
        }
        let managed = OtzariaDatabaseAccessController.shared.source == .managedInternal
        guard FileManager.default.fileExists(atPath: finalURL.path),
              let identity = storedIdentity(indexURL: finalURL),
              let currentDatabase = try? currentFingerprint(databasePath: databasePath),
              (managed
                  ? OtzariaSearchArtifactPolicy.managedIdentityMatchesCanonicalData(
                      identity,
                      currentDatabase: currentDatabase,
                      build: currentBuild
                    )
                  : identity.database == currentDatabase
                      && identity.upstreamCommit == currentBuild.upstreamCommit
                      && identity.engineVersion == currentBuild.engineVersion
                      && identity.indexSchemaVersion == currentBuild.indexSchemaVersion
                      && identity.defaultGenerationOrder == currentBuild.defaultGenerationOrder
                      && identity.adapterVersion == currentBuild.adapterVersion
                      && identity.resourceHashes == currentBuild.resourceHashes),
              (managed || identity.semanticArtifactIdentity == registeredSemantic),
              let compatibility = try? OtzariaSearchEngineBridge.checkCompatibility(indexURL: finalURL),
              compatibility.compatible else { return false }
        do {
            let engine = try OtzariaSearchEngineBridge(indexURL: finalURL)
            defer { engine.close() }
            _ = try engine.documentCount()
            return true
        } catch {
            return false
        }
    }

    func compatibility(databasePath: String) -> OtzariaIndexCompatibility? {
        try? OtzariaSearchEngineBridge.checkCompatibility(indexURL: indexURL(for: databasePath))
    }

    func promoteBuildingIndex(databasePath: String) throws {
        let fileManager = FileManager.default
        let finalURL = indexURL(for: databasePath)
        let buildingURL = buildingIndexURL(for: databasePath)
        let previousURL = previousIndexURL(for: databasePath)

        guard fileManager.fileExists(atPath: buildingURL.path) else {
            throw OtzariaSearchError.invalidEngineResponse("No validated building index exists to promote")
        }
        if fileManager.fileExists(atPath: previousURL.path) {
            OtzariaIndexFileLogger.log("promotion deleting previous index retained from the prior successful promotion")
            try fileManager.removeItem(at: previousURL)
        }
        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.moveItem(at: finalURL, to: previousURL)
        }
        do {
            try fileManager.moveItem(at: buildingURL, to: finalURL)
            try? fileManager.removeItem(at: sentinelURL(for: databasePath))
        } catch {
            if fileManager.fileExists(atPath: finalURL.path) {
                try? fileManager.removeItem(at: finalURL)
            }
            if fileManager.fileExists(atPath: previousURL.path) {
                try? fileManager.moveItem(at: previousURL, to: finalURL)
            }
            throw error
        }
    }

    func clearIndex(databasePath: String) throws {
        let fileManager = FileManager.default
        for url in [indexURL(for: databasePath), buildingIndexURL(for: databasePath), previousIndexURL(for: databasePath)] {
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        }
        try? fileManager.removeItem(at: sentinelURL(for: databasePath))
    }

    private func atomicWrite<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private func decode<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private func stablePathHash(_ value: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 { hash ^= UInt64(byte); hash &*= 1099511628211 }
        return String(hash, radix: 16)
    }

    func semanticCorpusIdentity(database: OtzariaIndexFingerprint, catalogueHash: String) -> String {
        stablePathHash([
            database.databasePath,
            String(database.fileSize),
            String(database.modificationTime.bitPattern),
            catalogueHash
        ].joined(separator: "\u{1f}"))
    }

    /// Conservative additional-space model. A seeded build needs one full
    /// final-index copy plus at least max(50% of the source DB, 256 MiB) for
    /// segment growth. A fresh build reserves max(2x source DB, 256 MiB).
    /// final, building and previous may coexist; 512 MiB is kept untouched for
    /// the OS and atomic metadata writes. The retained `previous` is deleted
    /// only at the next successful promotion, after a new build validates.
    private func preflightStorage(databasePath: String) throws {
        let fileManager = FileManager.default
        let databaseSize = (try? currentFingerprint(databasePath: databasePath).fileSize) ?? 0
        let finalURL = indexURL(for: databasePath)
        let buildingURL = buildingIndexURL(for: databasePath)
        let finalSize = directorySize(finalURL)
        let buildingSize = directorySize(buildingURL)
        let minimumIndex: UInt64 = 256 * 1_024 * 1_024
        let reserve: UInt64 = 512 * 1_024 * 1_024
        let projected = finalSize > 0
            ? finalSize + max(databaseSize / 2, minimumIndex)
            : max(databaseSize.multipliedReportingOverflow(by: 2).overflow ? UInt64.max : databaseSize * 2, minimumIndex)
        let additional = projected > buildingSize ? projected - buildingSize : 0
        let required = additional.addingReportingOverflow(reserve).overflow ? UInt64.max : additional + reserve
        let values = try indexRootURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])
        let reportedCapacity = values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map { Int64($0) }
            ?? 0
        let available = UInt64(max(reportedCapacity, 0))
        OtzariaIndexFileLogger.log(
            "storage preflight databaseBytes=\(databaseSize) finalBytes=\(finalSize) buildingBytes=\(buildingSize) " +
            "additionalBytes=\(additional) reserveBytes=\(reserve) availableBytes=\(available)"
        )
        guard available >= required else {
            throw OtzariaSearchError.insufficientStorage(requiredBytes: required, availableBytes: available)
        }
    }

    /// Recovers a trusted managed prebuilt index across app-container path,
    /// database mtime, and stale semantic-registration changes. The signed
    /// database and artifact manifests, engine/schema/resource identities,
    /// Tantivy compatibility, and document count are the canonical identity.
    @discardableResult
    func recoverTrustedManagedIndex(databasePath: String) throws -> UInt64? {
        guard OtzariaDatabaseAccessController.shared.source == .managedInternal else { return nil }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: indexRootURL, withIntermediateDirectories: true)
        let target = indexURL(for: databasePath)
        var candidates: [URL] = []
        if fileManager.fileExists(atPath: target.path) { candidates.append(target) }
        if let children = try? fileManager.contentsOfDirectory(
            at: indexRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            candidates += children.filter { candidate in
                candidate != target
                    && !candidate.lastPathComponent.hasSuffix(".building")
                    && !candidate.lastPathComponent.hasSuffix(".installing")
                    && !candidate.lastPathComponent.hasSuffix(".previous")
                    && fileManager.fileExists(
                        atPath: candidate.appendingPathComponent("otzaria_prebuilt_installation.json").path
                    )
            }
        }

        let databaseStorage = try OtzariaDatabaseStorage()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let databaseManifest = try decoder.decode(
            OtzariaDatabaseInstallationManifest.self,
            from: Data(contentsOf: databaseStorage.installationManifestURL)
        )
        let databaseBytes = Int64(try currentFingerprint(databasePath: databasePath).fileSize)
        let build = try OtzariaSearchEngineBridge.buildInfo()

        for candidate in candidates {
            let trustedURL = candidate.appendingPathComponent("otzaria_prebuilt_installation.json")
            guard let data = try? Data(contentsOf: trustedURL),
                  let manifest = try? JSONDecoder().decode(OtzariaSearchArtifactManifest.self, from: data),
                  (try? OtzariaSearchArtifactPolicy.validate(
                    manifest,
                    database: databaseManifest,
                    databaseBytes: databaseBytes,
                    build: build
                  )) != nil,
                  let compatibility = try? OtzariaSearchEngineBridge.checkCompatibility(indexURL: candidate),
                  compatibility.compatible else { continue }
            let engine = try OtzariaSearchEngineBridge(indexURL: candidate)
            let count: UInt64
            do { count = try engine.documentCount() } catch { engine.close(); continue }
            engine.close()
            guard count == manifest.lexicalArtifact.documentCount else { continue }

            if candidate != target {
                guard !fileManager.fileExists(atPath: target.path) else { continue }
                try fileManager.moveItem(at: candidate, to: target)
            }
            let repaired = OtzariaIndexBuildIdentity(
                database: try currentFingerprint(databasePath: databasePath),
                upstreamCommit: build.upstreamCommit,
                engineVersion: build.engineVersion,
                indexSchemaVersion: build.indexSchemaVersion,
                defaultGenerationOrder: build.defaultGenerationOrder,
                adapterVersion: build.adapterVersion,
                resourceHashes: build.resourceHashes,
                catalogueHash: manifest.lexicalArtifact.catalogueHash,
                semanticArtifactIdentity: nil
            )
            if storedIdentity(indexURL: target) != repaired {
                try writeIdentity(repaired, indexURL: target)
                OtzariaIndexFileLogger.log(
                    "repaired trusted managed index identity artifact=\(manifest.artifactIdentity)"
                )
            }
            return count
        }
        return nil
    }

    private func directorySize(_ url: URL) -> UInt64 {
        guard FileManager.default.fileExists(atPath: url.path),
              let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: []
              ) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            total &+= UInt64(values.fileSize ?? 0)
        }
        return total
    }

    private func canSeedBuildingIndex(from finalURL: URL, for identity: OtzariaIndexBuildIdentity) -> Bool {
        guard FileManager.default.fileExists(atPath: finalURL.path),
              let stored = storedIdentity(indexURL: finalURL),
              stored.upstreamCommit == identity.upstreamCommit,
              stored.engineVersion == identity.engineVersion,
              stored.indexSchemaVersion == identity.indexSchemaVersion,
              stored.defaultGenerationOrder == identity.defaultGenerationOrder,
              stored.adapterVersion == identity.adapterVersion,
              stored.resourceHashes == identity.resourceHashes,
              stored.semanticArtifactIdentity == identity.semanticArtifactIdentity,
              let compatibility = try? OtzariaSearchEngineBridge.checkCompatibility(indexURL: finalURL),
              compatibility.compatible else { return false }
        return true
    }
}
