import Foundation
import Observation

@MainActor protocol MaktabahNativeWorkspaceOwnerObserver: AnyObject {
    func workspaceOwnerWillChange()
}

/// Canonical storage for the lifecycle's actual workspace reference. The
/// owner-file proposal replaces its old @State reference, rather than copying
/// that reference into a second selection/permission model.
@MainActor @Observable final class MaktabahNativeWorkspaceOwner {
    private var workspace: StudyWorkspaceNavigationAdapter?
    @ObservationIgnored private var changing = false
    @ObservationIgnored private weak var observer: (any MaktabahNativeWorkspaceOwnerObserver)?
    @ObservationIgnored private var token: UUID?
    var current: StudyWorkspaceNavigationAdapter? { changing ? nil : workspace }
    var isPublishing: Bool { changing }
    #if os(iOS)
    /// Only the exact original scene host installs this weak forwarding link.
    /// Outer original presentation modifiers can carry that same session across
    /// their UIHostingController boundary without looking up a global window.
    private(set) weak var nativeRoutingSession: MaktabahNativeSceneSession?

    func attachNativeRoutingSession(_ session: MaktabahNativeSceneSession) throws {
        guard session.mounted, session.usesWorkspaceOwner(self),
              current?.sceneID == session.sceneID.rawValue,
              nativeRoutingSession == nil || nativeRoutingSession === session
                || nativeRoutingSession?.mounted == false else {
            throw WorkspaceOwnerError.nativeRoutingOwnerMismatch
        }
        nativeRoutingSession = session
    }
    func detachNativeRoutingSession(_ session: MaktabahNativeSceneSession) {
        guard nativeRoutingSession === session else { return }
        nativeRoutingSession = nil
    }
    #endif

    func replace(with next: StudyWorkspaceNavigationAdapter?) throws {
        guard !changing else { throw WorkspaceOwnerError.reentrantPublication }
        guard workspace !== next else { return }
        changing = true
        // Binding reads fail closed before the reference assignment itself.
        observer?.workspaceOwnerWillChange()
        workspace = next
        changing = false
    }
    func observe(_ observer: any MaktabahNativeWorkspaceOwnerObserver) throws -> UUID {
        guard self.observer == nil else { throw WorkspaceOwnerError.observerAlreadyInstalled }
        let token = UUID(); self.token = token; self.observer = observer
        return token
    }
    func cancelObservation(_ token: UUID) {
        guard self.token == token else { return }
        self.token = nil; observer = nil
    }
    isolated deinit { observer?.workspaceOwnerWillChange() }
    enum WorkspaceOwnerError: Error { case reentrantPublication, observerAlreadyInstalled, nativeRoutingOwnerMismatch }
}

/// Actual mount and refresh both use this fixed weak source. Neither closure
/// captures an old adapter strongly. Legacy v1 may read a weak legacy reference;
/// that path is explicitly ineligible for future public binding.
@MainActor final class MaktabahNativeWorkspaceProjectionSource {
    private weak var owner: MaktabahNativeWorkspaceOwner?
    private weak var legacy: StudyWorkspaceNavigationAdapter?
    private let authoritative: Bool
    var isAuthoritative: Bool { authoritative }
    init(owner: MaktabahNativeWorkspaceOwner?, legacyWorkspace: StudyWorkspaceNavigationAdapter?) {
        self.owner = owner; legacy = legacyWorkspace; authoritative = owner != nil
    }
    func read() throws -> StudyWorkspaceNavigationAdapter? {
        guard authoritative else { return legacy }
        guard let owner, !owner.isPublishing else { throw MaktabahNativeWorkspaceOwner.WorkspaceOwnerError.reentrantPublication }
        return owner.current
    }
    func uses(_ candidate: MaktabahNativeWorkspaceOwner) -> Bool { authoritative && owner === candidate }
    func projection<Value>(_ make: @escaping @MainActor (StudyWorkspaceNavigationAdapter?) throws -> Value) -> @MainActor () throws -> Value {
        { [self] in try make(read()) }
    }
}
