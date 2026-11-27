import Foundation
import Observation
import Synchronization

// Explicit executable source boundary. These values stand for the existing
// SwiftUI/UIKit/app feature owners. They are NOT an app, React runtime, native
// witness, Core authority or acceptance receipt. The generator inserts exact
// production root/latch/setter/readiness/wait bodies beside these inputs.
struct UIDestinationID: RawRepresentable, Equatable, Hashable, Sendable {
    let rawValue: String
    init?(rawValue: String) { self.rawValue = rawValue }
}
struct UIStableID: RawRepresentable, Equatable, Hashable, Sendable {
    let rawValue: String
    init?(rawValue: String) { self.rawValue = rawValue }
}
struct UIRouteError: Error {
    enum Status { case unavailable, staleState, failed, notSupported }
    let status: Status
    let reason: String
    init(_ status: Status, _ reason: String) { self.status = status; self.reason = reason }
}
enum AppMode { case viewer, search, history, annotations }
enum iOSTab: Equatable {
    case viewer, search, history, annotations
    var canonical: Self { self }
    var appMode: AppMode {
        switch self { case .viewer: .viewer; case .search: .search; case .history: .history; case .annotations: .annotations }
    }
}
@MainActor final class BooksData {}
@MainActor @Observable final class ReaderViewModel { var isPopoverPresented = false }
@MainActor @Observable final class DonationManager {
    static let shared = DonationManager()
    var showDonationSheet = false
}
@MainActor @Observable final class BoundaryOverview { var blocksRouting = false }
@MainActor final class ReaderSidebarPageCoordinator { let overview = BoundaryOverview() }
struct Transaction { var marker = 0 }
@MainActor struct Binding<Value> {
    private let read: () -> Value
    private let write: (Value, Transaction) -> Void
    private var suppliedTransaction = Transaction()
    init(get: @escaping () -> Value, set: @escaping (Value, Transaction) -> Void) { read = get; write = set }
    var wrappedValue: Value {
        get { read() }
        nonmutating set { write(newValue, suppliedTransaction) }
    }
    func transaction(_ transaction: Transaction) -> Self {
        var copy = self; copy.suppliedTransaction = transaction; return copy
    }
}
@MainActor final class OriginalRootState {
    var tab = iOSTab.viewer
    var settings = false
    var lastTransaction = Transaction()
}
@MainActor final class BoundaryNoteEditorOwner {
    var current: String?
    var presentationActive = false
}

struct NativeSurfaceState: Equatable, Sendable {
    let destination: UIDestinationID
    let stamp: Int
}
struct BoundaryInvocation: Sendable { let requestId: UUID }
struct BoundaryRoute: Sendable { let destination: UIDestinationID }
struct BoundaryValidatedRoute: Sendable { let route: BoundaryRoute }
struct UISceneCommand: Sendable {
    let invocation: BoundaryInvocation
    let route: BoundaryValidatedRoute
    init(request: UUID, destination: UIDestinationID) {
        invocation = .init(requestId: request); route = .init(route: .init(destination: destination))
    }
}
enum NativeSurfaceWitness {
    struct Evidence: Sendable {
        let sceneID: UIStableID
        let submissionID: UUID?
        let surface: NativeSurfaceState
        let isVisible: Bool
    }
}

