import Foundation
import Observation

/// Exact expected use of the ORIGINAL selectedBook setter. The revision is
/// source-owned metadata: it is never reset, supplied by a route, or authority.
@MainActor
private struct MaktabahNativePhoneTOCBookTransition {
    let book: BooksData
    let beforeBook: BooksData?
    let beforeMode: AppMode?
    let beforeRevision: UInt64
    let afterRevision: UInt64
    let assignsBook: Bool

    init(manager: iOSNavigationManager, book: BooksData) throws {
        guard manager.selectedBook == nil || manager.selectedBook === book,
              let revision = manager.selectedBookPresentationRevision else {
            throw UIRouteError(.unavailable, "native_phone_toc_book_unavailable")
        }
        self.book = book
        beforeBook = manager.selectedBook
        beforeMode = manager.selectedBookPresentationMode
        beforeRevision = revision
        assignsBook = manager.selectedBook !== book || manager.selectedBookPresentationMode != .viewer
        if assignsBook {
            guard revision < .max else {
                throw UIRouteError(.staleState, "native_phone_toc_presentation_exhausted")
            }
            afterRevision = revision + 1
        } else {
            afterRevision = revision
        }
    }

    func validateBefore(_ manager: iOSNavigationManager) throws {
        guard manager.selectedBook === beforeBook,
              manager.selectedBookPresentationMode == beforeMode,
              manager.selectedBookPresentationRevision == beforeRevision else {
            throw UIRouteError(.staleState, "native_phone_toc_book_changed")
        }
    }

    func validateAfter(_ manager: iOSNavigationManager) throws {
        guard manager.selectedBook === book, manager.currentMode == .viewer,
              manager.selectedBookPresentationMode == .viewer,
              manager.selectedBookPresentationRevision == afterRevision else {
            throw UIRouteError(.staleState, "native_phone_toc_book_transition_changed")
        }
    }
}

/// One scene-owned binding to the original phone Reader workspace. A cold
/// presentation may join its FIRST original mount after canonical apply; it
/// never creates a Reader, opens a book, retries a command or renews permission.
@MainActor @Observable
final class MaktabahNativePhoneTOCPresentationBinding {
    let sceneID: UIStableID
    private let manager: iOSNavigationManager
    private let workspaceSource: MaktabahNativeWorkspaceProjectionSource
    private let presentReader: @MainActor (iOSNavigationManager.ReaderTab) throws -> Void
    private(set) var renderRevision: UInt64 = 0
    private(set) var stateRevision: UInt64 = 0
    @ObservationIgnored private var registration: Registration?
    @ObservationIgnored private var activeSource: Source?
    @ObservationIgnored private var presentedSource: Source?
    @ObservationIgnored private var pending: Pending?
    @ObservationIgnored private var changed: @MainActor () -> Void = {}
    @ObservationIgnored private var invalidated: @MainActor () -> Void = {}

    private struct Registration {
        let token: UUID
        let tabID: UUID
        let book: BooksData
        let reader: ReaderViewModel
        let workspace: StudyWorkspaceNavigationAdapter
        let requested: @MainActor () -> Bool
        let blocked: @MainActor () -> Bool
        let present: @MainActor () throws -> Void
    }

    private final class Source {
        enum Phase: Equatable { case retained, applying, presented }
        let requestID: UUID
        let tab: iOSNavigationManager.ReaderTab
        let workspace: StudyWorkspaceNavigationAdapter
        let bookTransition: MaktabahNativePhoneTOCBookTransition
        let validateData: @MainActor () throws -> Void
        var mount: UUID?
        var phase: Phase = .retained
        var valid = true

        init(requestID: UUID, tab: iOSNavigationManager.ReaderTab,
             workspace: StudyWorkspaceNavigationAdapter,
             bookTransition: MaktabahNativePhoneTOCBookTransition,
             mount: UUID?, validateData: @escaping @MainActor () throws -> Void) {
            self.requestID = requestID; self.tab = tab; self.workspace = workspace
            self.bookTransition = bookTransition; self.mount = mount
            self.validateData = validateData
        }
    }

    private final class Pending {
        let source: Source
        let validate: @MainActor () throws -> Void
        var applied = false
        var rendering = false
        var rendered = false
        init(source: Source, validate: @escaping @MainActor () throws -> Void) {
            self.source = source; self.validate = validate
        }
    }

    init(sceneID: UIStableID, manager: iOSNavigationManager,
         workspaceSource: MaktabahNativeWorkspaceProjectionSource,
         presentReader: @escaping @MainActor (iOSNavigationManager.ReaderTab) throws -> Void) {
        self.sceneID = sceneID; self.manager = manager
        self.workspaceSource = workspaceSource; self.presentReader = presentReader
    }

