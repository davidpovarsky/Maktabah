import Foundation
import Observation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// Explicit Apple/app-domain boundaries. The compiled owner, window-source,
// root setter, mode setter and Session attachment methods are extracted byte-
// exactly from the pinned production/candidate sources by the input manifest.
// UIKit appearance/geometry itself is NOT exercised by these controls.
enum AppMode: Equatable { case viewer, history, search }
enum iOSTab: Equatable {
    case viewer, history, search
    var canonical: iOSTab { self }
    var appMode: AppMode { switch self { case .viewer: .viewer; case .history: .history; case .search: .search } }
}
final class BooksData {}
@MainActor struct Binding<T> {
    let get: () -> T
    let set: (T, Int) -> Void
    init(get: @escaping () -> T, set: @escaping (T, Int) -> Void) { self.get = get; self.set = set }
    var wrappedValue: T { get { get() } nonmutating set { set(newValue, 0) } }
    func transaction(_ value: Int) -> Binding<T> { self }
}
@MainActor final class WindowSession { let persistentIdentifier = "scene.A" }
@MainActor final class WindowScene {
    enum State { case foregroundActive, background }
    let session = WindowSession()
    var activationState = State.foregroundActive
}
@MainActor class UIView { weak var window: UIWindow? }
@MainActor class UIViewController {
    var viewIfLoaded: UIView?
    var presentedViewController: UIViewController?
    var isBeingPresented = false, isBeingDismissed = false
    var transitionCoordinator: UUID?
    var children: [UIViewController] = []
}
@MainActor final class UIWindow {
    var windowScene: WindowScene? = WindowScene()
    var isKeyWindow = true, isHidden = false, alpha = 1.0
    var rootViewController: UIViewController?
}
@MainActor final class MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let rootPublications: MaktabahNativeRootPublicationSource?
    let selectedTab: Binding<iOSTab>
    let showSettings: Binding<Bool>
    init(manager: iOSNavigationManager, root: MaktabahNativeRootPublicationSource,
         selectedTab: Binding<iOSTab>, showSettings: Binding<Bool>) {
        self.manager = manager; rootPublications = root
        self.selectedTab = root.selectionBinding(selectedTab); self.showSettings = root.settingsBinding(showSettings)
    }
}
@MainActor enum MaktabahNativeViewerParentWitness {
    final class Controller {
        let identity = UUID()
        var window: UIWindow?
        var visible = true
        func currentOriginalWindow(in sceneID: UIStableID) -> UIWindow? { visible ? window : nil }
    }
}

@MainActor final class MaktabahNativeWindowSource {
    private weak var source: UIView?
    private weak var window: UIWindow?
    private var observationRevision: UInt64? = 0

    @discardableResult
    func observe(_ window: UIWindow?, from source: UIView) -> Bool {
        if window == nil {
            guard self.source === source else { return false }
            self.source = nil; self.window = nil
            advanceObservation()
            return true
        }
        guard self.source !== source || self.window !== window else { return false }
        self.source = source; self.window = window
        advanceObservation()
        return true
    }

    private func advanceObservation() {
        guard let revision = observationRevision, revision < .max else {
            observationRevision = nil; return
        }
        observationRevision = revision + 1
    }

    /// Retain identity before foreground/layout awaits. Actual presentation
    /// readiness remains the independent unchanged original predicate below.
    func retainOriginalWindow(in sceneID: UIStableID,
                              isCurrentSource: @escaping @MainActor () -> Bool) throws -> MaktabahNativeWindowObservation {
        guard let originalSource = source, let originalWindow = window,
              let revision = observationRevision,
              originalSource.window === originalWindow,
              originalWindow.windowScene?.session.persistentIdentifier == sceneID.rawValue,
              isCurrentSource(), source === originalSource, window === originalWindow,
              observationRevision == revision else {
            throw UIRouteError(.staleState, "native_original_window_source_unavailable")
        }
        return MaktabahNativeWindowObservation(window: originalWindow) { [weak self, weak originalSource] actual in
            guard let self, let originalSource,
                  self.source === originalSource, self.window === actual,
                  originalSource.window === actual, self.observationRevision == revision,
                  actual.windowScene?.session.persistentIdentifier == sceneID.rawValue,
                  isCurrentSource() else { return false }
            return self.source === originalSource && self.window === actual
                && originalSource.window === actual && self.observationRevision == revision
        }
    }

