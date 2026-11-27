import Foundation

/// A native mount identity, never a public content locator or a JS navigation command.
struct SefariaEmbeddedSurfaceIdentity: Identifiable, Equatable, Sendable {
    let id: UUID
    let mountID: UUID
    let sceneID: String
    let epoch: UInt64

    var properties: [String: Any] {
        ["surfaceID": id.uuidString, "mountID": mountID.uuidString,
         "sceneID": sceneID, "epoch": epoch]
    }
    var valid: Bool {
        !sceneID.isEmpty && sceneID.count <= 256 && epoch > 0 && epoch <= 9_007_199_254_740_991
    }
}

/// Returned only after a real original ReaderApp instance completed its own init
/// and the React Native layout callback supplied nonzero original geometry.
struct SefariaEmbeddedSurfaceProof: Codable, Equatable, Sendable {
    struct Layout: Codable, Equatable, Sendable {
        let width: Double
        let height: Double
        let revision: UInt64
    }
    let contract: String
    let component: String
    let upstreamSHA: String
    let surfaceID: UUID
    let mountID: UUID
    let sceneID: String
    let epoch: UInt64
    let nonce: UUID
    let layout: Layout

    func matches(_ identity: SefariaEmbeddedSurfaceIdentity, nonce expectedNonce: UUID) -> Bool {
        identity.valid && contract == "chavrusa.original-rn-surface.v1" && component == "ReaderApp"
            && upstreamSHA == "2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c"
            && surfaceID == identity.id && mountID == identity.mountID
            && sceneID == identity.sceneID && epoch == identity.epoch && nonce == expectedNonce
            && layout.revision > 0 && layout.width.isFinite && layout.height.isFinite
            && layout.width > 0 && layout.height > 0
    }
}

/// Produced from the actual canonical receipt and the same still-visible native
/// host. Allocation, a headless handshake or a cached proof cannot construct it.
struct SefariaEmbeddedSurfaceAcceptanceEvidence: Codable, Sendable {
    let nativeReceiptID: UUID
    let nativeSceneID: String
    let nativeHostToken: UUID
    let runtimeRevision: UInt64
    let originalSurface: SefariaEmbeddedSurfaceProof
}

/// Original ReaderApp has process-wide tracker registrations. Keep at most one
/// visible original instance and never transfer it across scenes. Headless RPC
/// is independent and is neither claimed nor moved by this lease.
@MainActor final class SefariaEmbeddedSurfaceLease {
    static let shared = SefariaEmbeddedSurfaceLease()
    struct Lease: Equatable {
        let ownerID: UUID
        let identity: SefariaEmbeddedSurfaceIdentity
        let revision: UInt64
    }
    struct Snapshot: Equatable {
        let revision: UInt64
        let lease: Lease?
        let exhausted: Bool
    }
    private var revision: UInt64 = 0
    private var lease: Lease?
    private var exhausted = false
    var snapshot: Snapshot { .init(revision: revision, lease: lease, exhausted: exhausted) }

    func acquire(ownerID: UUID, identity: SefariaEmbeddedSurfaceIdentity,
                 expected: Snapshot) throws -> Lease {
        guard identity.valid, snapshot == expected, !exhausted, lease == nil, revision < .max else {
            throw SefariaRPCError(code: "SURFACE_LEASE_UNAVAILABLE", message: "The original Sefaria surface is unavailable.")
        }
        revision += 1
        let value = Lease(ownerID: ownerID, identity: identity, revision: revision)
        lease = value
        return value
    }
    func owns(_ value: Lease) -> Bool { !exhausted && lease == value }
    func release(_ value: Lease) {
        guard lease == value else { return }
        lease = nil
        if revision == .max { exhausted = true } else { revision += 1 }
    }
}
