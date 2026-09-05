import Foundation

struct OtzariaSearchArtifactStorage: Sendable {
    let indexRootURL: URL
    let downloadsRootURL: URL

    init() throws {
        let manager = OtzariaSearchIndexManager.shared
        indexRootURL = manager.indexRootURL
        var downloads = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Maktabah/Otzaria", isDirectory: true)
        let profileID = OtzariaDataProfileRegistry.activeProfileID
        if profileID == OtzariaDataProfileRegistry.productionID {
            downloads = downloads.appendingPathComponent("SearchDownloads", isDirectory: true)
        } else {
            downloads = downloads
                .appendingPathComponent("Profiles", isDirectory: true)
                .appendingPathComponent(profileID, isDirectory: true)
                .appendingPathComponent("OtzariaSearchDownloads", isDirectory: true)
        }
        downloadsRootURL = downloads
    }

    init(indexRootURL: URL, downloadsRootURL: URL) {
        self.indexRootURL = indexRootURL
        self.downloadsRootURL = downloadsRootURL
    }

    func workspaceURL(artifactIdentity: String) -> URL {
        downloadsRootURL.appendingPathComponent(artifactIdentity, isDirectory: true)
    }

    func stagingURL(databasePath: String) -> URL {
        OtzariaSearchIndexManager.shared.indexURL(for: databasePath)
            .appendingPathExtension("installing")
    }

    func availableCapacity() -> Int64 {
        guard let values = try? indexRootURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]) else { return 0 }
        if let important = values.volumeAvailableCapacityForImportantUsage {
            return max(0, important)
        }
        if let fallback = values.volumeAvailableCapacity {
            return max(0, Int64(fallback))
        }
        return 0
    }

    func prepare() throws {
        try FileManager.default.createDirectory(at: indexRootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloadsRootURL, withIntermediateDirectories: true)
        try excludeFromBackup(indexRootURL)
        try excludeFromBackup(downloadsRootURL)
    }

    private func excludeFromBackup(_ url: URL) throws {
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
    }
}

struct OtzariaSearchArtifactInstaller: Sendable {
    private let extractor = OtzariaZstdStreamExtractor()

