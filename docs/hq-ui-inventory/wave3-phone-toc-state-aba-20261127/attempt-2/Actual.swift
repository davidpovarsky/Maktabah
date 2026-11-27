import Foundation
import Observation
import Synchronization
import Foundation
public enum ActionStatus: String, Sendable, Codable {
    case completed, uiQueued = "ui_queued", requiresBackendSwitch = "requires_backend_switch"
    case requiresForeground = "requires_foreground", requiresConfirmation = "requires_confirmation"
    case needsDisambiguation = "needs_disambiguation", notSupported = "not_supported"
    case unavailable, staleState = "stale_state", cancelled, failed
}
public struct UIStableID: RawRepresentable, Codable, Sendable, Hashable {
    public let rawValue: String
    public init?(rawValue: String) {
        guard rawValue.utf8.count <= 128, rawValue.range(of: "^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$", options: .regularExpression) == rawValue.startIndex..<rawValue.endIndex else { return nil }
        self.rawValue = rawValue
    }
    public init(from decoder: any Decoder) throws {
        guard let id = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) else { throw UIRouteError(.failed, "invalid_stable_id") }
        self = id
    }
    public func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct UIRouteError: Error, Sendable, Equatable {
    public let status: ActionStatus
    public let code: String
    public init(_ status: ActionStatus, _ code: String) { self.status = status; self.code = code }
}


import Foundation
import Observation
// Explicit app-domain boundaries. No SwiftUI, UIKit, or backend delivery is simulated.
// The test double for captureOriginalSource exercises revocation; its production
// implementation has a separate immutable source/Observation proof.
enum AppMode: Equatable { case viewer, history }
@MainActor enum MaktabahApp { static var isIpad=false }
@MainActor @Observable final class BooksData {
 var id:Int;var backendLocator:String?
 init(_ id:Int=3891) {self.id=id;backendLocator="otzaria|book:\(id)|line:523"}
}
@MainActor @Observable final class ReaderViewModel {
 var currentBook:BooksData?
 var isPopoverPresented=false
 var readerInspectorVisible=false
 var originalTOCRevision:UInt64=0
 init(book:BooksData){currentBook=book}
}
@MainActor @Observable final class iOSNavigationManager {
 struct ReaderTab {let id:UUID;let book:BooksData;let viewModel:ReaderViewModel}
 var activeTabId:UUID?
 var openTabs:[ReaderTab]=[]
 var selectedContentId:Int?=523
 var selectedBookForInfo:BooksData?
 var showingTabsList=false
 var currentMode:AppMode = .history
 var activeReaderViewModel:ReaderViewModel? {openTabs.first{$0.id==activeTabId}?.viewModel}
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
 private(set) var selectedBookPresentationMode:AppMode?
 private(set) var selectedBookPresentationRevision:UInt64?=0
}
@MainActor @Observable final class MappingSource {var event:UInt64=0}
struct MappingProjection:Equatable {let activeTabID:UUID?}
enum MappingCoverage {case liveNativeSetters;case unavailable}
@MainActor struct MappingObservation {
 let source:MappingSource;let owner:ObjectIdentifier;let scene:String
 let epoch:UInt64;let projection:MappingProjection;let coverage:MappingCoverage
}
@MainActor @Observable final class StudyWorkspaceNavigationAdapter {
 var attached=true
 var isSwitching=false
 let sceneID:String
 let mappingOwnershipSource=MappingSource()
 var epoch:UInt64=0
 var coverage:MappingCoverage = .liveNativeSetters
 let manager:iOSNavigationManager
 init(manager:iOSNavigationManager,sceneID:String){self.manager=manager;self.sceneID=sceneID}
 func mappingOwnershipObservation()->MappingObservation? {
  .init(source:mappingOwnershipSource,owner:ObjectIdentifier(manager),scene:sceneID,
    epoch:epoch,projection:.init(activeTabID:manager.activeTabId),coverage:coverage)
 }
}
@MainActor @Observable final class MaktabahNativeWorkspaceProjectionSource {
 var isAuthoritative=true
 var workspace:StudyWorkspaceNavigationAdapter?
 init(_ workspace:StudyWorkspaceNavigationAdapter){self.workspace=workspace}
 func read() throws -> StudyWorkspaceNavigationAdapter? {workspace}
}
typealias MaktabahNativeComponentSourceObservation = NativeComponentSourceObservation
@MainActor enum MaktabahNativeTOCComponents {
 enum Anchor {case contents}
 static func currentReader(_ manager:iOSNavigationManager)->ReaderViewModel? {
  let tabs=manager.openTabs.filter{$0.id==manager.activeTabId}
  return tabs.count==1 ? tabs[0].viewModel:nil
 }
 static func captureOriginalSource(_ anchor:Anchor,manager:iOSNavigationManager) throws -> @MainActor () throws -> Void {
  guard let reader=currentReader(manager) else{throw UIRouteError(.staleState,"boundary_reader")}
  let proof=NativeComponentSourceObservation {
   _=manager.activeTabId;_=manager.openTabs;_=reader.originalTOCRevision
  }
  return {try proof.validate();guard currentReader(manager) === reader else{throw UIRouteError(.staleState,"boundary_reader_changed")}}
 }
}


