#if os(iOS)
import Foundation
import UIKit
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Scene-owned access to the ORIGINAL Search saved-results sheet. It opens no
/// substitute UI and never invokes the result button, database or query loader.
@MainActor final class MaktabahNativeSavedResultsBinding {
    typealias Record = NativeSavedResultIntentService.Record
    typealias Tree = MaktabahNativeSavedResultsSource
    static let destination = UIDestinationID(rawValue: "native.savedResults")!

    enum StateField { case path, filter, loading, operation }
    struct SheetAccess {
        let token: UUID
        let model: ResultsViewModel
        let path: @MainActor () -> [FolderNode]
        let setPath: @MainActor ([FolderNode]) -> Void
        let filter: @MainActor () -> String
        let loading: @MainActor () -> Bool
        let blocked: @MainActor () -> Bool
    }
    struct PageKey: Hashable {
        let folder: ObjectIdentifier?
        init(_ folder: FolderNode?) { self.folder = folder.map(ObjectIdentifier.init) }
    }
    struct RowKey: Hashable {
        let kind: NativeSavedResultIntentService.Kind
        let object: ObjectIdentifier
        init(_ node: Tree.Node) {
            switch node {
            case .folder(let folder): kind = .folder; object = ObjectIdentifier(folder)
            case .result(let result): kind = .result; object = ObjectIdentifier(result)
            }
        }
    }
    struct ScrollKey: Hashable {
        let kind: String
        let id: Int64
        static func folder(_ node: FolderNode) -> Self { .init(kind: "folder", id: node.id) }
        static func result(_ node: ResultNode) -> Self { .init(kind: "result", id: node.id) }
    }
    private final class SearchHost {
        let token: UUID
        weak var manager: iOSNavigationManager?
        var requested: @MainActor () -> Bool
        var setRequested: @MainActor (Bool) -> Void
        var otherBlocked: @MainActor () -> Bool
        var revision: UInt64? = 0
        init(token: UUID, manager: iOSNavigationManager, requested: @escaping @MainActor () -> Bool,
             setRequested: @escaping @MainActor (Bool) -> Void, otherBlocked: @escaping @MainActor () -> Bool) {
            self.token = token; self.manager = manager; self.requested = requested
            self.setRequested = setRequested; self.otherBlocked = otherBlocked
        }
    }
    private final class SheetHost {
        var access: SheetAccess
        weak var view: UIView?
        var revision: UInt64? = 0
        init(access: SheetAccess, view: UIView) { self.access = access; self.view = view }
    }
    private final class Page {
        let token: UUID
        let sheet: UUID
        let folder: FolderNode?
        weak var view: UIView?
        var reveal: @MainActor (ScrollKey) -> Void
        init(token: UUID, sheet: UUID, folder: FolderNode?, view: UIView,
             reveal: @escaping @MainActor (ScrollKey) -> Void) {
            self.token = token; self.sheet = sheet; self.folder = folder
            self.view = view; self.reveal = reveal
        }
    }
    private final class Row {
        let token: UUID
        let sheet: UUID
        let page: PageKey
        let node: Tree.Node
        weak var view: UIView?
        init(token: UUID, sheet: UUID, page: PageKey, node: Tree.Node, view: UIView) {
            self.token = token; self.sheet = sheet; self.page = page; self.node = node; self.view = view
        }
    }
    private final class Source {
        let requestID: UUID
        let record: Record?
        let tree: Tree?
        let entry: Tree.Entry?
        let search: SearchHost
        let searchRevision: UInt64
        let initiallyRequested: Bool
        let window: MaktabahNativeWindowObservation
        let validateForeign: @MainActor () throws -> Void
        let initialPath: [FolderNode]
        let targetPath: [FolderNode]
        let filter: [UInt8]
        var sheet: SheetHost?
        var sheetRevision: UInt64?
        var pageToken: UUID?
        var rowToken: UUID?
        var valid = true
        var applied = false
        var searchPublished = false
        var pathPublished = false
        var loadingCompleted = false
        var scrolled = false
        init(requestID: UUID, record: Record?, tree: Tree?, entry: Tree.Entry?, search: SearchHost,
             searchRevision: UInt64, requested: Bool, sheet: SheetHost?, initialPath: [FolderNode],
             targetPath: [FolderNode], filter: String, window: MaktabahNativeWindowObservation,
             validateForeign: @escaping @MainActor () throws -> Void) {
            self.requestID = requestID; self.record = record; self.tree = tree; self.entry = entry
            self.search = search; self.searchRevision = searchRevision; initiallyRequested = requested
            self.sheet = sheet; sheetRevision = sheet?.revision
            self.initialPath = initialPath; self.targetPath = targetPath; self.filter = Array(filter.utf8)
            self.window = window; self.validateForeign = validateForeign
        }
        var page: PageKey { PageKey(targetPath.last) }
    }
    private final class Pending {
        let source: Source
        let validate: @MainActor () throws -> Void
        var applying = false
        var rendering = false
        init(source: Source, validate: @escaping @MainActor () throws -> Void) {
            self.source = source; self.validate = validate
        }
    }
    /// A permit authorizes only one observed original setter publication. It
    /// carries no execution authority: only apply(), under Core, creates it.
    private final class Publication {
        enum Field { case search, path }
        let pending: Pending
        let field: Field
        let token: UUID
        var will = false
        var did = false
        init(pending: Pending, field: Field, token: UUID) {
            self.pending = pending; self.field = field; self.token = token
        }
    }