    func install(
        artifact: OtzariaResolvedSearchArtifact,
        downloadedParts: [String: URL],
        databasePath: String,
        storage: OtzariaSearchArtifactStorage,
        progress: @escaping @Sendable (_ extracted: Int64, _ total: Int64) -> Void
    ) throws -> UInt64 {
        let manager = OtzariaSearchIndexManager.shared
        let fileManager = FileManager.default
        let stagingURL = storage.stagingURL(databasePath: databasePath)
        if fileManager.fileExists(atPath: stagingURL.path) {
            try fileManager.removeItem(at: stagingURL)
        }
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try excludeFromBackup(stagingURL)

        var extracted: Int64 = 0
        do {
            for part in artifact.manifest.lexicalArtifact.parts {
                try Task.checkCancellation()
                guard let archiveURL = downloadedParts[part.assetName] else {
                    throw OtzariaSearchArtifactError.missingPart(part.assetName)
                }
                let destination = stagingURL.appendingPathComponent(part.destinationPath)
                let standardizedRoot = stagingURL.standardizedFileURL.path + "/"
                guard destination.standardizedFileURL.path.hasPrefix(standardizedRoot) else {
                    throw OtzariaSearchArtifactError.invalidPartPath(part.destinationPath)
                }
                try fileManager.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let base = extracted
                do {
                    try extractor.extractPart(
                        archiveURL: archiveURL,
                        outputURL: destination,
                        expectedOffset: part.destinationOffset,
                        expectedOutputBytes: part.uncompressedBytes
                    ) { consumed, total in
                        let fraction = total > 0 ? Double(consumed) / Double(total) : 0
                        progress(
                            base + Int64(Double(part.uncompressedBytes) * fraction),
                            artifact.manifest.lexicalArtifact.extractedBytes
                        )
                    }
                } catch {
                    throw OtzariaSearchArtifactError.extractionFailed(error.localizedDescription)
                }
                extracted += part.uncompressedBytes
                progress(extracted, artifact.manifest.lexicalArtifact.extractedBytes)
            }

            let build = try OtzariaSearchEngineBridge.buildInfo()
            let fingerprint = try manager.currentFingerprint(databasePath: databasePath)
            let identity = OtzariaIndexBuildIdentity(
                database: fingerprint,
                upstreamCommit: build.upstreamCommit,
                engineVersion: build.engineVersion,
                indexSchemaVersion: build.indexSchemaVersion,
                defaultGenerationOrder: build.defaultGenerationOrder,
                adapterVersion: build.adapterVersion,
                resourceHashes: build.resourceHashes,
                catalogueHash: artifact.manifest.lexicalArtifact.catalogueHash,
                semanticArtifactIdentity: nil
            )
            try manager.writeIdentity(identity, indexURL: stagingURL)
            let compatibility = try OtzariaSearchEngineBridge.checkCompatibility(indexURL: stagingURL)
            guard compatibility.compatible else {
                throw OtzariaSearchArtifactError.validationFailed(
                    compatibility.reason ?? compatibility.status
                )
            }
            let engine = try OtzariaSearchEngineBridge(indexURL: stagingURL)
            let count: UInt64
            do {
                count = try engine.documentCount()
            } catch {
                engine.close()
                throw error
            }
            engine.close()
            guard count == artifact.manifest.lexicalArtifact.documentCount else {
                throw OtzariaSearchArtifactError.validationFailed(
                    "opened document count \(count), expected \(artifact.manifest.lexicalArtifact.documentCount)"
                )
            }
            try writeTrustedManifest(artifact.manifest, to: stagingURL)
            try promote(stagingURL: stagingURL, databasePath: databasePath)
            return count
        } catch is CancellationError {
            try? fileManager.removeItem(at: stagingURL)
            throw OtzariaSearchArtifactError.cancelled
        } catch let error as OtzariaSearchArtifactError {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw OtzariaSearchArtifactError.validationFailed(error.localizedDescription)
        }
    }

    func installStreaming(
        artifact: OtzariaResolvedSearchArtifact,
        databasePath: String,
        storage: OtzariaSearchArtifactStorage,
        downloadPart: @escaping @Sendable (OtzariaSearchArtifactManifest.Part) async throws -> URL,
        progress: @escaping @Sendable (_ extracted: Int64, _ total: Int64) -> Void
    ) async throws -> UInt64 {
        let manager = OtzariaSearchIndexManager.shared
        let fileManager = FileManager.default
        let stagingURL = storage.stagingURL(databasePath: databasePath)
        if fileManager.fileExists(atPath: stagingURL.path) { try fileManager.removeItem(at: stagingURL) }
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try excludeFromBackup(stagingURL)

        var extracted: Int64 = 0
        do {
            for part in artifact.manifest.lexicalArtifact.parts {
                try Task.checkCancellation()
                let archiveURL = try await downloadPart(part)
                let destination = stagingURL.appendingPathComponent(part.destinationPath)
                guard destination.standardizedFileURL.path.hasPrefix(stagingURL.standardizedFileURL.path + "/") else {
                    throw OtzariaSearchArtifactError.invalidPartPath(part.destinationPath)
                }
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                let base = extracted
                do {
                    try extractor.extractPart(
                        archiveURL: archiveURL,
                        outputURL: destination,
                        expectedOffset: part.destinationOffset,
                        expectedOutputBytes: part.uncompressedBytes
                    ) { consumed, total in
                        let fraction = total > 0 ? Double(consumed) / Double(total) : 0
                        progress(base + Int64(Double(part.uncompressedBytes) * fraction), artifact.manifest.lexicalArtifact.extractedBytes)
                    }
                } catch {
                    throw OtzariaSearchArtifactError.extractionFailed(error.localizedDescription)
                }
                extracted += part.uncompressedBytes
                progress(extracted, artifact.manifest.lexicalArtifact.extractedBytes)
                try fileManager.removeItem(at: archiveURL)
            }

            let build = try OtzariaSearchEngineBridge.buildInfo()
            let fingerprint = try manager.currentFingerprint(databasePath: databasePath)
            let identity = OtzariaIndexBuildIdentity(
                database: fingerprint, upstreamCommit: build.upstreamCommit,
                engineVersion: build.engineVersion, indexSchemaVersion: build.indexSchemaVersion,
                defaultGenerationOrder: build.defaultGenerationOrder, adapterVersion: build.adapterVersion,
                resourceHashes: build.resourceHashes,
                catalogueHash: artifact.manifest.lexicalArtifact.catalogueHash,
                semanticArtifactIdentity: nil
            )
            try manager.writeIdentity(identity, indexURL: stagingURL)
            let compatibility = try OtzariaSearchEngineBridge.checkCompatibility(indexURL: stagingURL)
            guard compatibility.compatible else {
                throw OtzariaSearchArtifactError.validationFailed(compatibility.reason ?? compatibility.status)
            }
            let engine = try OtzariaSearchEngineBridge(indexURL: stagingURL)
            let count = try engine.documentCount()
            engine.close()
            guard count == artifact.manifest.lexicalArtifact.documentCount else {
                throw OtzariaSearchArtifactError.validationFailed("opened document count \(count), expected \(artifact.manifest.lexicalArtifact.documentCount)")
            }
            try writeTrustedManifest(artifact.manifest, to: stagingURL)
            try promote(stagingURL: stagingURL, databasePath: databasePath)
            return count
        } catch is CancellationError {
            try? fileManager.removeItem(at: stagingURL)
            throw OtzariaSearchArtifactError.cancelled
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        }
    }