    func isPresentationReady(in sceneID: UIStableID) -> Bool {
        guard let source, let window, source.window === window,
              window.isKeyWindow, !window.isHidden, window.alpha >= 0.95,
              let scene = window.windowScene, scene.activationState == .foregroundActive,
              scene.session.persistentIdentifier == sceneID.rawValue,
              let root = window.rootViewController, root.viewIfLoaded?.window === window else { return false }
        // Read the original controller tree now, including the dismissal
        // interval after a SwiftUI sheet binding has already become false.
        var controllers = [root]
        while let controller = controllers.popLast() {
            guard controller.presentedViewController == nil,
                  !controller.isBeingPresented, !controller.isBeingDismissed,
                  controller.transitionCoordinator == nil else { return false }
            controllers.append(contentsOf: controller.children)
        }
        return true
    }
}



/// Issued by the ORIGINAL root window source before any await. Its closure
/// re-reads that source's exact UIView/UIWindow identity and monotonic lifetime
/// revision, plus the scene's original source-object attachment revision.
/// It is neither a cached presentation admission nor a navigation grant.
@MainActor
final class MaktabahNativeWindowObservation {
    private weak var window: UIWindow?
    private let validateOriginalOwner: @MainActor (UIWindow) -> Bool

    init(window: UIWindow, validateOriginalOwner: @escaping @MainActor (UIWindow) -> Bool) {
        self.window = window; self.validateOriginalOwner = validateOriginalOwner
    }

    func validate() throws -> UIWindow {
        guard let window, validateOriginalOwner(window), self.window === window else {
            throw UIRouteError(.staleState, "native_original_window_changed")
        }
        return window
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
    @ObservationIgnored private(set) var nativeModePresentationRevision: UInt64? = 0
    var selectedBook: BooksData?
    var selectedBookPresentationMode: AppMode?
    var selectedBookPresentationRevision: UInt64? = 0
    func switchToMode(_ mode: AppMode) { currentMode = mode }
}

@MainActor final class WindowSessionOwner {
    let sceneID = UIStableID(rawValue: "scene.A")!
    var mounted = true
    private weak var windowSource: MaktabahNativeWindowSource?
    private var windowSourceRevision: UInt64? = 0
    func attachWindowSource(_ source: MaktabahNativeWindowSource) {
        guard mounted else { return }
        if windowSource !== source {
            if let revision = windowSourceRevision, revision < .max { windowSourceRevision = revision + 1 }
            else { windowSourceRevision = nil }
        }
        windowSource = source
    }
    func retainOriginalWindowObservation() throws -> MaktabahNativeWindowObservation {
        guard mounted, let originalSource = windowSource, let revision = windowSourceRevision else {
            throw UIRouteError(.staleState, "native_original_window_source_unavailable")
        }
        return try originalSource.retainOriginalWindow(in: sceneID) { [weak self, weak originalSource] in
            guard let self, let originalSource else { return false }
            return self.mounted && self.windowSource === originalSource && self.windowSourceRevision == revision
        }
    }
}


/// Scene-owned registration of the ORIGINAL Viewer container. It neither
/// selects a root nor acknowledges a route. Only its retained request can
/// admit the first cold host after the canonical parent effect.
@MainActor
final class MaktabahNativeViewerParentHost {
    let sceneID: UIStableID
    private weak var manager: iOSNavigationManager?
    private let isCurrentSession: @MainActor () -> Bool
    private let captureOriginalWindow: @MainActor () throws -> MaktabahNativeWindowObservation
    private let originalRootIsReady: @MainActor () -> Bool
    private weak var controller: MaktabahNativeViewerParentWitness.Controller?
    private(set) var witnessID: UUID?
    private(set) var presentationRevision: UInt64? = 0
    private weak var pending: MaktabahNativeViewerParentContinuation?
    private var modePublication: UUID?
    private var retaining = false
    private var retired = false

    init(sceneID: UIStableID, manager: iOSNavigationManager,
         isCurrentSession: @escaping @MainActor () -> Bool,
         captureOriginalWindow: @escaping @MainActor () throws -> MaktabahNativeWindowObservation,
         originalRootIsReady: @escaping @MainActor () -> Bool) {
        self.sceneID = sceneID; self.manager = manager
        self.isCurrentSession = isCurrentSession; self.captureOriginalWindow = captureOriginalWindow
        self.originalRootIsReady = originalRootIsReady
    }