    func install(changed: @escaping @MainActor () -> Void,
                 invalidated: @escaping @MainActor () -> Void) {
        self.changed = changed; self.invalidated = invalidated
    }

    var isMounted: Bool { registration != nil }
    var contentsRequested: Bool { registration?.requested() == true }
    var blocksRouting: Bool {
        manager.selectedBookForInfo != nil || manager.showingTabsList
            || manager.activeReaderViewModel?.isPopoverPresented == true
            || manager.activeReaderViewModel?.readerInspectorVisible == true
            || registration?.blocked() == true
    }
    var isTransitioning: Bool { pending.map { $0.applied && !$0.rendered } ?? false }

    var isPresented: Bool {
        guard let registration, !blocksRouting, registration.requested(),
              registrationIsCurrent(registration),
              manager.selectedBook === registration.book,
              manager.selectedBookPresentationMode == .viewer,
              manager.currentMode == .viewer else { return false }
        return true
    }

    func isAvailable() -> Bool {
        guard !MaktabahApp.isIpad, !blocksRouting,
              let tab = originalTab(), workspaceSource.isAuthoritative,
              let workspace = try? workspaceSource.read(), workspace.attached, !workspace.isSwitching,
              workspace.sceneID == sceneID.rawValue,
              let mapping = workspace.mappingOwnershipObservation(),
              mapping.owner == ObjectIdentifier(manager), mapping.scene == sceneID.rawValue,
              mapping.projection.activeTabID == tab.id,
              manager.selectedBook == nil || manager.selectedBook === tab.book,
              manager.selectedBookPresentationRevision != nil else { return false }
        guard case .liveNativeSetters = mapping.coverage else { return false }
        if let registration, !registrationIsCurrent(registration) { return false }
        return true
    }

    private func originalTab() -> iOSNavigationManager.ReaderTab? {
        guard let id = manager.activeTabId else { return nil }
        let matches = manager.openTabs.filter { $0.id == id }
        guard matches.count == 1, let tab = matches.first,
              let reader = MaktabahNativeTOCComponents.currentReader(manager),
              reader === tab.viewModel, reader.currentBook?.id == tab.book.id,
              reader.currentBook?.backendLocator == tab.book.backendLocator else { return nil }
        return tab
    }

    private func registrationIsCurrent(_ value: Registration) -> Bool {
        guard let tab = originalTab(), tab.id == value.tabID,
              tab.book === value.book, tab.viewModel === value.reader,
              let workspace = try? workspaceSource.read(), workspace === value.workspace,
              workspace.sceneID == sceneID.rawValue, workspace.attached, !workspace.isSwitching else { return false }
        return true
    }

    /// Original NavigationStack ownership, independent of whether its current
    /// child is Reader or TOC. A Group child transition is not a new workspace.
    func ownsOriginalWorkspace(token: UUID) -> Bool {
        guard let registration, registration.token == token,
              registrationIsCurrent(registration),
              manager.selectedBook === registration.book,
              manager.selectedBookPresentationMode == .viewer,
              manager.currentMode == .viewer else { return false }
        return true
    }

    /// This recognizes only the synchronous original callback already bounded
    /// by render(). It is not a public permission, a retry or a second grant.
    func isRenderingOriginalContents(token: UUID) -> Bool {
        guard let value = pending, value.applied, value.rendering, !value.rendered,
              value.source.valid, value.source.mount == token,
              registration?.token == token else { return false }
        do { try validate(value.source); try value.validate(); return pending === value && value.source.valid }
        catch { return false }
    }

    func retainSource(requestID: UUID) throws {
        guard activeSource == nil, pending == nil, isAvailable(),
              let tab = originalTab(), let workspace = try workspaceSource.read(),
              let mapping = workspace.mappingOwnershipObservation() else {
            throw UIRouteError(.unavailable, "native_phone_toc_source_unavailable")
        }
        let bookTransition = try MaktabahNativePhoneTOCBookTransition(manager: manager, book: tab.book)
        // This is the ONE original Reader/TOC proof also used by components.
        let readerSource = try MaktabahNativeTOCComponents.captureOriginalSource(.contents, manager: manager)
        let observation = MaktabahNativeComponentSourceObservation {
            _ = try? workspaceSource.read()
            _ = workspace.attached
            _ = workspace.isSwitching
            _ = workspace.mappingOwnershipSource.event
            _ = manager.selectedContentId
            _ = manager.selectedBookForInfo
            _ = manager.showingTabsList
            _ = tab.viewModel.currentBook
            _ = tab.viewModel.isPopoverPresented
            _ = tab.viewModel.readerInspectorVisible
        }
        let bookID = tab.book.id, locator = tab.book.backendLocator
        let currentBook = tab.viewModel.currentBook
        let selectedContentID = manager.selectedContentId
        let source = Source(requestID: requestID, tab: tab, workspace: workspace,
            bookTransition: bookTransition, mount: registration?.token) { [weak self, weak workspace] in
            try observation.validate()
            try readerSource()
            guard let self, let workspace, self.workspaceSource.isAuthoritative,
                  let current = try self.workspaceSource.read(), current === workspace,
                  workspace.attached, !workspace.isSwitching, workspace.sceneID == self.sceneID.rawValue,
                  let actual = workspace.mappingOwnershipObservation(),
                  actual.source === mapping.source, actual.owner == mapping.owner,
                  actual.scene == mapping.scene, actual.epoch == mapping.epoch,
                  actual.projection == mapping.projection,
                  tab.book.id == bookID, tab.book.backendLocator == locator,
                  tab.viewModel.currentBook === currentBook,
                  self.manager.selectedContentId == selectedContentID,
                  !self.blocksRouting else {
                throw UIRouteError(.staleState, "native_phone_toc_source_changed")
            }
            guard case .liveNativeSetters = actual.coverage else {
                throw UIRouteError(.staleState, "native_phone_toc_mapping_changed")
            }
        }
        try validate(source)
        activeSource = source
    }

