#if os(iOS)
import Foundation
@preconcurrency import Combine
import UIKit
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// One scene's ORIGINAL annotations collection. This owner has no database,
/// Reader, backend, editor or replacement view operation. Its sole effect is a
/// bounded synchronous reveal/selection on a retained original collection row.
@MainActor final class MaktabahNativeAnnotationSelectionBinding {
    typealias Record = NativeAnnotationSelectionIntentService.Record
    typealias OriginalRow = iOSAnnotationViewController.NativeRoutingRow
    static let destination = NativeAnnotationSelectionIntentService.destination

    @MainActor private final class Host {
        let token: UUID
        weak var controller: iOSAnnotationViewController?
        weak var model: AnnotationViewModel?
        var blocked: @MainActor () -> Bool
        init(controller: iOSAnnotationViewController, model: AnnotationViewModel, token: UUID,
             blocked: @escaping @MainActor () -> Bool) {
            self.controller = controller; self.model = model; self.token = token; self.blocked = blocked
        }
    }
    @MainActor private final class Catalog {
        struct Entry { let record: Record; let row: OriginalRow }
        let host: Host
        let entries: [Entry]
        private let modelPublication: MaktabahNativeAnnotationListPublication.Witness
        private let collectionPublication: MaktabahNativeAnnotationListPublication.Witness
        private let observation: MaktabahNativeComponentSourceObservation
        private let storePublication: NativeComponentSourceObservation
        private let storeEvents: AnyCancellable
        private var valid = true

        init(host: Host, sceneID: UIStableID) throws {
            guard let controller = host.controller, let model = host.model, controller.viewModel === model,
                  model.state == .loaded, !host.blocked() else { throw Self.stale() }
            self.host = host
            // Install the actual original publication witnesses before reading
            // the list. Store.events is a POST-transaction publication; this
            // proves the original displayed source, not a SQLite write lock.
            modelPublication = try model.nativeRoutingPublication.capture()
            collectionPublication = try controller.nativeRoutingPublication.capture()
            let storePublication = NativeComponentSourceObservation(read: {})
            self.storePublication = storePublication
            storeEvents = AnnotationStore.shared.events.sink { _ in storePublication.invalidate() }
            observation = MaktabahNativeComponentSourceObservation {
                _ = model.state; _ = model.searchText; _ = model.searchScope
                _ = model.groupingMode; _ = model.sortField; _ = model.sortAscending
                _ = model.selectedTags; _ = model.tagFilterMode
            }
            let backend = ActionAppIdentityBridge.actionBackend(BackendCoordinator.shared.activeBackendID)
            var entries: [Entry] = []
            for row in try controller.nativeRoutingRows() {
                let annotation = row.annotation
                let locator = annotation.backendLocator
                    ?? (annotation.bkId < 0 ? LegacyIdentityRegistry.shared.locator(for: annotation.bkId) : nil)
                let rowBackend = locator.map { ActionAppIdentityBridge.actionBackend($0.backend) }
                    ?? (annotation.bkId > 0 ? .otzaria : nil)
                guard rowBackend == backend else { continue }
                let title = String(String.UnicodeScalarView(row.item.node.title.unicodeScalars.prefix(256)))
                guard let record = try? Record(reference: .init(backend: backend, token: UUID()),
                                               title: title, sceneID: sceneID) else { continue }
                entries.append(Entry(record: record, row: row))
            }
            self.entries = entries
            try validate()
        }
        func retire() { valid = false; storePublication.invalidate() }
        func validate() throws {
            try storePublication.validate(); try observation.validate()
            try modelPublication.validate(); try collectionPublication.validate()
            guard valid, let model = host.model, let controller = host.controller,
                  controller.viewModel === model, model.state == .loaded, !host.blocked() else { throw Self.stale() }
            // A getter may reenter an original setter. Recheck after it; no
            // callback may recapture or replace this one-way observation.
            try storePublication.validate(); try observation.validate()
            try modelPublication.validate(); try collectionPublication.validate()
            guard valid else { throw Self.stale() }
        }
        func entry(_ record: Record) throws -> Entry {
            try validate()
            let matches = entries.filter { $0.record == record }
            guard matches.count == 1, let entry = matches.first,
                  host.controller?.nativeRoutingMatches(entry.row) == true else { throw Self.stale() }
            try validate()
            return entry
        }
        private static func stale() -> UIRouteError {
            UIRouteError(.staleState, "native_annotation_catalog_changed")
        }
    }
    @MainActor private final class Source {
        let requestID: UUID
        let catalog: Catalog
        let entry: Catalog.Entry
        let window: MaktabahNativeWindowObservation
        let validateForeign: @MainActor () throws -> Void
        var valid = true
        var applied = false
        init(requestID: UUID, catalog: Catalog, entry: Catalog.Entry, window: MaktabahNativeWindowObservation,
             validateForeign: @escaping @MainActor () throws -> Void) {
            self.requestID = requestID; self.catalog = catalog; self.entry = entry
            self.window = window; self.validateForeign = validateForeign
        }
    }
    @MainActor private final class Pending {
        enum Phase { case ready, applying, applied }
        let source: Source
        let validate: @MainActor () throws -> Void
        var phase = Phase.ready
        init(source: Source, validate: @escaping @MainActor () throws -> Void) {
            self.source = source; self.validate = validate
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
    private let publishOriginalUIKitPresentation: (@MainActor (UUID) -> Void)?
    private var publishingOriginalUIKitPresentation = false
    private var host: Host?
    private var catalogSource: Catalog?
    private var retained: Source?
    private var completed: Source?
    private var pending: Pending?
    private var accessing = false
    private var checkingPending = false
    private var reporting = false
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
         readForeignPresentations: @escaping @MainActor () -> Void,
         originalUIKitPresentationWillChange: (@MainActor (UUID) -> Void)? = nil) {
        self.sceneID = sceneID; self.bindings = bindings; self.workspaceSource = workspaceSource
        self.workspacePresentation = workspacePresentation; self.commonReady = commonReady
        self.windowReady = windowReady; self.retainWindow = retainWindow; readForeign = readForeignPresentations
        publishOriginalUIKitPresentation = originalUIKitPresentationWillChange
    }
    func install(changed: @escaping @MainActor () -> Void, invalidated: @escaping @MainActor () -> Void) {
        self.changed = changed; self.invalidated = invalidated
    }

