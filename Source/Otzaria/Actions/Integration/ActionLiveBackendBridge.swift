import Foundation
import OtzariaActionCore

// Exact port from P's frozen Core065148d3. The app target compiles this
// conformance beside the factory after the manager wires the same Core product.
extension ActionBackendCoordinatorFacade: ActionSynchronousBackendStatePort {}

/// App composition supplies one facade for P's existing typed ports. Discovery
/// observes the active runtime without initializing it or mutating user data.
@MainActor
enum ActionLiveBackendBridge {
    /// Core, Resolver and Scene navigation must all consume this same authority.
    /// `make` is retained for explicit isolated compositions/tests only.
    static let shared = make(coordinator: .shared)

    static func make(coordinator: BackendCoordinator,
                     otzariaSearchReadiness: (@Sendable (ActionBackendSnapshot) async -> ActionReadinessEvidence)? = nil,
                     legacyNetwork: (@Sendable () async -> ActionReadinessEvidence)? = nil) -> ActionBackendCoordinatorFacade {
        ActionBackendCoordinatorFacade(coordinator: coordinator,
            epoch: { await SefariaJSRPCBridge.shared.sessionEpoch },
            currentEpoch: { SefariaJSRPCBridge.shared.currentSessionEpoch },
            resourceWitness: {
                let bridge = OtzariaMaktabahBridge.shared
                let selection = OtzariaDatabaseAccessController.shared.selectionObservation()
                let generation = bridge.generationSnapshot()
                let path = selection.url?.path
                let profile = OtzariaDataProfileRegistry.activeProfileID
                let search = OtzariaTantivySearchRepository.shared.resourceObservation(databasePath: path)
                guard selection == OtzariaDatabaseAccessController.shared.selectionObservation(),
                      generation == bridge.generationSnapshot(), path == bridge.databasePath,
                      profile == OtzariaDataProfileRegistry.activeProfileID else { throw ActionPortError.staleState }
                return .init(databaseGeneration: generation, searchRevision: search.revision,
                    profileID: profile, databasePath: path, searchFingerprint: search.fingerprint,
                    databaseSelectionRevision: selection.revision)
            },
            readiness: { snapshot in
                var result = ActionBackendRuntimeEvidence(snapshot: snapshot)
                switch snapshot.backend {
                case .otzaria:
                    let proofs = await Task.detached(priority: .utility) {
                        ActionLiveReadinessProof.otzaria()
                    }.value
                    result.catalog = proofs.0 ? .ready : .unavailable
                    result.references = result.catalog
                    // Compatibility is necessary, but does not prove an open,
                    // complete index. Consume a trusted app observation rather
                    // than opening the writer-capable engine during assessment.
                    if proofs.1 {
                        if let otzariaSearchReadiness { result.search = await otzariaSearchReadiness(snapshot) }
                        else { result.search = proofs.2 }
                    } else { result.search = .unavailable }
                case .sefaria:
                    if let legacyNetwork { result.network = await legacyNetwork() }
                    else {
                        let available = try? await SefariaBackend.shared.remote.observeSearchService()
                        result.network = available == true ? .ready : .unavailable
                    }
                    let installed = await SefariaBackend.shared.packages.installedWorkKeys()
                    result.catalog = result.network.isReady || !installed.isEmpty ? .ready : .unknown
                    result.references = result.catalog
                    // Downloaded reading does not provide a local search index.
                    result.search = result.network
                case .sefariaEmbedded:
                    let runtime = SefariaRuntimeManager.shared
                    let state = await runtime.state
                    guard let epoch = snapshot.rpcEpoch else { return result }
                    let readiness = await runtime.observedReadiness(for: epoch)
                    let transport = await SefariaJSRPCBridge.shared.isTransportReady
                    result.host = state.isReady && transport && readiness.hostReady ? .ready : .unavailable
                    result.embeddedCatalog = readiness.catalogReady ? .ready : .unavailable
                    result.embeddedSearch = readiness.searchReady ? .ready : .unavailable
                    result.embeddedPackages = readiness.packagesReady ? .ready : .unavailable
                    result.catalog = result.host.isReady && readiness.catalogReady ? .ready : .unavailable
                    result.references = result.catalog
                    result.search = result.host.isReady && readiness.catalogReady && readiness.searchReady ? .ready : .unavailable
                    if result.host.isReady {
                        // Unknown method on an older deployed bundle fails
                        // closed. A matching local source file proves nothing.
                        let proof = try? await EmbeddedActionRPC.contract(snapshot: snapshot)
                        result.embeddedResponseFidelity = proof == true ? .ready : .unknown
                    }
                }
                return result
            }, embeddedSearch: { query, invocation in
                try await EmbeddedActionRPC.search(query, invocation: invocation)
            }, embeddedReferenceProof: { ref, invocation in
                try await EmbeddedActionRPC.validate(ref, invocation: invocation)
            }, embeddedCatalog: { invocation in
                try await EmbeddedActionRPC.catalog(invocation: invocation)
            }, occurrenceReadiness: ActionLiveOccurrenceCounter.readiness,
               occurrenceCounter: ActionLiveOccurrenceCounter.count,
               searchExecutionPreparation: ActionLiveSearchExecutionPreparation.make,
               searchPreparationObservation: ActionLiveSearchExecutionPreparation.observe)
    }
}