/// A controlled asynchronous input, not a timer or a fabricated native result.
/// The test cannot complete it without an explicit resume or cancellation.
@MainActor final class BoundarySuspension {
    private(set) var started = false
    private(set) var cancelled = false
    private var continuation: CheckedContinuation<Void, any Error>?
    private var startup: CheckedContinuation<Void, Never>?
    func untilStarted() async {
        if started { return }
        await withCheckedContinuation { startup = $0 }
    }
    func wait() async throws {
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { value in
                continuation = value; started = true
                let prior = startup; startup = nil; prior?.resume()
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }
    func succeed() { let value = continuation; continuation = nil; value?.resume() }
    func fail() {
        let value = continuation; continuation = nil
        value?.resume(throwing: UIRouteError(.staleState, "controlled-original-source-invalidation"))
    }
    func cancel() {
        cancelled = true
        let value = continuation; continuation = nil; value?.resume(throwing: CancellationError())
    }
}
@MainActor final class MaktabahNativeSefariaSurfaceBinding {
    static let destination = UIDestinationID(rawValue: "native.sefariaEmbedded")!
    struct PresentationFacets {
        var requested = false, mounted = false, visible = false, transitioning = false, ready = false
    }
    var isAvailable = true
    var presentationFacets = PresentationFacets()
    var continuingRequest: UUID?
    let originalWait = BoundarySuspension()
    private(set) var awaitCalls = 0
    func isContinuingAppliedRequest(requestID: UUID) -> Bool { continuingRequest == requestID }
    func awaitOriginalSurface(requestID: UUID) async throws {
        awaitCalls += 1
        try await originalWait.wait()
    }
}
@MainActor final class BoundaryWindowSource {
    var ready = true
    func isPresentationReady(in sceneID: UIStableID) -> Bool { ready }
}
@MainActor final class BoundaryPresentation {
    struct Observed { let surface: NativeSurfaceState }
    let markerWait = BoundarySuspension()
    private(set) var waitCalls = 0
    private(set) var reportCalls = 0
    private var observed: NativeSurfaceState?
    func report(_ state: NativeSurfaceState) {
        reportCalls += 1; observed = state; markerWait.succeed()
    }
    func wait(for command: UISceneCommand) async throws -> Observed {
        waitCalls += 1
        if observed == nil { try await markerWait.wait() }
        guard let observed else { throw UIRouteError(.unavailable, "controlled-marker-absent") }
        return .init(surface: observed)
    }
}

@MainActor @Observable final class iOSNavigationManager {
    var currentMode: AppMode = .viewer {
        willSet {
            // Observe every original mode publication, including equal writes.
            // This metadata neither selects a mode nor replaces TabView's owner.
            if let revision = nativeModePresentationRevision, revision < .max {
                nativeModePresentationRevision = revision + 1
            } else {
                nativeModePresentationRevision = nil
            }
        }
    }
    private(set) var nativeModePresentationRevision: UInt64? = 0
    var selectedBook: BooksData? {
        willSet {
            // Original presentation ownership metadata. Every setter, including
            // an equal-value write, advances; exhaustion can never recycle it.
            if let revision = selectedBookPresentationRevision, revision < .max {
                selectedBookPresentationRevision = revision + 1
            } else {
                selectedBookPresentationRevision = nil
            }
        }
        didSet { selectedBookPresentationMode = selectedBook.map { _ in currentMode } }
    }
    private(set) var selectedBookPresentationRevision: UInt64? = 0
    private(set) var selectedBookPresentationMode: AppMode?

    var selectedBookForInfo: BooksData?
    var showingTabsList = false
    var activeReaderViewModel: ReaderViewModel? = ReaderViewModel()
    init(modeSeed: UInt64? = 0, bookSeed: UInt64? = 0) {
        nativeModePresentationRevision = modeSeed
        selectedBookPresentationRevision = bookSeed
    }
}
@MainActor @Observable final class MaktabahNativeWorkspacePresentationBinding {
    private(set) var originalStateRevision: UInt64? = 0
    private func advanceOriginalStateRevision() {
        guard let value = originalStateRevision else { return }
        originalStateRevision = value < .max ? value + 1 : nil
    }
    init(seed: UInt64? = 0) { originalStateRevision = seed }
    // The genuine setter/sidebar call sites have their own peer controls. This
    // explicit boundary calls the exact source-owned advance method only.
    func publishOriginalState() { advanceOriginalStateRevision() }
    func publishGeometryOnly() {}
}
@MainActor struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let selectedTab: Binding<iOSTab>
    let showSettings: Binding<Bool>
    let sidebar: ReaderSidebarPageCoordinator?
    let rootPublications: MaktabahNativeRootPublicationSource?
    var isPresentationReady: Bool {
        !DonationManager.shared.showDonationSheet && manager.selectedBookForInfo == nil
            && !manager.showingTabsList && manager.activeReaderViewModel?.isPopoverPresented != true
            && sidebar?.overview.blocksRouting != true
    }
}

/// A one-shot cancellation witness over ORIGINAL observable source reads.
/// Restoring the same values cannot restore a captured request. This is not a
/// source cache or an authority; the original identity/generation checks remain.
public final class NativeComponentSourceObservation: Sendable {
    private let invalidated = Mutex(false)

    @MainActor
    public init(read: @MainActor () -> Void) {
        withObservationTracking {
            read()
        } onChange: { [weak self] in
            // Observation fires at willSet. Do not enqueue a Task: a complete
            // A -> B -> A edit can happen before a MainActor task resumes.
            self?.invalidate()
        }
    }