    private func validate(_ source: Source) throws {
        guard source.valid else { throw UIRouteError(.staleState, "native_phone_toc_source_retired") }
        try source.validateData()
        guard source.valid else { throw UIRouteError(.staleState, "native_phone_toc_source_retired") }
        switch source.phase {
        case .retained: try source.bookTransition.validateBefore(manager)
        case .presented: try source.bookTransition.validateAfter(manager)
        case .applying: throw UIRouteError(.staleState, "native_phone_toc_publication_in_progress")
        }
        if let token = source.mount {
            guard let registration, registration.token == token, registrationIsCurrent(registration) else {
                throw UIRouteError(.staleState, "native_phone_toc_mount_changed")
            }
        } else if registration != nil {
            throw UIRouteError(.staleState, "native_phone_toc_unadmitted_mount")
        }
    }

    func validateSource(requestID: UUID) throws {
        guard let source = activeSource, source.requestID == requestID else {
            throw UIRouteError(.staleState, "native_phone_toc_source_missing")
        }
        try validate(source)
    }

    func captureComponentSource() throws -> @MainActor () throws -> Void {
        guard let source = activeSource else {
            throw UIRouteError(.staleState, "native_phone_toc_parent_not_retained")
        }
        try validate(source)
        return { [weak self, source] in
            guard let self, self.activeSource === source || self.presentedSource === source else {
                throw UIRouteError(.staleState, "native_phone_toc_parent_replaced")
            }
            try self.validate(source)
        }
    }

    func retainedReader() throws -> ReaderViewModel {
        guard let source = activeSource else {
            throw UIRouteError(.staleState, "native_phone_toc_parent_not_retained")
        }
        try validate(source)
        return source.tab.viewModel
    }

    func releaseSource(requestID: UUID) {
        guard let source = activeSource, source.requestID == requestID else { return }
        if pending?.source === source {
            retire()
        } else {
            if presentedSource !== source { source.valid = false }
            activeSource = nil
        }
    }

    func begin(requestID: UUID, validate: @escaping @MainActor () throws -> Void) throws {
        guard pending == nil, let source = activeSource, source.requestID == requestID else {
            throw UIRouteError(.unavailable, "native_phone_toc_source_busy")
        }
        try self.validate(source); try validate()
        guard activeSource === source, source.valid else {
            throw UIRouteError(.staleState, "native_phone_toc_begin_reentered")
        }
        pending = Pending(source: source, validate: validate)
    }

    func apply(requestID: UUID) throws {
        guard let value = pending, value.source.requestID == requestID, !value.applied else {
            throw UIRouteError(.staleState, "native_phone_toc_command_changed")
        }
        try validate(value.source); try value.validate()
        guard pending === value, value.source.valid else {
            throw UIRouteError(.staleState, "native_phone_toc_apply_reentered")
        }
        value.source.phase = .applying
        do {
            // The shared ORIGINAL binding has the exact declared +0/+1 rule.
            try presentReader(value.source.tab)
            guard pending === value, value.source.valid else {
                throw UIRouteError(.staleState, "native_phone_toc_apply_reentered")
            }
            try value.source.validateData()
            try value.source.bookTransition.validateAfter(manager)
            value.source.phase = .presented
            try validate(value.source); try value.validate()
            guard pending === value, value.source.valid else {
                throw UIRouteError(.staleState, "native_phone_toc_apply_reentered")
            }
            value.applied = true
            renderRevision &+= 1
            changed()
        } catch {
            retire()
            throw error
        }
    }

