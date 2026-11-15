import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// Native UIKit/SwiftUI shells ONLY. The runner inserts exact app method bodies.
// R's actual producer body/native proposed-hook shell is compiled separately.
@MainActor final class HistoryViewModel {
    static let shared = HistoryViewModel()
    var searchText = ""
}
struct NPassiveEvidence: Equatable {
    let sceneID: UIStableID
    let surface: NativeSurfaceState
    var isVisible: Bool = true
}
enum NativeSurfaceWitness { typealias Evidence = NPassiveEvidence }
@MainActor final class NPresentationProbe {
    var revocations = 0
    func revoke() { revocations += 1 }
}
@MainActor struct NProjectionBoundary {
    enum Surface { case reader }
    let reader: NativeSurfaceState?
    let workspace: StudyWorkspaceNavigationAdapter?
    func surface(_ kind: Surface) throws -> NativeSurfaceState? { reader }
}
@MainActor final class NAppSessionBoundary {
    let sceneID: UIStableID
    var mounted = true, foreground = true, isPresentationReady = true
    var readerSurface: NativeSurfaceState?
    weak var projectedWorkspace: StudyWorkspaceNavigationAdapter?
    var invalidations = 0
    var revocations: Int { presentation.revocations }
    let presentation = NPresentationProbe()
    private var visible: [UIDestinationID: NativeSurfaceWitness.Evidence] = [:]
    private var visibilityChecks: [UIDestinationID: @MainActor () -> NativeSurfaceWitness.Evidence?] = [:]
    init(sceneID: UIStableID) { self.sceneID = sceneID }
    private func project() throws -> NProjectionBoundary { .init(reader: readerSurface, workspace: projectedWorkspace) }
    func nativeStateChanged() throws { invalidations += 1 }
    func unmount() { mounted = false }
    func installEvidence(_ surface: NativeSurfaceState, valid: Bool) {
        let evidence = NPassiveEvidence(sceneID: sceneID, surface: surface)
        visible[surface.destination] = evidence
        visibilityChecks[surface.destination] = { valid ? evidence : nil }
    }
    // EXACT_SESSION_PRESENTATION_BODY
    // EXACT_SESSION_WORKSPACE_IDENTITY_BODY
}
typealias MaktabahNativeSceneSession = NAppSessionBoundary

@MainActor final class NAppCompositionBoundary {
    private struct Registration {
        let managerID: ObjectIdentifier
        let session: MaktabahNativeSceneSession
        let lease: NativeNavigationAuthority.Lease
        var publicBinding: MaktabahNativePublicBindingAdapter?
    }
    let authority: NativeNavigationAuthority
    let directory: NativeSceneDirectory
    let backend: any ActionSynchronousBackendStatePort
    let session: MaktabahNativeSceneSession
    private var scenes: [UIStableID: Registration] = [:]
    private var contexts: [UIStableID: ActionExecutionContext] = [:]
    var hasContext: Bool { contexts[session.sceneID] != nil }
    func restoreContext(_ context: ActionExecutionContext) { contexts[session.sceneID] = context }
    init(_ n: PublicConsumerFixture, manager: iOSNavigationManager) {
        authority = n.authority; directory = n.directory; backend = n.backend
        session = .init(sceneID: n.sceneID)
        scenes[n.sceneID] = .init(managerID: ObjectIdentifier(manager), session: session, lease: n.lease)
        contexts[n.sceneID] = n.context
    }
    // EXACT_COMPOSITION_FACTORY_BODY
    // EXACT_COMPOSITION_WORKSPACE_UPDATE_BODY
    // EXACT_COMPOSITION_INVALIDATE_CONTEXT_BODY
}