    let sceneID: UIStableID
    private let bindings: MaktabahNativeSceneBindings
    private let workspaceSource: MaktabahNativeWorkspaceProjectionSource
    private weak var workspacePresentation: MaktabahNativeWorkspacePresentationBinding?
    private let commonReady: @MainActor () -> Bool
    private let windowReady: @MainActor () -> Bool
    private let retainWindow: @MainActor () throws -> MaktabahNativeWindowObservation
    private let readForeign: @MainActor () -> Void
    private var search: SearchHost?
    private var sheet: SheetHost?
    private var pages: [PageKey: Page] = [:]
    private var rows: [RowKey: Row] = [:]
    private var catalogSource: Tree?
    private var retained: Source?
    private var completed: Source?
    private var pending: Pending?
    private var publication: Publication?
    private var capturing = false
    private var retiring = false
    private var mounted = true
    private var lifetime: UInt64? = 0
    private var changed: (@MainActor () -> Void)?
    private var invalidated: (@MainActor () -> Void)?

    init(sceneID: UIStableID, bindings: MaktabahNativeSceneBindings,
         workspaceSource: MaktabahNativeWorkspaceProjectionSource,
         workspacePresentation: MaktabahNativeWorkspacePresentationBinding,
         commonReady: @escaping @MainActor () -> Bool, windowReady: @escaping @MainActor () -> Bool,
         retainWindow: @escaping @MainActor () throws -> MaktabahNativeWindowObservation,
         readForeignPresentations: @escaping @MainActor () -> Void) {
        self.sceneID = sceneID; self.bindings = bindings; self.workspaceSource = workspaceSource
        self.workspacePresentation = workspacePresentation; self.commonReady = commonReady
        self.windowReady = windowReady; self.retainWindow = retainWindow; readForeign = readForeignPresentations
    }
    func install(changed: @escaping @MainActor () -> Void, invalidated: @escaping @MainActor () -> Void) {
        self.changed = changed; self.invalidated = invalidated
    }
    var isRequestedOrMounted: Bool { search?.requested() == true || sheet != nil }
    /// Discovery/readiness facet only. Execution separately retains the actual
    /// original window and source; this does not create a request or grant.
    var isStableOriginalPresentation: Bool {
        guard isAvailable, search?.requested() == true, let sheet, let view = sheet.view,
              let window = view.window, !sheet.access.loading(), !sheet.access.blocked(),
              sheet.access.model.nativeLoadLifetime.settledRevision != nil else { return false }
        return MaktabahNativeSavedResultsGeometry.isVisible(view, in: view, window: window, sceneID: sceneID)
    }
    var isAvailable: Bool {
        guard mounted, lifetime != nil, let search, search.manager === bindings.manager,
              search.revision != nil, !search.otherBlocked(), commonReady(),
              bindings.selectedTab.wrappedValue == .search, bindings.manager.currentMode == .search,
              !bindings.showSettings.wrappedValue, bindings.isPresentationReady,
              bindings.manager.alertMessage == nil,
              !BackendCoordinator.shared.isTransitioning,
              BackendCoordinator.shared.activeBackendID == .otzaria,
              BackendCoordinator.shared.usesNativeMaktabahDataPath,
              iOSTab.search.isAvailable(for: BackendCoordinator.shared.activeCapabilities) else { return false }
        return true
    }