private enum ActionLiveSearchExecutionPreparation {
    /// Observe the original installed source without invoking make's returned
    /// execution work or constructing a native engine. A cold source remains
    /// unknown in the ordinary readiness report.
    @MainActor static func observe(_ invocation: ActionPortInvocation) async throws
        -> ActionExistingSearchPreparationObservation {
        try check(invocation)
        guard invocation.snapshot.backend == .otzaria else { return .unavailable }
        let bridge = OtzariaMaktabahBridge.shared
        let access = OtzariaDatabaseAccessController.shared
        let selection = access.selectionObservation()
        let profile = OtzariaDataProfileRegistry.activeProfileID
        guard selection.source == .managedInternal, let path = selection.url?.path,
              path == bridge.databasePath, let generation = bridge.tryGenerationSnapshot() else {
            return .unavailable
        }
        let repository = OtzariaTantivySearchRepository.shared
        let observation = repository.resourceObservation(databasePath: path)
        guard let fingerprint = observation.fingerprint else { return .unavailable }
        let validateSource: @Sendable () throws -> Void = {
            try check(invocation)
            guard let currentGeneration = bridge.tryGenerationSnapshot() else { throw ActionPortError.unavailable }
            guard selection == access.selectionObservation(), generation == currentGeneration,
                  path == bridge.databasePath, profile == OtzariaDataProfileRegistry.activeProfileID else {
                throw ActionPortError.staleState
            }
        }
        try validateSource()
        let task = Task.detached(priority: .utility) { () throws -> ActionExistingSearchPreparationObservation in
            try observeInstalledSource(databasePath: path, profileID: profile,
                expectedRevision: observation.revision, expectedFingerprint: fingerprint,
                invocation: invocation, validateSource: validateSource)
            return .eligible(invocation: invocation)
        }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    private static func observeInstalledSource(databasePath path: String, profileID profile: String,
                                                expectedRevision: UInt64, expectedFingerprint: Data,
                                                invocation: ActionPortInvocation,
                                                validateSource: @Sendable () throws -> Void) throws {
        try validateSource()
        let storage = try OtzariaDatabaseStorage(profileID: profile)
        guard URL(fileURLWithPath: path).standardizedFileURL == storage.finalDatabaseURL.standardizedFileURL else {
            throw ActionPortError.unavailable
        }
        let manager = OtzariaSearchIndexManager.shared
        let repository = OtzariaTantivySearchRepository.shared
        let url = manager.indexURL(for: path)
        func validateCurrentSource() throws {
            try validateSource()
            let observed = repository.resourceObservation(databasePath: path)
            guard observed.revision == expectedRevision, observed.fingerprint == expectedFingerprint,
                  manager.indexURL(for: path) == url else { throw ActionPortError.staleState }
            let files = FileManager.default
            guard !files.fileExists(atPath: manager.sentinelURL(for: path).path),
                  !files.fileExists(atPath: manager.buildingIndexURL(for: path).path),
                  !files.fileExists(atPath: url.appendingPathExtension("installing").path) else {
                throw ActionPortError.unavailable
            }
        }
        try validateCurrentSource()
        let current = try manager.currentFingerprint(databasePath: path)
        guard let databaseBytes = Int64(exactly: current.fileSize) else { throw ActionPortError.unavailable }
        let build = try OtzariaSearchEngineBridge.buildInfo()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let database = try decoder.decode(OtzariaDatabaseInstallationManifest.self,
            from: smallMetadata(at: storage.installationManifestURL, invocation: invocation))
        let manifest = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
            from: smallMetadata(at: url.appendingPathComponent("otzaria_prebuilt_installation.json"), invocation: invocation))
        let identity = try JSONDecoder().decode(OtzariaIndexBuildIdentity.self,
            from: smallMetadata(at: manager.identityURL(indexURL: url), invocation: invocation))
        try OtzariaSearchArtifactPolicy.validate(manifest, database: database,
            databaseBytes: databaseBytes, build: build)
        guard let expectedCount = UInt64(exactly: manifest.lexicalArtifact.documentCount), expectedCount > 0,
              OtzariaSearchArtifactPolicy.managedIdentityMatchesCanonicalData(identity,
                currentDatabase: current, build: build, trustedManifest: manifest) else {
            throw ActionPortError.unavailable
        }
        let indexMetadata = try smallMetadata(at: url.appendingPathComponent("otzaria_index_meta.json"), invocation: invocation)
        try OtzariaSearchEngineBridge.validateExistingCompatibleIndex(url)
        let translationKey = "Vendor/OtzariaSearchEngine/Resources/dictionary.json"
        let acronymsKey = "Vendor/OtzariaSearchEngine/Resources/Acronyms.json"
        guard Set(build.resourceHashes.keys) == Set([translationKey, acronymsKey]),
              let translationHash = build.resourceHashes[translationKey],
              let acronymsHash = build.resourceHashes[acronymsKey],
              let translation = Bundle.main.url(forResource: "dictionary", withExtension: "json"),
              let acronyms = Bundle.main.url(forResource: "Acronyms", withExtension: "json") else {
            throw ActionPortError.unavailable
        }
        try OtzariaSearchEngineBridge.validateExecutionDictionary(translation, expectedSHA256: translationHash,
            deadline: invocation.deadlineUptimeNanoseconds)
        try OtzariaSearchEngineBridge.validateExecutionDictionary(acronyms, expectedSHA256: acronymsHash,
            deadline: invocation.deadlineUptimeNanoseconds)
        // An already observed incomplete open index cannot become eligible.
        // Nil does not prove readiness: the positive installed-source checks
        // above only allow the original execution path to attempt preparation.
        if let count = repository.observedOpenIndexDocumentCount(databasePath: path),
           count == 0 || count != expectedCount { throw ActionPortError.unavailable }
        try validateCurrentSource()
        guard try smallMetadata(at: url.appendingPathComponent("otzaria_index_meta.json"), invocation: invocation) == indexMetadata else {
            throw ActionPortError.staleState
        }
        try validateCurrentSource()
    }

