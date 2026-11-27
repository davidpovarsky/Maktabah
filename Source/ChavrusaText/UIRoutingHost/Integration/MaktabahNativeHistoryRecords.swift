#if os(iOS)
import CryptoKit
import Foundation
import SwiftUI
import UIKit
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Expected publications by the ORIGINAL root and optional phone stack owners.
/// The source-owned counters cannot be reset or supplied by a public route.
@MainActor
struct MaktabahNativeHistoryRecordParentTransition {
    let rootPublications: MaktabahNativeRootPublicationSource
    let selectionRevision: UInt64
    let presentedSelectionRevision: UInt64
    let settingsRevision: UInt64
    let tab: iOSTab
    let mode: AppMode
    let modeRevision: UInt64
    let presentedModeRevision: UInt64
    let book: BooksData?
    let bookMode: AppMode?
    let bookRevision: UInt64
    let presentedBookRevision: UInt64
    let changesTab: Bool
    let popsBook: Bool

    init(bindings: MaktabahNativeSceneBindings) throws {
        let manager = bindings.manager
        tab = bindings.selectedTab.wrappedValue
        mode = manager.currentMode
        guard let rootPublications = bindings.rootPublications,
              let selectionRevision = rootPublications.selectionRevision,
              let settingsRevision = rootPublications.settingsRevision,
              tab == tab.canonical, mode == tab.appMode,
              let modeRevision = manager.nativeModePresentationRevision,
              let bookRevision = manager.selectedBookPresentationRevision else {
            throw UIRouteError(.unavailable, "native_history_record_parent_unavailable")
        }
        self.modeRevision = modeRevision; self.bookRevision = bookRevision
        self.rootPublications = rootPublications
        self.selectionRevision = selectionRevision; self.settingsRevision = settingsRevision
        book = manager.selectedBook; bookMode = manager.selectedBookPresentationMode
        changesTab = tab != .history
        popsBook = !MaktabahApp.isIpad && book != nil
        guard (!changesTab || (selectionRevision < .max && modeRevision < .max)),
              (!popsBook || bookRevision < .max) else {
            throw UIRouteError(.staleState, "native_history_record_parent_exhausted")
        }
        presentedModeRevision = changesTab ? modeRevision + 1 : modeRevision
        presentedSelectionRevision = changesTab ? selectionRevision + 1 : selectionRevision
        presentedBookRevision = popsBook ? bookRevision + 1 : bookRevision
    }

    func validateBefore(_ bindings: MaktabahNativeSceneBindings) throws {
        let manager = bindings.manager
        guard bindings.rootPublications === rootPublications,
              rootPublications.selectionRevision == selectionRevision,
              rootPublications.settingsRevision == settingsRevision,
              bindings.selectedTab.wrappedValue == tab, manager.currentMode == mode,
              manager.nativeModePresentationRevision == modeRevision,
              manager.selectedBook === book, manager.selectedBookPresentationMode == bookMode,
              manager.selectedBookPresentationRevision == bookRevision else {
            throw UIRouteError(.staleState, "native_history_record_parent_changed")
        }
    }

    func validateAfter(_ bindings: MaktabahNativeSceneBindings, requiresPublishedMode: Bool) throws {
        let manager = bindings.manager
        let published = manager.currentMode == .history
            && manager.nativeModePresentationRevision == presentedModeRevision
        let awaitingOriginalPublisher = changesTab && !requiresPublishedMode
            && manager.currentMode == mode && manager.nativeModePresentationRevision == modeRevision
        guard bindings.rootPublications === rootPublications,
              rootPublications.selectionRevision == presentedSelectionRevision,
              rootPublications.settingsRevision == settingsRevision,
              bindings.selectedTab.wrappedValue == .history, published || awaitingOriginalPublisher,
              manager.selectedBook === (popsBook ? nil : book),
              manager.selectedBookPresentationMode == (popsBook ? nil : bookMode),
              manager.selectedBookPresentationRevision == presentedBookRevision else {
            throw UIRouteError(.staleState, "native_history_record_parent_transition_changed")
        }
    }
}

