import Combine
import Foundation

@MainActor
final class OtzariaTextSearchViewModel: ObservableObject, @unchecked Sendable {
    @Published var query = ""
    @Published var negativeQuery = ""
    @Published var results: [SearchResultItem] = []
    @Published var enginePage: OtzariaSearchPage?
    @Published var mode: OtzariaSearchMode = .advanced
    @Published var order: OtzariaSearchOrder = .catalogue
    @Published var scope: OtzariaSearchScope = .wordDistance
    @Published var negativeScope: OtzariaSearchScope = .wordDistance
    @Published var wordMatchMode: OtzariaWordMatchMode = .all
    @Published var wordMatchCount = 1
    @Published var grouping: OtzariaResultGrouping?
    @Published var distance = 0
    @Published var negativeDistance = 0
    @Published var customSpacing: [String: String] = [:]
    @Published var negativeCustomSpacing: [String: String] = [:]
    @Published var alternativeWords: [String: [String]] = [:]
    @Published var negativeAlternativeWords: [String: [String]] = [:]
    @Published var searchOptions: [String: [String: Bool]] = [:]
    @Published var negativeSearchOptions: [String: [String: Bool]] = [:]
    @Published var matchNikud = false
    @Published var matchTaamim = false
    @Published var isSearching = false
    @Published var isIndexing = false
    @Published var isInstallingArtifact = false
    @Published var status: OtzariaSearchIndexStatus = .unavailable
    @Published var errorMessage: String?
    @Published var indexStatusDetail: String?

    var resultsTruncated: Bool { enginePage?.truncated == true }
    var totalCount: UInt32 { enginePage?.totalCount ?? 0 }
    var groupCount: UInt32? { enginePage?.groupCount }
    var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    private let repository = OtzariaTantivySearchRepository.shared
    private let indexingService = OtzariaSearchIndexingService.shared
    private let artifactService = OtzariaSearchArtifactService.shared
    private var currentTask: Task<Void, Never>?