    func catalog() throws -> [Record] {
        guard !capturing, !retiring, pending == nil, retained == nil, let captureRevision = lifetime else { return [] }
        capturing = true
        defer { capturing = false }
        guard isAvailable,
              let sheet, search?.requested() == true, !sheet.access.loading(), !sheet.access.blocked(),
              sheet.revision != nil else { return [] }
        if let current = catalogSource {
            do { try current.validate() }
            catch { current.retire(); catalogSource = nil }
        }
        if catalogSource == nil {
            let next = try Tree(model: sheet.access.model, sceneID: sceneID)
            guard mounted, lifetime == captureRevision, self.sheet === sheet,
                  pending == nil, retained == nil, isAvailable, !sheet.access.loading(), !sheet.access.blocked() else {
                next.retire(); throw stale()
            }
            catalogSource = next
        }
        guard let source = catalogSource else { throw stale() }
        try source.validate()
        let filter = sheet.access.filter()
        let records = source.entries.filter { source.matchesOriginalFilter($0, filter: filter) }.map(\.record)
        guard lifetime == captureRevision, catalogSource === source, self.sheet === sheet,
              pending == nil, retained == nil else { throw stale() }
        return records
    }

    /// Retain BEFORE the first foreground/Core await. A cached record may join
    /// only the exact warm original tree; a cold primitive root retains no node.
    func retain(record: Record?, requestID: UUID) throws {
        guard !capturing, !retiring, retained == nil, pending == nil,
              let captureRevision = lifetime else { throw stale() }
        capturing = true
        defer { capturing = false }
        guard isAvailable,
              let search, let searchRevision = search.revision, let lifetime,
              let workspacePresentation, let workspaceRevision = workspacePresentation.originalStateRevision,
              workspaceSource.isAuthoritative, let workspace = try workspaceSource.read(),
              workspace.attached, !workspace.isSwitching, workspace.sceneID == sceneID.rawValue,
              workspace.errorMessage == nil, workspace.store.loadError == nil,
              let mapping = workspace.mappingOwnershipObservation(),
              let stored = workspace.store.mappingObservation(scene: sceneID.rawValue),
              mapping.owner == ObjectIdentifier(bindings.manager), mapping.scene == sceneID.rawValue,
              mapping.coverage == .liveNativeSetters, stored.coverage == .workspaceStoreOnly,
              let root = bindings.rootPublications, let selectionRevision = root.selectionRevision,
              let settingsRevision = root.settingsRevision,
              let modeRevision = bindings.manager.nativeModePresentationRevision,
              let bookRevision = bindings.manager.selectedBookPresentationRevision else {
            throw UIRouteError(.unavailable, "native_saved_results_source_unavailable")
        }
        let window = try retainWindow()
        _ = try window.validate()
        let requested = search.requested()
        let originalSheet = sheet
        guard requested == (originalSheet != nil), originalSheet?.access.blocked() != true,
              originalSheet?.access.loading() != true, originalSheet == nil || originalSheet?.revision != nil else {
            throw UIRouteError(.unavailable, "native_saved_results_transition_in_progress")
        }
        let path = originalSheet?.access.path() ?? [], filter = originalSheet?.access.filter() ?? ""
        var tree: Tree?, entry: Tree.Entry?
        if let record {
            guard requested, let source = catalogSource, source.model === originalSheet?.access.model,
                  record.sceneID == sceneID else { throw stale() }
            tree = source; entry = try source.entry(record)
            guard let entry, source.matchesOriginalFilter(entry, filter: filter) else { throw stale() }
        }
        let targetPath: [FolderNode]
        if let entry {
            switch entry.node {
            case .folder: targetPath = entry.path
            case .result: targetPath = filter.isEmpty ? entry.path : []
            }
        } else { targetPath = [] }
        let manager = bindings.manager, originalBook = manager.selectedBook
        let originalBookMode = manager.selectedBookPresentationMode
        let session = manager.unifiedSearchSession, model = manager.searchViewModel, reader = manager.activeReaderViewModel
        let observation = MaktabahNativeComponentSourceObservation {
            _ = try? self.workspaceSource.read(); _ = workspace.attached; _ = workspace.isSwitching
            _ = workspace.errorMessage; _ = workspace.store.loadError
            _ = mapping.source.event; _ = stored.source.event
            _ = root.selectionRevision; _ = root.settingsRevision
            _ = manager.currentMode; _ = manager.selectedBook; _ = manager.selectedBookPresentationMode
            _ = manager.openTabs; _ = manager.activeTabId; _ = manager.selectedContentId
            _ = manager.unifiedSearchSession; _ = manager.searchViewModel
            _ = session.query; _ = session.scope; _ = session.requestConfiguration
            _ = session.selectedBookIds; _ = session.resultKitabFilter
            _ = session.showsBookFilterSheet; _ = session.showsSearchDataSheet; _ = session.showsAdvancedOptions
            _ = manager.selectedBookForInfo; _ = manager.showingTabsList; _ = manager.alertMessage
            _ = reader?.currentBook; _ = reader?.currentDestination; _ = reader?.isPopoverPresented
            _ = reader?.readerInspectorVisible; _ = DonationManager.shared.showDonationSheet
            self.readForeign()
        }
        let source = Source(requestID: requestID, record: record, tree: tree, entry: entry,
            search: search, searchRevision: searchRevision, requested: requested,
            sheet: originalSheet, initialPath: path, targetPath: targetPath, filter: filter, window: window) {
                [weak self, weak workspace, weak manager, weak workspacePresentation, weak session, weak model] in
                try observation.validate(); _ = try window.validate()
                guard let self, let workspace, let manager, let workspacePresentation, let session, let model,
                      self.mounted, self.lifetime == lifetime, self.isAvailable,
                      self.workspaceSource.isAuthoritative, try self.workspaceSource.read() === workspace,
                      workspace.attached, !workspace.isSwitching, workspace.sceneID == self.sceneID.rawValue,
                      workspace.store.loadError == nil, workspace.errorMessage == nil,
                      self.workspacePresentation === workspacePresentation,
                      workspacePresentation.originalStateRevision == workspaceRevision,
                      let current = workspace.mappingOwnershipObservation(),
                      let currentStored = workspace.store.mappingObservation(scene: self.sceneID.rawValue),
                      current.source === mapping.source, current.epoch == mapping.epoch,
                      current.owner == mapping.owner, current.projection == mapping.projection,
                      currentStored.source === stored.source, currentStored.epoch == stored.epoch,
                      currentStored.owner == stored.owner, currentStored.projection == stored.projection,
                      self.bindings.rootPublications === root, root.selectionRevision == selectionRevision,
                      root.settingsRevision == settingsRevision,
                      manager.nativeModePresentationRevision == modeRevision,
                      manager.selectedBookPresentationRevision == bookRevision,
                      manager.selectedBook === originalBook, manager.selectedBookPresentationMode == originalBookMode,
                      manager.unifiedSearchSession === session, manager.searchViewModel === model,
                      session.searchViewModel === model,
                      !session.showsBookFilterSheet, !session.showsSearchDataSheet, !session.showsAdvancedOptions else {
                    throw UIRouteError(.staleState, "native_saved_results_foreign_source_changed")
                }
                try observation.validate(); _ = try window.validate()
            }
        guard self.lifetime == lifetime, lifetime == captureRevision,
              self.search === search, self.sheet === originalSheet,
              retained == nil, pending == nil else { throw stale() }
        source.pageToken = pages[source.page]?.token
        if let entry { source.rowToken = rows[RowKey(entry.node)]?.token }
        completed?.valid = false; completed = nil; retained = source
        do { try validate(source) }
        catch { releaseSource(requestID: requestID); throw error }
    }