    /// Capture source ownership synchronously, without opening an engine. The
    /// facade rechecks its exact backend snapshot after this factory returns
    /// and before the returned work can begin on a utility executor.
    @MainActor static func make(_ query: ActionSearchQuery, _ invocation: ActionPortInvocation) throws
        -> ActionBackendCoordinatorFacade.SearchExecutionWork {
        try check(invocation)
        guard query.backend == .otzaria, invocation.snapshot.backend == .otzaria else {
            throw ActionPortError.unavailable
        }
        let bridge = OtzariaMaktabahBridge.shared
        let access = OtzariaDatabaseAccessController.shared
        let selection = access.selectionObservation()
        let generation = bridge.generationSnapshot()
        let profile = OtzariaDataProfileRegistry.activeProfileID
        guard selection.source == .managedInternal, let path = selection.url?.path,
              path == bridge.databasePath else { throw ActionPortError.unavailable }
        let repository = OtzariaTantivySearchRepository.shared
        let observation = repository.resourceObservation(databasePath: path)
        guard let fingerprint = observation.fingerprint else { throw ActionPortError.unavailable }
        let validateSource: @Sendable () throws -> Void = {
            try check(invocation)
            guard let currentGeneration = bridge.tryGenerationSnapshot() else {
                throw OtzariaSearchExecutionPreparationError.sourceBusy
            }
            guard selection == access.selectionObservation(), generation == currentGeneration,
                  path == bridge.databasePath, profile == OtzariaDataProfileRegistry.activeProfileID else {
                throw ActionPortError.staleState
            }
        }
        do { try validateSource() }
        catch OtzariaSearchExecutionPreparationError.sourceBusy { throw ActionPortError.unavailable }
        return {
            let task = Task.detached(priority: .utility) {
                try await prepare(databasePath: path, profileID: profile,
                    expectedRevision: observation.revision, expectedFingerprint: fingerprint,
                    invocation: invocation, validateSource: validateSource)
            }
            do { try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() } }
            catch let error as ActionPortError { throw error }
            catch is CancellationError { throw CancellationError() }
            catch let error as OtzariaSearchExecutionPreparationError {
                switch error {
                case .sourceChanged: throw ActionPortError.staleState
                case .deadlineExceeded: throw CancellationError()
                case .unavailable, .sourceBusy: throw ActionPortError.unavailable
                }
            }
            catch { throw ActionPortError.unavailable }
        }
    }

    private static func prepare(databasePath path: String, profileID profile: String,
                                expectedRevision: UInt64, expectedFingerprint: Data,
                                invocation: ActionPortInvocation,
                                validateSource: @escaping @Sendable () throws -> Void) async throws {
        try validateSource()
        let storage = try OtzariaDatabaseStorage(profileID: profile)
        guard URL(fileURLWithPath: path).standardizedFileURL == storage.finalDatabaseURL.standardizedFileURL else {
            throw ActionPortError.unavailable
        }
        let manager = OtzariaSearchIndexManager.shared
        let repository = OtzariaTantivySearchRepository.shared
        let url = manager.indexURL(for: path)
        let current = try manager.currentFingerprint(databasePath: path)
        guard let databaseBytes = Int64(exactly: current.fileSize) else { throw ActionPortError.unavailable }
        let build = try OtzariaSearchEngineBridge.buildInfo()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let database = try decoder.decode(OtzariaDatabaseInstallationManifest.self,
            from: smallMetadata(at: storage.installationManifestURL, invocation: invocation))
        let manifest = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
            from: smallMetadata(at: url.appendingPathComponent("otzaria_prebuilt_installation.json"), invocation: invocation))
        let identity = try JSONDecoder().decode(OtzariaIndexBuildIdentity.self,
            from: smallMetadata(at: manager.identityURL(indexURL: url), invocation: invocation))
        try OtzariaSearchArtifactPolicy.validate(manifest, database: database,
            databaseBytes: databaseBytes, build: build)
        guard let expectedCount = UInt64(exactly: manifest.lexicalArtifact.documentCount), expectedCount > 0,
              OtzariaSearchArtifactPolicy.managedIdentityMatchesCanonicalData(identity,
                currentDatabase: current, build: build, trustedManifest: manifest) else {
            throw ActionPortError.unavailable
        }
        let indexMetadata = try smallMetadata(at: url.appendingPathComponent("otzaria_index_meta.json"), invocation: invocation)
        try OtzariaSearchEngineBridge.validateExistingCompatibleIndex(url)
        try validateSource()
        let before = repository.resourceObservation(databasePath: path)
        guard before.revision == expectedRevision, before.fingerprint == expectedFingerprint else {
            throw ActionPortError.staleState
        }
        try await repository.prepareExistingSearchExecution(databasePath: path, profileID: profile,
            expectedIndexURL: url, expectedRevision: expectedRevision, expectedFingerprint: expectedFingerprint,
            expectedIndexMetadata: indexMetadata, expectedDocumentCount: expectedCount,
            requiredResourceHashes: build.resourceHashes, deadlineUptimeNanoseconds: invocation.deadlineUptimeNanoseconds,
            validateSource: validateSource)
        try validateSource()
        let after = repository.resourceObservation(databasePath: path)
        guard after.revision == expectedRevision, after.fingerprint == expectedFingerprint else {
            throw ActionPortError.staleState
        }
    }

    private static func smallMetadata(at url: URL, invocation: ActionPortInvocation) throws -> Data {
        try check(invocation)
        let maximum = 1_048_576
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.uint64Value > 0, size.uint64Value <= UInt64(maximum) else { throw ActionPortError.unavailable }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var bytes = Data()
        while bytes.count <= maximum {
            try check(invocation)
            guard let chunk = try file.read(upToCount: maximum + 1 - bytes.count), !chunk.isEmpty else {
                guard bytes.count == size.intValue else { throw ActionPortError.unavailable }
                return bytes
            }
            bytes.append(chunk)
        }
        throw ActionPortError.unavailable
    }

    private static func check(_ invocation: ActionPortInvocation) throws {
        try Task.checkCancellation()
        guard DispatchTime.now().uptimeNanoseconds < invocation.deadlineUptimeNanoseconds else { throw CancellationError() }
    }
}

