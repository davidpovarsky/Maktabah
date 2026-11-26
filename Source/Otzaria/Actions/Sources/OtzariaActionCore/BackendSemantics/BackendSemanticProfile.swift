import Foundation

/// Evidence is operation-specific. An unknown observation never means ready.
public enum ActionReadinessEvidence: Sendable, Equatable {
    case unknown, unavailable, ready
    public var isReady: Bool { self == .ready }
}

/// Every observation belongs to the exact backend generation and RPC epoch.
public struct ActionBackendRuntimeEvidence: Sendable, Equatable {
    public let snapshot: ActionBackendSnapshot
    public var registeredCapabilities: Set<String>
    public var catalog: ActionReadinessEvidence
    public var references: ActionReadinessEvidence
    public var search: ActionReadinessEvidence
    public var network: ActionReadinessEvidence
    public var host: ActionReadinessEvidence
    public var embeddedCatalog: ActionReadinessEvidence
    public var embeddedSearch: ActionReadinessEvidence
    public var embeddedPackages: ActionReadinessEvidence
    public var embeddedResponseFidelity: ActionReadinessEvidence

    public init(snapshot: ActionBackendSnapshot, registeredCapabilities: Set<String> = [],
                catalog: ActionReadinessEvidence = .unknown, references: ActionReadinessEvidence = .unknown,
                search: ActionReadinessEvidence = .unknown, network: ActionReadinessEvidence = .unknown,
                host: ActionReadinessEvidence = .unknown, embeddedCatalog: ActionReadinessEvidence = .unknown,
                embeddedSearch: ActionReadinessEvidence = .unknown, embeddedPackages: ActionReadinessEvidence = .unknown,
                embeddedResponseFidelity: ActionReadinessEvidence = .unknown) {
        self.snapshot = snapshot; self.registeredCapabilities = registeredCapabilities
        self.catalog = catalog; self.references = references; self.search = search; self.network = network
        self.host = host; self.embeddedCatalog = embeddedCatalog; self.embeddedSearch = embeddedSearch
        self.embeddedPackages = embeddedPackages; self.embeddedResponseFidelity = embeddedResponseFidelity
    }
}

/// Preserved source capabilities are metadata, not permission to execute staged actions.
public enum ActionSourceFeatureState: String, Sendable, Equatable {
    case implemented, partial, defaultOnly, notRegistered, stub, networkDependent, runtimeDependent
}

public struct ActionBackendSourceFeatures: Sendable, Equatable {
    public let globalAuthors: Bool
    public let versionProvider: Bool
    public let packageProvider: Bool
    public let alternateNavigation: Bool
    public let searchNeedsNetwork: Bool
    public let versions: ActionSourceFeatureState
    public let alternateStructures: ActionSourceFeatureState
    public let packages: ActionSourceFeatureState
    public let topics: ActionSourceFeatureState
    public let offlineSearch: ActionSourceFeatureState
    public let exactOccurrencesVerified = false
}

public struct ActionBackendSemanticProfile: Sendable {
    public let backend: ActionBackendID
    public init(backend: ActionBackendID) { self.backend = backend }

    public var sourceFeatures: ActionBackendSourceFeatures {
        .init(globalAuthors: backend == .otzaria, versionProvider: backend != .otzaria,
              packageProvider: backend != .otzaria, alternateNavigation: backend != .otzaria,
              searchNeedsNetwork: backend == .sefaria,
              versions: backend == .otzaria ? .notRegistered : (backend == .sefaria ? .networkDependent : .partial),
              alternateStructures: backend == .otzaria ? .defaultOnly : (backend == .sefaria ? .implemented : .partial),
              packages: backend == .otzaria ? .notRegistered : (backend == .sefaria ? .implemented : .runtimeDependent),
              topics: backend == .otzaria ? .stub : (backend == .sefaria ? .networkDependent : .partial),
              offlineSearch: backend == .otzaria ? .implemented : (backend == .sefaria ? .notRegistered : .runtimeDependent))
    }

    public static let operations = [
        "system.listBackends", "system.selectBackend", "catalog.resolveWork", "catalog.resolveReference",
        "catalog.listAuthors", "search.query", "search.countOccurrences", "search.openResults",
        "reader.open", "reader.openCommentary", "reader.getSection", "reader.getTOC",
        "reader.getNavigationStructures", "reader.navigationItems", "reader.listVersions",
        "reader.relatedRefs", "reader.relatedSources", "reader.relatedTopics", "notes.prepareDraft",
        "notes.saveDraft", "packages.list", "packages.status", "packages.checkUpdates", "packages.install",
        "packages.installWorks", "packages.remove", "packages.removeWorks", "packages.update", "packages.cancel"
    ]

