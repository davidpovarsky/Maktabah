import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Per-process dependency supplied at the composition root. No static global
/// scene selection, cached rights, business resolver or alternate executor.
@MainActor
public final class NativeIntentService {
    public struct Destination: Sendable, Equatable, Identifiable {
        public let backend: ActionBackendID
        public let destination: UIDestinationID
        public let title: String
        public let sceneID: UIStableID
        public let component: UIDestinationID?
        public var id: String {
            let root = backend.rawValue + ":" + sceneID.rawValue + ":" + destination.rawValue
            return component.map { root + ":" + $0.rawValue } ?? root
        }
        public init(backend: ActionBackendID, destination: UIDestinationID, title: String, sceneID: UIStableID,
                    component: UIDestinationID? = nil) {
            self.backend = backend; self.destination = destination; self.title = title
            self.sceneID = sceneID; self.component = component
        }
    }
    public typealias Discover = @MainActor @Sendable () async throws -> [Destination]
    public typealias AwaitForeground = @MainActor @Sendable (Destination) async throws -> Void
    public typealias Open = @MainActor @Sendable (Destination) async throws -> UISceneAcknowledgement
    private let discover: Discover
    private let resolveEntities: Discover
    private let resolveReaderWindows: Discover
    private let awaitForeground: AwaitForeground?
    private let navigate: Open
    public init(discover: @escaping Discover, resolveEntities: Discover? = nil,
                resolveReaderWindows: Discover? = nil,
                awaitForeground: AwaitForeground? = nil, navigate: @escaping Open) {
        self.discover = discover
        self.resolveEntities = resolveEntities ?? discover
        self.resolveReaderWindows = resolveReaderWindows ?? resolveEntities ?? discover
        self.awaitForeground = awaitForeground
        self.navigate = navigate
    }

    public func destinations(identifiers: [String]? = nil, matching query: String? = nil) async throws -> [Destination] {
        try Task.checkCancellation()
        if let identifiers, identifiers.count > 64 { throw UIRouteError(.failed, "too_many_intent_entities") }
        guard query == nil || query!.utf8.count <= 512 else { throw UIRouteError(.failed, "intent_query_too_large") }
        // System parameter resolution may precede foreground activation. These
        // identities describe existing entities; they never authorize navigation.
        let values = try await resolveEntities()
        try Task.checkCancellation()
        return try filter(values, identifiers: identifiers, matching: query)
    }

    /// Existing mounted Library windows are metadata only. The host can resolve
    /// them without observing optional live controls or issuing UI admission.
    /// Opening still uses the original foreground and fresh execution guards.
    public func readerWindows(identifiers: [String]? = nil, matching query: String? = nil) async throws -> [Destination] {
        try Task.checkCancellation()
        if let identifiers, identifiers.count > 64 { throw UIRouteError(.failed, "too_many_intent_entities") }
        guard query == nil || query!.utf8.count <= 512 else { throw UIRouteError(.failed, "intent_query_too_large") }
        let values = try await resolveReaderWindows()
        try Task.checkCancellation()
        return try filter(values, identifiers: identifiers, matching: query).filter {
            $0.destination.rawValue == "native.library" && $0.component == nil
        }
    }

    private func filter(_ values: [Destination], identifiers: [String]?, matching query: String?) throws -> [Destination] {
        guard values.count <= 128, Set(values.map(\.id)).count == values.count else { throw UIRouteError(.failed, "invalid_live_intent_catalog") }
        let requested = identifiers.map(Set.init)
        let candidates = values.filter { requested == nil || requested!.contains($0.id) }
        guard let query else { return candidates }
        // Component names such as Search Data must not make the exact Search
        // destination ambiguous. Window suffixes disambiguate identities, not
        // the requested feature name; keep ALL exact matches across windows.
        let exact = candidates.filter {
            let name = $0.title.components(separatedBy: " — ").first ?? $0.title
            return name.localizedCaseInsensitiveCompare(query) == .orderedSame
        }
        return exact.isEmpty ? candidates.filter { $0.title.localizedCaseInsensitiveContains(query) } : exact
    }