    /// Discovery only. The real request captures its own original source
    /// before its first await, and later requires foreground/actual UIKit.
    func isAvailable(bindings: MaktabahNativeSceneBindings) -> Bool {
        let tab = bindings.selectedTab.wrappedValue
        guard !retired, !retaining, pending == nil, bindings.manager === manager,
              let manager, tab == tab.canonical, tab != .viewer,
              manager.currentMode == tab.appMode, !bindings.showSettings.wrappedValue,
              manager.selectedBook == nil || manager.selectedBookPresentationMode == .viewer,
              let root = bindings.rootPublications,
              let selection = root.selectionRevision, selection < .max,
              root.settingsRevision != nil,
              let mode = manager.nativeModePresentationRevision, mode < .max,
              manager.selectedBookPresentationRevision != nil, presentationRevision != nil,
              let original = try? captureOriginalWindow(), (try? original.validate()) != nil else { return false }
        return !retired && !retaining && pending == nil && bindings.manager === self.manager
    }

    func retain(requestID: UUID, tabID: UUID, bindings: MaktabahNativeSceneBindings) throws
        -> MaktabahNativeViewerParentContinuation {
        guard !retired, !retaining, pending == nil, bindings.manager === manager else {
            throw UIRouteError(.unavailable, "native_viewer_parent_unavailable")
        }
        retaining = true
        defer { retaining = false }
        let value = try MaktabahNativeViewerParentContinuation(requestID: requestID, tabID: tabID,
            host: self, bindings: bindings, window: captureOriginalWindow())
        guard !retired, pending == nil, bindings.manager === manager else {
            throw UIRouteError(.staleState, "native_viewer_parent_session_changed")
        }
        pending = value
        do { try value.validateRoot(); return value }
        catch { release(value); throw error }
    }

    fileprivate func retains(_ value: MaktabahNativeViewerParentContinuation) -> Bool {
        !retired && pending === value && manager === value.manager
    }
    fileprivate func validateSession(_ value: MaktabahNativeViewerParentContinuation,
                                     beforeParent: Bool = false) throws {
        guard retains(value), isCurrentSession(), retains(value),
              !beforeParent || originalRootIsReady(), retains(value) else {
            throw UIRouteError(.staleState, "native_viewer_parent_session_changed")
        }
    }
    fileprivate func release(_ value: MaktabahNativeViewerParentContinuation) {
        guard pending === value else { return }
        pending = nil; value.invalidate()
    }

    func attach(_ controller: MaktabahNativeViewerParentWitness.Controller,
                manager: iOSNavigationManager) {
        guard !retired, self.manager === manager else { return }
        if self.controller === controller {
            pending?.originalHostDidUpdate()
            return
        }
        let previous = witnessID
        self.controller = controller; witnessID = controller.identity
        pending?.originalHostDidAttach(previous: previous, current: controller.identity)
    }
    func detach(_ controller: MaktabahNativeViewerParentWitness.Controller) {
        guard self.controller === controller else { return }
        pending?.invalidate()
        self.controller = nil; witnessID = nil
    }
    func originalPresentationDidChange(_ controller: MaktabahNativeViewerParentWitness.Controller,
                                        disappeared: Bool = false) {
        guard !retired, self.controller === controller else { return }
        guard let revision = presentationRevision, revision < .max else {
            presentationRevision = nil; pending?.invalidate(); return
        }
        // ONLY an original UIKit appearance/layout/window lifecycle event
        // advances this counter. Body/update callbacks never do so.
        presentationRevision = revision + 1
        if disappeared { pending?.invalidate() }
        else { pending?.originalHostDidUpdate() }
    }

    fileprivate func visibleParent(for value: MaktabahNativeViewerParentContinuation) throws
        -> (id: UUID, revision: UInt64, window: UIWindow)? {
        try validateSession(value)
        guard let controller, witnessID == controller.identity,
              let revision = presentationRevision,
              let window = controller.currentOriginalWindow(in: sceneID),
              window === (try value.originalWindow.validate()),
              retains(value), self.controller === controller, witnessID == controller.identity else { return nil }
        return (controller.identity, revision, window)
    }

