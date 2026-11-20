import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// Explicit app/UIKit boundary doubles. The real Reader models, window layout,
// text rendering and native setter installation are NOT executed by this fixture.
// The runner inserts the unchanged complete app adapter, actual Inspector owner,
// actual session projection/mount methods and actual workspace ownership source.
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID: BackendID = .otzaria
}
@MainActor final class ReaderState { var selectedRange: NSRange? = .init(location: 2, length: 3) }
struct FixtureBook { let id: Int; let backendLocator: TextLocator? }
@MainActor final class ReaderViewModel {
    enum State { case loaded, loading }
    struct Section { var locator: TextLocator }
    var currentDestination: LibraryReaderDestination?
    var backendSection: Section?
    var contentText = "Original fixture source text"
    var state: State = .loaded
    var selectedSegmentLocator: TextLocator?
    var otzariaSelectedLineAnchor: OtzariaLineAnchor?
    var currentBook: FixtureBook?
    var readerState = ReaderState()
    var currentReaderTextMode = LibraryReaderTextMode.allCases[0]
    var currentContentId = 7
    var readerInspectorVisible = false
}
@MainActor final class iOSNavigationManager {
    enum Mode { case viewer, search }
    struct ReaderTab { let id: UUID; let book: FixtureBook; let viewModel: ReaderViewModel }
    var currentMode: Mode = .viewer
    var activeTabId: UUID?
    var openTabs: [ReaderTab] = []
}
@MainActor final class StudyWorkspaceNavigationAdapter {
    struct Reservation { let policy: StudyWorkspaceReaderReservation; let tab: iOSNavigationManager.ReaderTab }
    let mappingOwnershipSource = StudyWorkspaceMappingSource(available: true)
    let manager: iOSNavigationManager
    let sceneID: String
    var projection: StudyWorkspaceMappingProjection
    var coverage: StudyWorkspaceMappingCoverage = .liveNativeSetters
    init(manager: iOSNavigationManager, sceneID: String, projection: StudyWorkspaceMappingProjection) {
        self.manager = manager; self.sceneID = sceneID; self.projection = projection
    }
    func mappingOwnershipObservation() -> StudyWorkspaceMappingObservation? {
        guard let epoch = mappingOwnershipSource.event.epoch else { return nil }
        return .init(source: mappingOwnershipSource, owner: ObjectIdentifier(manager), scene: sceneID,
                     epoch: epoch, coverage: coverage, projection: projection)
    }
    func reservedNativeReader(requestID: UUID) throws -> Reservation { throw ActionPortError.notSupported }
}
@MainActor enum MaktabahNativeReaderBinding {
    // The actual adapter's unrelated reader-content branch is deliberately not
    // enabled by this Inspector fixture. No fake successful reader resolution.
    static func appDestination(_ content: ActionReaderDestination) throws -> LibraryReaderDestination {
        throw ActionPortError.notSupported
    }
}
enum MaktabahNativeRootDestination { case search, tableOfContents; var isAvailable: Bool { true } }
@MainActor final class HistoryViewModel { static let shared = HistoryViewModel(); var searchText = "" }
struct FixtureSceneBindings {
    let manager: iOSNavigationManager
    func isRootAvailable(_ destination: MaktabahNativeRootDestination) -> Bool { true }
}
// UIKit's evidence is the explicit boundary: tests independently control these
// facts. No claim is made that a real UIKit view appeared or became hittable.
enum NativeSurfaceWitness {
    struct Evidence: Sendable, Equatable {
        let sceneID: UIStableID
        let surface: NativeSurfaceState
        let isVisible: Bool
        let submissionID: UUID?
    }
}
@MainActor struct FixtureProjection {
    enum Surface { case reader, inspector, noteDraft }
    let manager: iOSNavigationManager
    let workspace: StudyWorkspaceNavigationAdapter
    var renderedReader = true
    func surface(_ kind: Surface) throws -> NativeSurfaceState? {
        guard let reader = MaktabahNativeInspectorBinding.currentReader(in: manager),
              let destination = reader.currentDestination else { return nil }
        let group = UIStableID(rawValue: workspace.projection.groupID.uuidString)!
        let profile = UIStableID(rawValue: workspace.projection.profileID.uuidString)!
        switch kind {
        case .reader:
            return .init(destination: .init(rawValue: "native.reader")!,
                presentation: .init(kind: .currentTab, tabID: manager.activeTabId.flatMap { .init(rawValue: $0.uuidString) }),
                content: .init(sectionLocator: try ActionAppIdentityBridge.actionRef(destination.sectionLocator)),
                state: .init(workspaceID: group, profileID: profile, inspectorVisible: reader.readerInspectorVisible), focus: nil)
        case .inspector:
            guard reader.readerInspectorVisible else { return nil }
            return .init(destination: .init(rawValue: "native.reader.inspector")!, presentation: .init(kind: .inspector),
                content: nil, state: .init(workspaceID: group, profileID: profile, inspectorVisible: true), focus: nil)
        case .noteDraft: return nil
        }
    }
    func hasRenderedReaderEvidence(sceneID: UIStableID) -> Bool { renderedReader }
    func identity() throws -> NativeSceneIdentity {
        let reader = MaktabahNativeInspectorBinding.currentReader(in: manager)
        return .init(topLevel: 0, activeTabID: manager.activeTabId.flatMap { .init(rawValue: $0.uuidString) },
            section: try reader?.currentDestination.map { try ActionAppIdentityBridge.actionRef($0.sectionLocator) },
            selectedRange: .init(location: 2, length: 3),
            state: .init(workspaceID: .init(rawValue: workspace.projection.groupID.uuidString),
                         profileID: .init(rawValue: workspace.projection.profileID.uuidString),
                         inspectorVisible: reader?.readerInspectorVisible), libraryQuery: "", globalQuery: "")
    }
}
@MainActor final class FixtureNoteBinding { func validateVisible() throws { throw ActionPortError.notSupported } }
@MainActor final class FixtureSceneSession {
    let sceneID: UIStableID
    let directory: NativeSceneDirectory
    let bindings: FixtureSceneBindings
    let workspace: StudyWorkspaceNavigationAdapter
    var lease: NativeSceneDirectory.Lease?
    var mounted = true, foreground = true, isPresentationReady = true, searchFieldAvailable = false
    var renderedReader = true
    var command: UISceneCommand?
    var visible: [UIDestinationID: NativeSurfaceWitness.Evidence] = [:]
    var visibilityChecks: [UIDestinationID: @MainActor () -> NativeSurfaceWitness.Evidence?] = [:]
    var inspectorBinding: MaktabahNativeInspectorBinding?
    var noteDraftBinding: FixtureNoteBinding?
    init(sceneID: UIStableID, directory: NativeSceneDirectory, manager: iOSNavigationManager,
         workspace: StudyWorkspaceNavigationAdapter) {
        self.sceneID = sceneID; self.directory = directory; bindings = .init(manager: manager); self.workspace = workspace
    }
    func project() throws -> FixtureProjection { .init(manager: bindings.manager, workspace: workspace, renderedReader: renderedReader) }
    func surface(_ kind: FixtureProjection.Surface) throws -> NativeSurfaceState? {
        if kind == .inspector { try inspectorBinding?.validate() }
        return try project().surface(kind)
    }
    func surfaceKind(_ destination: UIDestinationID) -> FixtureProjection.Surface? {
        switch destination.rawValue {
        case "native.reader": .reader
        case "native.reader.inspector": .inspector
        default: nil
        }
    }
    func publish(_ kind: FixtureProjection.Surface, isVisible: Bool, scene: UIStableID? = nil, submission: UUID? = nil) throws {
        guard let actual = try project().surface(kind) else { return }
        let evidence = NativeSurfaceWitness.Evidence(sceneID: scene ?? sceneID, surface: actual,
            isVisible: isVisible, submissionID: submission ?? command?.invocation.requestId)
        visible[actual.destination] = evidence
        visibilityChecks[actual.destination] = { evidence }
    }
    // ACTUAL_SESSION_MOUNT
    // ACTUAL_SESSION_PUBLIC_PRESENTATION
}