    func validateSource(requestID: UUID) throws {
        guard let value = retained, value.requestID == requestID else { throw stale() }
        try validate(value)
    }
    func selectedItem(requestID: UUID) throws -> UIStableID? {
        try validateSource(requestID: requestID)
        return retained?.record?.itemID
    }
    func begin(requestID: UUID, validate: @escaping @MainActor () throws -> Void) throws {
        guard pending == nil, let source = retained, source.requestID == requestID else { throw stale() }
        try self.validate(source); try validate(); try self.validate(source)
        guard retained === source, pending == nil, source.initiallyRequested || windowReady() else { throw stale() }
        if source.initiallyRequested { try visibleSheet(source) }
        pending = Pending(source: source, validate: validate)
    }
    func apply(requestID: UUID) throws {
        guard let value = pending, value.source === retained, value.source.requestID == requestID,
              !value.source.applied, !value.applying else { throw stale() }
        try validatePending(value)
        value.applying = true
        // Claim the one canonical effect before original State callbacks.
        // This permits only this command's own in-progress presentation; all
        // surface reporting stays closed until apply and actual layout finish.
        value.source.applied = true
        defer { value.applying = false }
        do {
            if !value.source.initiallyRequested {
                try publish(value, field: .search, token: value.source.search.token) {
                    value.source.search.setRequested(true)
                }
            } else if !Tree.identical(value.source.initialPath, value.source.targetPath) {
                guard let sheet = value.source.sheet else { throw stale() }
                try publish(value, field: .path, token: sheet.access.token) {
                    sheet.access.setPath(value.source.targetPath)
                }
            }
            guard pending === value, retained === value.source, value.source.valid else { throw stale() }
            try validatePending(value)
        } catch { retire(); throw error }
        value.applying = false
        renderOriginalContainer()
        try validatePending(value)
        changed?()
    }