    public func assess(action: String, query: ActionSearchQuery? = nil,
                       evidence: ActionBackendRuntimeEvidence) throws -> ActionCapabilityAssessment {
        guard Self.operations.contains(action) else {
            return .init(registered: false, supported: false, availableNow: false, reasonCode: "action_not_implemented")
        }
        if action == "system.listBackends" {
            return .init(registered: true, supported: true, availableNow: true)
        }
        let capability = Self.capability(for: action)
        let registered = (capability.map { evidence.registeredCapabilities.contains($0) } ?? false)
            && (action != "reader.openCommentary" || evidence.registeredCapabilities.contains("links"))
        let sourceSupported = sourceSupports(action)
        let initial = ["catalog.resolveWork", "catalog.resolveReference", "search.query", "search.openResults", "reader.getTOC", "reader.getSection", "reader.listVersions", "reader.open", "reader.openCommentary", "notes.prepareDraft"].contains(action)
        var unsupported: String? = sourceSupported ? nil : "source_capability_not_supported"
        if action == "search.countOccurrences" { unsupported = "exact_count_unavailable" }
        else if !initial { unsupported = "action_not_implemented" }
        if ["search.query", "search.openResults"].contains(action) {
            guard let query, query.backend == backend else { throw ActionPortError.invalidResponse }
            try ActionSearchSemantics.validateBounds(query)
            unsupported = action == "search.openResults" ? ActionSearchResultsQuery.unsupportedReason(query) : ActionSearchSemantics.unsupportedReason(query)
        }
        let supported = unsupported == nil
        if let unsupported {
            return .init(registered: registered, supported: false, availableNow: false, reasonCode: unsupported)
        }
        guard evidence.snapshot.backend == backend else {
            return .init(registered: registered, supported: supported, availableNow: false, reasonCode: "backend_selection_required")
        }
        guard registered else {
            return .init(registered: false, supported: supported, availableNow: false, reasonCode: "provider_not_registered")
        }
        let readiness: ActionReadinessEvidence = switch action {
        case "catalog.resolveWork": evidence.catalog
        case "reader.getTOC", "reader.getSection": evidence.catalog.isReady ? evidence.references : evidence.catalog
        case "reader.listVersions": evidence.catalog.isReady ? evidence.network : evidence.catalog
        case "catalog.resolveReference", "reader.open", "reader.openCommentary", "notes.prepareDraft": evidence.references
        case "search.query", "search.openResults": evidence.search
        default: .unknown
        }
        guard readiness.isReady else {
            return .init(registered: true, supported: true, availableNow: false, reasonCode: "operation_readiness_unverified")
        }
        if backend == .sefaria, ["search.query", "search.openResults"].contains(action), !evidence.network.isReady {
            return .init(registered: true, supported: true, availableNow: false, reasonCode: "search_requires_network")
        }
        if backend == .sefariaEmbedded {
            guard evidence.snapshot.rpcEpoch != nil, evidence.host.isReady, evidence.embeddedCatalog.isReady else {
                return .init(registered: true, supported: true, availableNow: false, reasonCode: "embedded_catalog_unavailable")
            }
            if ["search.query", "search.openResults"].contains(action) {
                guard evidence.embeddedSearch.isReady else {
                    return .init(registered: true, supported: true, availableNow: false, reasonCode: "embedded_search_unavailable")
                }
                guard evidence.embeddedResponseFidelity.isReady else {
                    return .init(registered: true, supported: true, availableNow: false, reasonCode: "embedded_response_fidelity_unverified")
                }
            }
        }
        return .init(registered: true, supported: true, availableNow: true)
    }

    public func report(evidence: ActionBackendRuntimeEvidence) throws -> ActionBackendReport {
        var operations: [String: ActionCapabilityAssessment] = [:]
        for action in Self.operations {
            let query = ["search.query", "search.openResults"].contains(action) ? ActionSearchQuery(backend: backend, text: "capability probe") : nil
            operations[action] = try assess(action: action, query: query, evidence: evidence)
        }
        return .init(id: backend, operations: operations)
    }

    private func sourceSupports(_ action: String) -> Bool {
        if action == "catalog.listAuthors" { return sourceFeatures.globalAuthors }
        // The Embedded adapter can currently conflate failed RPC with an
        // empty version list. Only the original strict HTTP provider can fulfill
        // this action until Embedded exposes a distinct failure result.
        if action == "reader.listVersions" { return backend == .sefaria && sourceFeatures.versionProvider }
        if action == "reader.relatedRefs" { return sourceFeatures.versionProvider }
        if action.hasPrefix("packages.") { return sourceFeatures.packageProvider }
        if action == "reader.relatedTopics", backend == .otzaria { return false }
        return true
    }

    public static func capability(for action: String) -> String? {
        switch action {
        case "catalog.resolveWork": "catalog"
        case "catalog.listAuthors": "authors"
        case "catalog.resolveReference", "reader.open", "reader.openCommentary", "reader.getTOC",
             "reader.getNavigationStructures", "reader.navigationItems", "notes.prepareDraft", "notes.saveDraft": "navigation"
        case "search.query", "search.countOccurrences", "search.openResults": "search"
        case "reader.getSection": "reading"
        case "reader.listVersions", "reader.relatedRefs": "versions"
        case "reader.relatedSources", "reader.relatedTopics": "links"
        default: action.hasPrefix("packages.") ? "offlineLibrary" : nil
        }
    }
}