    func recover(databasePath: String, storage: OtzariaSearchArtifactStorage) {
        let fileManager = FileManager.default
        let staging = storage.stagingURL(databasePath: databasePath)
        if fileManager.fileExists(atPath: staging.path) { try? fileManager.removeItem(at: staging) }
        let manager = OtzariaSearchIndexManager.shared
        let final = manager.indexURL(for: databasePath)
        let previous = manager.previousIndexURL(for: databasePath)
        if !fileManager.fileExists(atPath: final.path), fileManager.fileExists(atPath: previous.path) {
            try? fileManager.moveItem(at: previous, to: final)
        }
    }
}

private extension OtzariaSearchArtifactInstaller {
    func promote(stagingURL: URL, databasePath: String) throws {
        let manager = OtzariaSearchIndexManager.shared
        let fileManager = FileManager.default
        let final = manager.indexURL(for: databasePath)
        let previous = manager.previousIndexURL(for: databasePath)
        OtzariaTantivySearchRepository.shared.invalidate(databasePath: databasePath)
        if fileManager.fileExists(atPath: previous.path) { try fileManager.removeItem(at: previous) }
        if fileManager.fileExists(atPath: final.path) { try fileManager.moveItem(at: final, to: previous) }
        do {
            try fileManager.moveItem(at: stagingURL, to: final)
            let engine = try OtzariaSearchEngineBridge(indexURL: final)
            _ = try engine.documentCount()
            engine.close()
            if fileManager.fileExists(atPath: previous.path) { try fileManager.removeItem(at: previous) }
            OtzariaTantivySearchRepository.shared.invalidate(databasePath: databasePath)
        } catch {
            if fileManager.fileExists(atPath: final.path) { try? fileManager.removeItem(at: final) }
            if fileManager.fileExists(atPath: previous.path) { try? fileManager.moveItem(at: previous, to: final) }
            throw OtzariaSearchArtifactError.activationFailed(error.localizedDescription)
        }
    }

    func writeTrustedManifest(
        _ manifest: OtzariaSearchArtifactManifest,
        to indexURL: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = indexURL.appendingPathComponent("otzaria_prebuilt_installation.json")
        try encoder.encode(manifest).write(to: url, options: .atomic)
        try excludeFromBackup(url)
    }

    func excludeFromBackup(_ url: URL) throws {
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
    }
}