    /// Metadata may remain available in a background scene. The actual window
    /// and foreground admission are independently required before any effect.
    var isAvailable: Bool {
        guard mounted, !retiring, !hasOriginalUIKitPresentation, lifetime != nil, let host, let controller = host.controller,
              let model = host.model, model === bindings.manager.annotationViewModel,
              controller.viewModel === model, controller.isViewLoaded, model.state == .loaded,
              !model.nativeRoutingPublication.searchPending, !host.blocked(), commonReady(),
              bindings.selectedTab.wrappedValue == .annotations, bindings.manager.currentMode == .annotations,
              !bindings.showSettings.wrappedValue, bindings.isPresentationReady,
              bindings.manager.alertMessage == nil, !BackendCoordinator.shared.isTransitioning,
              iOSTab.annotations.isAvailable(for: BackendCoordinator.shared.activeCapabilities) else { return false }
        return true
    }

    func catalog() throws -> [Record] {
        guard !accessing, !retiring, retained == nil, pending == nil, let revision = lifetime else { return [] }
        accessing = true; defer { accessing = false }
        guard isAvailable, let host else { return [] }
        if let current = catalogSource {
            do { try current.validate() }
            catch { current.retire(); catalogSource = nil }
        }
        if catalogSource == nil {
            let next = try Catalog(host: host, sceneID: sceneID)
            guard self.host === host, lifetime == revision, mounted, isAvailable,
                  retained == nil, pending == nil, catalogSource == nil else {
                next.retire(); throw stale()
            }
            catalogSource = next
        }
        guard let source = catalogSource, source.host === host else { throw stale() }
        try source.validate()
        guard catalogSource === source, self.host === host, lifetime == revision,
              retained == nil, pending == nil else { throw stale() }
        return source.entries.map(\.record)
    }