    /// A passive boundary around the EXISTING TabView.onChange mode call.
    /// The caller always performs that original call once, even on refusal.
    func beginOriginalModePublication(manager: iOSNavigationManager, mode: AppMode) -> UUID? {
        guard !retired, self.manager === manager, let pending else { return nil }
        guard modePublication == nil else { pending.invalidate(); return nil }
        let token = UUID(); modePublication = token
        pending.originalModeWillPublish(token: token, mode: mode)
        return token
    }
    func endOriginalModePublication(_ token: UUID?) {
        guard let token else { return }
        guard modePublication == token else { pending?.invalidate(); return }
        // Clear before callbacks. A nested/replayed publication cannot borrow
        // the original interval or reset its consumed request-local permit.
        modePublication = nil
        pending?.originalModeDidPublish(token: token)
    }

    func unmount() {
        guard !retired else { return }
        retired = true
        let value = pending; pending = nil; value?.invalidate()
        controller = nil; witnessID = nil; modePublication = nil
    }

    /// The original root source calls this only for an observed source/window
    /// identity transition, including nil and return-to-the-same-window ABA.
    /// It cancels the same waiter without manufacturing layout or a new grant.
    func originalWindowSourceDidChange() { pending?.invalidate() }
}

/// One retained original root transition. The workspace/tab/Reader source is
/// retained by the existing ReaderTab binding, not copied into this object.
/// This object owns no Core grant: only the orchestrator may call the original
/// selection after consuming its same-preparation terminal capability.
@MainActor
final class MaktabahNativeViewerParentContinuation {
    fileprivate let manager: iOSNavigationManager
    let requestID: UUID
    private let tabID: UUID
    private let host: MaktabahNativeViewerParentHost
    fileprivate let originalWindow: MaktabahNativeWindowObservation
    private let bindings: MaktabahNativeSceneBindings
    private let root: MaktabahNativeRootPublicationSource
    private let originalTab: iOSTab
    private let originalMode: AppMode
    private let originalBook: BooksData?
    private let originalBookMode: AppMode?
    private let selectionRevision: UInt64
    private let settingsRevision: UInt64
    private let modeRevision: UInt64
    private let bookRevision: UInt64
    private let activationID = UUID()
    private enum Phase: Equatable { case retained, bound, publishingParent, awaitingParent, selecting, selected, retired }
    private var phase: Phase = .retained
    private var command: UISceneCommand?
    private var originalWitness: UUID?
    private var parentStartRevision: UInt64?
    private var modeToken: UUID?
    private var modeWasPublished = false
    private var waitStarted = false
    private var waiter: (id: UUID, continuation: CheckedContinuation<NativeOriginalParentObservation, Error>)?

    fileprivate init(requestID: UUID, tabID: UUID, host: MaktabahNativeViewerParentHost,
                     bindings: MaktabahNativeSceneBindings, window: MaktabahNativeWindowObservation) throws {
        let manager = bindings.manager, tab = bindings.selectedTab.wrappedValue
        guard tab == tab.canonical, tab != .viewer, manager.currentMode == tab.appMode,
              !bindings.showSettings.wrappedValue,
              manager.selectedBook == nil || manager.selectedBookPresentationMode == .viewer,
              let root = bindings.rootPublications,
              let selection = root.selectionRevision, selection < .max,
              let settings = root.settingsRevision,
              let mode = manager.nativeModePresentationRevision, mode < .max,
              let book = manager.selectedBookPresentationRevision,
              host.presentationRevision != nil else {
            throw UIRouteError(.unavailable, "native_viewer_parent_source_unavailable")
        }
        self.requestID = requestID; self.tabID = tabID; self.host = host; self.bindings = bindings
        originalWindow = window
        self.manager = manager; self.root = root
        originalTab = tab; originalMode = manager.currentMode
        originalBook = manager.selectedBook; originalBookMode = manager.selectedBookPresentationMode
        selectionRevision = selection; settingsRevision = settings; modeRevision = mode; bookRevision = book
        originalWitness = host.witnessID
    }