private enum ActionLiveReadinessProof {
    /// Read-only subset of the existing artifact policy. Do not invoke the
    /// manager's recovery/status helpers: a semantic read must not repair/move
    /// indexes or refresh/download data as a side effect.
    static func otzaria() -> (Bool, Bool, ActionReadinessEvidence) {
        let databaseReady = (try? OtzariaMaktabahBridge.shared.withDatabase { database in
            let book = try database.fetch(query: "SELECT 1 FROM book LIMIT 1") { $0.int(at: 0) }.first == 1
            let category = try database.fetch(query: "SELECT 1 FROM category LIMIT 1") { $0.int(at: 0) }.first == 1
            return book && category
        }) == true
        let selection = OtzariaDatabaseAccessController.shared.selectionObservation()
        guard databaseReady, let path = selection.url?.path,
              path == OtzariaMaktabahBridge.shared.databasePath else { return (databaseReady, false, .unavailable) }
        let profile = OtzariaDataProfileRegistry.activeProfileID
        do {
            let manager = OtzariaSearchIndexManager.shared
            let url = manager.indexURL(for: path)
            let current = try manager.currentFingerprint(databasePath: path)
            let build = try OtzariaSearchEngineBridge.buildInfo()
            guard let identity = manager.storedIdentity(indexURL: url) else { return (true, false, .unavailable) }
            var expectedCount: UInt64?
            var trustedManifest: OtzariaSearchArtifactManifest?
            if selection.source == .managedInternal {
                guard let databaseBytes = Int64(exactly: current.fileSize) else { return (true, false, .unavailable) }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let storage = try OtzariaDatabaseStorage()
                let database = try decoder.decode(OtzariaDatabaseInstallationManifest.self,
                    from: Data(contentsOf: storage.installationManifestURL))
                let manifest = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
                    from: Data(contentsOf: url.appendingPathComponent("otzaria_prebuilt_installation.json")))
                try OtzariaSearchArtifactPolicy.validate(manifest, database: database,
                    databaseBytes: databaseBytes, build: build)
                expectedCount = UInt64(exactly: manifest.lexicalArtifact.documentCount)
                trustedManifest = manifest
            } else if identity.database != current { return (true, false, .unavailable) }
            // A directional read contract needs the independently validated
            // original producer manifest before the existing identity check.
            guard OtzariaSearchArtifactPolicy.managedIdentityMatchesCanonicalData(identity,
                      currentDatabase: current, build: build, trustedManifest: trustedManifest),
                  try OtzariaSearchEngineBridge.checkCompatibility(indexURL: url).compatible else {
                return (true, false, .unavailable)
            }
            let count = OtzariaTantivySearchRepository.shared.observedOpenIndexDocumentCount(databasePath: path)
            guard selection == OtzariaDatabaseAccessController.shared.selectionObservation(),
                  profile == OtzariaDataProfileRegistry.activeProfileID,
                  path == OtzariaMaktabahBridge.shared.databasePath else { return (true, false, .unknown) }
            guard let count else { return (true, true, .unknown) }
            return (true, true, count > 0 && (expectedCount == nil || count == expectedCount) ? .ready : .unavailable)
        } catch { return (true, false, .unavailable) }
    }
}