    /// Read-only capture of the SAME cached original row for the original List
    /// Edit action. Its independent publications survive only catalog retirement
    /// caused by presenting that editor; no list/Store/backend event is waived.
    @MainActor final class OriginalEditorRecord {
        let record: Record
        let annotation: Annotation
        let listOwner: UUID
        private let check: @MainActor () throws -> Void
        private let checkVisible: @MainActor (UIWindow) throws -> Void
        private let invalidateSource: @MainActor () -> Void
        private var valid = true
        private var checking = false
        fileprivate init(record: Record, annotation: Annotation, listOwner: UUID,
                         check: @escaping @MainActor () throws -> Void,
                         checkVisible: @escaping @MainActor (UIWindow) throws -> Void,
                         invalidate: @escaping @MainActor () -> Void) {
            self.record = record; self.annotation = annotation; self.listOwner = listOwner
            self.check = check; self.checkVisible = checkVisible; invalidateSource = invalidate
        }
        func validateVisibleList(in window: UIWindow) throws {
            try validate(); try checkVisible(window); try validate()
        }
        func validate() throws {
            guard valid, !checking else { retire(); throw Self.stale() }
            checking = true; defer { checking = false }
            do {
                try check()
                guard valid else { throw Self.stale() }
            } catch { retire(); throw error }
        }
        func retire() { valid = false; invalidateSource() }
        private static func stale() -> UIRouteError {
            .init(.staleState, "native_annotation_original_editor_record_changed")
        }
    }

    func captureOriginalEditorRecord(_ record: Record) throws -> OriginalEditorRecord {
        guard !accessing, !retiring, retained == nil, pending == nil,
              let revision = lifetime, isAvailable, let host, let catalog = catalogSource,
              catalog.host === host, record.sceneID == sceneID,
              let controller = host.controller, let model = host.model else { throw stale() }
        accessing = true; defer { accessing = false }
        let entry = try catalog.entry(record)
        // These are NEW, independent observers of the existing original source,
        // installed synchronously before capture returns and BEFORE any await.
        // The old catalog's retire() never owns or rearms these observers.
        let modelPublication = try model.nativeRoutingPublication.capture()
        let collectionPublication = try controller.nativeRoutingPublication.capture()
        let storePublication = NativeComponentSourceObservation(read: {})
        let storeEvents = AnnotationStore.shared.events.sink { _ in storePublication.invalidate() }
        let observation = MaktabahNativeComponentSourceObservation {
            _ = model.state; _ = model.searchText; _ = model.searchScope
            _ = model.groupingMode; _ = model.sortField; _ = model.sortAscending
            _ = model.selectedTags; _ = model.tagFilterMode
        }
        let source = OriginalEditorRecord(record: record, annotation: entry.row.annotation,
            listOwner: host.token, check: { [weak self, weak controller, weak model] in
                _ = storeEvents // retain the exact original Store subscription
                try storePublication.validate(); try observation.validate()
                try modelPublication.validate(); try collectionPublication.validate()
                guard let self, let controller, let model, self.mounted, !self.retiring,
                      self.host === host, host.controller === controller, host.model === model,
                      model === self.bindings.manager.annotationViewModel, controller.viewModel === model,
                      model.state == .loaded, !model.nativeRoutingPublication.searchPending,
                      controller.nativeRoutingMatches(entry.row) else {
                    throw UIRouteError(.staleState, "native_annotation_original_editor_record_changed")
                }
                try storePublication.validate(); try observation.validate()
                try modelPublication.validate(); try collectionPublication.validate()
                guard self.mounted, !self.retiring, self.host === host,
                      host.controller === controller, host.model === model else { throw self.stale() }
            }, checkVisible: { [weak controller] window in
                guard let controller, let view = controller.viewIfLoaded, view.window === window,
                      !controller.isBeingDismissed, !controller.isMovingFromParent,
                      controller.presentedViewController == nil else {
                    throw UIRouteError(.unavailable, "native_annotation_original_list_not_visible")
                }
                let actual = MaktabahNativeSavedResultsGeometry.evidence(view)
                guard actual.foreground, !actual.hidden, !actual.transitioning, actual.alpha >= 0.95,
                      actual.visible.width > 1, actual.visible.height > 1 else {
                    throw UIRouteError(.unavailable, "native_annotation_original_list_not_visible")
                }
            }, invalidate: {
                storePublication.invalidate(); observation.invalidate()
            })
        do {
            try catalog.validate()
            guard mounted, lifetime == revision, self.host === host, catalogSource === catalog,
                  retained == nil, pending == nil, isAvailable else { throw stale() }
            try source.validate()
            try catalog.validate()
            guard mounted, lifetime == revision, self.host === host, catalogSource === catalog,
                  retained == nil, pending == nil else { throw stale() }
            return source
        } catch { source.retire(); throw error }
    }