    private func publish(_ value: Pending, field: Publication.Field, token: UUID,
                         perform: @MainActor () -> Void) throws {
        guard publication == nil, pending === value, retained === value.source, value.applying else { throw stale() }
        let permit = Publication(pending: value, field: field, token: token)
        publication = permit
        perform()
        guard publication === permit, permit.will, permit.did, pending === value,
              retained === value.source, value.source.valid else { throw stale() }
        publication = nil
        try validatePending(value)
    }

    /// The original State setter calls these on both sides of its unchanged
    /// assignment. Consume BEFORE any existing Session/SwiftUI callback.
    func searchWillPublish(owner: UUID, next: Bool) {
        guard let search, search.token == owner else { retire(); return }
        let owned = publication.map { $0.field == .search && $0.token == owner && !$0.will && !$0.did
            && $0.pending === pending && $0.pending.source === retained
            && $0.pending.applying && $0.pending.source.valid && !search.requested() && next } == true
        if owned { publication?.will = true }
        else { retire() }
        search.revision = nextRevision(search.revision)
        if search.revision == nil { retire() }
    }
    func searchDidPublish(owner: UUID) {
        guard let permit = publication, permit.field == .search, permit.token == owner,
              permit.will, !permit.did, permit.pending === pending,
              permit.pending.source === retained, permit.pending.source.valid,
              search === permit.pending.source.search, search?.requested() == true,
              let revision = search?.revision, permit.pending.source.searchRevision < .max,
              revision == permit.pending.source.searchRevision + 1 else { return }
        permit.did = true; permit.pending.source.searchPublished = true
    }
    func originalOtherSearchStateWillChange(owner: UUID) {
        guard search?.token == owner else { return }
        retire()
    }
    func sheetStateWillPublish(owner: UUID, field: StateField, nextPath: [FolderNode]? = nil,
                               nextLoading: Bool? = nil) {
        guard let sheet, sheet.access.token == owner else { retire(); return }
        let ownedPath: Bool
        if let permit = publication, let nextPath {
            ownedPath = permit.field == .path && permit.token == owner && !permit.will && !permit.did
                && permit.pending === pending && permit.pending.source === retained && permit.pending.applying
                && permit.pending.source.valid && field == .path
                && Tree.identical(nextPath, permit.pending.source.targetPath)
        } else { ownedPath = false }
        // A root cold load is an original view lifecycle, never a node claim.
        // Permit only its first actual true -> false completion; all other
        // State writes invalidate the already retained request.
        let coldLoad = field == .loading && nextLoading == false && sheet.access.loading()
            && pending?.source === retained && pending?.source.applied == true
            && pending?.source.initiallyRequested == false && pending?.source.record == nil
            && pending?.source.loadingCompleted == false && pending?.source.sheet === sheet
        if ownedPath { publication?.will = true }
        else if coldLoad { pending?.source.loadingCompleted = true }
        else { retire() }
        sheet.revision = nextRevision(sheet.revision)
        if sheet.revision == nil { retire() }
        if coldLoad, let value = pending?.source { value.sheetRevision = sheet.revision }
    }
    func sheetStateDidPublish(owner: UUID, field: StateField) {
        guard let sheet, sheet.access.token == owner else { return }
        if let permit = publication, permit.field == .path, permit.token == owner, field == .path,
           permit.will, !permit.did, permit.pending === pending, permit.pending.source === retained,
           permit.pending.source.valid, let previous = permit.pending.source.sheetRevision,
           previous < .max, sheet.revision == previous + 1,
           Tree.identical(sheet.access.path(), permit.pending.source.targetPath) {
            permit.did = true; permit.pending.source.pathPublished = true
        }
        renderOriginalContainer(); changed?()
    }

