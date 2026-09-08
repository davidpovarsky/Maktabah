import Foundation

actor OtzariaDatabaseBootstrapService {
    static let shared = OtzariaDatabaseBootstrapService()

    typealias ProgressHandler = @Sendable (OtzariaDatabaseBootstrapProgress) -> Void

    private let releaseClient = OtzariaLibraryReleaseClient()
    private let downloader = OtzariaDatabaseDownloader()
    private let installer = OtzariaDatabaseInstaller()
    private var currentStorage: OtzariaDatabaseStorage?

    struct Preparation: Sendable {
        let prepared: OtzariaPreparedDatabaseInstallation
        let storage: OtzariaDatabaseStorage
        let resumeFromBytes: Int64
        let actualSHA256: String?
        let downloadElapsedSeconds: TimeInterval
        let verificationElapsedSeconds: TimeInterval
    }

    func prepareManagedDatabase(
        progress: @escaping ProgressHandler
    ) async throws -> Preparation {
        progress(.init(
            stage: .connecting,
            fraction: 0.01,
            detail: String(localized: "bootstrap.status.connecting")
        ))
        let release = try await releaseClient.fetchLatestRelease()
        let storage = try OtzariaDatabaseStorage()
        currentStorage = storage
        try storage.prepareDirectories()

        let existingPart = OtzariaDatabaseDownloader.existingPartialSize(
            workspaceURL: storage.downloadsRoot,
            release: release
        )
        try storage.preflightDownload(release: release, existingPart: existingPart)

        print(
            "[OtzariaBootstrap] release tag=\(release.tag) id=\(release.id) " +
            "assetId=\(release.asset.id) compressedSize=\(release.asset.compressedSize) " +
            "resumeFrom=\(existingPart)"
        )

        let archiveURL: URL
        let downloadStarted = Date()
        var downloadElapsed: TimeInterval = 0
        var verificationElapsed: TimeInterval = 0
        var actualSHA256: String?
        do {
            archiveURL = try await downloader.download(
                release: release,
                workspaceURL: storage.downloadsRoot
            ) { downloaded, total, resumedFrom in
                let ratio = total > 0 ? Double(downloaded) / Double(total) : 0
                let detail: String
                if resumedFrom > 0 {
                    detail = String(
                        format: String(localized: "bootstrap.status.download.resuming"),
                        locale: .current,
                        Self.format(resumedFrom),
                        Self.format(downloaded),
                        Self.format(total)
                    )
                } else {
                    detail = String(
                        format: String(localized: "bootstrap.status.download.progress"),
                        locale: .current,
                        Self.format(downloaded),
                        Self.format(total)
                    )
                }
                progress(.init(
                    stage: .downloading(resumedFrom: resumedFrom),
                    fraction: 0.03 + 0.65 * min(max(ratio, 0), 1),
                    detail: detail
                ))
            }
            downloadElapsed = Date().timeIntervalSince(downloadStarted)

            progress(.init(
                stage: .verifyingDownload,
                fraction: 0.70,
                detail: String(localized: "bootstrap.status.verifyingDownload")
            ))
            let verificationStarted = Date()
            actualSHA256 = try await Task.detached(priority: .utility) {
                try OtzariaDatabaseDownloader.verifyDownload(at: archiveURL, release: release)
            }.value
            verificationElapsed = Date().timeIntervalSince(verificationStarted)
            print(
                "[OtzariaBootstrap] download verified bytes=\(release.asset.compressedSize) " +
                "sha256=\(release.expectedSHA256 == nil ? "not supplied" : "matched")"
            )
        } catch let error as OtzariaDatabaseBootstrapError {
            if case .digestMismatch = error {
                try? await downloader.invalidateDownload(workspaceURL: storage.downloadsRoot)
            }
            if case .downloadSizeMismatch = error {
                try? await downloader.invalidateDownload(workspaceURL: storage.downloadsRoot)
            }
            throw error
        }

        do {
            let prepared = try await Task.detached(priority: .utility) { [installer] in
                try installer.prepare(
                    archiveURL: archiveURL,
                    release: release,
                    storage: storage
                ) { consumed, total in
                    let ratio = total > 0 ? Double(consumed) / Double(total) : 0
                    progress(.init(
                        stage: .extracting,
                        fraction: 0.72 + 0.20 * min(max(ratio, 0), 1),
                        detail: String(
                            format: String(localized: "bootstrap.status.extracting"),
                            locale: .current,
                            Self.format(consumed),
                            Self.format(total)
                        )
                    ))
                } validationStarted: {
                    progress(.init(
                        stage: .validatingDatabase,
                        fraction: 0.93,
                        detail: String(localized: "bootstrap.status.verifyingDatabase")
                    ))
                }
            }.value
            progress(.init(
                stage: .validatingDatabase,
                fraction: 0.94,
                detail: String(localized: "bootstrap.status.databaseVerified")
            ))
            print(
                "[OtzariaBootstrap] extraction and SQLite validation completed " +
                "outputBytes=\(prepared.databaseFileSize)"
            )
            return Preparation(
                prepared: prepared,
                storage: storage,
                resumeFromBytes: existingPart,
                actualSHA256: actualSHA256,
                downloadElapsedSeconds: downloadElapsed,
                verificationElapsedSeconds: verificationElapsed
            )
        } catch let error as OtzariaDatabaseBootstrapError {
            if case .zstdCorruptData = error {
                try? await downloader.invalidateDownload(workspaceURL: storage.downloadsRoot)
            }
            throw error
        }
    }

    func promote(
        _ prepared: OtzariaPreparedDatabaseInstallation,
        storage: OtzariaDatabaseStorage,
        progress: @escaping ProgressHandler
    ) async throws -> URL {
        progress(.init(
            stage: .installing,
            fraction: 0.97,
            detail: String(localized: "bootstrap.status.installingLibrary")
        ))
        let finalURL = try await Task.detached(priority: .utility) { [installer] in
            try installer.promote(prepared, storage: storage)
        }.value
        progress(.init(
            stage: .ready,
            fraction: 1,
            detail: String(localized: "bootstrap.status.ready")
        ))
        print("[OtzariaBootstrap] managed database promoted path=\(finalURL.path)")
        return finalURL
    }

    func finishSuccessfulInstall(storage: OtzariaDatabaseStorage) async {
        await Task.detached(priority: .utility) { [installer] in
            installer.completePromotion(storage: storage)
        }.value
        await downloader.cleanupAfterSuccessfulInstall(workspaceURL: storage.downloadsRoot)
        currentStorage = nil
    }

    func rollbackFailedActivation(storage: OtzariaDatabaseStorage) async throws {
        try await Task.detached(priority: .utility) { [installer] in
            try installer.rollbackPromotion(storage: storage)
        }.value
        currentStorage = nil
    }

    func cancel() async {
        await downloader.cancel()
    }

    func recoverInterruptedInstallation() throws {
        let storage = try OtzariaDatabaseStorage()
        try installer.recoverInterruptedInstallation(storage: storage)
    }

    private static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