extension MaktabahNativeSceneBindings {
    func presentOriginalHistoryRecord(_ expected: MaktabahNativeHistoryRecordParentTransition) throws {
        guard !showSettings.wrappedValue, isPresentationReady else {
            throw UIRouteError(.unavailable, "native_history_record_parent_blocked")
        }
        try expected.validateBefore(self)
        if expected.popsBook { manager.selectedBook = nil }
        if expected.changesTab { selectedTab.wrappedValue = .history }
        // The original TabView remains the sole currentMode publisher.
        try expected.validateAfter(self, requiresPublishedMode: false)
    }
}

/// Local stable identity of an actual published original record. Neither the
/// numeric work ID nor a copied UI model can resolve this source reference.
@MainActor enum MaktabahNativeHistoryRecords {
    typealias Kind = NativeHistoryRecordIntentService.Kind
    typealias Record = NativeHistoryRecordIntentService.Record
    static let destination = UIDestinationID(rawValue: "native.history")!
    static let originalGridID = "native.history.original-grid"

    static func record(_ card: HistoryQualifiedPublication.Card, kind: Kind) throws -> Record {
        let reference = NativeHistoryRecordIntentService.Reference(kind: kind,
            locator: try ActionAppIdentityBridge.actionRef(card.locator))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: try encoder.encode(reference)).map { String(format: "%02x", $0) }.joined()
        guard let itemID = UIStableID(rawValue: "history." + kind.rawValue + "." + digest) else {
            throw UIRouteError(.failed, "native_history_record_identity_invalid")
        }
        return try Record(reference: reference, title: card.book.book, itemID: itemID)
    }
    static func catalog(model: HistoryViewModel = .shared) throws -> [Record] {
        guard let publication = model.qualifiedPublication, publication.isCurrent(in: model) else { return [] }
        let history = model.filteredHistory, favorites = model.filteredFavorites
        let values = try publication.history.filter { card in history.contains { $0 === card.book } }
            .map { try record($0, kind: .history) }
            + publication.favorites.filter { card in favorites.contains { $0 === card.book } }
            .map { try record($0, kind: .favorite) }
        guard publication.isCurrent(in: model), Set(values.map(\.id)).count == values.count,
              Set(values.map(\.itemID)).count == values.count else {
            throw UIRouteError(.staleState, "native_history_record_catalog_changed")
        }
        return values
    }
    static func accessibilityID(book: BooksData, kind: Kind, model: HistoryViewModel) -> String {
        guard let publication = model.qualifiedPublication, publication.isCurrent(in: model) else { return "" }
        let cards = kind == .history ? publication.history : publication.favorites
        let matches = cards.filter { $0.book === book }
        guard matches.count == 1, let card = matches.first, let value = try? record(card, kind: kind) else { return "" }
        return "native-history-record-" + value.itemID.rawValue
    }
}

/// One retained record source and one canonical parent/row reveal. The original
/// List, BookCard and UIScrollView remain the sole UI and scrolling owners.
@MainActor final class MaktabahNativeHistoryRecordBinding {
    typealias Kind = NativeHistoryRecordIntentService.Kind
    typealias Record = NativeHistoryRecordIntentService.Record
    let sceneID: UIStableID
    private let bindings: MaktabahNativeSceneBindings
    private let workspaceSource: MaktabahNativeWorkspaceProjectionSource
    private weak var workspacePresentation: MaktabahNativeWorkspacePresentationBinding?
    private let commonReady: @MainActor () -> Bool
    private let windowReady: @MainActor () -> Bool
    private let readForeignPresentations: @MainActor () -> Void
    private var changed: (@MainActor () -> Void)?
    private var invalidated: (@MainActor () -> Void)?
    private var root: Root?
    private var rows: [RowKey: Row] = [:]
    private var source: Source?
    private var completed: Source?
    private var pending: Pending?

