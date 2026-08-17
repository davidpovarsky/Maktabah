import Foundation
import SQLite3

/// Opt-in DEBUG runner used only by the native bootstrap CI scripts. Normal app
/// launches never enter this path.
enum OtzariaNativeBootstrapAcceptanceRunner {
    private static let phaseKey = "OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE"
    private static let resultKey = "OTZARIA_NATIVE_BOOTSTRAP_RESULT"
    private static let priorReportKey = "OTZARIA_NATIVE_BOOTSTRAP_PRIOR_REPORT"

    /// Outcome of the cancellation phase's production install task. Recorded so a
    /// download that fails on its own is reported with its real error instead of
    /// being masked by the cancellation-threshold deadline.
    @MainActor private static var cancelPhaseInstallFinished = false
    @MainActor private static var cancelPhaseInstallFailure: Error?

    static var isRequested: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment[phaseKey] != nil
        #else
        false
        #endif
    }

    private struct Report: Codable {
        var passed = false
        var phase = ""
        var releaseID: Int64?
        var releaseTag: String?
        var assetID: Int64?
        var assetName: String?
        var expectedCompressedBytes: Int64?
        var downloadedBytes: Int64 = 0
        var resumeFromBytes: Int64 = 0
        var expectedSHA256: String?
        var actualSHA256: String?
        var shaMatched = false
        var downloadElapsedSeconds: TimeInterval = 0
        var verificationElapsedSeconds: TimeInterval = 0
        var extractedBytes: Int64 = 0
        var extractionElapsedSeconds: TimeInterval = 0
        var validationElapsedSeconds: TimeInterval = 0
        var quickCheck: String?
        var requiredTables: [String] = []
        var bookCount: Int = 0
        var lineCount: Int = 0
        var finalPath: String?
        var source: String?
        var restoreAfterRelaunch = false
        var partCleanedAfterSuccess = false
        var sidecarCleanedAfterSuccess = false
        var finalExists = false
        var stagingAbsentAfterSuccess = false
        var previousAbsentAfterSuccess = false
        var installationManifestExists = false
        var backupExcluded = false
        var managedWithoutSecurityScope = false
        var dictionaryConfigured = false
        var errors: [String] = []
    }

    private struct DictionaryReport: Codable {
        var passed = false
        var translationLoaded = false
        var acronymsLoaded = false
        var lexicalOptional = false
        var missingRequiredRejected = false
        var malformedRequiredRejected = false
        var exactSearchPassed = false
        var advancedSearchPassed = false
        var error: String?
    }

    @MainActor
    static func runIfRequested() async {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard let phase = environment[phaseKey],
              let resultPath = environment[resultKey] else { return }
        let resultURL = URL(fileURLWithPath: resultPath)

        switch phase {
        case "cancel":
            await runCancellationPhase(environment: environment, resultURL: resultURL)
        case "install":
            await runInstallPhase(resultURL: resultURL)
        case "restore":
            await runRestorePhase(environment: environment, resultURL: resultURL)
        case "dictionary":
            runDictionaryPhase(resultURL: resultURL)
        default:
            var report = Report(phase: phase)
            report.errors = ["Unknown native bootstrap acceptance phase: \(phase)"]
            try? write(report, to: resultURL)
        }
        #endif
    }
}