    func bind(_ command: UISceneCommand) throws {
        try validateRoot()
        guard phase == .retained, self.command == nil,
              command.invocation.requestId == requestID, command.scene.sceneID == host.sceneID,
              command.route.route.destination == NativeReaderTabIntentService.destination,
              command.route.route.presentation.tabID?.rawValue == tabID.uuidString else {
            throw UIRouteError(.staleState, "native_viewer_parent_command_changed")
        }
        try host.validateSession(self, beforeParent: true)
        self.command = command; phase = .bound
    }
    func validates(_ command: UISceneCommand) throws {
        guard self.command == command, phase != .retired, host.retains(self) else {
            throw UIRouteError(.staleState, "native_viewer_parent_command_changed")
        }
        try validateRoot()
    }

    func validateRoot() throws {
        _ = try originalWindow.validate()
        guard phase != .retired, host.retains(self), bindings.manager === manager,
              bindings.rootPublications === root, root.settingsRevision == settingsRevision,
              !bindings.showSettings.wrappedValue else { throw sourceChanged() }
        switch phase {
        case .retained, .bound:
            guard root.selectionRevision == selectionRevision,
                  bindings.selectedTab.wrappedValue == originalTab,
                  manager.currentMode == originalMode,
                  manager.nativeModePresentationRevision == modeRevision else { throw sourceChanged() }
        case .publishingParent, .awaitingParent, .selecting, .selected:
            guard root.selectionRevision == selectionRevision + 1,
                  bindings.selectedTab.wrappedValue == .viewer else { throw sourceChanged() }
            if modeWasPublished {
                guard manager.currentMode == .viewer,
                      manager.nativeModePresentationRevision == modeRevision + 1 else { throw sourceChanged() }
            } else {
                // Only the original mode wrapper may be inside its one setter.
                // No value equality can impersonate a completed publication.
                let before = manager.currentMode == originalMode && manager.nativeModePresentationRevision == modeRevision
                let duringOriginal = modeToken != nil && manager.currentMode == .viewer
                    && manager.nativeModePresentationRevision == modeRevision + 1
                guard before || duringOriginal else { throw sourceChanged() }
            }
        case .retired: throw sourceChanged()
        }
        if phase != .selecting && phase != .selected {
            guard manager.selectedBook === originalBook, manager.selectedBookPresentationMode == originalBookMode,
                  manager.selectedBookPresentationRevision == bookRevision else { throw sourceChanged() }
        }
        guard host.retains(self) else { throw sourceChanged() }
    }

    func applyParent(_ command: UISceneCommand) throws {
        try validates(command)
        guard phase == .bound, let revision = host.presentationRevision else { throw sourceChanged() }
        try host.validateSession(self, beforeParent: true)
        parentStartRevision = revision
        phase = .publishingParent
        // The ONLY root effect. TabView.onChange retains its original sole
        // switchToMode call; there is no duplicate synchronous mode setter.
        bindings.selectedTab.wrappedValue = .viewer
        try validateRoot()
        guard phase == .publishingParent, host.retains(self) else { throw sourceChanged() }
        phase = .awaitingParent
        originalHostDidUpdate()
    }

    fileprivate func originalModeWillPublish(token: UUID, mode: AppMode) {
        do {
            try validateRoot()
            guard phase == .publishingParent || phase == .awaitingParent,
                  mode == .viewer, modeToken == nil, !modeWasPublished,
                  manager.currentMode == originalMode,
                  manager.nativeModePresentationRevision == modeRevision else { throw sourceChanged() }
            modeToken = token
        } catch { invalidate() }
    }
    fileprivate func originalModeDidPublish(token: UUID) {
        guard phase != .retired, host.retains(self), modeToken == token, !modeWasPublished else { invalidate(); return }
        modeToken = nil
        guard manager.currentMode == .viewer, manager.nativeModePresentationRevision == modeRevision + 1,
              root.selectionRevision == selectionRevision + 1,
              bindings.selectedTab.wrappedValue == .viewer else { invalidate(); return }
        modeWasPublished = true
        originalHostDidUpdate()
    }

    fileprivate func originalHostDidAttach(previous: UUID?, current: UUID) {
        guard phase != .retired else { return }
        if let originalWitness {
            guard previous == originalWitness, current == originalWitness else { invalidate(); return }
        } else {
            guard previous == nil, phase == .publishingParent || phase == .awaitingParent else { invalidate(); return }
            originalWitness = current
        }
        originalHostDidUpdate()
    }
    fileprivate func originalHostDidUpdate() {
        guard let waiter else { return }
        do {
            if let observation = try currentParentObservation() {
                self.waiter = nil; waiter.continuation.resume(returning: observation)
            }
        } catch {
            self.waiter = nil; waiter.continuation.resume(throwing: error)
            invalidate()
        }
    }