    func attachSearch(owner: UUID, manager: iOSNavigationManager, requested: @escaping @MainActor () -> Bool,
                      setRequested: @escaping @MainActor (Bool) -> Void,
                      otherBlocked: @escaping @MainActor () -> Bool) {
        guard mounted, manager === bindings.manager else { return }
        if let search, search.token == owner, search.manager === manager {
            search.requested = requested; search.setRequested = setRequested; search.otherBlocked = otherBlocked
            return
        }
        retire(); search = SearchHost(token: owner, manager: manager, requested: requested,
            setRequested: setRequested, otherBlocked: otherBlocked)
        changed?()
    }
    func detachSearch(owner: UUID) {
        guard search?.token == owner else { return }
        // The original presenter can be covered by its own sheet. Its captured
        // State owner stays exact; a replacement owner still revokes it.
        guard search?.requested() != true else { return }
        retire(); search = nil; changed?()
    }
    func attachSheet(access: SheetAccess, view: UIView) {
        guard mounted, access.model === ResultsViewModel.shared, search?.requested() == true else { return }
        if let sheet, sheet.access.token == access.token, sheet.access.model === access.model, sheet.view === view {
            sheet.access = access; renderOriginalContainer(); return
        }
        let cold = sheet == nil && pending?.source.applied == true
            && pending?.source.initiallyRequested == false && pending?.source.sheet == nil
            && pending?.source.valid == true && pending?.source === retained
        if !cold { retire() }
        let next = SheetHost(access: access, view: view)
        sheet = next
        if cold, let value = pending?.source { value.sheet = next; value.sheetRevision = next.revision }
        renderOriginalContainer(); changed?()
    }
    func detachSheet(owner: UUID, view: UIView) {
        guard sheet?.access.token == owner, sheet?.view === view else { return }
        retire(); sheet = nil; pages.removeAll(); rows.removeAll(); changed?()
    }
    func attachPage(token: UUID, sheet owner: UUID, folder: FolderNode?, view: UIView,
                    reveal: @escaping @MainActor (ScrollKey) -> Void) {
        guard sheet?.access.token == owner else { return }
        let key = PageKey(folder)
        if let page = pages[key], page.token == token, page.view === view, page.sheet == owner {
            page.reveal = reveal; renderOriginalContainer(); return
        }
        if let source = retained ?? completed, source.page == key,
           source.pageToken != nil || !source.applied { retire() }
        pages[key] = Page(token: token, sheet: owner, folder: folder, view: view, reveal: reveal)
        if let source = pending?.source, source.valid, source.applied, source.page == key,
           source.pageToken == nil { source.pageToken = token }
        renderOriginalContainer(); changed?()
    }
    func detachPage(token: UUID, sheet owner: UUID, folder: FolderNode?, view: UIView) {
        let key = PageKey(folder)
        guard let page = pages[key], page.token == token, page.sheet == owner, page.view === view else { return }
        if let source = retained ?? completed, source.pageToken == token { retire() }
        pages.removeValue(forKey: key); changed?()
    }
    func attachRow(token: UUID, sheet owner: UUID, page folder: FolderNode?, node: Tree.Node, view: UIView) {
        guard sheet?.access.token == owner else { return }
        let key = RowKey(node), page = PageKey(folder)
        if let row = rows[key], row.token == token, row.sheet == owner, row.page == page, row.view === view { return }
        if let source = retained ?? completed, source.entry.map({ RowKey($0.node) }) == key,
           source.rowToken != nil || !source.applied { retire() }
        rows[key] = Row(token: token, sheet: owner, page: page, node: node, view: view)
        if let source = pending?.source, source.valid, source.applied,
           source.entry.map({ RowKey($0.node) }) == key, source.rowToken == nil { source.rowToken = token }
        changed?()
    }
    func detachRow(token: UUID, node: Tree.Node, view: UIView) {
        let key = RowKey(node)
        guard let row = rows[key], row.token == token, row.view === view else { return }
        if let source = retained ?? completed, source.rowToken == token { retire() }
        rows.removeValue(forKey: key); changed?()
    }
    func originalLayoutDidChange() { renderOriginalContainer(); changed?() }