    private struct RowKey: Hashable {
        let book: ObjectIdentifier
        let section: String
        init(_ book: BooksData, _ kind: Kind) { self.book = ObjectIdentifier(book); section = kind.rawValue }
    }
    private final class Root {
        let token: UUID
        weak var view: UIView?
        weak var model: HistoryViewModel?
        var reveal: @MainActor (BooksData, Kind) -> Void
        init(token: UUID, view: UIView, model: HistoryViewModel,
             reveal: @escaping @MainActor (BooksData, Kind) -> Void) {
            self.token = token; self.view = view; self.model = model; self.reveal = reveal
        }
    }
    private final class Row {
        let token: UUID
        let root: UUID
        let kind: Kind
        weak var book: BooksData?
        weak var view: UIView?
        weak var scroll: MaktabahNativeHistoryScrollOwner?
        var blocked: Bool
        init(token: UUID, root: UUID, kind: Kind, book: BooksData, view: UIView,
             scroll: MaktabahNativeHistoryScrollOwner?, blocked: Bool) {
            self.token = token; self.root = root; self.kind = kind; self.book = book
            self.view = view; self.scroll = scroll; self.blocked = blocked
        }
    }
    private final class Source {
        enum Phase { case retained, applying, presented }
        let requestID: UUID
        let record: Record
        let card: HistoryQualifiedPublication.Card
        let publication: HistoryQualifiedPublication
        let model: HistoryViewModel
        let parent: MaktabahNativeHistoryRecordParentTransition
        let validateData: @MainActor () throws -> Void
        var rootToken: UUID?
        var rowToken: UUID?
        var phase: Phase = .retained
        var valid = true
        var revealed = false
        init(requestID: UUID, record: Record, card: HistoryQualifiedPublication.Card,
             publication: HistoryQualifiedPublication, model: HistoryViewModel,
             parent: MaktabahNativeHistoryRecordParentTransition, rootToken: UUID?, rowToken: UUID?,
             validateData: @escaping @MainActor () throws -> Void) {
            self.requestID = requestID; self.record = record; self.card = card; self.publication = publication
            self.model = model; self.parent = parent; self.rootToken = rootToken; self.rowToken = rowToken
            self.validateData = validateData
        }
    }
    private final class Pending {
        let source: Source
        let validate: @MainActor () throws -> Void
        var applied = false
        var rendering = false
        var vertical = false
        var horizontal = false
        init(source: Source, validate: @escaping @MainActor () throws -> Void) {
            self.source = source; self.validate = validate
        }
    }

    init(sceneID: UIStableID, bindings: MaktabahNativeSceneBindings,
         workspaceSource: MaktabahNativeWorkspaceProjectionSource,
         workspacePresentation: MaktabahNativeWorkspacePresentationBinding,
         commonReady: @escaping @MainActor () -> Bool,
         windowReady: @escaping @MainActor () -> Bool,
         readForeignPresentations: @escaping @MainActor () -> Void) {
        self.sceneID = sceneID; self.bindings = bindings; self.workspaceSource = workspaceSource
        self.workspacePresentation = workspacePresentation
        self.commonReady = commonReady; self.windowReady = windowReady
        self.readForeignPresentations = readForeignPresentations
    }
    func install(changed: @escaping @MainActor () -> Void, invalidated: @escaping @MainActor () -> Void) {
        self.changed = changed; self.invalidated = invalidated
    }

    var isAvailable: Bool {
        guard commonReady(), !bindings.showSettings.wrappedValue, bindings.isPresentationReady,
              bindings.manager.alertMessage == nil, workspaceSource.isAuthoritative,
              let workspace = try? workspaceSource.read(), workspace.attached, !workspace.isSwitching,
              workspace.sceneID == sceneID.rawValue, let mapping = workspace.mappingOwnershipObservation(),
              mapping.owner == ObjectIdentifier(bindings.manager), mapping.scene == sceneID.rawValue,
              bindings.rootPublications?.selectionRevision != nil,
              bindings.rootPublications?.settingsRevision != nil,
              workspacePresentation?.originalStateRevision != nil,
              bindings.manager.nativeModePresentationRevision != nil,
              bindings.manager.selectedBookPresentationRevision != nil else { return false }
        guard case .liveNativeSetters = mapping.coverage else { return false }
        return true
    }