    func waitUntilReady(_ command: UISceneCommand) async throws -> NativeOriginalParentObservation {
        try validates(command)
        guard phase == .awaitingParent, !waitStarted else { throw sourceChanged() }
        waitStarted = true
        try Task.checkCancellation()
        if let current = try currentParentObservation() { return current }
        let token = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled, phase == .awaitingParent, host.retains(self), waiter == nil else {
                    continuation.resume(throwing: CancellationError()); return
                }
                waiter = (token, continuation)
                originalHostDidUpdate()
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancelWait(token) }
        }
    }
    private func cancelWait(_ token: UUID) {
        guard let waiter, waiter.id == token else { return }
        self.waiter = nil; waiter.continuation.resume(throwing: CancellationError())
        invalidate()
    }

    private func currentParentObservation() throws -> NativeOriginalParentObservation? {
        try validateRoot()
        guard phase == .awaitingParent, modeWasPublished, modeToken == nil,
              let start = parentStartRevision, let actual = try host.visibleParent(for: self),
              actual.id == originalWitness, actual.revision > start else { return nil }
        guard actual.window === (try originalWindow.validate()) else { throw sourceChanged() }
        try validateRoot()
        guard host.retains(self), phase == .awaitingParent else { throw sourceChanged() }
        return .init(requestID: requestID, sceneID: host.sceneID, activationID: activationID,
                     witnessID: actual.id, presentationRevision: actual.revision)
    }
    func validateParent(_ observation: NativeOriginalParentObservation, command: UISceneCommand) throws {
        try validates(command)
        guard observation.requestID == requestID, observation.sceneID == host.sceneID,
              observation.activationID == activationID, observation.witnessID == originalWitness,
              let actual = try currentParentObservation(), actual.witnessID == observation.witnessID,
              actual.presentationRevision >= observation.presentationRevision else { throw sourceChanged() }
    }

    /// Source phase only, NOT permission. The original orchestrator has just
    /// consumed the Core terminal capability. The existing ReaderTab binding
    /// continues to fence its exact book setter and Store checkpoint.
    func beginSelection(_ observation: NativeOriginalParentObservation, command: UISceneCommand) throws {
        try validateParent(observation, command: command)
        guard phase == .awaitingParent, host.retains(self) else { throw sourceChanged() }
        phase = .selecting
    }
    func selectionDidApply() throws {
        guard phase == .selecting, host.retains(self) else { throw sourceChanged() }
        phase = .selected
        try validateRoot()
    }
    func validateOriginalSelectionEntry() throws {
        try validateRoot()
        guard phase == .selecting, host.retains(self) else { throw sourceChanged() }
    }
    func release() { host.release(self) }
    func invalidate() {
        guard phase != .retired else { return }
        phase = .retired; modeToken = nil
        if let waiter {
            self.waiter = nil
            waiter.continuation.resume(throwing: UIRouteError(.staleState, "native_viewer_parent_source_changed"))
        }
    }
    private func sourceChanged() -> UIRouteError {
        invalidate()
        return UIRouteError(.staleState, "native_viewer_parent_source_changed")
    }
}

/// Preserves the exact original mode call and ordering on every path. The
/// observer cannot veto an ordinary UI publication or perform a replacement.
@MainActor enum MaktabahNativeViewerModePublication {
    static func perform(host: MaktabahNativeViewerParentHost?, manager: iOSNavigationManager,
                        mode: AppMode, original: () -> Void) {
        let token = host?.beginOriginalModePublication(manager: manager, mode: mode)
        defer { host?.endOriginalModePublication(token) }
        original()
    }
}