    /// Original non-Observation publishers may revoke this same latch. There is
    /// deliberately no reset, rearm or setter that can make a request live again.
    public func invalidate() {
        invalidated.withLock { $0 = true }
    }

    public func validate() throws {
        guard !invalidated.withLock({ $0 }) else {
            throw UIRouteError(.staleState, "native_component_source_changed")
        }
    }
}
@MainActor
final class MaktabahNativeRootPublicationSource {
    private(set) var selectionRevision: UInt64? = 0
    private(set) var settingsRevision: UInt64? = 0

    func selectionBinding(_ original: Binding<iOSTab>) -> Binding<iOSTab> {
        Binding(get: { original.wrappedValue }, set: { [self] value, transaction in
            selectionRevision = Self.advanced(selectionRevision)
            original.transaction(transaction).wrappedValue = value
        })
    }
    func settingsBinding(_ original: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { original.wrappedValue }, set: { [self] value, transaction in
            settingsRevision = Self.advanced(settingsRevision)
            original.transaction(transaction).wrappedValue = value
        })
    }
    private static func advanced(_ revision: UInt64?) -> UInt64? {
        guard let revision, revision < .max else { return nil }
        return revision + 1
    }
}
@MainActor private final class MaktabahNativeSefariaRootSource {
    private let observation: NativeComponentSourceObservation
    private let managerID: ObjectIdentifier
    private let root: MaktabahNativeRootPublicationSource
    private weak var workspacePresentation: MaktabahNativeWorkspacePresentationBinding?
    private let workspaceRevision: UInt64
    private let selectionRevision: UInt64
    private let settingsRevision: UInt64
    private let modeRevision: UInt64
    private let bookRevision: UInt64
    private let tab: iOSTab
    private let mode: AppMode
    private let bookID: ObjectIdentifier?
    private let bookMode: AppMode?

    static func isAvailable(_ bindings: MaktabahNativeSceneBindings,
                            workspace: MaktabahNativeWorkspacePresentationBinding?) -> Bool {
        bindings.rootPublications?.selectionRevision != nil
            && bindings.rootPublications?.settingsRevision != nil
            && bindings.manager.nativeModePresentationRevision != nil
            && bindings.manager.selectedBookPresentationRevision != nil
            && workspace?.originalStateRevision != nil
            && bindings.selectedTab.wrappedValue == bindings.selectedTab.wrappedValue.canonical
            && bindings.manager.currentMode == bindings.selectedTab.wrappedValue.appMode
            && !bindings.showSettings.wrappedValue && bindings.isPresentationReady
    }

    init(bindings: MaktabahNativeSceneBindings,
         workspace: MaktabahNativeWorkspacePresentationBinding,
         readForeignPresentations: @MainActor () -> Void) throws {
        let manager = bindings.manager
        observation = NativeComponentSourceObservation {
            _ = manager.currentMode; _ = manager.selectedBook; _ = manager.selectedBookPresentationMode
            _ = manager.selectedBookForInfo; _ = manager.showingTabsList
            _ = manager.activeReaderViewModel?.isPopoverPresented
            _ = DonationManager.shared.showDonationSheet
            _ = bindings.sidebar?.overview.blocksRouting
            _ = workspace.originalStateRevision
            readForeignPresentations()
        }
        guard Self.isAvailable(bindings, workspace: workspace),
              let root = bindings.rootPublications,
              let selection = root.selectionRevision, let settings = root.settingsRevision,
              let mode = manager.nativeModePresentationRevision,
              let book = manager.selectedBookPresentationRevision,
              let workspaceRevision = workspace.originalStateRevision else {
            throw UIRouteError(.unavailable, "native_sefaria_original_root_unavailable")
        }
        self.root = root; managerID = ObjectIdentifier(manager)
        workspacePresentation = workspace; self.workspaceRevision = workspaceRevision
        selectionRevision = selection; settingsRevision = settings
        modeRevision = mode; bookRevision = book
        tab = bindings.selectedTab.wrappedValue; self.mode = manager.currentMode
        bookID = manager.selectedBook.map(ObjectIdentifier.init)
        bookMode = manager.selectedBookPresentationMode
        try validate(bindings, workspace: workspace)
    }