    func retain(record: Record, requestID: UUID) throws {
        guard source == nil, pending == nil, isAvailable,
              let workspacePresentation, let workspaceRevision = workspacePresentation.originalStateRevision,
              let workspace = try workspaceSource.read(), let mapping = workspace.mappingOwnershipObservation() else {
            throw UIRouteError(.unavailable, "native_history_record_owner_unavailable")
        }
        let model = HistoryViewModel.shared, manager = bindings.manager
        guard let publication = model.qualifiedPublication, publication.isCurrent(in: model) else {
            throw UIRouteError(.unavailable, "native_history_record_publication_missing")
        }
        let candidates = record.reference.kind == .history ? publication.history : publication.favorites
        let matches = try candidates.filter { try MaktabahNativeHistoryRecords.record($0, kind: record.reference.kind).reference == record.reference }
        guard matches.count == 1, let card = matches.first,
              try MaktabahNativeHistoryRecords.record(card, kind: record.reference.kind) == record,
              try MaktabahNativeHistoryRecords.catalog(model: model).contains(record) else {
            throw UIRouteError(.staleState, "native_history_record_no_longer_published")
        }
        let parent = try MaktabahNativeHistoryRecordParentTransition(bindings: bindings)
        let reader = manager.activeReaderViewModel
        let observation = MaktabahNativeComponentSourceObservation {
            _ = try? workspaceSource.read(); _ = workspace.attached; _ = workspace.isSwitching
            _ = workspace.mappingOwnershipSource.event
            _ = manager.openTabs; _ = manager.activeTabId; _ = manager.selectedContentId
            _ = manager.selectedBookForInfo; _ = manager.showingTabsList; _ = manager.alertMessage
            _ = DonationManager.shared.showDonationSheet
            _ = reader?.isPopoverPresented; _ = reader?.readerInspectorVisible
            _ = model.qualifiedPublication; _ = model.historyBooks; _ = model.favoriteBooks
            _ = model.searchText; _ = model.historyOrder; _ = model.entriesByBookId
            readForeignPresentations()
        }
        let query = Array(model.searchText.utf8)
        let selected = Source(requestID: requestID, record: record, card: card, publication: publication,
            model: model, parent: parent, rootToken: root?.token,
            rowToken: rows[RowKey(card.book, record.reference.kind)]?.token) { [weak self, weak workspace, weak manager, weak workspacePresentation] in
                try observation.validate()
                guard let self, let workspace, let manager, let workspacePresentation, isAvailable,
                      self.workspacePresentation === workspacePresentation,
                      workspacePresentation.originalStateRevision == workspaceRevision,
                      let actualWorkspace = try workspaceSource.read(), actualWorkspace === workspace,
                      let actual = workspace.mappingOwnershipObservation(), actual.source === mapping.source,
                      actual.owner == mapping.owner, actual.scene == mapping.scene, actual.epoch == mapping.epoch,
                      actual.projection == mapping.projection, ObjectIdentifier(manager) == mapping.owner,
                      model.searchText.utf8.elementsEqual(query), publication.isCurrent(in: model),
                      card.book.backendLocator == card.locator,
                      try MaktabahNativeHistoryRecords.record(card, kind: record.reference.kind) == record,
                      try MaktabahNativeHistoryRecords.catalog(model: model).contains(record) else {
                    throw UIRouteError(.staleState, "native_history_record_source_changed")
                }
                guard case .liveNativeSetters = actual.coverage else {
                    throw UIRouteError(.staleState, "native_history_record_mapping_changed")
                }
            }
        try validate(selected)
        completed = nil; source = selected
    }

    func validateSource(requestID: UUID) throws {
        guard let source, source.requestID == requestID else {
            throw UIRouteError(.staleState, "native_history_record_request_changed")
        }
        try validate(source)
    }
    func selectedItem(requestID: UUID) throws -> UIStableID {
        try validateSource(requestID: requestID)
        guard let source, source.requestID == requestID else {
            throw UIRouteError(.staleState, "native_history_record_request_changed")
        }
        return source.record.itemID
    }
    private func validate(_ value: Source, rendered: Bool = false) throws {
        guard value.valid else { throw UIRouteError(.staleState, "native_history_record_retired") }
        try value.validateData()
        guard value.valid else { throw UIRouteError(.staleState, "native_history_record_retired") }
        switch value.phase {
        case .retained: try value.parent.validateBefore(bindings)
        case .presented: try value.parent.validateAfter(bindings, requiresPublishedMode: rendered || value.revealed)
        case .applying: throw UIRouteError(.staleState, "native_history_record_apply_in_progress")
        }
        if let token = value.rootToken {
            guard root?.token == token, root?.model === value.model, root?.view?.window != nil else {
                throw UIRouteError(.staleState, "native_history_record_root_replaced")
            }
        } else if root != nil && value.phase == .retained {
            throw UIRouteError(.staleState, "native_history_record_root_not_admitted")
        }
        let row = rows[RowKey(value.card.book, value.record.reference.kind)]
        if let token = value.rowToken {
            guard row?.token == token, row?.root == value.rootToken, row?.book === value.card.book,
                  row?.view?.window != nil, row?.blocked == false else {
                throw UIRouteError(.staleState, "native_history_record_row_replaced")
            }
        } else if row != nil && value.phase == .retained {
            throw UIRouteError(.staleState, "native_history_record_row_not_admitted")
        }
    }

