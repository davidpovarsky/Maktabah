import Foundation

/// Owns only opaque, single-use authority over an observation. Search results,
/// provider requests, offsets and UI State remain with their original owners.
@MainActor
final class OriginalSearchContinuationClaim {
    enum Kind: Equatable, Sendable { case loadedHit, nextPage }
    enum Refusal: Error, Equatable { case busy, stale, duplicate, wrongOperation, ambiguous }
    struct Token: Equatable, Sendable {
        let id: UUID
        let kind: Kind
        let identity: Data?
    }
    struct Observation: Equatable, Sendable {
        let id: UUID
        let source: Data
        let hits: [Token]
        let next: Token?
    }
    struct Claim: Equatable, Sendable {
        let id: UUID
        let observationID: UUID
        let token: Token
        let source: Data
    }

    private var observation: Observation?
    private var available: [UUID: Token] = [:]
    private var spent: Set<UUID> = []
    private(set) var active: Claim?

    func observe(source: Data, hitIdentities: [Data], hasNextPage: Bool) throws -> Observation {
        guard active == nil else { throw Refusal.busy }
        guard Set(hitIdentities).count == hitIdentities.count else { throw Refusal.ambiguous }
        if let observation, observation.source == source,
           observation.hits.map(\.identity) == hitIdentities.map(Optional.some),
           (observation.next != nil) == hasNextPage {
            return observation
        }
        let hits = hitIdentities.map { Token(id: UUID(), kind: .loadedHit, identity: $0) }
        let next = hasNextPage ? Token(id: UUID(), kind: .nextPage, identity: nil) : nil
        let value = Observation(id: UUID(), source: source, hits: hits, next: next)
        observation = value
        available = Dictionary(uniqueKeysWithValues: (hits + [next].compactMap { $0 }).map { ($0.id, $0) })
        // Only the current observation needs replay classification. A token
        // from an older observation is stale and can never resolve again.
        spent.removeAll(keepingCapacity: true)
        return value
    }

    /// Synchronous claim BEFORE invoking the original provider or UI setter.
    /// No await, callback or mirrored loading flag separates validation/claim.
    func claim(tokenID: UUID, kind: Kind, observationID: UUID, source: Data) throws -> Claim {
        guard active == nil else { throw Refusal.busy }
        guard let observation, observation.id == observationID, observation.source == source else { throw Refusal.stale }
        guard !spent.contains(tokenID) else { throw Refusal.duplicate }
        guard let token = available[tokenID] else { throw Refusal.stale }
        guard token.kind == kind else { throw Refusal.wrongOperation }
        available.removeValue(forKey: tokenID)
        spent.insert(tokenID)
        let value = Claim(id: UUID(), observationID: observationID, token: token, source: source)
        active = value
        return value
    }

    func validate(_ claim: Claim) throws {
        guard active == claim, observation?.id == claim.observationID,
              observation?.source == claim.source, spent.contains(claim.token.id) else { throw Refusal.stale }
    }

    func finish(_ claim: Claim) {
        guard active == claim else { return }
        active = nil
        // A failed/cancelled operation remains consumed. A new read after an
        // actual source transition may issue a different token; finish cannot.
    }

    func invalidate() {
        observation = nil
        available.removeAll(keepingCapacity: true)
        // Keep the active claim until its exact owner finishes, so no second
        // operation can overlap an in-flight request after source invalidation.
    }
}
