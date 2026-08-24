import Foundation

actor OtzariaSearchArtifactService {
    static let shared = OtzariaSearchArtifactService()

    typealias ProgressHandler = @Sendable (OtzariaSearchArtifactProgress) -> Void

    private let client = OtzariaSearchArtifactReleaseClient()
    private let downloader = OtzariaSearchArtifactDownloader()
    private let installer = OtzariaSearchArtifactInstaller()
    private var activeArtifact: OtzariaResolvedSearchArtifact?

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
        let availability = try await checkAvailability(databasePath: databasePath)
        guard availability.availableFreeBytes >= availability.requiredFreeBytes else {
            throw OtzariaSearchArtifactError.insufficientStorage(
                required: availability.requiredFreeBytes,
                available: availability.availableFreeBytes
            )
        }
        let artifact = availability.artifact
        let storage = try OtzariaSearchArtifactStorage()
        let workspace = storage.workspaceURL(artifactIdentity: artifact.manifest.artifactIdentity)
        progress(.init(stage: .downloading, completedBytes: availability.downloadedBytes,
                       totalBytes: artifact.manifest.lexicalArtifact.packagedBytes))
        let parts = try await downloader.downloadAndVerify(
            artifact: artifact,
            workspaceURL: workspace
        ) { completed, total in
            progress(.init(stage: .downloading, completedBytes: completed, totalBytes: total))
        }
        progress(.init(stage: .verifying, completedBytes: artifact.manifest.lexicalArtifact.packagedBytes,
                       totalBytes: artifact.manifest.lexicalArtifact.packagedBytes))
        let count = try installer.install(
            artifact: artifact,
            downloadedParts: parts,
            databasePath: databasePath,
            storage: storage
        ) { completed, total in
            progress(.init(stage: .extracting, completedBytes: completed, totalBytes: total))
        }
        await downloader.cleanup(workspaceURL: workspace)
        progress(.init(stage: .ready, completedBytes: Int64(count), totalBytes: Int64(count)))
        return count
    }

    func cancel() async {
        await downloader.cancel()
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
