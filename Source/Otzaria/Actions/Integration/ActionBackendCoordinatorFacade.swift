import Foundation
import OtzariaActionCore

/// Additive facade over the real application coordinator. No automatic backend
/// selection, app composition, UI command, private registration or new engine.
@MainActor
final class ActionBackendCoordinatorFacade: ActionBackendStatePort, ActionResolverDataPort, ActionSearchPort, ActionCommentaryDataPort, ActionOccurrenceCountPort, ActionSearchPreparationObservationPort, ActionTableOfContentsPort, ActionSourceTextPort, ActionVersionListPort, ActionNavigationStructurePort, ActionNavigationItemsPort, ActionCatalogAuthorsPort, ActionRelatedSourcesPort, ActionRelatedRefsPort, ActionRelatedTopicsPort, ActionOfflinePackageObservationPort, ActionOfflinePackageCancellationPort {
    typealias ReadinessProbe = @MainActor @Sendable (ActionBackendSnapshot) async throws -> ActionBackendRuntimeEvidence
    typealias EpochProbe = @Sendable () async -> UInt64?
    typealias EmbeddedSearch = @Sendable (ActionSearchQuery, ActionPortInvocation) async throws -> ActionSearchPage
    typealias EmbeddedReferenceProof = @Sendable (ActionTextRef, ActionPortInvocation) async throws -> Void
    typealias EmbeddedCatalog = @Sendable (ActionPortInvocation) async throws -> [LibraryCatalogNode]
    typealias OccurrenceReadiness = @Sendable (ActionBackendSnapshot) async -> ActionReadinessEvidence
    typealias OccurrenceCounter = @Sendable (ActionOccurrenceQuery, ActionPortInvocation) async throws -> ActionExactOccurrenceCount
    typealias SearchExecutionWork = @Sendable () async throws -> Void
    typealias SearchExecutionPreparation = @MainActor @Sendable (ActionSearchQuery, ActionPortInvocation) throws -> SearchExecutionWork
    typealias SearchPreparationObservation = @MainActor @Sendable (ActionPortInvocation) async throws -> ActionExistingSearchPreparationObservation
    private let coordinator: BackendCoordinator
    private let readiness: ReadinessProbe
    private let epoch: EpochProbe
    private let currentEpoch: (@MainActor @Sendable () throws -> UInt64?)?
    private let resourceWitness: (@MainActor @Sendable () throws -> BackendCoordinator.ResourceWitness)?
    private let embeddedSearch: EmbeddedSearch?
    private let embeddedReferenceProof: EmbeddedReferenceProof?
    private let embeddedCatalog: EmbeddedCatalog?
    private let occurrenceReadiness: OccurrenceReadiness?
    private let occurrenceCounter: OccurrenceCounter?
    private let searchExecutionPreparation: SearchExecutionPreparation?
    private let searchPreparationObservation: SearchPreparationObservation?
    nonisolated let hasSearchExecutionPreparation: Bool

    init(coordinator: BackendCoordinator, epoch: @escaping EpochProbe = { nil },
         currentEpoch: (@MainActor @Sendable () throws -> UInt64?)? = nil,
         resourceWitness: (@MainActor @Sendable () throws -> BackendCoordinator.ResourceWitness)? = nil,
         readiness: @escaping ReadinessProbe = { .init(snapshot: $0) },
         embeddedSearch: EmbeddedSearch? = nil,
         embeddedReferenceProof: EmbeddedReferenceProof? = nil,
         embeddedCatalog: EmbeddedCatalog? = nil,
         occurrenceReadiness: OccurrenceReadiness? = nil,
         occurrenceCounter: OccurrenceCounter? = nil,
         searchExecutionPreparation: SearchExecutionPreparation? = nil,
         searchPreparationObservation: SearchPreparationObservation? = nil) {
        self.coordinator = coordinator; self.epoch = epoch; self.currentEpoch = currentEpoch; self.readiness = readiness
        self.resourceWitness = resourceWitness
        self.embeddedSearch = embeddedSearch; self.embeddedReferenceProof = embeddedReferenceProof
        self.embeddedCatalog = embeddedCatalog
        self.occurrenceReadiness = occurrenceReadiness
        self.occurrenceCounter = occurrenceCounter
        self.searchPreparationObservation = searchPreparationObservation
        self.searchExecutionPreparation = searchExecutionPreparation
        self.hasSearchExecutionPreparation = searchExecutionPreparation != nil
    }

    func snapshot() async throws -> ActionBackendSnapshot {
        try Task.checkCancellation()
        if currentEpoch != nil { return try currentBackendSnapshot() }
        try observeCurrentResources()
        let backend = ActionAppIdentityBridge.actionBackend(coordinator.activeBackendID)
        let generation = coordinator.generation
        let rpcEpoch = backend == .sefariaEmbedded ? await epoch() : nil
        try observeCurrentResources()
        guard generation == coordinator.generation,
              backend == ActionAppIdentityBridge.actionBackend(coordinator.activeBackendID) else { throw ActionPortError.staleState }
        return .init(backend: backend, generation: generation, rpcEpoch: rpcEpoch)
    }