#if DEBUG
private extension OtzariaNativeBootstrapAcceptanceRunner {
    @MainActor
    static func runCancellationPhase(
        environment: [String: String],
        resultURL: URL
    ) async {
        var report = Report(phase: "cancel")
        do {
            let storage = try OtzariaDatabaseStorage()
            let threshold = environment["OTZARIA_NATIVE_BOOTSTRAP_CANCEL_BYTES"]
                .flatMap(Int64.init) ?? 64 * 1_024 * 1_024
            Self.cancelPhaseInstallFinished = false
            Self.cancelPhaseInstallFailure = nil
            let install = Task { @MainActor in
                do {
                    _ = try await OtzariaBootstrapAdapter.downloadAndInstallManagedDatabase { _ in }
                } catch {
                    Self.cancelPhaseInstallFailure = error
                }
                Self.cancelPhaseInstallFinished = true
            }
            let deadline = Date().addingTimeInterval(20 * 60)
            var persistedBytes: Int64 = 0
            var reachedThreshold = false
            while Date() < deadline {
                persistedBytes = OtzariaDatabaseDownloader.fileSize(
                    at: storage.downloadsRoot.appendingPathComponent(
                        OtzariaDatabaseDownloader.partFileName
                    )
                )
                if persistedBytes >= threshold {
                    OtzariaBootstrapAdapter.cancelManagedDatabaseDownload()
                    reachedThreshold = true
                    break
                }
                // Stop as soon as the production install settles on its own; the
                // recorded failure below is the diagnosis, not the deadline.
                if Self.cancelPhaseInstallFinished { break }
                try await Task.sleep(nanoseconds: 250_000_000)
            }
            if !reachedThreshold {
                install.cancel()
                if let failure = Self.cancelPhaseInstallFailure { throw failure }
                let reason = Self.cancelPhaseInstallFinished
                    ? "download finished before reaching the cancellation threshold"
                    : "download did not reach the cancellation threshold within 20 minutes; persisted \(persistedBytes) bytes"
                throw OtzariaDatabaseBootstrapError.invalidResumeResponse(reason)
            }
            await install.value
            guard let cancellation = Self.cancelPhaseInstallFailure else {
                throw OtzariaDatabaseBootstrapError.invalidResumeResponse(
                    "download completed before cancellation was observed"
                )
            }
            guard let bootstrapError = cancellation as? OtzariaDatabaseBootstrapError,
                  case .cancelled = bootstrapError else {
                throw cancellation
            }

            let partURL = storage.downloadsRoot.appendingPathComponent(
                OtzariaDatabaseDownloader.partFileName
            )
            let sidecarURL = storage.downloadsRoot.appendingPathComponent(
                OtzariaDatabaseDownloader.sidecarFileName
            )
            let metadata = try OtzariaDatabaseDownloader.loadMetadata(from: sidecarURL)
            report.releaseID = metadata?.releaseID
            report.releaseTag = metadata?.releaseTag
            report.assetID = metadata?.assetID
            report.assetName = metadata?.assetName
            report.expectedCompressedBytes = metadata?.expectedCompressedSize
            report.expectedSHA256 = metadata?.digest?.replacingOccurrences(
                of: "sha256:",
                with: ""
            )
            report.downloadedBytes = OtzariaDatabaseDownloader.fileSize(at: partURL)
            report.resumeFromBytes = report.downloadedBytes
            report.finalExists = FileManager.default.fileExists(
                atPath: storage.finalDatabaseURL.path
            )
            let sidecarExists = FileManager.default.fileExists(atPath: sidecarURL.path)
            report.passed = report.downloadedBytes > 0 &&
                sidecarExists &&
                !report.finalExists
        } catch {
            report.errors.append(error.localizedDescription)
            if let storage = try? OtzariaDatabaseStorage() {
                let partURL = storage.downloadsRoot.appendingPathComponent(
                    OtzariaDatabaseDownloader.partFileName
                )
                let sidecarURL = storage.downloadsRoot.appendingPathComponent(
                    OtzariaDatabaseDownloader.sidecarFileName
                )
                report.downloadedBytes = OtzariaDatabaseDownloader.fileSize(at: partURL)
                report.errors.append(
                    "downloads root: \(storage.downloadsRoot.path); part bytes: " +
                    "\(report.downloadedBytes); sidecar present: " +
                    "\(FileManager.default.fileExists(atPath: sidecarURL.path))"
                )
            }
        }
        try? write(report, to: resultURL)
    }