    /// Called before the FIRST foreground/Core await. No alternate catalog,
    /// model, row, window or source can join this request after this capture.
    func retain(record: Record, requestID: UUID) throws {
        guard !accessing, !retiring, retained == nil, pending == nil, let revision = lifetime else { throw stale() }
        accessing = true; defer { accessing = false }
        guard isAvailable, let host, let catalog = catalogSource, catalog.host === host,
              record.sceneID == sceneID, let workspacePresentation,
              let workspaceRevision = workspacePresentation.originalStateRevision,
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
              let bookRevision = bindings.manager.selectedBookPresentationRevision else { throw stale() }
        let entry = try catalog.entry(record)
        let window = try retainWindow()
        _ = try window.validate()
        let manager = bindings.manager, model = manager.annotationViewModel
        let book = manager.selectedBook, bookMode = manager.selectedBookPresentationMode
        let reader = manager.activeReaderViewModel
        let observation = MaktabahNativeComponentSourceObservation {
            _ = try? self.workspaceSource.read(); _ = workspace.attached; _ = workspace.isSwitching
            _ = workspace.errorMessage; _ = workspace.store.loadError
            _ = mapping.source.event; _ = stored.source.event
            _ = root.selectionRevision; _ = root.settingsRevision
            _ = manager.currentMode; _ = manager.selectedBook; _ = manager.selectedBookPresentationMode
            _ = manager.openTabs; _ = manager.activeTabId; _ = manager.selectedContentId
            _ = manager.annotationViewModel; _ = manager.selectedBookForInfo
            _ = manager.showingTabsList; _ = manager.alertMessage
            _ = reader?.currentBook; _ = reader?.currentDestination; _ = reader?.isPopoverPresented
            _ = reader?.readerInspectorVisible; _ = DonationManager.shared.showDonationSheet
            self.readForeign()
        }
        let source = Source(requestID: requestID, catalog: catalog, entry: entry, window: window) {
            [weak self, weak workspace, weak manager, weak model, weak workspacePresentation] in
            try observation.validate(); _ = try window.validate()
            guard let self, let workspace, let manager, let model, let workspacePresentation,
                  self.mounted, self.lifetime == revision, self.isAvailable,
                  self.host === host, self.catalogSource === catalog,
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
                  root.settingsRevision == settingsRevision, manager.nativeModePresentationRevision == modeRevision,
                  manager.selectedBookPresentationRevision == bookRevision,
                  manager.selectedBook === book, manager.selectedBookPresentationMode == bookMode,
                  manager.annotationViewModel === model, host.model === model else { throw UIRouteError(.staleState, "native_annotation_foreign_source_changed") }
            try observation.validate(); _ = try window.validate()
        }
        guard mounted, lifetime == revision, self.host === host, catalogSource === catalog,
              retained == nil, pending == nil else { source.valid = false; throw stale() }
        completed?.valid = false; completed = nil; retained = source
        do { try validate(source) }
        catch { releaseSource(requestID: requestID); throw error }
    }