    func validate(_ bindings: MaktabahNativeSceneBindings,
                  workspace: MaktabahNativeWorkspacePresentationBinding?) throws {
        try observation.validate()
        let manager = bindings.manager
        guard ObjectIdentifier(manager) == managerID, bindings.rootPublications === root,
              let workspace, workspacePresentation === workspace,
              workspace.originalStateRevision == workspaceRevision,
              root.selectionRevision == selectionRevision, root.settingsRevision == settingsRevision,
              manager.nativeModePresentationRevision == modeRevision,
              manager.selectedBookPresentationRevision == bookRevision,
              bindings.selectedTab.wrappedValue == tab, manager.currentMode == mode,
              manager.selectedBook.map(ObjectIdentifier.init) == bookID,
              manager.selectedBookPresentationMode == bookMode,
              !bindings.showSettings.wrappedValue, bindings.isPresentationReady else {
            throw UIRouteError(.staleState, "native_sefaria_original_root_changed")
        }
    }
    func invalidate() { observation.invalidate() }
}

// Boundary-only exhaustion seeds. No production setter/API is added or reset.
extension MaktabahNativeRootPublicationSource {
    func seedForControls(selection: UInt64?, settings: UInt64?) {
        selectionRevision = selection; settingsRevision = settings
    }
}
@MainActor @Observable private final class Harness {
    let bindings: MaktabahNativeSceneBindings
    let state: OriginalRootState
    let root: MaktabahNativeRootPublicationSource
    var workspacePresentation: MaktabahNativeWorkspacePresentationBinding?
    let sceneID = UIStableID(rawValue: "original-source-scene")!
    var mounted = true
    var foreground = true
    var hasOriginalWorkspacePresentation = false
    var studyChatPresentationID: UUID?
    var noteEditorOwner: BoundaryNoteEditorOwner? = BoundaryNoteEditorOwner()
    var sefariaSurfaceBinding: MaktabahNativeSefariaSurfaceBinding? = MaktabahNativeSefariaSurfaceBinding()
    var windowSource: BoundaryWindowSource? = BoundaryWindowSource()
    var submissionID: UUID?
    var command: UISceneCommand?
    var retainedSefariaSurface = true
    var retainedComponentOwner: Bool?
    var visibilityChecks: [UIDestinationID: @MainActor () -> NativeSurfaceWitness.Evidence?] = [:]
    let presentation = BoundaryPresentation()
    var captured: MaktabahNativeSefariaRootSource?
    var markerVisible = false
    var markerChecks = 0
    var validations = 0
    let expectedSurface = NativeSurfaceState(destination: MaktabahNativeSefariaSurfaceBinding.destination, stamp: 47)