    @MainActor
    static func runInstallPhase(resultURL: URL) async {
        var report = Report(phase: "install")
        do {
            let result = try await OtzariaBootstrapAdapter.downloadAndInstallManagedDatabase { _ in }
            let storage = try OtzariaDatabaseStorage()
            report.releaseID = result.release.id
            report.releaseTag = result.release.tag
            report.assetID = result.release.asset.id
            report.assetName = result.release.asset.name
            report.expectedCompressedBytes = result.release.asset.compressedSize
            report.downloadedBytes = result.downloadedBytes
            report.resumeFromBytes = result.resumeFromBytes
            report.expectedSHA256 = result.release.expectedSHA256
            report.actualSHA256 = result.actualSHA256
            report.shaMatched = result.release.expectedSHA256 == nil ||
                result.release.expectedSHA256 == result.actualSHA256
            report.downloadElapsedSeconds = result.downloadElapsedSeconds
            report.verificationElapsedSeconds = result.verificationElapsedSeconds
            report.extractedBytes = result.databaseFileSize
            report.extractionElapsedSeconds = result.extractionElapsedSeconds
            report.validationElapsedSeconds = result.validationElapsedSeconds
            report.finalPath = result.finalURL.path
            try populateDatabaseState(&report, storage: storage)
            let dictionaryReport = try runDictionaryChecks()
            report.dictionaryConfigured = dictionaryReport.passed
            report.passed = report.shaMatched &&
                report.resumeFromBytes > 0 &&
                report.quickCheck?.lowercased() == "ok" &&
                Set(report.requiredTables) == Set(["book", "line", "category"]) &&
                report.bookCount > 0 &&
                report.lineCount > 0 &&
                report.source == "managedInternal" &&
                report.partCleanedAfterSuccess &&
                report.sidecarCleanedAfterSuccess &&
                report.finalExists &&
                report.stagingAbsentAfterSuccess &&
                report.previousAbsentAfterSuccess &&
                report.installationManifestExists &&
                report.backupExcluded &&
                report.managedWithoutSecurityScope &&
                report.dictionaryConfigured
        } catch {
            report.errors.append(error.localizedDescription)
        }
        try? write(report, to: resultURL)
    }

    @MainActor
    static func runRestorePhase(
        environment: [String: String],
        resultURL: URL
    ) async {
        var report = Report(phase: "restore")
        do {
            guard let priorPath = environment[priorReportKey] else {
                throw OtzariaDatabaseBootstrapError.invalidAssetMetadata(
                    "restore phase is missing its install report"
                )
            }
            report = try JSONDecoder().decode(
                Report.self,
                from: Data(contentsOf: URL(fileURLWithPath: priorPath))
            )
            report.phase = "restore"
            let restored = try OtzariaBootstrapAdapter.restoreForAppLaunch()
            let storage = try OtzariaDatabaseStorage()
            report.restoreAfterRelaunch = restored
            try populateDatabaseState(&report, storage: storage)
            report.passed = report.passed &&
                restored &&
                report.source == "managedInternal" &&
                report.finalExists &&
                report.quickCheck?.lowercased() == "ok" &&
                report.bookCount > 0 &&
                report.lineCount > 0
        } catch {
            report.passed = false
            report.errors.append(error.localizedDescription)
        }
        try? write(report, to: resultURL)
    }

    static func runDictionaryPhase(resultURL: URL) {
        let report: DictionaryReport
        do {
            report = try runDictionaryChecks()
        } catch {
            report = DictionaryReport(error: error.localizedDescription)
        }
        try? write(report, to: resultURL)
    }

