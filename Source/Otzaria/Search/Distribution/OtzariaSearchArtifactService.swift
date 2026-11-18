import Foundation

actor OtzariaSearchArtifactService {
    static let shared = OtzariaSearchArtifactService()

    typealias ProgressHandler = @Sendable (OtzariaSearchArtifactProgress) -> Void

    private let client = OtzariaSearchArtifactReleaseClient()
    private let downloader = OtzariaSearchArtifactDownloader()
    private let installer = OtzariaSearchArtifactInstaller()
    private var activeArtifact: OtzariaResolvedSearchArtifact?
    private var installTask: Task<UInt64, Error>?

    func checkAvailability(databasePath: String) async throws -> OtzariaSearchArtifactAvailability {
        let context = try context(databasePath: databasePath)
        let artifact = try await client.matchingArtifact(
            database: context.databaseManifest,
            databaseBytes: context.databaseBytes,
            build: context.build
        )
        activeArtifact = artifact
        let storage = try OtzariaSearchArtifactStorage()
        try storage.prepare()
        let workspace = storage.workspaceURL(artifactIdentity: artifact.manifest.artifactIdentity)
        let downloaded = await downloader.existingBytes(
            manifest: artifact.manifest,
            workspaceURL: workspace
        )
        let existingFinal = directorySize(OtzariaSearchIndexManager.shared.indexURL(for: databasePath))
        let required = OtzariaSearchArtifactPolicy.requiredInstallCapacity(
            manifest: artifact.manifest,
            alreadyDownloadedBytes: downloaded,
            existingFinalBytes: existingFinal
        )
        return OtzariaSearchArtifactAvailability(
            artifact: artifact,
            downloadedBytes: downloaded,
            requiredFreeBytes: required,
            availableFreeBytes: storage.availableCapacity()
        )
    }

    func install(
        databasePath: String,
        progress: @escaping ProgressHandler
    ) async throws -> UInt64 {
        guard installTask == nil else { throw OtzariaSearchArtifactError.operationInProgress }
        try Task.checkCancellation()
        let profile = OtzariaDataProfileRegistry.activeProfileID
        let fingerprint = try OtzariaSearchIndexManager.shared.currentFingerprint(databasePath: databasePath)
        let validateContext: @Sendable () throws -> Void = {
            try Task.checkCancellation()
            guard profile == OtzariaDataProfileRegistry.activeProfileID,
                  try OtzariaSearchIndexManager.shared.currentFingerprint(databasePath: databasePath) == fingerprint else {
                throw OtzariaSearchArtifactError.incompatible("active database/profile changed during installation")
            }
        }
        let task = Task {
            try await self.performInstall(databasePath: databasePath,
                validateContext: validateContext, progress: progress)
        }
        installTask = task
        defer { installTask = nil }
        return try await withTaskCancellationHandler(
            operation: { try await task.value },
            onCancel: { task.cancel() }
        )
    }

    private func performInstall(
        databasePath: String,
        validateContext: @escaping @Sendable () throws -> Void,
        progress: @escaping ProgressHandler
    ) async throws -> UInt64 {
        OtzariaIndexFileLogger.log("[ArtifactService] install requested for database: \(databasePath)")
        do {
            try validateContext()
            let availability = try await checkAvailability(databasePath: databasePath)
            try validateContext()
            let artifact = availability.artifact
            let storage = try OtzariaSearchArtifactStorage()
            let workspace = storage.workspaceURL(artifactIdentity: artifact.manifest.artifactIdentity)
            // Only the admitted installer may retire partial streaming files.
            await downloader.prepareStreamingWorkspace(manifest: artifact.manifest, workspaceURL: workspace)
            let downloaded = await downloader.existingBytes(manifest: artifact.manifest, workspaceURL: workspace)
            try validateContext()
            let required = OtzariaSearchArtifactPolicy.requiredInstallCapacity(
                manifest: artifact.manifest, alreadyDownloadedBytes: downloaded,
                existingFinalBytes: directorySize(OtzariaSearchIndexManager.shared.indexURL(for: databasePath)))
            let available = storage.availableCapacity()
            guard available >= required else {
                throw OtzariaSearchArtifactError.insufficientStorage(required: required, available: available)
            }
            let partDownloader = downloader
            progress(.init(stage: .downloading, completedBytes: downloaded,
                           totalBytes: artifact.manifest.lexicalArtifact.packagedBytes))
            let count = try await installer.installStreaming(
                artifact: artifact,
                databasePath: databasePath,
                storage: storage,
                validateContext: validateContext,
                downloadPart: { part in
                    let base = artifact.manifest.lexicalArtifact.parts
                        .prefix { $0.assetName != part.assetName }
                        .reduce(Int64(0)) { $0 + $1.packagedBytes }
                    let url = try await partDownloader.downloadAndVerifyPart(
                        artifact: artifact,
                        part: part,
                        workspaceURL: workspace
                    ) { received in
                        progress(.init(
                            stage: .downloading,
                            completedBytes: base + received,
                            totalBytes: artifact.manifest.lexicalArtifact.packagedBytes
                        ))
                    }
                    return url
                }
            ) { completed, total in
                progress(.init(stage: .extracting, completedBytes: completed, totalBytes: total))
            }
            await downloader.cleanup(workspaceURL: workspace)
            progress(.init(stage: .ready, completedBytes: Int64(count), totalBytes: Int64(count)))
            OtzariaIndexFileLogger.log("[ArtifactService] install successfully completed with \(count) docs")
            return count
        } catch {
            OtzariaIndexFileLogger.logError("[ArtifactService] install encountered error", error: error)
            throw error
        }
    }

    func cancel() async {
        installTask?.cancel()
    }

    /// A status refresh must never remove another window's admitted staging.
    /// Await its completion; the active installer owns its rollback/cleanup.
    func recoverInterruptedInstallation(databasePath: String, profileID: String) async {
        if let task = installTask {
            _ = try? await task.value
            return
        }
        guard profileID == OtzariaDataProfileRegistry.activeProfileID,
              let storage = try? OtzariaSearchArtifactStorage() else { return }
        installer.recover(databasePath: databasePath, storage: storage)
    }
}

struct OtzariaSearchArtifactAvailability: Equatable, Sendable {
    let artifact: OtzariaResolvedSearchArtifact
    let downloadedBytes: Int64
    let requiredFreeBytes: Int64
    let availableFreeBytes: Int64
}

struct OtzariaSearchArtifactProgress: Equatable, Sendable {
    enum Stage: Equatable, Sendable { case downloading, verifying, extracting, installing, ready }
    let stage: Stage
    let completedBytes: Int64
    let totalBytes: Int64
}

private extension OtzariaSearchArtifactService {
    struct Context {
        let databaseManifest: OtzariaDatabaseInstallationManifest
        let databaseBytes: Int64
        let build: OtzariaSearchEngineBuildInfo
    }

    func context(databasePath: String) throws -> Context {
        guard OtzariaDatabaseAccessController.shared.source == .managedInternal else {
            throw OtzariaSearchArtifactError.incompatible("external/custom database")
        }
        let storage = try OtzariaDatabaseStorage()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(
            OtzariaDatabaseInstallationManifest.self,
            from: Data(contentsOf: storage.installationManifestURL)
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: databasePath)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        return Context(
            databaseManifest: manifest,
            databaseBytes: bytes,
            build: try OtzariaSearchEngineBridge.buildInfo()
        )
    }

    func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
        ) else { return 0 }
        return enumerator.compactMap { $0 as? URL }.reduce(0) { total, file in
            guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { return total }
            return total + Int64(values.fileSize ?? 0)
        }
    }
}
