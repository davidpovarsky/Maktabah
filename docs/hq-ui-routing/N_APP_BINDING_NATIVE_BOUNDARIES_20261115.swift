import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost
extension StudyWorkspaceNavigationAdapter {
    // EXACT_R_SELECTION_GETTER
}

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
    init(reader: NativeSurfaceState?, workspace: StudyWorkspaceNavigationAdapter?) { self.reader = reader; self.workspace = workspace }
    init(manager: iOSNavigationManager, selectedTab: Int, columnVisibility: Int, settingsPresented: Bool, sidebar: Int?, workspace: StudyWorkspaceNavigationAdapter?) {
        reader = nil; self.workspace = workspace
    }
    func surface(_ kind: Surface) throws -> NativeSurfaceState? { reader }
}
@MainActor final class NAppSessionBoundary {
    let sceneID: UIStableID
    var mounted = true, foreground = true, isPresentationReady = true
    var readerSurface: NativeSurfaceState?
    weak var projectedWorkspace: StudyWorkspaceNavigationAdapter?
    var workspaceProjectionSource: MaktabahNativeWorkspaceProjectionSource?
    var actualProject: (@MainActor () throws -> NProjectionBoundary)?
    var invalidations = 0
    var revocations: Int { presentation.revocations }
    let presentation = NPresentationProbe()
    private var visible: [UIDestinationID: NativeSurfaceWitness.Evidence] = [:]
    private var visibilityChecks: [UIDestinationID: @MainActor () -> NativeSurfaceWitness.Evidence?] = [:]
    init(sceneID: UIStableID) { self.sceneID = sceneID }
    private func project() throws -> NProjectionBoundary { try actualProject?() ?? .init(reader: readerSurface, workspace: projectedWorkspace) }
    func readMountedWorkspace() throws -> StudyWorkspaceNavigationAdapter? { try project().workspace }
    func updateProjection(_ project: @escaping @MainActor () throws -> NProjectionBoundary) { actualProject = project }
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
    static var shared: NAppCompositionBoundary!
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
    func mount(sceneID: UIStableID, manager: iOSNavigationManager, bindings: MaktabahNativeSceneBindings, foreground: Bool,
               workspaceSource: MaktabahNativeWorkspaceProjectionSource? = nil,
               project: @escaping @MainActor () throws -> NProjectionBoundary) throws -> MaktabahNativeSceneSession {
        session.workspaceProjectionSource = workspaceSource; session.actualProject = project
        return session
    }
    func installIntentDependency() {}
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
typealias MaktabahNativeRoutingComposition = NAppCompositionBoundary
typealias MaktabahNativeSceneProjection = NProjectionBoundary
struct NBindingValue<Value> { var wrappedValue: Value }
struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let selectedTab = NBindingValue(wrappedValue: 0)
    let columnVisibility = NBindingValue(wrappedValue: 0)
    let showSettings = NBindingValue(wrappedValue: false)
}
struct NAlertMessage { let title: String; let message: String }
extension iOSNavigationManager {
    var alertMessage: NAlertMessage? { get { nil } set {} }
}
@MainActor final class NActualRoutingHostPath {
    enum Phase { case active }
    let manager: iOSNavigationManager
    let workspaceOwner: MaktabahNativeWorkspaceOwner?
    private weak var legacyWorkspace: StudyWorkspaceNavigationAdapter?
    var workspace: StudyWorkspaceNavigationAdapter? { workspaceOwner?.current ?? legacyWorkspace }
    let sceneID: String
    var session: MaktabahNativeSceneSession?
    var ready = true
    var phase: Phase = .active
    var bindings: MaktabahNativeSceneBindings { .init(manager: manager) }
    init(manager: iOSNavigationManager, sceneID: String, owner: MaktabahNativeWorkspaceOwner?, legacy: StudyWorkspaceNavigationAdapter? = nil) {
        self.manager = manager; self.sceneID = sceneID; workspaceOwner = owner; legacyWorkspace = legacy
    }
    func runMount() { mountIfReady() }
    func runRefresh() { refreshProjection() }
    func setLegacyEnvironment(_ workspace: StudyWorkspaceNavigationAdapter?) { legacyWorkspace = workspace }
    // EXACT_HOST_MOUNT_BODY
    // EXACT_HOST_REFRESH_BODY
}
