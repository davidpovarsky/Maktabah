// Explicit platform/domain boundary for compiling the COMPLETE real RN binding.
// Foundation/Observation/Swift concurrency, runtime, RPC actor, one-way latches,
// lease, ticket, source membership and binding methods remain actual source.
// UIKit rendering, Combine, backend/Store data and Core receipt issuance are NOT
// implemented or qualified here. Geometry and JS have separate source controls.
enum BackendID: String { case sefariaEmbedded, otzaria }
enum BackendCapability { case catalog, reading }
@MainActor final class AnyCancellable {
    let cancellation: () -> Void
    init(_ cancellation: @escaping () -> Void) { self.cancellation = cancellation }
    isolated deinit { cancellation() }
}
@MainActor final class BoundaryBackendPublisher {
    private var listeners: [UUID: (Int) -> Void] = [:]
    func sink(_ receive: @escaping (Int) -> Void) -> AnyCancellable {
        let id = UUID(); listeners[id] = receive
        return AnyCancellable { [weak self] in self?.listeners.removeValue(forKey: id) }
    }
    func send() { for callback in Array(listeners.values) { callback(0) } }
}
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    let objectWillChange = BoundaryBackendPublisher()
    var activeBackendID = BackendID.sefariaEmbedded { willSet { objectWillChange.send() } }
    var generation: UInt64 = 1 { willSet { objectWillChange.send() } }
    var isTransitioning = false { willSet { objectWillChange.send() } }
    var activeCapabilities: Set<BackendCapability> = [.catalog, .reading]
}
@MainActor @Observable final class BoundaryMappingSource { var event = 0 }
struct StudyWorkspaceMappingObservation {
    enum Coverage { case workspaceStoreOnly, liveNativeSetters }
    let source: BoundaryMappingSource
    let epoch: Int
    let owner: ObjectIdentifier
    let scene: String
    let coverage: Coverage
}
@MainActor final class iOSNavigationManager {}
@MainActor @Observable final class BoundaryWorkspaceStore {
    var loadError: String?
    let source = BoundaryMappingSource()
    func mappingObservation(scene: String) -> StudyWorkspaceMappingObservation? {
        .init(source: source, epoch: source.event, owner: ObjectIdentifier(self), scene: scene, coverage: .workspaceStoreOnly)
    }
}
@MainActor @Observable final class StudyWorkspaceNavigationAdapter {
    let sceneID: String
    let manager: iOSNavigationManager
    let store = BoundaryWorkspaceStore()
    let source = BoundaryMappingSource()
    var attached = true; var isSwitching = false; var errorMessage: String?
    init(sceneID: String, manager: iOSNavigationManager) { self.sceneID = sceneID; self.manager = manager }
    func mappingOwnershipObservation() -> StudyWorkspaceMappingObservation? {
        .init(source: source, epoch: source.event, owner: ObjectIdentifier(manager), scene: sceneID, coverage: .liveNativeSetters)
    }
}
struct UIStableID: Equatable, Sendable { let rawValue: String; init?(rawValue: String) { if rawValue.isEmpty { return nil }; self.rawValue = rawValue } }
struct UIDestinationID: Equatable, Sendable { let rawValue: String; init?(rawValue: String) { if rawValue.isEmpty { return nil }; self.rawValue = rawValue } }
struct UIRouteError: Error { enum Status { case unavailable, staleState }; let status: Status; let code: String; init(_ status: Status, _ code: String) { self.status = status; self.code = code } }
struct UISceneReceipt {
    struct Route {
        struct Presentation { enum Kind { case sheet, currentTab }; let kind: Kind }
        let requestId: UUID; let destination: UIDestinationID; let presentation: Presentation
        let content: Int?; let focus: Int?
    }
    let requestId: UUID; let sceneID: UIStableID; let route: Route
}
@MainActor final class SefariaExpoLifecycleAdapter {
    static let shared = SefariaExpoLifecycleAdapter()
    var canCreateVisibleSurface = true
}
@MainActor final class OtzariaFileLogger { static let shared = OtzariaFileLogger(); func log(_ text: String) {} }
@MainActor final class UIView { var bounds = CGRect(x: 0, y: 0, width: 600, height: 800) }
__ACTUAL_HOST_OBSERVER_PROTOCOL__
@MainActor final class SefariaEmbeddedNativeSurfaceController {
    struct Evidence { var mounted = true; var appeared = true; var visible = true; var transitioning = false }
    struct SemanticEvidence { let originalViews: [ObjectIdentifier] }
    let identity: SefariaEmbeddedSurfaceIdentity
    let token = UUID()
    var reactView: UIView? = UIView()
    var state = Evidence()
    var semanticVisible = true
    var observedTarget: SefariaEmbeddedSemanticTarget?
    var originalSemanticView = UIView()
    weak var observer: (any SefariaEmbeddedNativeSurfaceObserver)?
    var observing: (() -> Void)?
    init(identity: SefariaEmbeddedSurfaceIdentity) { self.identity = identity }
    func evidence() -> Evidence? { state }
    func semanticEvidence(target: SefariaEmbeddedSemanticTarget, language: String) -> SemanticEvidence? {
        guard state.visible, semanticVisible, target.originalVisibleTexts(language: language) != nil else { return nil }
        return .init(originalViews: [ObjectIdentifier(originalSemanticView)])
    }
    func observeSemanticTarget(_ target: SefariaEmbeddedSemanticTarget, language: String) {
        observedTarget = target; observing?(); observer?.surfaceDidChange(self)
    }
    func stopSemanticObservation() { observedTarget = nil }
    func detach() { state.visible = false; observer?.surfaceDidDetach(self); observer = nil }
}