    /// Only scrolling of the actual original list may continue from layout.
    /// Path/sheet selection has already happened once inside canonical apply.
    private func renderOriginalContainer() {
        guard let value = pending, value.source.applied, !value.applying, !value.rendering else { return }
        value.rendering = true
        defer { value.rendering = false }
        do {
            try validatePending(value)
            let source = value.source
            guard let sheet = source.sheet, !sheet.access.loading(),
                  Tree.identical(sheet.access.path(), source.targetPath),
                  let page = pages[source.page], page.sheet == sheet.access.token,
                  let pageView = page.view, let sheetView = sheet.view,
                  MaktabahNativeSavedResultsGeometry.isVisible(pageView, in: sheetView,
                      window: try source.window.validate(), sceneID: sceneID) else { return }
            if let token = source.pageToken { guard token == page.token else { throw stale() } }
            else { source.pageToken = page.token }
            if let entry = source.entry, case .result(let node) = entry.node, !source.scrolled {
                source.scrolled = true
                page.reveal(.result(node))
                try validatePending(value)
            }
        } catch { retire() }
    }

    func observedItem(requestID: UUID) -> UIStableID? {
        guard let source = pending?.source ?? completed, source.requestID == requestID else { return nil }
        do { try validateVisibleSource(source); return source.record?.itemID } catch { return nil }
    }
    func hasVisibleSurface(requestID: UUID) -> Bool {
        guard let source = pending?.source ?? completed, source.requestID == requestID else { return false }
        do { try validateVisibleSource(source); return true } catch { return false }
    }
    /// Only the SAME already-applied request may await its own original sheet
    /// transition. This passive facet must not call the Session validator.
    func isContinuingAppliedRequest(requestID: UUID) -> Bool {
        guard let value = pending, value.source === retained, value.source.requestID == requestID,
              value.source.valid, value.source.applied else { return false }
        return (try? validate(value.source)) != nil
    }
    func validateCompletedSurface(requestID: UUID) throws {
        guard let source = completed, source.requestID == requestID else { throw stale() }
        try validateVisibleSource(source)
    }
    func withValidatedSurface<T>(requestID: UUID, report: @MainActor () throws -> T) throws -> T {
        guard let value = pending, value.source.requestID == requestID else { throw stale() }
        try requireSurface(value)
        let result = try report()
        try requireSurface(value)
        return result
    }
    func finish(requestID: UUID, completed success: Bool) {
        guard let value = pending, value.source.requestID == requestID else { return }
        let accepted = success && (try? requireSurface(value)) != nil
        pending = nil; publication = nil
        if accepted { completed = value.source }
        else { value.source.valid = false }
    }
    func releaseSource(requestID: UUID) {
        guard let source = retained, source.requestID == requestID else { return }
        if pending?.source === source { retire() }
        if completed !== source { source.valid = false }
        retained = nil
    }
    func clearCompletedProof() { completed?.valid = false; completed = nil }
    func retire() {
        guard !retiring else { return }
        retiring = true
        defer { retiring = false }
        if let old = lifetime { lifetime = old < .max ? old + 1 : nil }
        let wasActive = retained != nil || pending != nil || completed != nil
        retained?.valid = false; completed?.valid = false
        pending = nil; publication = nil; completed = nil
        catalogSource?.retire(); catalogSource = nil
        if wasActive { invalidated?() }
    }
    func unmount() {
        mounted = false; retire(); retained = nil; search = nil; sheet = nil
        pages.removeAll(); rows.removeAll(); changed = nil; invalidated = nil
    }