@MainActor final class Fixture {
    let manager = iOSNavigationManager()
    let root = MaktabahNativeRootPublicationSource()
    var tab = iOSTab.history, settings = false
    let window = UIWindow(), view = UIView(), nativeRoot = UIViewController()
    let source = MaktabahNativeWindowSource(), session = WindowSessionOwner()
    let controller = MaktabahNativeViewerParentWitness.Controller()
    var bindings: MaktabahNativeSceneBindings!
    var host: MaktabahNativeViewerParentHost!
    var parent: MaktabahNativeViewerParentContinuation!
    var command: UISceneCommand!
    init() throws {
        manager.currentMode = .history
        view.window = window; nativeRoot.viewIfLoaded = view; window.rootViewController = nativeRoot
        source.observe(window, from: view); session.attachWindowSource(source)
        bindings = .init(manager: manager, root: root,
            selectedTab: .init(get: { [unowned self] in tab }, set: { [unowned self] value, _ in tab = value }),
            showSettings: .init(get: { [unowned self] in settings }, set: { [unowned self] value, _ in settings = value }))
        host = .init(sceneID: .init(rawValue: "scene.A")!, manager: manager,
            isCurrentSession: { true }, captureOriginalWindow: { [unowned self] in try session.retainOriginalWindowObservation() },
            originalRootIsReady: { [unowned self] in source.isPresentationReady(in: .init(rawValue: "scene.A")!) })
        let tabID = UUID(), request = UUID(), snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 1)
        let descriptor = UIDestinationDescriptor(id: NativeReaderTabIntentService.destination, title: "BOUNDARY ONLY",
            implementation: .implemented, supportedBackends: [.otzaria], presentations: [.currentTab], requiredCoreActions: [])
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        let route = RouteSpec(requestId: request, destination: descriptor.id, backend: .otzaria,
            presentation: .init(kind: .currentTab, tabID: .init(rawValue: tabID.uuidString)),
            state: .init(workspaceID: .init(rawValue: "group.A"), profileID: .init(rawValue: "profile.A")),
            scene: .init(kind: .specific, sceneID: .init(rawValue: "scene.A")))
        command = try .init(route: registry.validate(route), invocation: .init(requestId: request, snapshot: snapshot, deadlineUptimeNanoseconds: UInt64.max),
                            scene: .init(sceneID: .init(rawValue: "scene.A")!, revision: 1, backendSnapshot: snapshot))
        parent = try host.retain(requestID: request, tabID: tabID, bindings: bindings)
        try parent.bind(command)
    }
    func originalMode(_ mode: AppMode = .viewer) {
        MaktabahNativeViewerModePublication.perform(host: host, manager: manager, mode: mode) { manager.switchToMode(mode) }
    }
    func actualParent() async throws -> NativeOriginalParentObservation {
        try parent.applyParent(command)
        originalMode()
        controller.window = window
        host.attach(controller, manager: manager)
        host.originalPresentationDidChange(controller)
        return try await parent.waitUntilReady(command)
    }
}

