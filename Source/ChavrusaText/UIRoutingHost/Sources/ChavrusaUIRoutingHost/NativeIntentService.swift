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
        public var id: String { backend.rawValue + ":" + destination.rawValue }
        public init(backend: ActionBackendID, destination: UIDestinationID, title: String) {
            self.backend = backend; self.destination = destination; self.title = title
        }
    }
    public typealias Discover = @MainActor @Sendable () async throws -> [Destination]
    public typealias Open = @MainActor @Sendable (Destination) async throws -> UISceneAcknowledgement
    private let discover: Discover
    private let navigate: Open
    public init(discover: @escaping Discover, navigate: @escaping Open) { self.discover = discover; self.navigate = navigate }

    public func destinations(identifiers: [String]? = nil, matching query: String? = nil) async throws -> [Destination] {
        try Task.checkCancellation()
        if let identifiers, identifiers.count > 64 { throw UIRouteError(.failed, "too_many_intent_entities") }
        guard query == nil || query!.utf8.count <= 512 else { throw UIRouteError(.failed, "intent_query_too_large") }
        let values = try await discover()
        try Task.checkCancellation()
        guard values.count <= 128, Set(values.map(\.id)).count == values.count else { throw UIRouteError(.failed, "invalid_live_intent_catalog") }
        let requested = identifiers.map(Set.init)
        return values.filter { value in
            (requested == nil || requested!.contains(value.id)) && (query == nil || value.title.localizedCaseInsensitiveContains(query!))
        }
    }

    /// Re-resolve stale system entities against the current authorized catalog
    /// before handing off. The orchestrator reauthorizes at native commit.
    public func open(identifier: String) async throws -> UISceneAcknowledgement {
        guard identifier.utf8.count <= 256 else { throw UIRouteError(.failed, "invalid_intent_entity") }
        let matches = try await destinations(identifiers: [identifier])
        guard matches.count == 1, let target = matches.first else { throw UIRouteError(.staleState, "intent_entity_no_longer_available") }
        return try await navigate(target)
    }
}