    func refreshStatus() {
        guard !isIndexing, !isInstallingArtifact else { return }
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            status = .unavailable
            indexStatusDetail = nil
            return
        }
        Task.detached(priority: .utility) { [repository] in
            do {
                if try await OtzariaMagicDictionaryManager.shared.refreshIfNeeded() {
                    repository.invalidate(databasePath: path)
                    OtzariaIndexFileLogger.log("validated lexical.db release installed; search engine cache refreshed")
                }
            } catch {
                // A prior validated lexical.db remains in place. Morphology is
                // optional; lexical search/indexing must not be blocked.
                OtzariaIndexFileLogger.logError("lexical.db background refresh failed; retaining fallback", error: error)
            }
        }
        let manager = OtzariaSearchIndexManager.shared
        if OtzariaDatabaseAccessController.shared.source == .managedInternal,
           let storage = try? OtzariaSearchArtifactStorage() {
            let fileManager = FileManager.default
            let interrupted = fileManager.fileExists(
                atPath: storage.stagingURL(databasePath: path).path
            ) || (
                !fileManager.fileExists(atPath: manager.indexURL(for: path).path)
                && fileManager.fileExists(atPath: manager.previousIndexURL(for: path).path)
            )
            if interrupted {
                status = .checkingPackage
                Task.detached(priority: .utility) {
                    OtzariaSearchArtifactInstaller().recover(databasePath: path, storage: storage)
                    await MainActor.run { self.refreshStatus() }
                }
                return
            }
        }
        if manager.isIndexCurrent(databasePath: path) {
            do {
                status = .ready(documentCount: try repository.documentCount(databasePath: path))
                indexStatusDetail = buildInfoDetail()
            } catch {
                status = .failed(error.localizedDescription)
            }
            return
        }
        if OtzariaDatabaseAccessController.shared.source == .managedInternal {
            status = .checkingPackage
            indexStatusDetail = buildInfoDetail()
            let trustedIdentity = manager.trustedManagedArtifactIdentity(databasePath: path)
            Task.detached(priority: .utility) { [artifactService] in
                do {
                    let availability = try await artifactService.checkAvailability(databasePath: path)
                    await MainActor.run {
                        guard !self.isInstallingArtifact else { return }
                        let availableIdentity = availability.artifact.manifest.artifactIdentity
                        switch OtzariaSearchArtifactPolicy.managedDiscoveryDisposition(
                            trustedArtifactIdentity: trustedIdentity,
                            availableArtifactIdentity: availableIdentity
                        ) {
                        case .repairRequired:
                            self.status = .repairRequired(
                                "החבילה המותקנת זוהתה, אך פתיחת האינדקס או metadata משני דורשים תיקון."
                            )
                        case .updateAvailable:
                            self.status = .updateAvailable(
                                downloadBytes: availability.artifact.manifest.lexicalArtifact.packagedBytes,
                                artifactIdentity: availableIdentity
                            )
                        case .available:
                            self.status = .packageAvailable(
                                downloadBytes: availability.artifact.manifest.lexicalArtifact.packagedBytes,
                                requiredBytes: availability.requiredFreeBytes,
                                availableBytes: availability.availableFreeBytes
                            )
                        }
                    }
                } catch {
                    await MainActor.run {
                        guard !self.isInstallingArtifact else { return }
                        if trustedIdentity != nil {
                            self.status = .repairRequired(error.localizedDescription)
                        } else {
                            self.status = .packageUnavailable(error.localizedDescription)
                        }
                    }
                }
            }
            return
        }
        if let compatibility = manager.compatibility(databasePath: path), compatibility.requiresRebuild {
            status = .rebuildRequired(compatibility.reason ?? compatibility.status)
            return
        }
        if let checkpoint = manager.checkpoint(indexURL: manager.buildingIndexURL(for: path)) {
            status = .paused(processedBooks: checkpoint.committedBooks, totalBooks: max(checkpoint.totalBooks, 1))
            indexStatusDetail = "קיימת בנייה חלקית מחויבת; לחיצה על המשך אינדוקס תמשיך מה־checkpoint."
        } else {
            status = .notBuilt
            indexStatusDetail = buildInfoDetail()
        }
    }

    func rebuildIndex() {
        if OtzariaDatabaseAccessController.shared.source == .managedInternal {
            installPrebuiltIndex()
            return
        }
        OtzariaIndexFileLogger.clearLog()
        currentTask?.cancel()
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            status = .unavailable
            return
        }

        isIndexing = true
        status = .building(processedBooks: 0, totalBooks: 0, processedLines: 0)
        errorMessage = nil
        indexStatusDetail = nil

        currentTask = Task.detached(priority: .utility) { [indexingService] in
            do {
                let count = try await indexingService.rebuildIndex(databasePath: path) { progress in
                    Task { @MainActor in
                        guard self.currentTask?.isCancelled == false else { return }
                        self.status = progress.totalBooks > 0 && progress.processedBooks >= progress.totalBooks
                            ? .finalizing
                            : .building(
                                processedBooks: progress.processedBooks,
                                totalBooks: progress.totalBooks,
                                processedLines: progress.processedLines
                            )
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    self.status = .ready(documentCount: count)
                    self.indexStatusDetail = self.buildInfoDetail()
                    self.isIndexing = false
                    self.currentTask = nil
                }
            } catch is CancellationError {
                await self.finishPaused(path: path)
            } catch OtzariaSearchError.indexingCancelled {
                await self.finishPaused(path: path)
            } catch {
                await MainActor.run {
                    OtzariaIndexFileLogger.logError("indexing failed", error: error)
                    self.errorMessage = error.localizedDescription
                    self.status = .failed(error.localizedDescription)
                    self.isIndexing = false
                    self.currentTask = nil
                }
            }
        }
    }

    func cancelIndexing() {
        if isInstallingArtifact {
            currentTask?.cancel()
            Task { await artifactService.cancel() }
            return
        }
        currentTask?.cancel()
        indexStatusDetail = "עוצר לאחר rollback לנקודת ה־checkpoint המחויבת האחרונה…"
    }

    private func installPrebuiltIndex() {
        currentTask?.cancel()
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            status = .unavailable
            return
        }
        isInstallingArtifact = true
        isIndexing = true
        errorMessage = nil
        currentTask = Task.detached(priority: .utility) { [artifactService, repository] in
            do {
                let count = try await artifactService.install(databasePath: path) { progress in
                    Task { @MainActor in
                        switch progress.stage {
                        case .downloading, .verifying:
                            self.status = .downloadingPackage(
                                completedBytes: progress.completedBytes,
                                totalBytes: progress.totalBytes
                            )
                        case .extracting, .installing:
                            self.status = .installingPackage(
                                completedBytes: progress.completedBytes,
                                totalBytes: progress.totalBytes
                            )
                        case .ready:
                            break
                        }
                    }
                }
                repository.invalidate(databasePath: path)
                await MainActor.run {
                    self.status = .ready(documentCount: count)
                    self.indexStatusDetail = self.buildInfoDetail()
                    self.isInstallingArtifact = false
                    self.isIndexing = false
                    self.currentTask = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.status = .failed(error.localizedDescription)
                    self.isInstallingArtifact = false
                    self.isIndexing = false
                    self.currentTask = nil
                }
            }
        }
    }

    @discardableResult
    func installManagedArtifactAndWait() async -> Bool {
        guard !isReady else { return true }
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            status = .unavailable
            return false
        }
        isInstallingArtifact = true
        isIndexing = true
        errorMessage = nil
        do {
            let count = try await artifactService.install(databasePath: path) { progress in
                Task { @MainActor in
                    switch progress.stage {
                    case .downloading, .verifying:
                        self.status = .downloadingPackage(
                            completedBytes: progress.completedBytes,
                            totalBytes: progress.totalBytes
                        )
                    case .extracting, .installing:
                        self.status = .installingPackage(
                            completedBytes: progress.completedBytes,
                            totalBytes: progress.totalBytes
                        )
                    case .ready: break
                    }
                }
            }
            repository.invalidate(databasePath: path)
            status = .ready(documentCount: count)
            indexStatusDetail = buildInfoDetail()
            isInstallingArtifact = false
            isIndexing = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            status = .failed(error.localizedDescription)
            isInstallingArtifact = false
            isIndexing = false
            return false
        }
    }

    func removeManagedIndex() {
        guard let path = OtzariaMaktabahBridge.shared.databasePath else { return }
        do {
            try OtzariaSearchIndexManager.shared.clearIndex(databasePath: path)
            repository.invalidate(databasePath: path)
            status = .notBuilt
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { clear(); return }
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            errorMessage = OtzariaSearchError.databaseNotSelected.localizedDescription
            status = .unavailable
            return
        }
        let finalURL = OtzariaSearchIndexManager.shared.indexURL(for: path)
        guard FileManager.default.fileExists(atPath: finalURL.path) else {
            status = .notBuilt
            errorMessage = OtzariaDatabaseAccessController.shared.source == .managedInternal
                ? "האינדקס אינו מוכן. הורד והתקן חבילת חיפוש תואמת לפני החיפוש."
                : "האינדקס אינו מוכן. בנה או המשך את אינדקס אוצריא לפני החיפוש."
            return
        }

        isSearching = true
        errorMessage = nil
        let request = OtzariaSearchRequest(
            query: trimmed,
            mode: mode,
            facets: ["/"],
            limit: 100,
            offset: 0,
            order: order,
            distance: distance,
            negativeQuery: negativeQuery,
            negativeDistance: negativeDistance,
            scope: scope,
            negativeScope: negativeScope,
            wordMatchMode: wordMatchMode,
            wordMatchCount: wordMatchMode == .atLeast ? wordMatchCount : nil,
            customSpacing: customSpacing,
            negativeCustomSpacing: negativeCustomSpacing,
            alternativeWords: alternativeWords,
            negativeAlternativeWords: negativeAlternativeWords,
            searchOptions: searchOptions,
            negativeSearchOptions: negativeSearchOptions,
            matchNikud: matchNikud,
            matchTaamim: matchTaamim,
            grouping: grouping
        )

        Task.detached(priority: .userInitiated) { [repository] in
            do {
                let page = try repository.search(databasePath: path, request: request)
                let items = repository.navigationItems(from: page)
                await MainActor.run {
                    self.enginePage = page
                    self.results = items
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.enginePage = nil
                    self.results = []
                    self.isSearching = false
                }
            }
        }
    }

    func clear() {
        query = ""
        results = []
        enginePage = nil
        errorMessage = nil
    }

    func indexLogCopyText() -> String {
        let databasePath = OtzariaMaktabahBridge.shared.databasePath
        let manager = OtzariaSearchIndexManager.shared
        let finalURL = databasePath.map { manager.indexURL(for: $0) }
        let buildingURL = databasePath.map { manager.buildingIndexURL(for: $0) }
        let build = try? OtzariaSearchEngineBridge.buildInfo()
        return """
        Log file: \(OtzariaIndexFileLogger.logFileURL()?.path ?? "unavailable")
        Database path: \(databasePath ?? "unavailable")
        Final index: \(finalURL?.path ?? "unavailable")
        Building index: \(buildingURL?.path ?? "unavailable")
        Upstream: \(build?.upstreamCommit ?? "unavailable")
        Engine/schema: \(build?.engineVersion ?? "unavailable") / \(build.map { String($0.indexSchemaVersion) } ?? "unavailable")

        \(OtzariaIndexFileLogger.readLogText())
        """
    }

    private func finishPaused(path: String) {
        errorMessage = OtzariaSearchError.indexingCancelled.localizedDescription
        setPausedStatus(path: path)
        isIndexing = false
        currentTask = nil
    }

    private func setPausedStatus(path: String) {
        let manager = OtzariaSearchIndexManager.shared
        if let checkpoint = manager.checkpoint(indexURL: manager.buildingIndexURL(for: path)) {
            status = .paused(processedBooks: checkpoint.committedBooks, totalBooks: max(checkpoint.totalBooks, 1))
        } else {
            status = .notBuilt
        }
        indexStatusDetail = "הבנייה החלקית לא נמחקה. ניתן להמשיך מן ה־checkpoint האחרון."
    }

    private func buildInfoDetail() -> String? {
        guard let build = try? OtzariaSearchEngineBridge.buildInfo() else { return nil }
        return "Otzaria \(build.upstreamCommit.prefix(12)) · schema \(build.indexSchemaVersion) · semantic \(build.semanticEnabled ? "enabled" : "disabled")"
    }
}