    private func validate(_ source: Source) throws {
        guard mounted, source.valid, retained === source || completed === source,
              search === source.search else { throw stale() }
        try source.validateForeign()
        guard source.valid, retained === source || completed === source, search === source.search,
              source.searchRevision <= .max - (source.searchPublished ? 1 : 0),
              source.search.revision == source.searchRevision + (source.searchPublished ? 1 : 0),
              source.search.requested() == (source.initiallyRequested || source.searchPublished) else { throw stale() }
        try source.tree?.validate()
        if let expected = source.sheet {
            guard sheet === expected, let initial = source.sheetRevision,
                  initial <= .max - (source.pathPublished ? 1 : 0),
                  expected.revision == initial + (source.pathPublished ? 1 : 0),
                  !expected.access.blocked(), expected.access.filter().utf8.elementsEqual(source.filter),
                  Tree.identical(expected.access.path(), source.pathPublished ? source.targetPath : source.initialPath),
                  source.record == nil || !expected.access.loading() else { throw stale() }
        } else if sheet != nil { throw stale() }
        guard source.valid else { throw stale() }
    }
    private func validatePending(_ value: Pending) throws {
        guard pending === value, retained === value.source, value.source.valid else { throw stale() }
        try validate(value.source); try value.validate(); try validate(value.source)
        guard pending === value, retained === value.source, value.source.valid else { throw stale() }
    }
    private func visibleSheet(_ source: Source) throws {
        guard let sheet = source.sheet, self.sheet === sheet, let view = sheet.view,
              !sheet.access.loading(), !sheet.access.blocked(),
              MaktabahNativeSavedResultsGeometry.isVisible(view, in: view,
                  window: try source.window.validate(), sceneID: sceneID) else {
            throw UIRouteError(.unavailable, "native_saved_results_sheet_not_visible")
        }
    }
    private func requireSurface(_ value: Pending) throws {
        try validatePending(value)
        guard !value.applying, !value.rendering else { throw stale() }
        try validateVisibleSource(value.source)
        try validatePending(value)
    }
    private func validateVisibleSource(_ source: Source) throws {
        try validate(source)
        if let current = pending, current.source === source {
            guard !current.applying, !current.rendering else { throw stale() }
        }
        guard source.applied,
              let sheet = source.sheet, let sheetView = sheet.view,
              let page = pages[source.page], page.sheet == sheet.access.token,
              let pageView = page.view, !sheet.access.loading(), !sheet.access.blocked(),
              sheet.access.model.nativeLoadLifetime.settledRevision != nil,
              Tree.identical(sheet.access.path(), source.targetPath),
              MaktabahNativeSavedResultsGeometry.isVisible(pageView, in: sheetView,
                  window: try source.window.validate(), sceneID: sceneID) else {
            throw UIRouteError(.unavailable, "native_saved_results_original_page_not_visible")
        }
        if let token = source.pageToken { guard token == page.token else { throw stale() } }
        else { source.pageToken = page.token }
        if let entry = source.entry, case .result = entry.node {
            guard source.scrolled, let row = rows[RowKey(entry.node)], row.sheet == sheet.access.token,
                  row.page == source.page, let rowView = row.view,
                  MaktabahNativeSavedResultsGeometry.isVisible(rowView, in: sheetView,
                      window: try source.window.validate(), sceneID: sceneID) else {
                throw UIRouteError(.unavailable, "native_saved_results_original_row_not_visible")
            }
            if let token = source.rowToken { guard token == row.token else { throw stale() } }
            else { source.rowToken = row.token }
        }
        try validate(source)
    }
    /// Compute before publication. Invalidation invokes app-owned callbacks and
    /// must never run while an inout access to the original host is held.
    private func nextRevision(_ revision: UInt64?) -> UInt64? {
        guard let old = revision, old < .max else { return nil }
        return old + 1
    }
    private func stale() -> UIRouteError { UIRouteError(.staleState, "native_saved_results_source_changed") }
}
#endif