    init(selection: UInt64? = 0, settings: UInt64? = 0,
         mode: UInt64? = 0, book: UInt64? = 0, workspace: UInt64? = 0) {
        DonationManager.shared.showDonationSheet = false
        let state = OriginalRootState(), root = MaktabahNativeRootPublicationSource()
        root.seedForControls(selection: selection, settings: settings)
        self.state = state; self.root = root
        let tab = Binding(get: { state.tab }, set: { state.tab = $0; state.lastTransaction = $1 })
        let sheet = Binding(get: { state.settings }, set: { state.settings = $0; state.lastTransaction = $1 })
        bindings = .init(manager: .init(modeSeed: mode, bookSeed: book),
                         selectedTab: root.selectionBinding(tab), showSettings: root.settingsBinding(sheet),
                         sidebar: ReaderSidebarPageCoordinator(), rootPublications: root)
        workspacePresentation = .init(seed: workspace)
        let request = UUID()
        submissionID = request
        command = .init(request: request, destination: MaktabahNativeSefariaSurfaceBinding.destination)
        visibilityChecks[MaktabahNativeSefariaSurfaceBinding.destination] = { [weak self] in
            guard let self else { return nil }
            markerChecks += 1
            return markerVisible ? .init(sceneID: sceneID, submissionID: submissionID,
                surface: expectedSurface, isVisible: true) : nil
        }
    }
    func capture() throws -> MaktabahNativeSefariaRootSource {
        try MaktabahNativeSefariaRootSource(bindings: bindings, workspace: workspacePresentation!) { [weak self] in
            guard let self else { return }
            _ = mounted; _ = foreground; _ = studyChatPresentationID
            _ = noteEditorOwner?.current; _ = noteEditorOwner?.presentationActive
        }
    }
    func validateSurface(_ command: UISceneCommand) throws {
        validations += 1
        guard mounted, foreground, let captured else { throw UIRouteError(.unavailable, "controlled-source-absent") }
        try captured.validate(bindings, workspace: workspacePresentation)
    }
    func observe(_ evidence: NativeSurfaceWitness.Evidence) {
        // This is the named test input at the view boundary, not the product's
        // final source-locked ACK method or a native acceptance claim.
        if evidence.isVisible { presentation.report(evidence.surface) }
    }
    private var isSefariaOriginalRootReady: Bool {
        mounted && foreground && !bindings.showSettings.wrappedValue && bindings.isPresentationReady
            && !hasOriginalWorkspacePresentation && studyChatPresentationID == nil
            && noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true
            && MaktabahNativeSefariaRootSource.isAvailable(bindings, workspace: workspacePresentation)
    }
    func isPresentationReady(for destination: UIDestinationID) -> Bool {
        if destination == MaktabahNativeSefariaSurfaceBinding.destination {
            guard isSefariaOriginalRootReady, let original = sefariaSurfaceBinding,
                  original.isAvailable else { return false }
            let actual = original.presentationFacets
            if let requestID = submissionID, command?.invocation.requestId == requestID,
               command?.route.route.destination == destination,
               original.isContinuingAppliedRequest(requestID: requestID) {
                return true
            }
            if actual.requested || actual.mounted || actual.transitioning {
                return actual.requested && actual.mounted && actual.visible && !actual.transitioning
            }
            // Only a cold request uses the original root window. A stable own
            // sheet supplies its exact host; unrelated modal transitions block.
            return windowSource?.isPresentationReady(in: sceneID) == true
        }
        return false // Other routes are outside this boundary.
    }
    func waitUntilVisible(_ command: UISceneCommand) async throws -> NativeSurfaceState {
        if command.route.route.destination == MaktabahNativeSefariaSurfaceBinding.destination {
            guard retainedSefariaSurface, let original = sefariaSurfaceBinding,
                  submissionID == command.invocation.requestId else {
                throw UIRouteError(.staleState, "native_sefaria_wait_not_owned")
            }
            try validateSurface(command)
            // This awaits the original RPC/host children inside the existing
            // orchestrator deadline. No detached task, new grant or new timer
            // extends that admission. Cancellation joins the original child.
            try await original.awaitOriginalSurface(requestID: command.invocation.requestId)
            try Task.checkCancellation()
            try validateSurface(command)
            if let actual = visibilityChecks[command.route.route.destination]?() { observe(actual) }
        }
        #if DEBUG
        if command.route.route.destination.rawValue == "native.reader.noteDraft" {
            diagnoseNoteDraftSurface(stage: "wait-begin")
        }
        #endif
        // A container's deduplicated layout callback can precede final geometry
        // or TextKit paint/scroll restoration. Observe the same live UIKit
        // witness only while its original request is waiting; never echo the route.
        let readerObservation: Task<Void, Never>?
        if retainedComponentOwner != nil || ["native.reader", "native.reader.noteDraft", "native.library", "native.reader.toc", "native.annotations",
                                             "native.workspace.profiles", "native.workspace.overview", "native.sefariaEmbedded"].contains(command.route.route.destination.rawValue) {
            readerObservation = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    guard let self, mounted, submissionID == command.invocation.requestId else { return }
                    if let actual = visibilityChecks[command.route.route.destination]?() { observe(actual) }
                    do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
                }
            }
        } else { readerObservation = nil }
        defer { readerObservation?.cancel() }
        do { return try await presentation.wait(for: command).surface }
        catch {
            #if DEBUG
            OtzariaFileLogger.shared.log("[NativePresentationWait] code=\((error as? UIRouteError)?.code ?? (error is CancellationError ? "cancelled" : "unavailable")) mounted=\(mounted) foreground=\(foreground) ready=\(isPresentationReady)")
            if command.route.route.destination.rawValue == "native.reader.noteDraft" {
                diagnoseNoteDraftSurface(stage: "wait-error")
            }
            #endif
            throw error
        }
    }
}
private struct ControlFailure: Error, CustomStringConvertible {
    let description: String
    init(_ value: String) { description = value }
}
@MainActor private func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw ControlFailure(message) }
}
@MainActor private func rejects(_ operation: () throws -> Void) throws {
    do { try operation() }
    catch { return }
    throw ControlFailure("retained source was accepted after invalidation")
}
@MainActor private func rejectsAsync(_ operation: () async throws -> Void) async throws {
    do { try await operation() }
    catch { return }
    throw ControlFailure("operation completed despite the refused original input")
}