    private static func runDictionaryChecks() throws -> DictionaryReport {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "otzaria-dictionary-acceptance-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let engine = try OtzariaSearchEngineBridge(indexURL: root)
        defer { engine.close() }
        let translation = Bundle.main.url(forResource: "dictionary", withExtension: "json")
        let acronyms = Bundle.main.url(forResource: "Acronyms", withExtension: "json")
        let status = try OtzariaTantivySearchRepository.configureRequiredDictionaries(
            engine: engine,
            magic: nil,
            translation: translation,
            acronyms: acronyms
        )

        var missingRejected = false
        do {
            _ = try OtzariaTantivySearchRepository.configureRequiredDictionaries(
                engine: engine,
                magic: nil,
                translation: nil,
                acronyms: acronyms
            )
        } catch {
            missingRejected = true
        }

        _ = try engine.addTextBook(
            title: "Dictionary acceptance",
            topics: "/acceptance",
            filePath: "otzaria-book:1",
            catalogueOrder: 0,
            generationOrder: 5,
            text: "שלום עולם",
            extraFacets: []
        )
        try engine.commit()
        let exact = try engine.search(OtzariaSearchRequest(
            query: "שלום",
            mode: .exact,
            facets: ["/"],
            limit: 10
        ))
        let advanced = try engine.search(OtzariaSearchRequest(
            query: "שלום",
            mode: .advanced,
            facets: ["/"],
            limit: 10
        ))

        let malformed = root.appendingPathComponent("malformed.json")
        try Data("{not-json".utf8).write(to: malformed)
        var malformedRejected = false
        do {
            _ = try OtzariaTantivySearchRepository.configureRequiredDictionaries(
                engine: engine,
                magic: nil,
                translation: malformed,
                acronyms: acronyms
            )
        } catch {
            malformedRejected = true
        }

        let report = DictionaryReport(
            passed: status["translation"] == true &&
                status["acronyms"] == true &&
                status["magic"] != true &&
                missingRejected && malformedRejected &&
                exact.totalCount > 0 && advanced.totalCount > 0,
            translationLoaded: status["translation"] == true,
            acronymsLoaded: status["acronyms"] == true,
            lexicalOptional: status["magic"] != true,
            missingRequiredRejected: missingRejected,
            malformedRequiredRejected: malformedRejected,
            exactSearchPassed: exact.totalCount > 0,
            advancedSearchPassed: advanced.totalCount > 0,
            error: nil
        )
        return report
    }

    private static func populateDatabaseState(
        _ report: inout Report,
        storage: OtzariaDatabaseStorage
    ) throws {
        let database = try SQLiteDatabase(
            path: storage.finalDatabaseURL.path,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        )
        report.quickCheck = try database.fetch(query: "PRAGMA quick_check(1)") {
            $0.string(at: 0) ?? ""
        }.first
        report.requiredTables = try database.fetch(
            query: "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('book', 'line', 'category') ORDER BY name"
        ) { $0.string(at: 0) ?? "" }
        report.bookCount = try database.fetch(query: "SELECT COUNT(*) FROM book") {
            $0.int(at: 0)
        }.first ?? 0
        report.lineCount = try database.fetch(query: "SELECT COUNT(*) FROM line") {
            $0.int(at: 0)
        }.first ?? 0

        let fileManager = FileManager.default
        let partURL = storage.downloadsRoot.appendingPathComponent(
            OtzariaDatabaseDownloader.partFileName
        )
        let sidecarURL = storage.downloadsRoot.appendingPathComponent(
            OtzariaDatabaseDownloader.sidecarFileName
        )
        report.partCleanedAfterSuccess = !fileManager.fileExists(atPath: partURL.path)
        report.sidecarCleanedAfterSuccess = !fileManager.fileExists(atPath: sidecarURL.path)
        report.finalExists = fileManager.fileExists(atPath: storage.finalDatabaseURL.path)
        report.stagingAbsentAfterSuccess = !fileManager.fileExists(
            atPath: storage.stagingDatabaseURL.path
        )
        report.previousAbsentAfterSuccess = !fileManager.fileExists(
            atPath: storage.previousDatabaseURL.path
        )
        report.installationManifestExists = fileManager.fileExists(
            atPath: storage.installationManifestURL.path
        )
        report.backupExcluded = try storage.finalDatabaseURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup == true
        if case .managedInternal? = OtzariaDatabaseAccessController.shared.source {
            report.source = "managedInternal"
            report.managedWithoutSecurityScope = true
        } else {
            report.source = "other"
        }
    }

    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
#endif