import Observation
import Synchronization

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


@MainActor final class Harness {
 let manager=iOSNavigationManager()
 let book=BooksData()
 let reader:ReaderViewModel
 let tab:iOSNavigationManager.ReaderTab
 let workspace:StudyWorkspaceNavigationAdapter
 let projection:MaktabahNativeWorkspaceProjectionSource
 let requestID=UUID()
 var token=UUID()
 var owner:MaktabahNativePhoneTOCPresentationBinding!
 var requested=false,blocked=false,admitted=true
 var readerCalls=0,presentCalls=0,changedCalls=0,invalidatedCalls=0
 var duringReader:(@MainActor () throws -> Void)?
 var duringOriginal:(@MainActor () throws -> Void)?
 var duringAdmission:(@MainActor () throws -> Void)?
 init(warm:Bool=false,wrongMode:Bool=false) {
  reader=ReaderViewModel(book:book)
  tab = .init(id:UUID(),book:book,viewModel:reader)
  manager.openTabs=[tab];manager.activeTabId=tab.id
  workspace=StudyWorkspaceNavigationAdapter(manager:manager,sceneID:"scene-1")
  projection=MaktabahNativeWorkspaceProjectionSource(workspace)
  if warm {
   manager.currentMode = wrongMode ? .history:.viewer
   manager.selectedBook=book
   manager.currentMode = .history
  }
  owner=MaktabahNativePhoneTOCPresentationBinding(sceneID:UIStableID(rawValue:"scene-1")!,
    manager:manager,workspaceSource:projection,presentReader:{[weak self] retained in
     guard let self,retained.id==self.tab.id,retained.book === self.book,
       retained.viewModel === self.reader else{throw UIRouteError(.staleState,"boundary_wrong_reader")}
     self.readerCalls+=1
     self.manager.currentMode = .viewer
     if self.manager.selectedBook !== retained.book || self.manager.selectedBookPresentationMode != .viewer {
      self.manager.selectedBook=retained.book
     }
     try self.duringReader?()
    })
  owner.install(changed:{[weak self] in self?.changedCalls+=1},
    invalidated:{[weak self] in self?.invalidatedCalls+=1})
 }
 func begin() throws {
  try owner.retainSource(requestID:requestID)
  try owner.begin(requestID:requestID){[weak self] in
   guard let self,self.admitted else{throw UIRouteError(.staleState,"boundary_expired")}
   try self.duringAdmission?()
  }
 }
 func apply() throws {try owner.apply(requestID:requestID)}
 func attach(_ token:UUID?=nil) {
  let chosen=token ?? self.token
  owner.attach(token:chosen,tabID:tab.id,book:book,reader:reader,workspace:workspace,
    requested:{[weak self] in self?.requested==true},
    blocked:{[weak self] in self?.blocked != false},
    present:{[weak self] in
     guard let self,self.owner.isRenderingOriginalContents(token:chosen) else{throw UIRouteError(.staleState,"boundary_not_original_render")}
     self.presentCalls+=1
     try self.duringOriginal?()
     self.requested=true
    })
 }
 func render(){owner.render(token:token)}
 func complete() {owner.finish(requestID:requestID,completed:true);owner.releaseSource(requestID:requestID)}
}