    func begin(requestID: UUID, validate lifetime: @escaping @MainActor () throws -> Void) throws {
        guard pending == nil, let source, source.requestID == requestID, windowReady() else {
            throw UIRouteError(.unavailable, "native_history_record_not_ready")
        }
        try validate(source); try lifetime()
        guard self.source === source, source.valid else { throw UIRouteError(.staleState, "native_history_record_reentered") }
        pending = Pending(source: source, validate: lifetime)
    }
    func apply(requestID: UUID) throws {
        guard let value = pending, value.source === source, value.source.requestID == requestID, !value.applied else {
            throw UIRouteError(.staleState, "native_history_record_command_changed")
        }
        try validate(value.source); try value.validate()
        guard pending === value, value.source.valid else { throw UIRouteError(.staleState, "native_history_record_reentered") }
        value.source.phase = .applying
        do { try bindings.presentOriginalHistoryRecord(value.source.parent) }
        catch { retire(); throw error }
        value.source.phase = .presented
        guard pending === value, value.source.valid else { throw UIRouteError(.staleState, "native_history_record_reentered") }
        try validate(value.source)
        value.applied = true
        renderOriginalContainer()
        try value.validate(); try validate(value.source)
    }

    func attachRoot(token: UUID, view: UIView, model: HistoryViewModel,
                    reveal: @escaping @MainActor (BooksData, Kind) -> Void) {
        if let root, root.token == token, root.view === view, root.model === model {
            root.reveal = reveal; renderOriginalContainer(); return
        }
        if root != nil || source?.phase == .retained { retire() }
        root = Root(token: token, view: view, model: model, reveal: reveal)
        if let value = pending, value.applied, value.source.rootToken == nil {
            value.source.rootToken = token
            if let row = rows[RowKey(value.source.card.book, value.source.record.reference.kind)],
               row.root == token, row.book === value.source.card.book, row.view?.window != nil {
                value.source.rowToken = row.token
            }
        }
        renderOriginalContainer(); changed?()
    }
    func detachRoot(token: UUID, view: UIView) {
        guard root?.token == token, root?.view === view else { return }
        retire(); root = nil; rows.removeAll(); changed?()
    }
    func observeRow(token: UUID, root rootToken: UUID, kind: Kind, book: BooksData,
                    view: UIView, scroll: MaktabahNativeHistoryScrollOwner?, blocked: Bool) {
        let key = RowKey(book, kind)
        var ownershipChanged = false
        if let old = rows[key], old.token == token, old.root == rootToken, old.view === view {
            if old.blocked != blocked { originalStateWillChange(root: rootToken); ownershipChanged = true }
            if old.scroll !== scroll { originalStateWillChange(root: rootToken); ownershipChanged = true }
            old.blocked = blocked; old.scroll = scroll
        } else {
            if let target = source ?? completed, target.card.book === book, target.record.reference.kind == kind,
               rows[key] != nil || target.phase == .retained { retire() }
            rows[key] = Row(token: token, root: rootToken, kind: kind, book: book, view: view, scroll: scroll, blocked: blocked)
            ownershipChanged = true
        }
        if let value = pending, value.applied, value.source.rowToken == nil,
           value.source.card.book === book, value.source.record.reference.kind == kind,
           value.source.rootToken == rootToken { value.source.rowToken = token }
        renderOriginalContainer()
        // Stable UIViewRepresentable updates are not source changes and must
        // not create a SwiftUI update/layout loop. Actual geometry is read live.
        if ownershipChanged { changed?() }
    }
    func detachRow(token: UUID, kind: Kind, book: BooksData) {
        let key = RowKey(book, kind)
        guard rows[key]?.token == token else { return }
        if source?.rowToken == token || completed?.rowToken == token { retire() }
        rows.removeValue(forKey: key); changed?()
    }
    func originalStateWillChange(root token: UUID) {
        guard root?.token == token else { return }
        retire()
    }
    func originalForeignStateWillChange() { retire() }