    func attach(token: UUID, tabID: UUID, book: BooksData, reader: ReaderViewModel,
                workspace: StudyWorkspaceNavigationAdapter,
                requested: @escaping @MainActor () -> Bool,
                blocked: @escaping @MainActor () -> Bool,
                present: @escaping @MainActor () throws -> Void) {
        guard !MaktabahApp.isIpad else { return }
        let next = Registration(token: token, tabID: tabID, book: book, reader: reader,
            workspace: workspace, requested: requested, blocked: blocked, present: present)
        guard registrationIsCurrent(next), manager.selectedBook === book,
              manager.selectedBookPresentationMode == .viewer, manager.currentMode == .viewer else {
            retire()
            return
        }
        if let old = registration, old.token == token, old.tabID == tabID,
           old.book === book, old.reader === reader, old.workspace === workspace {
            // Keep live original getters fresh without publishing another graph
            // update. Actual source/state events publish through their own hooks.
            registration = next
            return
        }
        if registration != nil { retire() }
        if let source = activeSource, source.mount == nil {
            guard let value = pending, value.source === source, value.applied,
                  source.phase == .presented, source.tab.id == tabID,
                  source.tab.book === book, source.tab.viewModel === reader,
                  source.workspace === workspace else {
                retire()
                registration = next
                changed()
                return
            }
            // Only the first exact original mount can join an applied command.
            source.mount = token
        }
        registration = next
        stateRevision &+= 1
        changed()
    }

    func render(token: UUID) {
        guard let value = pending, value.applied, !value.rendering, !value.rendered,
              let registration, registration.token == token,
              value.source.mount == token, !registration.blocked() else { return }
        do {
            try validate(value.source); try value.validate()
            guard pending === value, self.registration?.token == token, value.source.valid else {
                throw UIRouteError(.staleState, "native_phone_toc_render_reentered")
            }
            value.rendering = true
            if !registration.requested() { try registration.present() }
            guard pending === value, self.registration?.token == token,
                  value.source.valid, registration.requested(), !registration.blocked() else {
                throw UIRouteError(.staleState, "native_phone_toc_render_changed")
            }
            try validate(value.source); try value.validate()
            guard pending === value, self.registration?.token == token, value.source.valid else {
                throw UIRouteError(.staleState, "native_phone_toc_render_reentered")
            }
            value.rendering = false; value.rendered = true
            stateRevision &+= 1
            changed()
            // Actual original tocColumn NativeSurfaceWitness is still required.
        } catch { retire() }
    }

    func detach(token: UUID) {
        guard registration?.token == token else { return }
        registration = nil
        retire()
        stateRevision &+= 1
        changed()
    }

    func originalStateWillChange(token: UUID) {
        guard registration?.token == token else { return }
        retire()
    }

    func stateDidChange(token: UUID) {
        guard registration?.token == token else { return }
        stateRevision &+= 1
        changed()
    }

    func finish(requestID: UUID, completed: Bool) {
        guard let value = pending, value.source.requestID == requestID else { return }
        pending = nil
        if completed, value.applied, value.rendered {
            do {
                try validate(value.source)
                presentedSource?.valid = false
                presentedSource = value.source
            } catch {
                value.source.valid = false
            }
        } else {
            value.source.valid = false
        }
        stateRevision &+= 1
        changed()
    }

    func unmount() {
        registration = nil
        retire()
    }

    func retire() {
        let wasPending = pending != nil
        activeSource?.valid = false; presentedSource?.valid = false
        activeSource = nil; presentedSource = nil; pending = nil
        stateRevision &+= 1
        if wasPending { invalidated() }
        changed()
    }
}


/// One caller-owned original SwiftUI workspace lifetime. The parent reference
/// is weak; an obsolete view cannot operate the next attachment's registration.
@MainActor
final class MaktabahNativePhoneTOCViewAttachment {
    let token = UUID()
    private weak var owner: MaktabahNativePhoneTOCPresentationBinding?

    func use(_ owner: MaktabahNativePhoneTOCPresentationBinding) {
        guard self.owner !== owner else { return }
        self.owner?.detach(token: token)
        self.owner = owner
    }

    func isBound(to candidate: MaktabahNativePhoneTOCPresentationBinding) -> Bool { owner === candidate }
    func render() { owner?.render(token: token) }
    func originalStateWillChange() { owner?.originalStateWillChange(token: token) }
    func stateDidChange() { owner?.stateDidChange(token: token) }
    func disappeared() {
        // The ORIGINAL Group can replace its child as part of this very route.
        // Actual NavigationStack/source replacement must detach; requested TOC
        // flags alone are never taken as proof of the workspace's lifetime.
        if owner?.ownsOriginalWorkspace(token: token) != true { detach() }
    }
    func detach() {
        owner?.detach(token: token)
        owner = nil
    }
    isolated deinit { owner?.detach(token: token) }
}

