import Foundation
import OtzariaActionCore

/// Factory only: this tranche does not register it in the app or UI. Network
/// evidence and a matching Embedded bundle/epoch proof must come from trusted
/// application observations, never from an ActionRequest or coarse capability bit.
@MainActor
enum ActionLiveBackendBridge {
    static func make(coordinator: BackendCoordinator,
                     otzariaSearchReadiness: @escaping @Sendable (ActionBackendSnapshot) async -> ActionReadinessEvidence = { _ in .unknown },
                     legacyNetwork: @escaping @Sendable () async -> ActionReadinessEvidence = { .unknown },
                     verifiedEmbeddedSearchEpoch: @escaping @Sendable () async -> UInt64? = { nil }) -> ActionBackendCoordinatorFacade {
        ActionBackendCoordinatorFacade(coordinator: coordinator,
            epoch: { await SefariaJSRPCBridge.shared.sessionEpoch },
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
                    result.search = proofs.1 ? await otzariaSearchReadiness(snapshot) : .unavailable
                case .sefaria:
                    result.network = await legacyNetwork()
                    let installed = await SefariaBackend.shared.packages.installedWorkKeys()
                    result.catalog = result.network.isReady || !installed.isEmpty ? .ready : .unknown
                    result.references = result.catalog
                    // Downloaded reading does not provide a local search index.
                    result.search = result.network
                case .sefariaEmbedded:
                    let runtime = SefariaRuntimeManager.shared
                    let state = await runtime.state
                    let readiness = await runtime.readiness
                    let transport = await SefariaJSRPCBridge.shared.isTransportReady
                    result.host = state.isReady && transport && readiness.hostReady ? .ready : .unavailable
                    result.embeddedCatalog = readiness.catalogReady ? .ready : .unavailable
                    result.embeddedSearch = readiness.searchReady ? .ready : .unavailable
                    result.embeddedPackages = readiness.packagesReady ? .ready : .unavailable
                    result.catalog = result.host.isReady && readiness.catalogReady ? .ready : .unavailable
                    result.references = result.catalog
                    result.search = result.host.isReady && readiness.catalogReady && readiness.searchReady ? .ready : .unavailable
                    let verified = await verifiedEmbeddedSearchEpoch()
                    result.embeddedResponseFidelity = verified != nil && verified == snapshot.rpcEpoch ? .ready : .unknown
                }
                return result
            }, embeddedSearch: { query, invocation in
                try await EmbeddedActionRPC.search(query, invocation: invocation)
            }, embeddedReferenceProof: { ref, invocation in
                try await EmbeddedActionRPC.validate(ref, invocation: invocation)
            }, embeddedCatalog: { invocation in
                try await EmbeddedActionRPC.catalog(invocation: invocation)
            })
    }
}

private enum ActionLiveReadinessProof {
    /// Read-only subset of the existing artifact policy. Do not invoke the
    /// manager's recovery/status helpers: a semantic read must not repair/move
    /// indexes or refresh/download data as a side effect.
    static func otzaria() -> (Bool, Bool) {
        let databaseReady = (try? OtzariaMaktabahBridge.shared.withDatabase { database in
            let book = try database.fetch(query: "SELECT 1 FROM book LIMIT 1") { $0.int(at: 0) }.first == 1
            let category = try database.fetch(query: "SELECT 1 FROM category LIMIT 1") { $0.int(at: 0) }.first == 1
            return book && category
        }) == true
        guard databaseReady, let path = OtzariaMaktabahBridge.shared.databasePath else { return (databaseReady, false) }
        do {
            let manager = OtzariaSearchIndexManager.shared
            let url = manager.indexURL(for: path)
            let current = try manager.currentFingerprint(databasePath: path)
            let build = try OtzariaSearchEngineBridge.buildInfo()
            guard let identity = manager.storedIdentity(indexURL: url),
                  OtzariaSearchArtifactPolicy.managedIdentityMatchesCanonicalData(identity, currentDatabase: current, build: build),
                  try OtzariaSearchEngineBridge.checkCompatibility(indexURL: url).compatible else { return (true, false) }
            if OtzariaDatabaseAccessController.shared.source == .managedInternal {
                guard let databaseBytes = Int64(exactly: current.fileSize) else { return (true, false) }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let storage = try OtzariaDatabaseStorage()
                let database = try decoder.decode(OtzariaDatabaseInstallationManifest.self,
                    from: Data(contentsOf: storage.installationManifestURL))
                let manifest = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
                    from: Data(contentsOf: url.appendingPathComponent("otzaria_prebuilt_installation.json")))
                try OtzariaSearchArtifactPolicy.validate(manifest, database: database,
                    databaseBytes: databaseBytes, build: build)
            } else if identity.database != current { return (true, false) }
            return (true, true)
        } catch { return (true, false) }
    }
}

private enum EmbeddedActionRPC {
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