    func validateSource(requestID: UUID) throws {
        guard let source = retained, source.requestID == requestID else { throw stale() }
        try validate(source)
    }
    func selectedItem(requestID: UUID) throws -> UIStableID {
        guard let source = retained, source.requestID == requestID else { throw stale() }
        try validate(source); return source.entry.record.itemID
    }
    func begin(requestID: UUID, validate: @escaping @MainActor () throws -> Void) throws {
        guard !accessing, !retiring, pending == nil, let source = retained,
              source.requestID == requestID else { throw stale() }
        accessing = true; defer { accessing = false }
        try self.validate(source); try validate(); try self.validate(source)
        guard retained === source, pending == nil, windowReady() else { throw stale() }
        try requireHost(source)
        guard retained === source, pending == nil else { throw stale() }
        pending = Pending(source: source, validate: validate)
    }
    func apply(requestID: UUID) throws {
        guard !reporting, let value = pending, value.source === retained,
              value.source.requestID == requestID, value.phase == .ready else { throw stale() }
        // Consume before ANY validation/UI callback; a callback cannot enter a
        // second apply on the same request, even while the first is validating.
        value.phase = .applying
        do {
            try validatePending(value); try requireHost(value.source)
            guard let controller = value.source.catalog.host.controller else { throw stale() }
            try controller.nativeRoutingReveal(value.source.entry.row) { [weak self, weak value] in
                guard let self, let value, value.phase == .applying else {
                    throw UIRouteError(.staleState, "native_annotation_apply_retired")
                }
                try self.validatePending(value); try self.requireHost(value.source)
            }
            try validatePending(value)
            guard value.phase == .applying else { throw stale() }
            value.source.applied = true; value.phase = .applied
            changed?()
            try validatePending(value)
        } catch { retire(); throw error }
    }

    func observedItem(requestID: UUID) -> UIStableID? {
        guard let source = pending?.source ?? completed, source.requestID == requestID else { return nil }
        do { try validateVisible(source); return source.entry.record.itemID } catch { return nil }
    }
    func hasVisibleSurface(requestID: UUID) -> Bool {
        guard let source = pending?.source ?? completed, source.requestID == requestID else { return false }
        return (try? validateVisible(source)) != nil
    }
    func validateCompletedSurface(requestID: UUID) throws {
        guard let source = completed, source.requestID == requestID else { throw stale() }
        try validateVisible(source)
    }
    func withValidatedSurface<T>(requestID: UUID, report: @MainActor () throws -> T) throws -> T {
        guard !reporting, let value = pending, value.source.requestID == requestID else { throw stale() }
        reporting = true; defer { reporting = false }
        try requireSurface(value)
        let result = try report()
        try requireSurface(value)
        return result
    }
    func finish(requestID: UUID, completed success: Bool) {
        guard !accessing, let value = pending, value.source.requestID == requestID else { return }
        accessing = true; defer { accessing = false }
        let accepted = success && (try? requireSurface(value)) != nil
        guard pending === value, retained === value.source, value.source.valid else { return }
        pending = nil
        if accepted { completed = value.source }
        else { retire() }
    }
    func releaseSource(requestID: UUID) {
        guard let source = retained, source.requestID == requestID else { return }
        if pending != nil || completed !== source { retire() }
        if retained === source { retained = nil }
    }
    func clearCompletedProof() { completed?.valid = false; completed = nil }

    func attach(controller: iOSAnnotationViewController, model: AnnotationViewModel, owner: UUID,
                blocked: @escaping @MainActor () -> Bool) {
        guard mounted, !retiring, model === bindings.manager.annotationViewModel,
              controller.viewModel === model else { return }
        if let host, host.token == owner, host.controller === controller, host.model === model {
            host.blocked = blocked; return
        }
        retire()
        guard mounted, !retiring else { return }
        host = Host(controller: controller, model: model, token: owner, blocked: blocked)
        changed?()
    }
    func detach(controller: iOSAnnotationViewController, owner: UUID) {
        guard let host, host.token == owner, host.controller === controller else { return }
        self.host = nil; retire(); changed?()
    }
    func originalModalWillChange(owner: UUID) {
        guard host?.token == owner else { return }
        retire()
    }
    /// Actual current UIKit modality, including the synchronous publication
    /// callback itself. This is a blocker, never a synthetic presentation ACK.
    var hasOriginalUIKitPresentation: Bool {
        publishingOriginalUIKitPresentation || host?.controller?.presentedViewController != nil
    }
    func originalUIKitPresentationWillChange(controller: iOSAnnotationViewController, owner: UUID) {
        guard mounted, !retiring, let host, host.token == owner,
              host.controller === controller else { return }
        guard !publishingOriginalUIKitPresentation else {
            controller.nativeRoutingPublication.willPublish(); retire(); return
        }
        publishingOriginalUIKitPresentation = true
        defer { publishingOriginalUIKitPresentation = false }
        // Fixed original source invalidation precedes every arbitrary callback.
        controller.nativeRoutingPublication.willPublish()
        retire()
        guard mounted, !retiring, self.host === host, host.controller === controller else { return }
        publishOriginalUIKitPresentation?(owner)
    }
    func hostLayoutChanged(controller: iOSAnnotationViewController, owner: UUID) {
        guard let host, host.token == owner, host.controller === controller else { return }
        // Layout only wakes the existing bounded observation. It cannot grant,
        // select, scroll, reattach a source or issue another preparation.
        changed?()
    }
    func retire() {
        guard !retiring else { return }
        retiring = true; defer { retiring = false }
        if let old = lifetime { lifetime = old < .max ? old + 1 : nil }
        let active = retained != nil || pending != nil || completed != nil
        retained?.valid = false; completed?.valid = false
        retained = nil; pending = nil; completed = nil
        catalogSource?.retire(); catalogSource = nil
        if active { invalidated?() }
    }
    func unmount() {
        mounted = false; host = nil; retire(); changed = nil; invalidated = nil
    }