private enum EmbeddedActionRPC {
    static func contract(snapshot: ActionBackendSnapshot) async throws -> Bool {
        let nonce = UUID().uuidString
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: snapshot,
            deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 2_000_000_000)
        let body = try await response(method: "runtime.actionContract", params: ["nonce": .string(nonce)], invocation: invocation)
        return EmbeddedActionResponseProof.matchesRuntimeContract(body, nonce: nonce)
    }
    static func catalog(invocation: ActionPortInvocation) async throws -> [LibraryCatalogNode] {
        let body = try await response(method: "catalog.toc", params: [:], invocation: invocation)
        let entries = try EmbeddedActionResponseProof.catalogEntries(body, invocation: invocation)
        return try entries.map { entry in
            let locator = try ActionAppIdentityBridge.appLocator(.init(backend: entry.workRef.backend,
                workKey: entry.workRef.workKey, position: .canonicalRef(entry.workRef.workKey)))
            let work = LibraryWork(locator: locator, title: entry.title, heTitle: entry.aliases.first, categories: [], description: nil)
            return .init(id: locator.persistenceKey, kind: .work, title: work.title, heTitle: work.heTitle, work: work, children: [])
        }
    }
    private static func response(method: String, params: ActionObject, invocation: ActionPortInvocation) async throws -> ActionJSON {
        try Task.checkCancellation()
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < invocation.deadlineUptimeNanoseconds else { throw CancellationError() }
        guard invocation.snapshot.backend == .sefariaEmbedded,
              let epoch = invocation.snapshot.rpcEpoch,
              await SefariaJSRPCBridge.shared.sessionEpoch == epoch else { throw ActionPortError.staleState }
        let remainingMs = (invocation.deadlineUptimeNanoseconds - now) / 1_000_000
        let timeout = Int(min(15_000, max(1, remainingMs)))
        let encoded = try JSONEncoder().encode(params)
        let response = try await SefariaJSRPCBridge.shared.call(method: method,
            paramsJson: String(decoding: encoded, as: UTF8.self), generation: epoch, timeoutMs: timeout)
        try Task.checkCancellation()
        guard DispatchTime.now().uptimeNanoseconds < invocation.deadlineUptimeNanoseconds else { throw CancellationError() }
        guard await SefariaJSRPCBridge.shared.sessionEpoch == epoch else { throw ActionPortError.staleState }
        guard response.isSuccess else { throw ActionPortError.unavailable }
        let maximumBytes = method == "catalog.toc" ? 8_388_608 : 1_048_576
        guard let string = response.resultJson, string.utf8.count <= maximumBytes,
              let data = string.data(using: .utf8) else { throw ActionPortError.invalidResponse }
        do { return try JSONDecoder().decode(ActionJSON.self, from: data) }
        catch { throw ActionPortError.invalidResponse }
    }

    static func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage {
        try ActionSearchSemantics.validateBounds(query)
        guard ActionSearchSemantics.unsupportedReason(query) == nil else { throw ActionPortError.notSupported }
        let body = try await response(method: "search.query", params: [
            "query": .string(query.text), "offset": .integer(Int64(query.offset)), "limit": .integer(Int64(query.limit)),
            "type": .string("text"), "field": .string("exact"), "exact": .bool(true),
            "appliedFilters": .array([]), "sortType": .string("relevance")
        ], invocation: invocation)
        return try EmbeddedActionResponseProof.searchPage(body, query: query)
    }

    static func validate(_ ref: ActionTextRef, invocation: ActionPortInvocation) async throws {
        guard case .canonicalRef(let value) = ref.position else { throw ActionPortError.notSupported }
        let body = try await response(method: "text.load", params: [
            "ref": .string(value), "context": .bool(true), "fallbackOnDefaultVersions": .bool(true), "failSilently": .bool(false)
        ], invocation: invocation)
        try EmbeddedActionResponseProof.validateText(body, ref: ref)
    }
}
