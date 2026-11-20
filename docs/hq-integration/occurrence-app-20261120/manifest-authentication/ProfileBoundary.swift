import Foundation
// This tool serializes the complete original manifest model. No profile lookup
// participates in decoding/encoding; fail immediately if that boundary is used.
enum OtzariaDataProfileRegistry {
    struct Identity { let id: String; let version: Int }
    static var productionID: String { fatalError("unexpected profile lookup") }
    static var activeIdentity: Identity { fatalError("unexpected profile lookup") }
}
