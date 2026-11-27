#if os(iOS)
import Foundation
import SwiftUI
import UIKit
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Finite original source identities only. The group consumer retains and
/// validates its actual prepared stage; this value cannot create that stage.
fileprivate enum MaktabahNativeViewerParentTarget {
    case readerTab(UUID)
    case workspaceSelection(profileID: UUID, groupID: UUID, activeDocumentID: UUID?)

    @MainActor func matches(_ command: UISceneCommand) -> Bool {
        let route = command.route.route
        switch self {
        case .readerTab(let tabID):
            return route.destination == NativeReaderTabIntentService.destination
                && route.presentation.tabID?.rawValue == tabID.uuidString
        case .workspaceSelection(let profileID, let groupID, let activeDocumentID):
            return route.destination == NativeWorkspaceSelectionIntentService.destination
                && route.presentation == .init(kind: .currentTab,
                    tabID: activeDocumentID.flatMap { UIStableID(rawValue: $0.uuidString) })
                && route.state == .init(workspaceID: UIStableID(rawValue: groupID.uuidString),
                                        profileID: UIStableID(rawValue: profileID.uuidString))
                && route.content == nil && route.focus == nil
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
        try retain(requestID: requestID, target: .readerTab(tabID), bindings: bindings)
    }

    func retainWorkspaceSelection(requestID: UUID, profileID: UUID, groupID: UUID,
                                  activeDocumentID: UUID?, bindings: MaktabahNativeSceneBindings) throws
        -> MaktabahNativeViewerParentContinuation {
        try retain(requestID: requestID,
            target: .workspaceSelection(profileID: profileID, groupID: groupID,
                                        activeDocumentID: activeDocumentID), bindings: bindings)
    }

    private func retain(requestID: UUID, target: MaktabahNativeViewerParentTarget,
                        bindings: MaktabahNativeSceneBindings) throws -> MaktabahNativeViewerParentContinuation {
        guard !retired, !retaining, pending == nil, bindings.manager === manager else {
            throw UIRouteError(.unavailable, "native_viewer_parent_unavailable")
        }
        retaining = true
        defer { retaining = false }
        let value = try MaktabahNativeViewerParentContinuation(requestID: requestID, target: target,
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
/// retained by its original selection binding, not copied into this object.
/// This object owns no Core grant: only the orchestrator may call the original
/// selection after consuming its same-preparation terminal capability.
@MainActor
final class MaktabahNativeViewerParentContinuation {
    fileprivate let manager: iOSNavigationManager
    let requestID: UUID
    private let target: MaktabahNativeViewerParentTarget
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

    fileprivate init(requestID: UUID, target: MaktabahNativeViewerParentTarget, host: MaktabahNativeViewerParentHost,
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
        self.requestID = requestID; self.target = target; self.host = host; self.bindings = bindings
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
              target.matches(command) else {
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

    /// Group terminal validation is repeated after the ORIGINAL snapshot
    /// flush and before its Store/native writes. Those synchronous callbacks
    /// may change UIKit while the root values stay equal. Re-read the SAME
    /// original host/window/visible geometry; this check grants no effect.
    func validateWorkspaceSelectionSource() throws {
        try validateRoot()
        let expectedPhase = phase
        guard case .workspaceSelection = target,
              phase == .selecting || phase == .selected,
              modeWasPublished, modeToken == nil, let start = parentStartRevision,
              let actual = try host.visibleParent(for: self),
              actual.id == originalWitness, actual.revision > start,
              actual.window === (try originalWindow.validate()) else { throw sourceChanged() }
        try validateRoot()
        guard phase == expectedPhase, host.retains(self) else { throw sourceChanged() }
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
#endif