extension MaktabahNativeWindowSource {
    // Test-only initial metadata boundary, never present in the app source.
    func exhaustRevisionForControl() { observationRevision = .max }
}
@main struct OwnerControls {
    @MainActor static var rows: [[String: Any]] = []
    @MainActor static func record(_ name: String, _ pass: Bool) { rows.append(["name": name, "pass": pass]) }
    @MainActor static func refuses(_ operation: () throws -> Void) -> Bool { do { try operation(); return false } catch { return true } }
    @MainActor static func main() async {
        do {
            do {
                let f = try Fixture(), proof = try f.session.retainOriginalWindowObservation()
                record("same_original_window_valid", try proof.validate() === f.window)
                let unchanged = !f.source.observe(f.window, from: f.view)
                let sameWindow = try proof.validate() === f.window
                record("equal_source_observation_is_not_identity_change", unchanged && sameWindow)
                f.session.attachWindowSource(f.source)
                record("equal_source_attachment_preserves_proof", try proof.validate() === f.window)
            }
            for change in ["window_ABA", "view_ABA", "nil_return", "source_attachment_ABA", "source_exhaustion"] {
                let f = try Fixture(), proof = try f.session.retainOriginalWindowObservation()
                switch change {
                case "window_ABA":
                    let next = UIWindow(); f.view.window = next; f.source.observe(next, from: f.view)
                    f.view.window = f.window; f.source.observe(f.window, from: f.view)
                case "view_ABA":
                    let next = UIView(); next.window = f.window; f.source.observe(f.window, from: next); f.source.observe(f.window, from: f.view)
                case "nil_return":
                    f.view.window = nil; f.source.observe(nil, from: f.view)
                    f.view.window = f.window; f.source.observe(f.window, from: f.view)
                case "source_attachment_ABA":
                    let next = MaktabahNativeWindowSource(); f.session.attachWindowSource(next); f.session.attachWindowSource(f.source)
                default:
                    f.source.exhaustRevisionForControl(); f.source.observe(nil, from: f.view); f.source.observe(f.window, from: f.view)
                }
                record(change + "_cannot_revive_proof", refuses { _ = try proof.validate() })
            }
            do {
                let f = try Fixture(), proof = try f.session.retainOriginalWindowObservation()
                f.nativeRoot.transitionCoordinator = UUID()
                record("source_identity_does_not_relax_presentation_guard", (try proof.validate()) === f.window && !f.source.isPresentationReady(in: .init(rawValue: "scene.A")!))
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                try f.parent.validateParent(actual, command: f.command)
                try f.parent.beginSelection(actual, command: f.command)
                try f.parent.validateOriginalSelectionEntry(); try f.parent.selectionDidApply()
                record("actual_parent_then_same_owned_selection_phase", f.tab == .viewer && f.manager.currentMode == .viewer && f.root.selectionRevision == 1 && f.manager.nativeModePresentationRevision == 2)
                record("parent_cannot_reselect_root", refuses { try f.parent.applyParent(f.command) })
            }
            do {
                let f = try Fixture(); try f.parent.applyParent(f.command)
                f.manager.switchToMode(.viewer)
                record("unowned_equal_mode_cannot_impersonate_original_publisher", refuses { try f.parent.validateRoot() })
            }
            do {
                let f = try Fixture(); try f.parent.applyParent(f.command); f.originalMode(); f.originalMode()
                record("second_mode_publication_revokes_but_preserves_UI_calls", f.manager.nativeModePresentationRevision == 3 && refuses { try f.parent.validateRoot() })
            }
            do {
                let f = try Fixture(); try f.parent.applyParent(f.command)
                var calls = 0
                MaktabahNativeViewerModePublication.perform(host: f.host, manager: f.manager, mode: .viewer) {
                    f.originalMode(); calls += 1; f.manager.switchToMode(.viewer)
                }
                record("nested_mode_publication_revokes_without_vetoing_UI", calls == 1 && f.manager.nativeModePresentationRevision == 3 && refuses { try f.parent.validateRoot() })
            }
            do {
                let f = try Fixture(); try f.parent.applyParent(f.command); f.originalMode(.search)
                record("wrong_original_mode_call_is_preserved_and_refused", f.manager.currentMode == .search && refuses { try f.parent.validateRoot() })
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                f.host.detach(f.controller); f.host.attach(f.controller, manager: f.manager)
                record("host_detach_return_cannot_revive_parent", refuses { try f.parent.validateParent(actual, command: f.command) })
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                let next = MaktabahNativeViewerParentWitness.Controller(); next.window = f.window
                f.host.attach(next, manager: f.manager)
                record("first_host_permission_cannot_transfer_to_replacement", refuses { try f.parent.validateParent(actual, command: f.command) })
            }
            do {
                let f = try Fixture(); f.controller.window = f.window; f.host.attach(f.controller, manager: f.manager)
                record("cold_host_cannot_join_before_canonical_parent_apply", refuses { try f.parent.validateRoot() })
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                f.bindings.selectedTab.wrappedValue = .history; f.bindings.selectedTab.wrappedValue = .viewer
                record("root_ABA_revokes_exact_parent", refuses { try f.parent.validateParent(actual, command: f.command) })
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                f.bindings.showSettings.wrappedValue = true; f.bindings.showSettings.wrappedValue = false
                record("settings_ABA_revokes_exact_parent", refuses { try f.parent.validateParent(actual, command: f.command) })
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                f.parent.release()
                record("released_source_never_authorizes_selection", refuses { try f.parent.beginSelection(actual, command: f.command) })
            }
        } catch { rows.append(["name": "unexpected_error", "pass": false, "error": String(describing: error)]) }
        let failures = rows.filter { !($0["pass"] as! Bool) }
        print(String(data: try! JSONSerialization.data(withJSONObject: ["rows": rows, "pass_count": rows.count-failures.count, "fail_count": failures.count,
            "boundary": "Actual owner/source/setter bodies; explicit UIKit/app-domain substitutes; no Core grant or native UI acceptance"], options: [.sortedKeys]), encoding: .utf8)!)
        if !failures.isEmpty { exit(1) }
    }
}