@MainActor private final class Runner {
    var passed = 0, failed = 0
    func check(_ name: String, _ body: () throws -> Void) {
        do { try body(); passed += 1; print("PASS \(name)") }
        catch { failed += 1; print("FAIL \(name): \(error)") }
    }
    func checkAsync(_ name: String, _ body: () async throws -> Void) async {
        do { try await body(); passed += 1; print("PASS \(name)") }
        catch { failed += 1; print("FAIL \(name): \(error)") }
    }
    func run() async -> Int32 {
        check("root capture preserves all original +0 owners") {
            let h = Harness(), source = try h.capture()
            try source.validate(h.bindings, workspace: h.workspacePresentation)
            try require(h.root.selectionRevision == 0 && h.root.settingsRevision == 0, "root changed")
            try require(h.bindings.manager.nativeModePresentationRevision == 0, "mode changed")
            try require(h.bindings.manager.selectedBookPresentationRevision == 0, "book changed")
            try require(h.workspacePresentation?.originalStateRevision == 0, "Workspace changed")
        }
        check("selectedTab A-B-A before original mode publication revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.selectedTab.wrappedValue = .history; h.bindings.selectedTab.wrappedValue = .viewer
            try require(h.bindings.manager.nativeModePresentationRevision == 0, "test must precede mode publisher")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("equal original selectedTab write revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.selectedTab.wrappedValue = .viewer
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("Settings false-true-false before view mount revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.showSettings.wrappedValue = true; h.bindings.showSettings.wrappedValue = false
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("equal original Settings false write revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.showSettings.wrappedValue = false
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("last finite selection revision permits zero writes then exhausts") {
            let h = Harness(selection: .max), source = try h.capture()
            try source.validate(h.bindings, workspace: h.workspacePresentation)
            h.bindings.selectedTab.wrappedValue = .viewer
            try require(h.root.selectionRevision == nil, "counter wrapped")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("exhausted Settings revision never re-arms") {
            let h = Harness(settings: .max), source = try h.capture()
            h.bindings.showSettings.wrappedValue = false; h.bindings.showSettings.wrappedValue = false
            try require(h.root.settingsRevision == nil, "counter re-armed")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original mode A-B-A revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.manager.currentMode = .history; h.bindings.manager.currentMode = .viewer
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("equal original mode publication revokes") {
            let h = Harness(), source = try h.capture()
            h.bindings.manager.currentMode = .viewer
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original mode exhaustion fails closed") {
            let h = Harness(mode: .max), source = try h.capture()
            h.bindings.manager.currentMode = .viewer
            try require(h.bindings.manager.nativeModePresentationRevision == nil, "mode wrapped")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original selectedBook A-B-A revokes") {
            let h = Harness(), a = BooksData(), b = BooksData()
            h.bindings.manager.selectedBook = a
            let source = try h.capture()
            h.bindings.manager.selectedBook = b; h.bindings.manager.selectedBook = a
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("same original selectedBook assignment revokes") {
            let h = Harness(), a = BooksData(); h.bindings.manager.selectedBook = a
            let source = try h.capture(); h.bindings.manager.selectedBook = a
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original book exhaustion fails closed") {
            let h = Harness(book: .max), source = try h.capture()
            h.bindings.manager.selectedBook = nil
            try require(h.bindings.manager.selectedBookPresentationRevision == nil, "book wrapped")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("foreign Workspace local State A-B-A revokes") {
            let h = Harness(), source = try h.capture()
            h.workspacePresentation?.publishOriginalState(); h.workspacePresentation?.publishOriginalState()
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("foreign Workspace exhausted publication never re-arms") {
            let h = Harness(workspace: .max), source = try h.capture()
            h.workspacePresentation?.publishOriginalState(); h.workspacePresentation?.publishOriginalState()
            try require(h.workspacePresentation?.originalStateRevision == nil, "Workspace counter re-armed")
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original geometry alone does not change Workspace State source") {
            let h = Harness(), source = try h.capture()
            h.workspacePresentation?.publishGeometryOnly()
            try source.validate(h.bindings, workspace: h.workspacePresentation)
        }
        check("replaced Workspace state owner with same counter is refused") {
            let h = Harness(), source = try h.capture()
            h.workspacePresentation = MaktabahNativeWorkspacePresentationBinding()
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("missing original source counters refuse capture") {
            for h in [Harness(selection: nil), Harness(settings: nil), Harness(mode: nil), Harness(book: nil), Harness(workspace: nil)] {
                try rejects { _ = try h.capture() }
            }
        }
        check("replaced root publication object with equal values is refused") {
            let h = Harness(), source = try h.capture(), replacement = MaktabahNativeRootPublicationSource()
            let b = MaktabahNativeSceneBindings(manager: h.bindings.manager,
                selectedTab: h.bindings.selectedTab, showSettings: h.bindings.showSettings,
                sidebar: h.bindings.sidebar, rootPublications: replacement)
            try rejects { try source.validate(b, workspace: h.workspacePresentation) }
        }
        check("replaced original manager with equal values is refused") {
            let h = Harness(), source = try h.capture()
            let b = MaktabahNativeSceneBindings(manager: iOSNavigationManager(),
                selectedTab: h.bindings.selectedTab, showSettings: h.bindings.showSettings,
                sidebar: h.bindings.sidebar, rootPublications: h.root)
            try rejects { try source.validate(b, workspace: h.workspacePresentation) }
        }
        check("Donation modal A-B-A consumes original observation") {
            let h = Harness(), source = try h.capture()
            DonationManager.shared.showDonationSheet = true; DonationManager.shared.showDonationSheet = false
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original Reader popover A-B-A consumes observation") {
            let h = Harness(), source = try h.capture()
            h.bindings.manager.activeReaderViewModel?.isPopoverPresented = true
            h.bindings.manager.activeReaderViewModel?.isPopoverPresented = false
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("original Sidebar blocker A-B-A consumes observation") {
            let h = Harness(), source = try h.capture()
            h.bindings.sidebar?.overview.blocksRouting = true; h.bindings.sidebar?.overview.blocksRouting = false
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("background-foreground does not renew original source") {
            let h = Harness(), source = try h.capture()
            h.foreground = false; h.foreground = true
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("foreign note editor presentation A-B-A consumes observation") {
            let h = Harness(), source = try h.capture()
            h.noteEditorOwner?.presentationActive = true; h.noteEditorOwner?.presentationActive = false
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }
        check("native window owner invalidation cannot be rearmed") {
            let h = Harness(), source = try h.capture(); source.invalidate()
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
            try rejects { try source.validate(h.bindings, workspace: h.workspacePresentation) }
        }

        let destination = MaktabahNativeSefariaSurfaceBinding.destination
        check("cold RN requires actual original ready window") {
            let h = Harness()
            try require(h.isPresentationReady(for: destination), "initial root refused")
            h.windowSource?.ready = false
            try require(!h.isPresentationReady(for: destination), "foreign transition accepted")
        }
        check("cold RN does not substitute a missing window owner") {
            let h = Harness(); h.windowSource = nil
            try require(!h.isPresentationReady(for: destination), "missing original window accepted")
        }
        check("cold RN cannot use unavailable original runtime/backend") {
            let h = Harness(); h.sefariaSurfaceBinding?.isAvailable = false
            try require(!h.isPresentationReady(for: destination), "unavailable feature accepted")
        }
        check("Settings remains blocking without dismissal") {
            let h = Harness(); h.bindings.showSettings.wrappedValue = true
            try require(!h.isPresentationReady(for: destination), "Settings was bypassed")
            try require(h.state.settings, "Settings was dismissed")
        }
        check("foreign Workspace presentation remains blocking") {
            let h = Harness(); h.hasOriginalWorkspacePresentation = true
            try require(!h.isPresentationReady(for: destination), "Workspace modal was bypassed")
        }
        check("own applied continuation can await only its same transition") {
            let h = Harness(); h.windowSource?.ready = false
            h.sefariaSurfaceBinding?.presentationFacets = .init(requested: true, mounted: false, visible: false, transitioning: true, ready: false)
            h.sefariaSurfaceBinding?.continuingRequest = h.submissionID
            try require(h.isPresentationReady(for: destination), "same admitted transition refused")
            h.sefariaSurfaceBinding?.continuingRequest = UUID()
            try require(!h.isPresentationReady(for: destination), "foreign continuation accepted")
        }
        check("own continuation cannot bypass foreign Settings") {
            let h = Harness(); h.bindings.showSettings.wrappedValue = true
            h.sefariaSurfaceBinding?.continuingRequest = h.submissionID
            try require(!h.isPresentationReady(for: destination), "own request covered foreign Settings")
        }
        check("pending requested sheet without actual mount is not fresh readiness") {
            let h = Harness(); h.sefariaSurfaceBinding?.presentationFacets.requested = true
            try require(!h.isPresentationReady(for: destination), "request alone accepted")
        }
        check("warm original sheet requires stable real host facets") {
            let h = Harness(); h.windowSource?.ready = false
            h.sefariaSurfaceBinding?.presentationFacets = .init(requested: true, mounted: true, visible: true, transitioning: false, ready: true)
            try require(h.isPresentationReady(for: destination), "stable own sheet refused")
            h.sefariaSurfaceBinding?.presentationFacets.visible = false
            try require(!h.isPresentationReady(for: destination), "hidden own sheet accepted")
        }
        check("foreign foreground lifetime and ended command cannot continue") {
            let h = Harness(); h.sefariaSurfaceBinding?.continuingRequest = h.submissionID
            h.sefariaSurfaceBinding?.presentationFacets.transitioning = true
            h.command = nil
            try require(!h.isPresentationReady(for: destination), "ended command continued")
            h.foreground = false
            try require(!h.isPresentationReady(for: destination), "background accepted")
        }

        await checkAsync("structured RN wait cannot inspect or report marker before original child drains") {
            let h = Harness(); h.captured = try h.capture(); h.markerVisible = true
            let original = h.sefariaSurfaceBinding!, command = h.command!
            let task = Task { @MainActor in try await h.waitUntilVisible(command) }
            await original.originalWait.untilStarted()
            try require(h.markerChecks == 0 && h.presentation.waitCalls == 0, "marker read before original RPC proof")
            original.originalWait.succeed()
            let result = try await task.value
            try require(result == h.expectedSurface, "observed state changed")
            try require(original.awaitCalls == 1 && h.presentation.reportCalls > 0, "new wait or missing marker")
        }
        await checkAsync("cancelled original RN child joins before shared wait returns") {
            let h = Harness(); h.captured = try h.capture(); h.markerVisible = true
            let original = h.sefariaSurfaceBinding!, command = h.command!
            let task = Task { @MainActor in try await h.waitUntilVisible(command) }
            await original.originalWait.untilStarted(); task.cancel()
            try await rejectsAsync { _ = try await task.value }
            try require(original.originalWait.cancelled, "child not drained")
            try require(h.presentation.reportCalls == 0 && h.presentation.waitCalls == 0, "cancelled child produced observation")
        }
        await checkAsync("original RN invalidation stops before marker observation") {
            let h = Harness(); h.captured = try h.capture(); h.markerVisible = true
            let original = h.sefariaSurfaceBinding!, command = h.command!
            let task = Task { @MainActor in try await h.waitUntilVisible(command) }
            await original.originalWait.untilStarted(); original.originalWait.fail()
            try await rejectsAsync { _ = try await task.value }
            try require(h.markerChecks == 0 && h.presentation.reportCalls == 0, "invalidated proof reached marker")
        }
        await checkAsync("Settings ABA during original RN wait is checked again before marker") {
            let h = Harness(); h.captured = try h.capture(); h.markerVisible = true
            let original = h.sefariaSurfaceBinding!, command = h.command!
            let task = Task { @MainActor in try await h.waitUntilVisible(command) }
            await original.originalWait.untilStarted()
            h.bindings.showSettings.wrappedValue = true; h.bindings.showSettings.wrappedValue = false
            original.originalWait.succeed()
            try await rejectsAsync { _ = try await task.value }
            try require(h.markerChecks == 0 && h.presentation.reportCalls == 0, "stale root reached marker")
        }
        await checkAsync("RN source proof alone cannot replace missing native marker") {
            let h = Harness(); h.captured = try h.capture()
            let original = h.sefariaSurfaceBinding!, command = h.command!
            let task = Task { @MainActor in try await h.waitUntilVisible(command) }
            await original.originalWait.untilStarted(); original.originalWait.succeed()
            await h.presentation.markerWait.untilStarted()
            try require(h.presentation.reportCalls == 0, "proof fabricated visible marker")
            task.cancel()
            try await rejectsAsync { _ = try await task.value }
            try require(h.presentation.markerWait.cancelled, "native wait not drained")
        }
        await checkAsync("different submission cannot start original RN child") {
            let h = Harness(); h.captured = try h.capture(); let original = h.sefariaSurfaceBinding!
            let foreign = UISceneCommand(request: UUID(), destination: destination)
            try await rejectsAsync { _ = try await h.waitUntilVisible(foreign) }
            try require(original.awaitCalls == 0, "foreign submission started RPC")
        }
        print("RESULT \(passed) PASS / \(failed) FAIL")
        return failed == 0 ? 0 : 1
    }
}
@main private enum Controls {
    static func main() async { exit(await Runner().run()) }
}