// Explicit local state storage boundary; phone branch of both actual setters.
// Native SwiftUI State presentation remains unexecuted.
struct Annotation {}
struct StudyPresentationBoundary { mutating func beginNote(id:UUID)->Bool {true} }
enum NoteHostBoundary {case reader;case compactStudy}
@MainActor final class OriginalWorkspaceStateBoundary {
 let nativePhoneTOCAttachment:MaktabahNativePhoneTOCViewAttachment
 let usesNativeStudySheet=false
 var nativeStudyPresentation=StudyPresentationBoundary()
 var showPanelSheet=false
 var fallbackNoteHost:NoteHostBoundary = .reader
 var nativeNoteEditorPresentationID=UUID()
 var editingAnnotation:Annotation?
 var noteErrorMessage:String?
 init(_ attachment:MaktabahNativePhoneTOCViewAttachment){nativePhoneTOCAttachment=attachment}
     private func setEditingAnnotation(_ value: Annotation?) {
        nativePhoneTOCAttachment.originalStateWillChange()
        // One identity per original sheet entry, including reopening the same
        // unsaved value. Callback closures capture this value, never a live getter.
        if value != nil {
            let presentationID = UUID()
            if usesNativeStudySheet {
                guard nativeStudyPresentation.beginNote(id: presentationID) else { return }
            } else {
                // The compact inspector is already a system sheet. Its note
                // editor must be owned by that sheet, not a sibling presenter.
                fallbackNoteHost = showPanelSheet ? .compactStudy : .reader
            }
            nativeNoteEditorPresentationID = presentationID
        }
        editingAnnotation = value
    }
    private func setNoteErrorMessage(_ value: String?) {
        nativePhoneTOCAttachment.originalStateWillChange()
        noteErrorMessage = value
    }
 func annotation(_ value:Annotation?){setEditingAnnotation(value)}
 func error(_ value:String?){setNoteErrorMessage(value)}
}


@main struct StateControls {
 @MainActor static func main() throws {
  var passed=0,failed=0
  func check(_ name:String,_ value:@autoclosure()->Bool){
   if value(){passed+=1;print("PASS "+name)}else{failed+=1;print("FAIL "+name)}
  }
  func rejects(_ action:()throws->Void)->Bool{do{try action();return false}catch{return true}}
  func fresh() throws -> (Harness,OriginalWorkspaceStateBoundary) {
   let h=Harness(warm:true);h.manager.currentMode = .viewer
   let attachment=MaktabahNativePhoneTOCViewAttachment()
   h.token=attachment.token;attachment.use(h.owner);h.attach()
   let local=OriginalWorkspaceStateBoundary(attachment)
   try h.begin()
   return (h,local)
  }
  do {
   let (h,state)=try fresh();let oldPresentation=state.nativeNoteEditorPresentationID
   state.annotation(Annotation());state.annotation(nil)
   check("original annotation setter ABA keeps original Notes behavior and retires source",
    state.editingAnnotation==nil && state.nativeNoteEditorPresentationID != oldPresentation
     && rejects{try h.apply()} && h.readerCalls==0)
  }
  do {
   let (h,state)=try fresh()
   state.error("Original note validation error");state.error(nil)
   check("original error alert set-clear ABA cannot regain pending source",
    state.noteErrorMessage==nil && rejects{try h.apply()} && h.readerCalls==0)
  }
  do {
   let (h,state)=try fresh()
   state.annotation(nil)
   check("equal original annotation setter cannot preserve a captured callback",
    state.editingAnnotation==nil && rejects{try h.apply()} && h.readerCalls==0)
  }
  print("RESULT passed=\(passed) failed=\(failed)")
  if failed>0{exit(1)}
 }
}
