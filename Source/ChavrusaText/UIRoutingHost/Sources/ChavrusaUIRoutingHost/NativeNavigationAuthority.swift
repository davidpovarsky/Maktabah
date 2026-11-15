import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Scene lifecycle and currently admitted trusted request only. Core performs
/// policy/rights authorization. This store never manufactures a backend state.
@MainActor
public final class NativeNavigationAuthority: ActionNavigationAuthority {
    public struct Lease: Sendable, Equatable { public let sceneID: UIStableID; public let lifetimeID: UUID }
    private struct Entry {
        let lease: Lease
        var revision: UInt64
        var foreground: Bool
        var context: ActionExecutionContext?
    }
    private var entries: [UIStableID: Entry] = [:]
    private var revision: UInt64 = 0
    private let capacity: Int
    public init(capacity: Int = 16) throws {
        guard (1...64).contains(capacity) else { throw UIRouteError(.failed, "invalid_scene_capacity") }
        self.capacity = capacity
    }
    private func advance() throws -> UInt64 {
        guard revision < UInt64.max else { throw UIRouteError(.unavailable, "native_authority_revision_exhausted") }
        revision += 1; return revision
    }
    public func mount(sceneID: UIStableID, foreground: Bool) throws -> Lease {
        guard entries[sceneID] == nil, entries.count < capacity else { throw UIRouteError(.unavailable, "native_authority_admission_rejected") }
        let lease = Lease(sceneID: sceneID, lifetimeID: UUID())
        entries[sceneID] = Entry(lease: lease, revision: try advance(), foreground: foreground)
        return lease
    }
    public func setForeground(_ value: Bool, lease: Lease) throws {
        guard var entry = entries[lease.sceneID], entry.lease == lease else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
        guard entry.foreground != value else { return }
        entry.foreground = value; entry.revision = try advance(); entry.context = nil
        entries[lease.sceneID] = entry
    }
    /// Auth/profile/workspace/document/selection/permission revocation, including
    /// revoke/restore ABA, must synchronously invalidate the admitted context.
    public func invalidate(_ lease: Lease) throws {
        guard var entry = entries[lease.sceneID], entry.lease == lease else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
        entry.revision = try advance(); entry.context = nil; entries[lease.sceneID] = entry
    }
    public func unmount(_ lease: Lease) {
        guard entries[lease.sceneID]?.lease == lease else { return }
        entries.removeValue(forKey: lease.sceneID)
    }
    @discardableResult
    public func admit(context: ActionExecutionContext, sceneID: UIStableID) throws -> ActionNavigationState {
        try Task.checkCancellation()
        guard var entry = entries[sceneID] else { throw UIRouteError(.unavailable, "scene_missing") }
        guard entry.foreground, context.foregroundSceneID == sceneID.rawValue else { throw UIRouteError(.requiresForeground, "exact_foreground_scene_required") }
        guard entry.context == nil else { throw UIRouteError(.unavailable, "native_scene_busy") }
        entry.context = context; entry.revision = try advance(); entries[sceneID] = entry
        return try navigationState(sceneID: sceneID.rawValue)
    }
    public func release(_ admitted: ActionNavigationState) {
        guard let id = UIStableID(rawValue: admitted.sceneID), var entry = entries[id],
              entry.lease.lifetimeID == admitted.lifetimeID, entry.revision == admitted.authorityRevision,
              entry.context == admitted.context else { return }
        entry.context = nil; entries[id] = entry
    }
    public func navigationState(sceneID: String) throws -> ActionNavigationState {
        guard let id = UIStableID(rawValue: sceneID), let entry = entries[id], let context = entry.context else {
            throw UIRouteError(.unavailable, "native_context_unavailable")
        }
        return .init(context: context, sceneID: id.rawValue, lifetimeID: entry.lease.lifetimeID,
                     authorityRevision: entry.revision, active: entry.foreground)
    }
}