    private func validate(_ source: Source) throws {
        guard mounted, source.valid, retained === source || completed === source,
              catalogSource === source.catalog, host === source.catalog.host else { throw stale() }
        try source.validateForeign(); try source.catalog.validate()
        guard source.catalog.host.controller?.nativeRoutingMatches(source.entry.row) == true else { throw stale() }
        guard mounted, source.valid, retained === source || completed === source,
              catalogSource === source.catalog, host === source.catalog.host else { throw stale() }
        try source.catalog.validate()
    }
    private func validatePending(_ value: Pending) throws {
        guard !checkingPending, pending === value, retained === value.source, value.source.valid else { throw stale() }
        checkingPending = true; defer { checkingPending = false }
        try validate(value.source); try value.validate(); try validate(value.source)
        guard pending === value, retained === value.source, value.source.valid else { throw stale() }
    }
    private func requireHost(_ source: Source) throws {
        let window = try source.window.validate()
        guard windowReady(), let controller = source.catalog.host.controller,
              let original = controller.viewIfLoaded, original.window === window,
              !controller.isBeingDismissed, !controller.isMovingFromParent,
              window.windowScene?.session.persistentIdentifier == sceneID.rawValue else { throw stale() }
        let actual = MaktabahNativeSavedResultsGeometry.evidence(original)
        guard actual.foreground, !actual.hidden, !actual.transitioning, actual.alpha >= 0.95,
              actual.visible.width > 1, actual.visible.height > 1 else {
            throw UIRouteError(.unavailable, "native_annotation_original_list_not_visible")
        }
    }
    private func validateVisible(_ source: Source) throws {
        try validate(source); try requireHost(source)
        guard source.applied, pending?.source !== source || pending?.phase == .applied,
              let controller = source.catalog.host.controller, let original = controller.viewIfLoaded,
              let cell = controller.nativeRoutingSelectedCell(source.entry.row), cell.isDescendant(of: original),
              cell.window === (try source.window.validate()) else {
            throw UIRouteError(.unavailable, "native_annotation_selected_cell_not_visible")
        }
        let actual = MaktabahNativeSavedResultsGeometry.evidence(cell)
        guard actual.foreground, !actual.hidden, !actual.transitioning, actual.alpha >= 0.95,
              actual.frame.origin.x.isFinite, actual.frame.origin.y.isFinite,
              actual.frame.width.isFinite, actual.frame.height.isFinite,
              actual.frame.width > 1, actual.frame.height > 1, !actual.visible.isNull,
              actual.visible.width * actual.visible.height >= actual.frame.width * actual.frame.height * 0.98 else {
            throw UIRouteError(.unavailable, "native_annotation_selected_cell_not_visible")
        }
        try validate(source)
    }
    private func requireSurface(_ value: Pending) throws {
        try validatePending(value)
        guard value.phase == .applied else { throw stale() }
        try validateVisible(value.source); try validatePending(value)
    }
    private func stale() -> UIRouteError {
        UIRouteError(.staleState, "native_annotation_selection_source_changed")
    }
}
#endif
