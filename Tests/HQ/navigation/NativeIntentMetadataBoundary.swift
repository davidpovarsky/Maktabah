import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// Explicit OS/UI/DI boundaries. No AppIntents, UIKit, live catalog, visible UI,
// or native effect is supplied by this portable reproduction.
extension String { var localized: String { self } }
@MainActor final class OtzariaFileLogger {
    static let shared = OtzariaFileLogger()
    func log(_ value: String) {}
}
public struct NativeDestinationEntity: Equatable, Sendable {
    public let id: String
    public let title: String
    public init(id: String, title: String) { self.id = id; self.title = title }
}
@MainActor final class AppDependencyManager {
    static let shared = AppDependencyManager()
    var native: NativeIntentService?
    func add<T>(dependency: T) { if let value = dependency as? NativeIntentService { native = value } }
}
@MainActor final class FixtureReaderWindowQuery {
    let service: NativeIntentService
    init(service: NativeIntentService) { self.service = service }
    // ACTUAL_READER_WINDOW_QUERY_METHODS
}
enum FixtureBoundaryError: Error { case unexpectedNativeExecution }
@MainActor final class FixturePresentation {
    var revoked = 0
    func revoke() { revoked += 1 }
}
@MainActor final class FixtureManager {}
@MainActor final class MaktabahNativeSceneSession {
    struct Presentation { let inspectorAvailable: Bool }
    let sceneID: UIStableID
    let directory: NativeSceneDirectory
    var foreground: Bool
    var mounted = true
    var isPresentationReady = true
    var lease: NativeSceneDirectory.Lease?
    let presentation = FixturePresentation()
    init(sceneID: UIStableID, directory: NativeSceneDirectory, foreground: Bool) {
        self.sceneID = sceneID; self.directory = directory; self.foreground = foreground
    }
    func windowLabel(number: Int) -> String { "Window \(number)" }
    func isRootAvailable(_ id: UIDestinationID) -> Bool {
        ["native.library", "native.history", "native.search", "native.annotations"].contains(id.rawValue)
    }
    func publicBindingPresentation() throws -> Presentation { .init(inspectorAvailable: false) }
    func mount(validateLifetime: @escaping NativeSceneDirectory.ValidateLifetime) throws {
        lease = try directory.mount(sceneID: sceneID, observe: { [self] in
            .init(isForeground: foreground, isMounted: mounted, visibleRoute: nil)
        }, validateLifetime: validateLifetime)
    }
    func nativeStateChanged() throws {
        guard let lease else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
        try directory.invalidate(lease)
    }
}
@MainActor final class FixtureBackend: ActionSynchronousBackendStatePort {
    var value: ActionBackendSnapshot
    var snapshotCalls = 0
    var synchronousReads = 0
    var onSynchronousRead: (@MainActor (Int) throws -> Void)?
    var onNextSnapshot: (@MainActor () throws -> Void)?
    init(_ backend: ActionBackendID) {
        value = .init(backend: backend, generation: 1, rpcEpoch: backend == .sefariaEmbedded ? 7 : nil)
    }
    func currentBackendSnapshot() throws -> ActionBackendSnapshot {
        synchronousReads += 1
        try onSynchronousRead?(synchronousReads)
        return value
    }
    func snapshot() async throws -> ActionBackendSnapshot {
        snapshotCalls += 1
        let action = onNextSnapshot; onNextSnapshot = nil
        try action?()
        try Task.checkCancellation()
        return value
    }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport { .init(id: backend, operations: [:]) }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: false, supported: false, availableNow: false)
    }
}
struct FixturePorts: ActionResolverPort, ActionSearchPort {
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> { throw FixtureBoundaryError.unexpectedNativeExecution }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { throw FixtureBoundaryError.unexpectedNativeExecution }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { throw FixtureBoundaryError.unexpectedNativeExecution }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage { throw FixtureBoundaryError.unexpectedNativeExecution }
}
@MainActor final class FixtureSink: ActionUICommandSink {
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement { throw FixtureBoundaryError.unexpectedNativeExecution }
}
@MainActor final class MaktabahNativeRoutingComposition: UIDestinationEligibilityPort {
    let backend: FixtureBackend
    let authority: NativeNavigationAuthority
    let directory: NativeSceneDirectory
    let core: ActionExecutor
    let registry: UIDestinationRegistry
    struct Registration {
        let managerID: ObjectIdentifier
        let session: MaktabahNativeSceneSession
        let lease: NativeNavigationAuthority.Lease
        let windowNumber: Int
        var publicBinding: (any UIPublicNavigationEligibilityPort)? = nil
    }
    struct MountWaiter { let token: UUID; let continuation: CheckedContinuation<UIStableID, any Error> }
    var scenes: [UIStableID: Registration] = [:]
    var contexts: [UIStableID: ActionExecutionContext] = [:]
    var mountWaiters: [ObjectIdentifier: MountWaiter] = [:]
    var managers: [FixtureManager] = []
    var intentsInstalled = false
    var foregroundPreparationCalls = 0
    var nativeEffectCalls = 0
    init(backendID: ActionBackendID = .otzaria) throws {
        backend = FixtureBackend(backendID)
        authority = try NativeNavigationAuthority()
        directory = try NativeSceneDirectory(authority: backend)
        let ports = FixturePorts()
        core = try ActionExecutor(state: backend, resolver: ports, search: ports, ui: FixtureSink(), navigationAuthority: authority)
        // ACTUAL_REGISTRY_INITIALIZATION
    }
    @discardableResult func mountFixture(_ rawID: String = "scene.A", foreground: Bool) throws -> MaktabahNativeSceneSession {
        let sceneID = UIStableID(rawValue: rawID)!, manager = FixtureManager()
        managers.append(manager)
        let session = MaktabahNativeSceneSession(sceneID: sceneID, directory: directory, foreground: foreground)
        let lease = try authority.mount(sceneID: sceneID, foreground: foreground)
        // ACTUAL_COMPOSITION_MOUNT_VALIDATOR
        scenes[sceneID] = .init(managerID: ObjectIdentifier(manager), session: session, lease: lease, windowNumber: managers.count)
        return session
    }
    func query() throws -> FixtureReaderWindowQuery {
        AppDependencyManager.shared.native = nil
        installIntentDependency()
        guard let service = AppDependencyManager.shared.native else { throw FixtureBoundaryError.unexpectedNativeExecution }
        return .init(service: service)
    }
    func rootID(_ session: MaktabahNativeSceneSession) -> String {
        NativeIntentService.Destination(backend: backend.value.backend, destination: .init(rawValue: "native.library")!, title: "Library", sceneID: session.sceneID).id
    }
    func holdOriginalContext(_ session: MaktabahNativeSceneSession) throws -> ActionExecutionContext {
        let value = context(sceneID: session.sceneID, origin: .appIntent, snapshot: backend.value)
        try issue(value, sceneID: session.sceneID)
        return value
    }
    func releaseOriginalContext(_ value: ActionExecutionContext, session: MaktabahNativeSceneSession) {
        finish(value, sceneID: session.sceneID)
    }
    func invalidateHanlin(sceneID: UIStableID) {}
    func awaitIntentForeground(_ destination: NativeIntentService.Destination) async throws {
        foregroundPreparationCalls += 1; throw FixtureBoundaryError.unexpectedNativeExecution
    }
    func open(destination: NativeIntentService.Destination) async throws -> UISceneAcknowledgement {
        nativeEffectCalls += 1; throw FixtureBoundaryError.unexpectedNativeExecution
    }
    func readerIntentMetadata(_ request: ActionRequest) async throws -> NativeReaderIntentService.CoreObservation {
        throw FixtureBoundaryError.unexpectedNativeExecution
    }
    func openReaderIntent(_ request: NativeReaderIntentService.OpenRequest) async throws -> UISceneAcknowledgement {
        nativeEffectCalls += 1; throw FixtureBoundaryError.unexpectedNativeExecution
    }
    // ACTUAL_COMPOSITION_METHODS
}