    /// Re-resolve stale system entities against the current authorized catalog
    /// before handing off. The orchestrator reauthorizes at native commit.
    public func open(identifier: String) async throws -> UISceneAcknowledgement {
        guard identifier.utf8.count <= 512 else { throw UIRouteError(.failed, "invalid_intent_entity") }
        try Task.checkCancellation()
        if let awaitForeground {
            // Resolve only the selected mounted identity before waiting for the
            // system's foreground lifecycle. Metadata does not grant authority.
            let candidates = try filter(try await resolveEntities(), identifiers: [identifier], matching: nil)
            guard candidates.count == 1, let target = candidates.first else {
                throw UIRouteError(.staleState, "intent_entity_no_longer_available")
            }
            try await awaitForeground(target)
            try Task.checkCancellation()
        }
        // Always obtain fresh execution eligibility. A resolved background entity
        // or a stale system reference cannot borrow foreground authority.
        let values = try await discover()
        try Task.checkCancellation()
        let matches = try filter(values, identifiers: [identifier], matching: nil)
        guard matches.count == 1, let target = matches.first else { throw UIRouteError(.staleState, "intent_entity_no_longer_available") }
        return try await navigate(target)
    }
}


/// These are finite projections of destinations already declared by the native
/// host. They carry no new permission, scene selection or execution authority.
public enum NativeFeatureIntentTarget: Sendable {
    case settingsSection
    case readerContents
    case readingHistory

    fileprivate func accepts(_ value: NativeIntentService.Destination) -> Bool {
        switch self {
        case .settingsSection:
            guard value.destination.rawValue == "native.settings",
                  let component = value.component?.rawValue else { return false }
            return [
                "native.settings.backend", "native.settings.offline",
                "native.settings.databaseMode", "native.settings.history",
                "native.settings.storage", "native.settings.annotations",
                "native.settings.cloud", "native.settings.appearance",
                "native.settings.searchData", "native.settings.searchCredits",
                "native.settings.searchIndex", "native.settings.optimization",
                "native.settings.updates", "native.settings.downloads",
                "native.settings.miniApps"
            ].contains(component)
        case .readerContents:
            guard value.destination.rawValue == "native.reader.toc" else { return false }
            guard let component = value.component?.rawValue else { return true }
            return [
                "native.reader.toc.contents", "native.reader.toc.structure",
                "native.reader.toc.currentSelection"
            ].contains(component)
        case .readingHistory:
            return value.destination.rawValue == "native.history" && value.component == nil
        }
    }
}

extension NativeIntentService {
    /// Validate the complete original metadata catalog before narrowing it.
    /// Feature filtering precedes the original exact-title search so "History"
    /// in another feature cannot hide the Settings control with that name.
    public func featureDestinations(_ feature: NativeFeatureIntentTarget,
                                    identifiers: [String]? = nil,
                                    matching query: String? = nil) async throws -> [Destination] {
        try Task.checkCancellation()
        if let identifiers, identifiers.count > 64 {
            throw UIRouteError(.failed, "too_many_intent_entities")
        }
        guard query == nil || query!.utf8.count <= 512 else {
            throw UIRouteError(.failed, "intent_query_too_large")
        }
        let values = try await destinations()
        try Task.checkCancellation()
        return try filter(values.filter(feature.accepts), identifiers: identifiers, matching: query)
    }

    /// The entity must belong to the requested semantic action. The original
    /// open() then waits for foreground and independently discovers fresh
    /// execution eligibility before using the single native orchestrator.
    public func openFeature(_ feature: NativeFeatureIntentTarget,
                            identifier: String) async throws -> UISceneAcknowledgement {
        guard identifier.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_intent_entity")
        }
        try Task.checkCancellation()
        let matches = try await featureDestinations(feature, identifiers: [identifier])
        guard matches.count == 1 else {
            throw UIRouteError(.staleState, "intent_feature_no_longer_available")
        }
        try Task.checkCancellation()
        return try await open(identifier: identifier)
    }
}