    /// P's synchronous commit guard reads the same production authority as the
    /// async port. An async-only Embedded composition cannot invent a value.
    func currentBackendSnapshot() throws -> ActionBackendSnapshot {
        try observeCurrentResources()
        let backend = ActionAppIdentityBridge.actionBackend(coordinator.activeBackendID)
        let epoch: UInt64?
        if backend == .sefariaEmbedded {
            guard let currentEpoch, let actual = try currentEpoch() else { throw ActionPortError.unavailable }
            epoch = actual
        } else { epoch = nil }
        return .init(backend: backend, generation: coordinator.generation, rpcEpoch: epoch)
    }

    private func observeCurrentResources() throws {
        if coordinator.activeBackendID == .otzaria, let resourceWitness {
            coordinator.observeResourceWitness(try resourceWitness(), for: .otzaria)
        }
    }

    private func currentEvidence(for backend: ActionBackendID) async throws -> ActionBackendRuntimeEvidence {
        let before = try await snapshot()
        if before.backend != backend { return .init(snapshot: before) }
        var result = try await readiness(before)
        guard result.snapshot == before, try await snapshot() == before else { throw ActionPortError.staleState }
        // Bits establish provider registration only; operation readiness comes
        // exclusively from the separate snapshot-bound observation above.
        result.registeredCapabilities = ActionAppIdentityBridge.capabilityNames(coordinator.capabilities)
        if backend == .sefariaEmbedded {
            if embeddedCatalog == nil { result.catalog = .unavailable; result.references = .unavailable }
            if embeddedSearch == nil { result.embeddedResponseFidelity = .unknown }
            if embeddedReferenceProof == nil { result.references = .unavailable }
        }
        return result
    }

    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        let evidence = try await currentEvidence(for: backend)
        var operations = try ActionBackendSemanticProfile(backend: backend).report(evidence: evidence).operations
        operations["search.countOccurrences"] = await occurrenceAssessment(backend: backend, evidence: evidence)
        guard try await snapshot() == evidence.snapshot else { throw ActionPortError.staleState }
        return .init(id: backend, operations: operations)
    }

    /// The generic source profile continues to fail closed. Only this optional
    /// app-owned composition can attest qualified complete managed artifacts.
    /// A registered search provider or a nonempty index alone is insufficient.
    private func occurrenceAssessment(backend: ActionBackendID, query: ActionOccurrenceQuery? = nil,
                                      evidence: ActionBackendRuntimeEvidence) async -> ActionCapabilityAssessment {
        let registered = evidence.registeredCapabilities.contains("search") && occurrenceCounter != nil
        guard backend == .otzaria, occurrenceCounter != nil, let occurrenceReadiness else {
            return .init(registered: registered, supported: false, availableNow: false,
                         reasonCode: "exact_count_unavailable")
        }
        if let query, let reason = query.unsupportedReason {
            return .init(registered: registered, supported: false, availableNow: false, reasonCode: reason)
        }
        guard evidence.snapshot.backend == backend else {
            return .init(registered: registered, supported: true, availableNow: false,
                         reasonCode: "backend_selection_required")
        }
        guard registered else {
            return .init(registered: false, supported: true, availableNow: false,
                         reasonCode: "provider_not_registered")
        }
        guard evidence.catalog.isReady, evidence.search.isReady,
              await occurrenceReadiness(evidence.snapshot) == .ready else {
            return .init(registered: true, supported: true, availableNow: false,
                         reasonCode: "occurrence_coverage_unverified")
        }
        return .init(registered: true, supported: true, availableNow: true)
    }

    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        let target = try ActionBackendArgumentTarget.resolve(arguments, fallback: invocation.snapshot.backend)
        let before = try await snapshot()
        try ActionBackendInvocationGuard.check(invocation, current: before, target: before.backend)
        if action == "search.countOccurrences" {
            let query = try ActionOccurrenceQuery.arguments(arguments, backend: target)
            let result = await occurrenceAssessment(backend: target, query: query,
                evidence: try await currentEvidence(for: target))
            try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: before.backend)
            return result
        }
        let query = ["search.query", "search.openResults"].contains(action) ? try ActionSearchArgumentMapping.query(arguments, backend: target) : nil
        let result = try ActionBackendSemanticProfile(backend: target).assess(action: action, query: query,
                    evidence: await currentEvidence(for: target))
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: before.backend)
        return result
    }

    private func require(_ action: String, backend: ActionBackendID, query: ActionSearchQuery? = nil,
                         invocation: ActionPortInvocation) async throws {
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
        let result = try ActionBackendSemanticProfile(backend: backend).assess(action: action, query: query,
                        evidence: await currentEvidence(for: backend))
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
        guard result.registered else { throw ActionPortError.unavailable }
        guard result.supported else { throw ActionPortError.notSupported }
        guard result.availableNow else { throw ActionPortError.unavailable }
    }

    private func catalogWorks(backend: ActionBackendID, invocation: ActionPortInvocation) async throws -> ActionAppCatalogSnapshot {
        try await require("catalog.resolveWork", backend: backend, invocation: invocation)
        let nodes: [LibraryCatalogNode]
        do {
            if backend == .sefariaEmbedded {
                guard let embeddedCatalog else { throw ActionPortError.notSupported }
                nodes = try await embeddedCatalog(invocation)
            } else { nodes = try await coordinator.catalog(for: ActionAppIdentityBridge.appBackend(backend)) }
        }
        catch { throw safe(error) }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
        guard !nodes.isEmpty else { throw ActionPortError.unavailable }
        let task = Task.detached {
            let works = try ActionLibraryProjection.works(nodes, invocation: invocation)
            return ActionAppCatalogSnapshot(works: works, workKeys: Set(works.map { $0.locator.workKey }))
        }
        let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
        guard !result.works.isEmpty else { throw ActionPortError.unavailable }
        return result
    }

    func catalog(for backend: ActionBackendID, invocation: ActionPortInvocation) async throws -> [ActionCatalogEntry] {
        let works = try await catalogWorks(backend: backend, invocation: invocation)
        let task = Task.detached { try ActionLibraryProjection.catalog(works.works, backend: backend, invocation: invocation) }
        let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
        return result
    }

    /// Execution-only optional seam. It cannot manufacture registration,
    /// capability readiness or a read grant; Core reassesses after it returns.
    func prepareSearchExecution(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws {
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
        guard query.backend == .otzaria, let searchExecutionPreparation else { throw ActionPortError.unavailable }
        try ActionSearchSemantics.validateBounds(query)
        guard ActionSearchSemantics.unsupportedReason(query) == nil else { throw ActionPortError.notSupported }
        let evidence = try await currentEvidence(for: query.backend)
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
        guard evidence.catalog.isReady, evidence.registeredCapabilities.contains("search") else {
            throw ActionPortError.unavailable
        }
        // Capture the app's source synchronously, then check this same facade's
        // authority before starting work. A source change between the first
        // await and capture must not open the newly selected source by accident.
        let work = try searchExecutionPreparation(query, invocation)
        try ActionBackendInvocationGuard.check(invocation, current: currentBackendSnapshot(), target: query.backend)
        do { try await work() }
        catch { throw safe(error) }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
    }


    /// Observation only: keep execution preparation and capability assessment
    /// untouched. No returned work is invoked and no readiness bit is promoted.
    func observeExistingSearchPreparation(invocation: ActionPortInvocation) async throws
        -> ActionExistingSearchPreparationObservation {
        let backend = invocation.snapshot.backend
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
        guard backend == .otzaria, searchExecutionPreparation != nil,
              let searchPreparationObservation else { return .unavailable }
        let evidence = try await currentEvidence(for: backend)
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
        guard evidence.snapshot == invocation.snapshot, evidence.catalog.isReady,
              evidence.registeredCapabilities.contains("search") else { return .unavailable }
        let observed = try await searchPreparationObservation(invocation)
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
        guard observed == .eligible(invocation: invocation) else { return .unavailable }
        return observed
    }

    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage {
        try await require("search.query", backend: query.backend, query: query, invocation: invocation)
        let works = try await catalogWorks(backend: query.backend, invocation: invocation)
        if query.backend == .sefariaEmbedded {
            guard let embeddedSearch else { throw ActionPortError.notSupported }
            let result: ActionSearchPage
            do { result = try await embeddedSearch(query, invocation) }
            catch { throw safe(error) }
            try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
            try await require("search.query", backend: query.backend, query: query, invocation: invocation)
            guard result.hits.allSatisfy({ $0.locator.backend == query.backend && works.workKeys.contains($0.locator.workKey) }) else {
                throw ActionPortError.invalidResponse
            }
            return result
        }
        let scopeTask = Task.detached {
            let scoped = works.works.map { ActionSearchScopeEntry(workRef: .init(backend: query.backend, workKey: $0.locator.workKey),
                                                           authoritativeFilter: $0.searchPath) }
            return try ActionSearchScopeMapping.filters(for: query, catalog: scoped)
        }
        let filters = try await withTaskCancellationHandler { try await scopeTask.value } onCancel: { scopeTask.cancel() }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
        var request = LibrarySearchRequest(query: query.text, offset: query.offset, limit: query.limit)
        request.filters = filters
        // Legacy may perform unbounded postfilter scans when these are passed
        // without authoritative filters. Never enter that fallback here.
        request.scopeWorkKeys = []
        guard let mode = LibrarySearchMode(rawValue: query.searchMode.rawValue),
              let match = LibrarySearchMatchMode(rawValue: query.matchMode.rawValue),
              let order = LibrarySearchSortOrder(rawValue: query.sortOrder.rawValue) else { throw ActionPortError.notSupported }
        request.options.searchMode = mode
        request.options.matchMode = match
        request.options.sortOrder = order
        request.options.wordDistance = query.wordDistance
        let page: LibrarySearchPage
        do { page = try await coordinator.search(request) }
        catch { throw safe(error) }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
        // Recheck operation-specific readiness after provider execution too.
        try await require("search.query", backend: query.backend, query: query, invocation: invocation)
        let task = Task.detached { try ActionLibraryProjection.searchPage(page, query: query, works: works.works) }
        let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
        return result
    }

    func countOccurrences(_ query: ActionOccurrenceQuery,
                          invocation: ActionPortInvocation) async throws -> ActionExactOccurrenceCount {
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
        guard query.unsupportedReason == nil else { throw ActionOccurrenceFailure.unsupportedQuery }
        guard let occurrenceCounter else { throw ActionPortError.notSupported }
        let assessment = await occurrenceAssessment(backend: query.backend, query: query,
            evidence: try await currentEvidence(for: query.backend))
        guard assessment.supported else { throw ActionPortError.notSupported }
        guard assessment.registered, assessment.availableNow else { throw ActionOccurrenceFailure.incompleteCoverage }
        let works = try await catalogWorks(backend: query.backend, invocation: invocation)
        guard query.scopeWorkRefs.allSatisfy({ $0.backend == query.backend && works.workKeys.contains($0.workKey) }) else {
            throw ActionPortError.notFound
        }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
        let result: ActionExactOccurrenceCount
        do { result = try await occurrenceCounter(query, invocation) }
        catch let error as ActionOccurrenceFailure { throw error }
        catch { throw safe(error) }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
        let after = await occurrenceAssessment(backend: query.backend, query: query,
            evidence: try await currentEvidence(for: query.backend))
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
        guard after.registered, after.supported, after.availableNow else { throw ActionOccurrenceFailure.staleIndex }
        guard result.requestId == invocation.requestId, result.snapshot == invocation.snapshot,
              result.query == query, result.query.text.utf8.elementsEqual(query.text.utf8) else {
            throw ActionPortError.invalidResponse
        }
        return result
    }

    func catalogAuthors(backend: ActionBackendID, invocation: ActionPortInvocation) async throws -> [ActionCatalogAuthor] {
        try await require("catalog.listAuthors", backend: backend, invocation: invocation)
        let original: [LibraryAuthor]
        do { original = try await coordinator.authors() }
        catch { throw safe(error) }
        try await require("catalog.listAuthors", backend: backend, invocation: invocation)
        return original.map { .init(id: $0.id, name: $0.name) }
    }

    func navigationStructures(for work: ActionWorkRef, invocation: ActionPortInvocation)
        async throws -> [ActionNavigationStructure] {
        try await require("reader.getNavigationStructures", backend: work.backend, invocation: invocation)
        let catalog = try await catalogWorks(backend: work.backend, invocation: invocation)
        guard let sourceWork = catalog.works.first(where: { $0.locator.workKey.utf8.elementsEqual(work.workKey.utf8) }) else {
            throw ActionPortError.notFound
        }
        let original: [LibraryNavigationStructure]
        do { original = try await coordinator.navigationStructures(for: sourceWork) }
        catch { throw safe(error) }
        try await require("reader.getNavigationStructures", backend: work.backend, invocation: invocation)
        return original.map { .init(id: $0.id, title: $0.title) }
    }

    func navigationItems(for work: ActionWorkRef, structureID: String?, maximumEntries: Int,
                         invocation: ActionPortInvocation) async throws -> [ActionSourceSectionEntry] {
        guard work.catalogRevision == nil, (1...101).contains(maximumEntries) else {
            throw ActionContractError.invalid("workRef")
        }
        try await require("reader.navigationItems", backend: work.backend, invocation: invocation)
        let catalog = try await catalogWorks(backend: work.backend, invocation: invocation)
        guard let sourceWork = catalog.works.first(where: { $0.locator.workKey.utf8.elementsEqual(work.workKey.utf8) }) else {
            throw ActionPortError.notFound
        }

        let entries: [ActionSourceSectionEntry]
        do {
            if let structureID {
                let structures = try await coordinator.navigationStructures(for: sourceWork)
                let matches = structures.filter { $0.id.utf8.elementsEqual(structureID.utf8) }
                guard matches.count <= 1 else { throw ActionPortError.invalidResponse }
                guard let structure = matches.first else { throw ActionPortError.notFound }
                let task = Task.detached {
                    try ActionLibraryProjection.sourceSections(structure.nodes, invocation: invocation,
                                                               maximumEntries: maximumEntries, leavesOnly: true)
                }
                entries = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            } else {
                let items = try await coordinator.navigationItems(for: sourceWork)
                entries = try items.prefix(maximumEntries).map {
                    .init(locator: try ActionAppIdentityBridge.actionRef($0.locator), title: $0.title)
                }
            }
        } catch let error as ActionPortError { throw error }
        catch { throw safe(error) }
        try await require("reader.navigationItems", backend: work.backend, invocation: invocation)
        return entries
    }

    func versions(for work: ActionWorkRef, invocation: ActionPortInvocation) async throws -> [ActionTextVersion] {
        try await require("reader.listVersions", backend: work.backend, invocation: invocation)
        let catalog = try await catalogWorks(backend: work.backend, invocation: invocation)
        guard let sourceWork = catalog.works.first(where: { $0.locator.workKey.utf8.elementsEqual(work.workKey.utf8) }) else {
            throw ActionPortError.notFound
        }
        let original: [TextVersionMetadata]
        do { original = try await coordinator.versions(for: sourceWork.locator.workKey) }
        catch { throw safe(error) }
        try await require("reader.listVersions", backend: work.backend, invocation: invocation)
        return original.map {
            .init(title: $0.title, language: $0.language, actualLanguage: $0.actualLanguage,
                  sourceURL: $0.sourceURL?.absoluteString, license: $0.license, notes: $0.notes, isPrimary: $0.isPrimary)
        }
    }

    func tableOfContents(for work: ActionWorkRef, maximumEntries: Int,
                         invocation: ActionPortInvocation) async throws -> [ActionSourceSectionEntry] {
        guard work.catalogRevision == nil, (1...101).contains(maximumEntries) else {
            throw ActionContractError.invalid("workRef")
        }
        try await require("reader.getTOC", backend: work.backend, invocation: invocation)
        let catalog = try await catalogWorks(backend: work.backend, invocation: invocation)
        guard let sourceWork = catalog.works.first(where: { $0.locator.workKey == work.workKey }) else {
            throw ActionPortError.notFound
        }
        let nodes: [LibraryTOCNode]
        do { nodes = try await coordinator.tableOfContents(for: sourceWork) }
        catch { throw safe(error) }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: work.backend)
        let task = Task.detached {
            try ActionLibraryProjection.sourceSections(nodes, invocation: invocation, maximumEntries: maximumEntries)
        }
        let entries = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
        try await require("reader.getTOC", backend: work.backend, invocation: invocation)
        return entries
    }

    func offlinePackages(forceRefresh: Bool, invocation: ActionPortInvocation) async throws -> [ActionOfflinePackage] {
        let backend = invocation.snapshot.backend
        try await require("packages.list", backend: backend, invocation: invocation)
        guard let provider = coordinator.offlineProvider() else { throw ActionPortError.invalidResponse }
        // The Embedded provider has no force-refresh operation.
        guard backend != .sefariaEmbedded || !forceRefresh else { throw ActionContractError.invalid("forceRefresh") }
        let packages: [OfflinePackage]
        do { packages = try await provider.packages(forceRefresh: forceRefresh) }
        catch { throw safe(error) }
        try await require("packages.list", backend: backend, invocation: invocation)
        return packages.map {
            .init(id: $0.id, title: $0.title, heTitle: $0.heTitle, parentID: $0.parentID,
                  compressedSize: $0.compressedSize, indexTitles: $0.indexTitles, isCompleteLibrary: $0.isCompleteLibrary)
        }
    }

    func offlinePackageStatus(includeWorks: Bool, invocation: ActionPortInvocation) async throws -> ActionOfflinePackageStatus {
        let backend = invocation.snapshot.backend
        try await require("packages.status", backend: backend, invocation: invocation)
        guard let provider = coordinator.offlineProvider() else { throw ActionPortError.invalidResponse }
        let packages = await provider.installedPackageIDs().sorted()
        let active = await (provider as? SefariaPackageManager)?.activeInstallID()
        try await require("packages.status", backend: backend, invocation: invocation)
        guard includeWorks else {
            return .init(installedPackageIDs: packages, installedWorkKeys: nil, activeOperationHandle: active)
        }
        guard let workProvider = coordinator.offlineWorkProvider() else { throw ActionPortError.invalidResponse }
        let works = await workProvider.installedWorkKeys().sorted()
        try await require("packages.status", backend: backend, invocation: invocation)
        return .init(installedPackageIDs: packages, installedWorkKeys: works, activeOperationHandle: active)
    }

    func offlinePackageCancellationAvailable(invocation: ActionPortInvocation) async throws -> Bool {
        try await require("packages.cancel", backend: .sefaria, invocation: invocation)
        guard let manager = coordinator.offlineProvider() as? SefariaPackageManager else { return false }
        let active = await manager.activeInstallID() != nil
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: .sefaria)
        return active
    }

    func cancelOfflinePackage(operationHandle: UUID?, sceneID: String, invocation: ActionPortInvocation,
                              authorization: ActionNavigationPreparation) async throws -> UUID {
        try await require("packages.cancel", backend: .sefaria, invocation: invocation)
        guard let manager = coordinator.offlineProvider() as? SefariaPackageManager else {
            throw ActionPortError.notSupported
        }
        guard let operation = await manager.installOperation(matching: operationHandle) else {
            throw ActionPortError.notFound
        }
        try authorization.authorizeCommit(invocation: invocation, sceneID: sceneID)
        // This handle only points at the captured original task. Even if the
        // manager has moved on, cancellation cannot affect a replacement.
        operation.task.cancel()
        return operation.id
    }

    func offlinePackageUpdates(invocation: ActionPortInvocation) async throws -> ActionOfflinePackageUpdates {
        let backend = invocation.snapshot.backend
        try await require("packages.checkUpdates", backend: backend, invocation: invocation)
        guard let provider = coordinator.offlineProvider() else { throw ActionPortError.invalidResponse }
        let updates: OfflineUpdateSummary
        do { updates = try await provider.availableUpdates() }
        catch { throw safe(error) }
        try await require("packages.checkUpdates", backend: backend, invocation: invocation)
        return .init(changedWorkCount: updates.changedWorkCount, affectedPackageIDs: updates.affectedPackageIDs.sorted())
    }

    func relatedRefs(for locator: ActionTextRef, invocation: ActionPortInvocation) async throws -> [ActionTextRef] {
        let backend = locator.backend
        try await require("reader.relatedRefs", backend: backend, invocation: invocation)
        guard try await validate(locator, invocation: invocation) == locator else { throw ActionPortError.invalidResponse }
        let native = try ActionAppIdentityBridge.appLocator(locator)
        let refs: [TextLocator]
        do { refs = try await coordinator.related(to: native) }
        catch { throw safe(error) }
        guard refs.count <= 10_000 else { throw ActionPortError.invalidResponse }
        let works = try await catalogWorks(backend: backend, invocation: invocation)
        var result: [ActionTextRef] = []
        for (index, ref) in refs.enumerated() {
            if index.isMultiple(of: 256) {
                await Task.yield()
                try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
            }
            guard ActionAppIdentityBridge.actionBackend(ref.backend) == backend,
                  works.workKeys.contains(ref.workKey) else { throw ActionPortError.invalidResponse }
            result.append(try ActionAppIdentityBridge.actionRef(ref))
        }
        try await require("reader.relatedRefs", backend: backend, invocation: invocation)
        return result
    }

    func relatedTopics(for locator: ActionTextRef, invocation: ActionPortInvocation) async throws -> [ActionRelatedTopic] {
        let backend = locator.backend
        try await require("reader.relatedTopics", backend: backend, invocation: invocation)
        guard try await validate(locator, invocation: invocation) == locator else { throw ActionPortError.invalidResponse }
        let native = try ActionAppIdentityBridge.appLocator(locator)
        let topics: [LibraryRelatedTopic]
        do { topics = try await coordinator.topics(for: native) }
        catch { throw safe(error) }
        guard topics.count <= 10_000 else { throw ActionPortError.invalidResponse }
        try await require("reader.relatedTopics", backend: backend, invocation: invocation)
        return topics.map { .init(slug: $0.slug, titleHe: $0.titleHe, titleEn: $0.titleEn) }
    }

    func relatedSources(for locator: ActionTextRef,
                        invocation: ActionPortInvocation) async throws -> [ActionRelatedSource] {
        let backend = locator.backend
        try await require("reader.relatedSources", backend: backend, invocation: invocation)
        guard try await validate(locator, invocation: invocation) == locator else { throw ActionPortError.invalidResponse }
        let native = try ActionAppIdentityBridge.appLocator(locator)
        let original: [LibraryRelatedSource]
        do { original = try await coordinator.links(for: native) }
        catch { throw safe(error) }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
        guard original.count <= 10_000 else { throw ActionPortError.invalidResponse }
        let works = try await catalogWorks(backend: backend, invocation: invocation)
        var result: [ActionRelatedSource] = []
        for (index, link) in original.enumerated() {
            if index.isMultiple(of: 256) {
                await Task.yield()
                try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
            }
            guard ActionAppIdentityBridge.actionBackend(link.locator.backend) == backend,
                  works.workKeys.contains(link.locator.workKey) else { throw ActionPortError.invalidResponse }
            result.append(.init(locator: try ActionAppIdentityBridge.actionRef(link.locator),
                                displayRef: link.displayRef, category: link.category, relationshipType: link.type))
        }
        try await require("reader.relatedSources", backend: backend, invocation: invocation)
        return result
    }

    func commentaryLinks(for baseLocator: ActionTextRef,
                         invocation: ActionPortInvocation) async throws -> [ActionCommentaryLink] {
        let backend = baseLocator.backend
        try await require("reader.openCommentary", backend: backend, invocation: invocation)
        guard try await validate(baseLocator, invocation: invocation) == baseLocator else { throw ActionPortError.invalidResponse }
        let nativeBase = try ActionAppIdentityBridge.appLocator(baseLocator)
        let sources: [LibraryRelatedSource]
        do { sources = try await coordinator.links(for: nativeBase) }
        catch { throw safe(error) }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
        guard sources.count <= 10_000 else { throw ActionPortError.invalidResponse }
        var result: [ActionCommentaryLink] = []
        for (index, source) in sources.enumerated() {
            if index.isMultiple(of: 256) {
                await Task.yield()
                try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
            }
            // The inspector's original classifier distinguishes actual
            // commentary from quoting commentary, translations and other links.
            guard OtzariaRelationshipClassifier.classify(category: source.category, type: source.type).relationshipKind == .commentary else { continue }
            guard ActionAppIdentityBridge.actionBackend(source.locator.backend) == backend else { throw ActionPortError.invalidResponse }
            let original = ReaderDestinationResolver.resolve(locator: source.locator)
            let destination = ActionReaderDestination(sectionLocator: try ActionAppIdentityBridge.actionRef(original.sectionLocator),
                focusLocator: try original.focusLocator.map(ActionAppIdentityBridge.actionRef))
            let names = [source.displayRef, source.heRef, source.collectiveTitle, source.heCollectiveTitle]
                .compactMap { $0 }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let title = names.last ?? source.displayRef
            result.append(.init(baseLocator: baseLocator, destination: destination, title: title, aliases: Array(Set(names)).sorted()))
        }
        try await require("reader.openCommentary", backend: backend, invocation: invocation)
        return result
    }

    func referenceCandidates(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> {
        if let work = query.workRef {
            guard work.backend == query.backend, !work.workKey.isEmpty, work.workKey.count <= 512 else {
                throw ActionContractError.invalid("workRef")
            }
            guard work.catalogRevision == nil else { throw ActionPortError.notSupported }
        }
        if let text = query.text, let section = query.section, text != section { throw ActionContractError.invalid("reference") }
        guard (query.text?.count ?? 0) <= 1_000, (query.section?.count ?? 0) <= 500 else { throw ActionContractError.invalid("reference") }
        try await require("catalog.resolveReference", backend: query.backend, invocation: invocation)
        let works = try await catalogWorks(backend: query.backend, invocation: invocation)
        let input = query.text ?? query.section
        guard var input, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .notFound }
        if query.text == nil, let work = query.workRef {
            guard works.workKeys.contains(work.workKey) else { return .notFound }
            if query.backend == .otzaria {
                guard work.workKey.hasPrefix("book:"), let book = Int(work.workKey.dropFirst(5)), book > 0 else { return .notFound }
                if let line = Int64(input) {
                    guard line >= 0, Int(exactly: line) != nil else { return .notFound }
                    input = "\(book)|\(line)"
                } else {
                    guard let sourceWork = works.works.first(where: { $0.locator.workKey == work.workKey }) else {
                        return .notFound
                    }
                    let nodes: [LibraryTOCNode]
                    do { nodes = try await coordinator.tableOfContents(for: sourceWork) }
                    catch { throw safe(error) }
                    try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
                    let section = input
                    let task = Task.detached {
                        let entries = try ActionLibraryProjection.sourceSections(nodes, invocation: invocation)
                        return try CatalogActionResolver.sourceSectionCandidates(section: section, work: work,
                            entries: entries, invocation: invocation)
                    }
                    let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
                    try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
                    try await require("catalog.resolveReference", backend: query.backend, invocation: invocation)
                    return result
                }
            } else if input != work.workKey, !input.hasPrefix(work.workKey + " ") {
                input = work.workKey + " " + input
            }
        }
        // Never use Embedded's trim-only normalizer as identity proof. The work
        // must already come from the shared resolver's actual catalog selection.
        if query.backend == .sefariaEmbedded {
            let work: ActionWorkRef
            if let selected = query.workRef { work = selected }
            else {
                let lookupInput = input
                let matchTask = Task.detached {
                    try ActionBackendInvocationGuard.check(invocation, current: invocation.snapshot, target: query.backend)
                    return works.workKeys.filter { lookupInput.hasPrefix($0 + " ") }
                }
                let keys = try await withTaskCancellationHandler { try await matchTask.value } onCancel: { matchTask.cancel() }
                try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
                // General alias/ambiguity handling belongs to the shared resolver.
                // Only one exact source-owned canonical work prefix is usable here.
                guard keys.count == 1, let key = keys.first else { throw ActionPortError.notSupported }
                work = .init(backend: query.backend, workKey: key)
            }
            guard works.workKeys.contains(work.workKey) else { throw ActionPortError.notFound }
            let value = input == work.workKey || input.hasPrefix(work.workKey + " ") ? input : work.workKey + " " + input
            let ref = ActionTextRef(backend: query.backend, workKey: work.workKey, position: .canonicalRef(value))
            return .unique(try await validate(ref, invocation: invocation))
        }
        let normalized: TextLocator
        do { normalized = try await coordinator.normalize(input) }
        catch LibraryBackendError.invalidLocator { return .notFound }
        catch { throw safe(error) }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: query.backend)
        guard ActionAppIdentityBridge.actionBackend(normalized.backend) == query.backend,
              works.workKeys.contains(normalized.workKey),
              query.workRef == nil || query.workRef?.workKey == normalized.workKey else { return .notFound }
        let ref = try ActionAppIdentityBridge.actionRef(normalized)
        return .unique(try await validate(ref, invocation: invocation))
    }

    func section(at locator: ActionTextRef, maximumSegments: Int,
                 invocation: ActionPortInvocation) async throws -> ActionSourceTextSection {
        guard (1...100).contains(maximumSegments) else { throw ActionContractError.invalid("maxSegments") }
        let native = try ActionAppIdentityBridge.appLocator(locator)
        try await require("reader.getSection", backend: locator.backend, invocation: invocation)
        try await requireSourceWork(for: native, invocation: invocation)
        let section = try await provenSection(at: native, invocation: invocation)
        let segments = try section.segments.prefix(maximumSegments).map { segment in
            ActionSourceTextSegment(locator: try ActionAppIdentityBridge.actionRef(segment.locator),
                                    sourceText: segment.sourceText)
        }
        return try .init(sectionLocator: ActionAppIdentityBridge.actionRef(section.locator),
                         displayRef: section.displayRef, segments: segments,
                         truncated: section.segments.count > maximumSegments)
    }

    func validate(_ ref: ActionTextRef, invocation: ActionPortInvocation) async throws -> ActionTextRef {
        let native = try ActionAppIdentityBridge.appLocator(ref)
        try await require("catalog.resolveReference", backend: ref.backend, invocation: invocation)
        try await requireSourceWork(for: native, invocation: invocation)
        if ref.backend == .sefariaEmbedded {
            guard case .canonicalRef(let value) = ref.position, value != ref.workKey else { throw ActionPortError.notSupported }
            guard let embeddedReferenceProof else { throw ActionPortError.notSupported }
            do { try await embeddedReferenceProof(ref, invocation) }
            catch { throw safe(error) }
            try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: ref.backend)
            return ref
        }
        _ = try await provenSection(at: native, invocation: invocation)
        return ref
    }

    private func requireSourceWork(for locator: TextLocator, invocation: ActionPortInvocation) async throws {
        let backend = ActionAppIdentityBridge.actionBackend(locator.backend)
        let works = try await catalogWorks(backend: backend, invocation: invocation)
        guard works.workKeys.contains(locator.workKey) else { throw ActionPortError.notFound }
        if backend != .otzaria {
            guard case .canonicalRef(let value) = locator.position,
                  value == locator.workKey || value.hasPrefix(locator.workKey + " ") else {
                throw ActionPortError.notFound
            }
        }
    }

    private func provenSection(at native: TextLocator,
                               invocation: ActionPortInvocation) async throws -> LibraryTextSection {
        let backend = ActionAppIdentityBridge.actionBackend(native.backend)
        let section: LibraryTextSection
        do { section = try await coordinator.section(at: native) }
        catch LibraryBackendError.invalidLocator { throw ActionPortError.notFound }
        catch { throw safe(error) }
        try ActionBackendInvocationGuard.check(invocation, current: await snapshot(), target: backend)
        guard !section.segments.isEmpty,
              section.locator.backend == native.backend, section.locator.workKey == native.workKey,
              section.locator == native || section.segments.contains(where: { $0.locator == native }) else {
            throw ActionPortError.notFound
        }
        return section
    }

    private func safe(_ error: any Error) -> any Error {
        if error is CancellationError { return CancellationError() }
        if let error = error as? ActionPortError { return error }
        if let error = error as? LibraryBackendError, error == .staleRequest { return ActionPortError.staleState }
        return ActionPortError.unavailable
    }
}