// ACTUAL_INSPECTOR_OWNER

final class FixtureClock: ActionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 1_000
    func now() -> UInt64 { lock.withLock { value } }
    func expire() { lock.withLock { value = 1_000_000_001 } }
    func sleep(until deadline: UInt64) async throws { try await Task.sleep(nanoseconds: 30_000_000_000) }
}
@MainActor final class FixtureBackend: ActionSynchronousBackendStatePort {
    var value: ActionBackendSnapshot
    init(_ id: ActionBackendID) { value = .init(backend: id, generation: 1, rpcEpoch: id == .sefariaEmbedded ? 13 : nil) }
    func snapshot() async throws -> ActionBackendSnapshot { try Task.checkCancellation(); return value }
    func currentBackendSnapshot() throws -> ActionBackendSnapshot { value }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport { .init(id: backend, operations: [:]) }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: false, supported: false, availableNow: false)
    }
}
struct FixturePorts: ActionResolverPort, ActionSearchPort {
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> { .notFound }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { .notFound }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { throw ActionPortError.notSupported }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage { throw ActionPortError.notSupported }
}
@MainActor final class FixtureSink: ActionUICommandSink {
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement { throw ActionPortError.notSupported }
}
@MainActor final class InspectorFixture {
    let sceneID = UIStableID(rawValue: "fixture-inspector-scene")!
    let manager = iOSNavigationManager(), reader = ReaderViewModel()
    let backend: FixtureBackend
    let clock = FixtureClock()
    let authority: NativeNavigationAuthority
    let lease: NativeNavigationAuthority.Lease
    let directory: NativeSceneDirectory
    let workspace: StudyWorkspaceNavigationAdapter
    let owner = MaktabahNativeWorkspaceOwner()
    let session: FixtureSceneSession
    let host: MaktabahNativePublicBindingAdapter
    let core: ActionExecutor
    let context: ActionExecutionContext
    let invocation: ActionPortInvocation
    let registry: UIDestinationRegistry
    let intent: PublicNavigationSpecV2
    var applied = 0
    init(_ id: ActionBackendID = .otzaria, origin: ActionOrigin = .deepLink, allowNavigation: Bool = true) throws {
        let appBackend = ActionAppIdentityBridge.appBackend(id)
        BackendCoordinator.shared.activeBackendID = appBackend
        let locator = TextLocator(backend: appBackend, workKey: id == .otzaria ? "book:9" : "Fixture",
            position: id == .otzaria ? .legacyLine(7) : .canonicalRef("Fixture 1:7"))
        reader.currentDestination = .init(sectionLocator: locator, focusLocator: nil)
        reader.backendSection = .init(locator: locator); reader.selectedSegmentLocator = locator
        reader.currentBook = .init(id: 9, backendLocator: locator)
        if id == .otzaria { reader.otzariaSelectedLineAnchor = .init(id: 107, bookId: 9, lineIndex: 7, heRef: nil, text: "Original", range: .init(location: 0, length: 8)) }
        let tabID = UUID(); manager.activeTabId = tabID
        manager.openTabs = [.init(id: tabID, book: reader.currentBook!, viewModel: reader)]
        let group = UUID(), profile = UUID()
        workspace = .init(manager: manager, sceneID: sceneID.rawValue,
            projection: .init(profileID: profile, groupID: group, profileIDs: [profile], groupIDs: [group],
                activeTabID: tabID, targets: [tabID: .init(backend: appBackend, bookID: 9, workKey: locator.workKey, readerOwner: ObjectIdentifier(reader))]))
        try owner.replace(with: workspace)
        backend = FixtureBackend(id)
        authority = try NativeNavigationAuthority(); lease = try authority.mount(sceneID: sceneID, foreground: true)
        directory = try NativeSceneDirectory(authority: backend, clock: clock)
        session = .init(sceneID: sceneID, directory: directory, manager: manager, workspace: workspace)
        context = .init(subjectID: "fixture.inspector", origin: origin, allowedBackends: [id],
            scopes: allowNavigation ? [.navigation, .discovery] : [.discovery], foregroundSceneID: sceneID.rawValue)
        let authority = authority, sceneID = sceneID
        try session.mount { context in
            guard try authority.navigationState(sceneID: sceneID.rawValue).context == context else { throw ActionPortError.staleState }
        }
        try session.publish(.reader, isVisible: true)
        host = try .init(sceneID: sceneID, manager: manager, workspace: workspace, workspaceOwner: owner,
            authority: authority, lease: lease, directory: directory, backend: backend,
            presentation: { [session] in try session.publicBindingPresentation() }, invalidated: {})
        _ = try authority.admit(context: context, sceneID: sceneID)
        invocation = .init(requestId: UUID(), snapshot: backend.value, deadlineUptimeNanoseconds: 1_000_000_000)
        let ports = FixturePorts()
        core = try ActionExecutor(state: backend, resolver: ports, search: ports, ui: FixtureSink(), clock: clock, navigationAuthority: authority)
        let destination = UIDestinationID(rawValue: "native.reader.inspector")!
        intent = .init(destination: destination, backend: id, presentation: .inspector)
        registry = try .init(descriptors: [.init(id: destination, title: "Original Inspector fixture", implementation: .implemented,
            supportedBackends: [id], presentations: [.inspector], requiredCoreActions: [],
            publicNavigationV2: .init(rules: [.init(presentation: .inspector)]))])
    }
    func prepare() async throws -> UIAuthorizedSceneCommand {
        let scene = try await directory.currentScene(sceneID: sceneID, context: context, invocation: invocation)
        guard case .surface(let prepared) = try await registry.bindPublicV2(intent, scene: scene, context: context,
            invocation: invocation, core: core, host: host, clock: clock) else { throw ActionPortError.invalidResponse }
        return prepared
    }
    func apply(_ prepared: UIAuthorizedSceneCommand) throws {
        session.inspectorBinding = try .init(manager: manager)
        session.command = prepared.command
        let current = try directory.synchronousScene(sceneID: sceneID, context: context, backend: backend.value)
        try prepared.authorizeCommit(current: current)
        try session.inspectorBinding!.apply(); applied += 1
    }
    func publishInspector(readerVisible: Bool = true, inspectorVisible: Bool = true, scene: UIStableID? = nil, submission: UUID? = nil) throws {
        try session.publish(.reader, isVisible: readerVisible)
        try session.publish(.inspector, isVisible: inspectorVisible, scene: scene, submission: submission)
    }
    func complete(_ prepared: UIAuthorizedSceneCommand) throws {
        guard let actual = try session.surface(.inspector) else { throw ActionPortError.unavailable }
        let observed = try directory.synchronousScene(sceneID: sceneID, context: context, backend: backend.value)
        let route = actual.observedRoute(for: prepared.command, backend: backend.value)
        let receipt = UISceneReceipt(requestId: invocation.requestId, route: route, backendSnapshot: backend.value,
            sceneID: sceneID, basedOnSceneRevision: prepared.command.scene.revision, appliedSceneRevision: observed.revision)
        try prepared.validateCompletion(receipt: receipt, observed: observed)
    }
}