    func renderOriginalContainer() {
        guard let value = pending, value.applied, !value.rendering, value.source === source,
              let root, let view = root.view, view.window != nil,
              view.bounds.width > 1, view.bounds.height > 1, windowReady() else { return }
        do {
            try validate(value.source); try value.validate()
            // The original TabView's own mode publication may follow its
            // selection setter. Keep the same admission until that publication.
            guard bindings.manager.currentMode == .history,
                  bindings.manager.nativeModePresentationRevision == value.source.parent.presentedModeRevision else { return }
            try validate(value.source, rendered: true)
            guard pending === value, self.root === root, value.source.valid else {
                throw UIRouteError(.staleState, "native_history_record_render_changed")
            }
            value.rendering = true
            defer { value.rendering = false }
            if !value.vertical {
                value.vertical = true
                root.reveal(value.source.card.book, value.source.record.reference.kind)
                try validate(value.source, rendered: true); try value.validate()
            }
            if value.source.record.reference.kind == .history {
                guard let row = rows[RowKey(value.source.card.book, .history)],
                      row.token == value.source.rowToken, row.root == root.token,
                      let original = row.view, let scroll = row.scroll else { return }
                if !value.horizontal {
                    guard scroll.canReveal(original, in: sceneID) else { return }
                    value.horizontal = true
                    try scroll.reveal(original, in: sceneID)
                    try validate(value.source, rendered: true); try value.validate()
                }
            }
            guard pending === value, value.source.valid else { throw UIRouteError(.staleState, "native_history_record_render_changed") }
            if !value.source.revealed {
                value.source.revealed = true
                changed?()
            }
        } catch { retire() }
    }

    func observedItem() throws -> UIStableID? {
        guard let value = source ?? completed, value.revealed else { return nil }
        try validate(value, rendered: true)
        guard windowReady(), let root, root.token == value.rootToken,
              let row = rows[RowKey(value.card.book, value.record.reference.kind)], row.token == value.rowToken,
              row.root == root.token, row.book === value.card.book, !row.blocked,
              let view = row.view, MaktabahNativeHistoryRecordGeometry.isVisible(view, sceneID: sceneID) else { return nil }
        return value.record.itemID
    }
    func withValidatedRecord(requestID: UUID, _ report: @MainActor () throws -> Void) throws {
        guard let value = pending, value.applied, value.source === source,
              value.source.requestID == requestID else { throw UIRouteError(.staleState, "native_history_record_report_changed") }
        let executed: Bool? = try value.source.publication.withCurrent(in: value.source.model) {
            try validate(value.source, rendered: true); try value.validate()
            guard pending === value, source === value.source, try observedItem() == value.source.record.itemID else {
                throw UIRouteError(.staleState, "native_history_record_not_visible")
            }
            try report()
            try validate(value.source, rendered: true)
            guard pending === value, source === value.source, value.source.valid else {
                throw UIRouteError(.staleState, "native_history_record_report_reentered")
            }
            return true
        }
        guard executed == true else { throw UIRouteError(.staleState, "native_history_record_store_changed") }
    }
    func finish(requestID: UUID, completed success: Bool) {
        guard let value = pending, value.source.requestID == requestID else { return }
        if success, value.source.valid, (try? observedItem()) == value.source.record.itemID { completed = value.source }
        else { value.source.valid = false; completed = nil }
        pending = nil
    }
    func releaseSource(requestID: UUID) {
        guard let source, source.requestID == requestID else { return }
        if pending?.source === source { retire(); pending = nil }
        if completed !== source { source.valid = false }
        self.source = nil
    }
    func clearCompletedProof() { completed?.valid = false; completed = nil }
    func retire() {
        source?.valid = false; completed?.valid = false
        invalidated?()
    }
    func unmount() { retire(); pending = nil; source = nil; completed = nil; root = nil; rows.removeAll() }
}
#endif
