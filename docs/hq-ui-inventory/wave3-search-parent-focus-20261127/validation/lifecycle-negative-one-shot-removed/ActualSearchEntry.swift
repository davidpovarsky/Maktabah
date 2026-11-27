import Foundation

/// Publication history owned by the ORIGINAL scene's State bindings. Values
/// remain in those bindings; this object cannot select a tab or cache a mode.
/// Equal-value writes count, and exhaustion permanently refuses retained proof.
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

/// Expected publications by the ORIGINAL root and optional phone stack owners.
/// The source-owned counters cannot be reset or supplied by a public route.
@MainActor
struct MaktabahNativeSearchEntryParentTransition {
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
            throw UIRouteError(.unavailable, "native_search_entry_parent_unavailable")
        }
        self.modeRevision = modeRevision; self.bookRevision = bookRevision
        self.rootPublications = rootPublications
        self.selectionRevision = selectionRevision; self.settingsRevision = settingsRevision
        book = manager.selectedBook; bookMode = manager.selectedBookPresentationMode
        changesTab = tab != .search
        popsBook = !MaktabahApp.isIpad && book != nil
        guard (!changesTab || (selectionRevision < .max && modeRevision < .max)),
              (!popsBook || bookRevision < .max) else {
            throw UIRouteError(.staleState, "native_search_entry_parent_exhausted")
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
            throw UIRouteError(.staleState, "native_search_entry_parent_changed")
        }
    }

    func validateAfter(_ bindings: MaktabahNativeSceneBindings, requiresPublishedMode: Bool) throws {
        let manager = bindings.manager
        let published = manager.currentMode == .search
            && manager.nativeModePresentationRevision == presentedModeRevision
        let awaitingOriginalPublisher = changesTab && !requiresPublishedMode
            && manager.currentMode == mode && manager.nativeModePresentationRevision == modeRevision
        guard bindings.rootPublications === rootPublications,
              rootPublications.selectionRevision == presentedSelectionRevision,
              rootPublications.settingsRevision == settingsRevision,
              bindings.selectedTab.wrappedValue == .search, published || awaitingOriginalPublisher,
              manager.selectedBook === (popsBook ? nil : book),
              manager.selectedBookPresentationMode == (popsBook ? nil : bookMode),
              manager.selectedBookPresentationRevision == presentedBookRevision else {
            throw UIRouteError(.staleState, "native_search_entry_parent_transition_changed")
        }
    }
}

/// Additive parent-then-focus contract for the SAME original search input.
/// `native.search.query` remains the separate, already-visible-only contract.
/// Core/Registry still own the sole command. This binding retains source and
/// renders that command through an actual original field, never a fallback UI.
@MainActor
final class MaktabahNativeSearchEntryBinding {
    static let destination = UIDestinationID(rawValue: "native.search")!
    static let anchor = UIDestinationID(rawValue: "native.search.queryEntry")!
    static var descriptors: [MaktabahNativeComponentDescriptor] {
        [.init(anchor: anchor, title: String(localized: "Open query input"))]
    }

    let sceneID: UIStableID
    private let bindings: MaktabahNativeSceneBindings
    private let workspaceSource: MaktabahNativeWorkspaceProjectionSource
    private let commonReady: @MainActor () -> Bool
    private let windowReady: @MainActor () -> Bool
    private let parentVisible: @MainActor () -> Bool
    private var registration: FieldRegistration?
    private var presentationOwner: UUID?
    private var activeSource: Source?
    private weak var completedSource: Source?
    private var pending: Pending?

    lazy var owner: MaktabahNativeComponentOwner = .init(
        destination: Self.destination, presentation: .currentTab, descriptors: Self.descriptors,
        available: { [weak self] anchor in anchor == Self.anchor && self?.isAvailable == true },
        captureSource: { [weak self] anchor in
            guard let self, anchor == Self.anchor, let source = activeSource else {
                throw UIRouteError(.unavailable, "native_search_entry_source_missing")
            }
            try validate(source)
            return { [weak self, source] in
                guard let self, activeSource === source || completedSource === source else {
                    throw UIRouteError(.staleState, "native_search_entry_source_replaced")
                }
                try validate(source)
            }
        }
    )

    private final class FieldRegistration {
        let token = UUID()
        weak var field: UISearchTextField?
        weak var window: UIWindow?
        var hasAttached = false
        var layoutRevision: UInt64 = 0
        var previousEvidence: NativeComponentEvidence?
        init(_ field: UISearchTextField) { self.field = field }
    }
    private final class Source {
        enum Phase: Equatable { case retained, applying, presented }
        let requestID: UUID
        let parent: MaktabahNativeSearchEntryParentTransition
        let query: [UInt8]
        let validateData: @MainActor () throws -> Void
        var fieldToken: UUID?
        var presentationOwner: UUID?
        var phase: Phase = .retained
        var focused = false
        var valid = true
        init(requestID: UUID, parent: MaktabahNativeSearchEntryParentTransition,
             query: [UInt8], fieldToken: UUID?, presentationOwner: UUID?,
             validateData: @escaping @MainActor () throws -> Void) {
            self.requestID = requestID; self.parent = parent; self.query = query
            self.fieldToken = fieldToken; self.presentationOwner = presentationOwner; self.validateData = validateData
        }
    }
    private final class Pending {
        let source: Source
        let validate: @MainActor () throws -> Void
        var applied = false
        var rendering = false
        init(source: Source, validate: @escaping @MainActor () throws -> Void) {
            self.source = source; self.validate = validate
        }
    }

    init(sceneID: UIStableID, bindings: MaktabahNativeSceneBindings,
         workspaceSource: MaktabahNativeWorkspaceProjectionSource,
         commonReady: @escaping @MainActor () -> Bool,
         windowReady: @escaping @MainActor () -> Bool,
         parentVisible: @escaping @MainActor () -> Bool) {
        self.sceneID = sceneID; self.bindings = bindings; self.workspaceSource = workspaceSource
        self.commonReady = commonReady; self.windowReady = windowReady; self.parentVisible = parentVisible
    }

    var isAvailable: Bool {
        let manager = bindings.manager, session = bindings.manager.unifiedSearchSession
        guard commonReady(), !bindings.showSettings.wrappedValue, bindings.isPresentationReady,
              manager.alertMessage == nil,
              MaktabahNativeRootDestination.search.isAvailable,
              session.searchViewModel === manager.searchViewModel,
              session.selectedBookIds == manager.searchViewModel.selectedBookIds,
              session.hasSubmitted || session.availableScopes.contains(session.scope),
              !session.showsBookFilterSheet, !session.showsSearchDataSheet, !session.showsAdvancedOptions,
              workspaceSource.isAuthoritative,
              let workspace = try? workspaceSource.read(), workspace.attached, !workspace.isSwitching,
              workspace.sceneID == sceneID.rawValue,
              let mapping = workspace.mappingOwnershipObservation(),
              mapping.owner == ObjectIdentifier(manager), mapping.scene == sceneID.rawValue,
              manager.selectedBookPresentationRevision != nil,
              manager.nativeModePresentationRevision != nil,
              bindings.rootPublications?.selectionRevision != nil,
              bindings.rootPublications?.settingsRevision != nil else { return false }
        guard case .liveNativeSetters = mapping.coverage else { return false }
        if !MaktabahApp.isIpad, let selected = manager.selectedBook {
            let matches = manager.openTabs.filter { $0.id == manager.activeTabId && $0.book === selected }
            guard matches.count == 1, manager.selectedBookPresentationMode == manager.currentMode else { return false }
        }
        if let activeSource {
            guard activeSource.valid, activeSource.phase != .applying else { return false }
            // Only this retained canonical transition may wait for its own
            // NavigationStack/TabView publication. Focus still needs a ready window.
            if activeSource.phase == .presented { return true }
        }
        return windowReady() && bindings.selectedTab.wrappedValue == bindings.selectedTab.wrappedValue.canonical
            && bindings.selectedTab.wrappedValue.appMode == manager.currentMode
    }

    func retainSource(requestID: UUID) throws {
        guard activeSource == nil, pending == nil, isAvailable,
              let workspace = try workspaceSource.read(), let mapping = workspace.mappingOwnershipObservation() else {
            throw UIRouteError(.unavailable, "native_search_entry_source_unavailable")
        }
        let manager = bindings.manager, session = bindings.manager.unifiedSearchSession, model = bindings.manager.searchViewModel
        let reader = manager.activeTabId.flatMap { id in manager.openTabs.first { $0.id == id }?.viewModel }
        let parent = try MaktabahNativeSearchEntryParentTransition(bindings: bindings)
        // Original @Observable reads are one-shot: value restoration cannot
        // restore this request. The backend bridge also observes aborted switches.
        let observation = MaktabahNativeComponentSourceObservation {
            _ = try? workspaceSource.read(); _ = workspace.attached; _ = workspace.isSwitching
            _ = workspace.mappingOwnershipSource.event
            _ = manager.openTabs; _ = manager.activeTabId; _ = manager.selectedContentId
            _ = manager.unifiedSearchSession; _ = manager.searchViewModel
            _ = manager.selectedBookForInfo; _ = manager.showingTabsList
            _ = manager.alertMessage; _ = DonationManager.shared.showDonationSheet
            _ = reader?.currentBook; _ = reader?.currentDestination; _ = reader?.currentContentId
            _ = reader?.isPopoverPresented; _ = reader?.readerInspectorVisible
            _ = session.searchViewModel; _ = session.query; _ = session.scope; _ = session.requestConfiguration
            _ = session.selectedBookIds; _ = session.resultKitabFilter; _ = session.hasSubmitted
            _ = session.submissionRevision; _ = session.cancellationRevision; _ = session.paginationRevision
            _ = session.showsBookFilterSheet; _ = session.showsSearchDataSheet; _ = session.showsAdvancedOptions
            _ = model.selectedBookIds; _ = model.filterText; _ = model.query; _ = model.searchMode
            _ = model.nearDistance; _ = model.sortKey; _ = model.sortAscending; _ = model.resultKitabFilter
            _ = model.backendSearchGeneration
        }
        // This one active request input is an ORIGINAL Combine publisher,
        // not @Observable. Subscribe to that input, not engine result progress.
        let zayitInput = NativeComponentSourceObservation(read: {})
        let zayitChange = session.zayitSession.model.$matchMode.dropFirst().sink { _ in zayitInput.invalidate() }
        let query = Array(session.query.utf8), configuration = session.requestConfiguration
        let source = Source(requestID: requestID, parent: parent, query: query,
            fieldToken: registration?.token, presentationOwner: presentationOwner) { [weak self, weak workspace, weak manager, weak session, weak model] in
            _ = zayitChange
            try zayitInput.validate()
            guard let self, let workspace, let manager, let session, let model,
                  let current = try workspaceSource.read(), current === workspace,
                  workspace.attached, !workspace.isSwitching, workspace.sceneID == sceneID.rawValue,
                  let actual = workspace.mappingOwnershipObservation(), actual.source === mapping.source,
                  actual.owner == mapping.owner, actual.scene == mapping.scene, actual.epoch == mapping.epoch,
                  actual.projection == mapping.projection,
                  manager.unifiedSearchSession === session, manager.searchViewModel === model,
                  session.searchViewModel === model, session.query.utf8.elementsEqual(query),
                  session.requestConfiguration == configuration, isAvailable else {
                throw UIRouteError(.staleState, "native_search_entry_source_changed")
            }
            guard case .liveNativeSetters = actual.coverage else {
                throw UIRouteError(.staleState, "native_search_entry_mapping_changed")
            }
        }
        try validate(source)
        activeSource = source
    }

    private func validate(_ source: Source) throws {
        guard source.valid else { throw UIRouteError(.staleState, "native_search_entry_retired") }
        try source.validateData()
        guard source.valid else { throw UIRouteError(.staleState, "native_search_entry_retired") }
        switch source.phase {
        case .retained: try source.parent.validateBefore(bindings)
        case .presented: try source.parent.validateAfter(bindings, requiresPublishedMode: source.focused)
        case .applying: throw UIRouteError(.staleState, "native_search_entry_publication_in_progress")
        }
        if let token = source.fieldToken {
            guard let registration, registration.token == token, registration.field != nil else {
                throw UIRouteError(.staleState, "native_search_entry_field_replaced")
            }
        } else if registration != nil && source.phase == .retained {
            throw UIRouteError(.staleState, "native_search_entry_unadmitted_field")
        }
        if let original = source.presentationOwner {
            guard presentationOwner == original else {
                throw UIRouteError(.staleState, "native_search_entry_original_view_changed")
            }
        } else if presentationOwner != nil && source.phase == .retained {
            throw UIRouteError(.staleState, "native_search_entry_unadmitted_view")
        }
    }

    func begin(requestID: UUID, validate lifetime: @escaping @MainActor () throws -> Void) throws {
        guard pending == nil, let source = activeSource, source.requestID == requestID else {
            throw UIRouteError(.unavailable, "native_search_entry_source_missing")
        }
        try validate(source); try lifetime()
        guard activeSource === source, source.valid else { throw UIRouteError(.staleState, "native_search_entry_reentered") }
        pending = Pending(source: source, validate: lifetime)
    }

    func apply(requestID: UUID) throws {
        guard let value = pending, value.source === activeSource, value.source.requestID == requestID, !value.applied else {
            throw UIRouteError(.staleState, "native_search_entry_command_changed")
        }
        try validate(value.source); try value.validate()
        guard pending === value, value.source.valid else { throw UIRouteError(.staleState, "native_search_entry_reentered") }
        value.source.phase = .applying
        do { try bindings.presentOriginalSearchEntry(value.source.parent) }
        catch { retire(); throw error }
        value.source.phase = .presented
        guard pending === value, value.source.valid else { throw UIRouteError(.staleState, "native_search_entry_reentered") }
        try validate(value.source)
        value.applied = true
        if value.source.presentationOwner == nil { value.source.presentationOwner = presentationOwner }
        if let field = registration?.field { originalFieldStateDidChange(field) }
        try value.validate(); try validate(value.source)
    }

    func attachOriginalField(_ field: UISearchTextField) {
        guard registration?.field !== field else { originalFieldStateDidChange(field); return }
        if registration != nil || activeSource?.phase == .retained { retire() }
        if let previous = registration { owner.detach(viewID: previous.token) }
        registration = FieldRegistration(field)
        originalFieldStateDidChange(field)
    }
    func detachOriginalField(_ field: UISearchTextField) {
        guard let original = registration, original.field === field else { return }
        retire(); owner.detach(viewID: original.token); registration = nil
    }

    func observeOriginalPresentation(owner original: UUID) {
        if let previous = presentationOwner, previous != original { retire() }
        if presentationOwner == nil, activeSource?.phase == .retained { retire() }
        presentationOwner = original
        if let value = pending, value.applied, value.source.presentationOwner == nil {
            value.source.presentationOwner = original
        }
    }
    func originalPresentationWillChange(owner original: UUID) {
        guard presentationOwner == original else { return }
        retire()
    }
    func originalPresentationDidDisappear(owner original: UUID) {
        guard presentationOwner == original else { return }
        retire(); presentationOwner = nil
    }

    /// didMoveToWindow / delegate events invalidate synchronously. Reattaching
    /// the same UIView still gets a new lifetime token and cannot revive proof.
    func originalFieldStateDidChange(_ field: UISearchTextField) {
        guard var original = registration, original.field === field else { return }
        if original.hasAttached && original.window !== field.window {
            retire(); owner.detach(viewID: original.token)
            original = FieldRegistration(field); registration = original
        }
        if let window = field.window, !original.hasAttached {
            if activeSource?.phase == .retained { retire() }
            original.window = window; original.hasAttached = true
        }
        if let value = pending, value.applied, value.source.phase == .presented,
           value.source.fieldToken == nil { value.source.fieldToken = original.token }
        guard original.hasAttached, original.window === field.window,
              field.window?.windowScene?.session.persistentIdentifier == sceneID.rawValue else { return }
        owner.attach(viewID: original.token, blocked: { [weak self, weak original] in
            guard let self, let original else { return true }
            return registration !== original || original.field == nil || !commonReady()
        })
        owner.observe(anchor: Self.anchor, token: original.token) { [weak self, weak original] in
            guard let self, let original, registration === original, let field = original.field else { return nil }
            return .init(anchor: Self.anchor, sceneID: sceneID,
                isVisible: field.isFirstResponder && Self.isVisible(field, in: sceneID))
        }
        if (activeSource?.focused == true || completedSource?.focused == true), !field.isFirstResponder { retire() }
        publishFieldEvidence(original)
    }

    /// Only an actual UIKit layout call advances this revision. No timer,
    /// request, SwiftUI body evaluation or forced layout creates a continuation.
    func originalFieldDidLayout(_ field: UISearchTextField) {
        originalFieldStateDidChange(field)
        guard let original = registration, original.field === field,
              original.hasAttached, original.window === field.window else { return }
        guard original.layoutRevision < .max else { retire(); return }
        original.layoutRevision += 1
        renderOriginalFieldIfReady()
    }
    private func publishFieldEvidence(_ original: FieldRegistration) {
        guard let field = original.field else { return }
        let evidence = NativeComponentEvidence(anchor: Self.anchor, sceneID: sceneID,
            isVisible: field.isFirstResponder && Self.isVisible(field, in: sceneID))
        guard evidence != original.previousEvidence else { return }
        original.previousEvidence = evidence; owner.geometryChanged()
    }

    /// Resumed by original field layout, real parent visibility/mode publication,
    /// or the canonical apply when that original field is already visible.
    func renderOriginalFieldIfReady() {
        guard let value = pending, value.applied, !value.rendering, value.source.phase == .presented else { return }
        do { try validate(value.source); try value.validate() } catch { retire(); return }
        guard let original = registration, value.source.fieldToken == original.token,
              let originalView = value.source.presentationOwner, presentationOwner == originalView,
              let field = original.field, original.hasAttached, original.window === field.window,
              windowReady(), parentVisible(), Self.isVisible(field, in: sceneID),
              field.markedTextRange == nil, (field.text ?? "").utf8.elementsEqual(value.source.query),
              (try? value.source.parent.validateAfter(bindings, requiresPublishedMode: true)) != nil else { return }
        value.rendering = true
        defer { value.rendering = false }
        owner.render(viewID: original.token, layoutRevision: original.layoutRevision) { _, _ in
            guard pending === value, registration === original,
                  field.isFirstResponder || field.becomeFirstResponder(),
                  pending === value, registration === original,
                  field.isFirstResponder, Self.isVisible(field, in: sceneID) else { return .awaitingOriginalLayout }
            value.source.focused = true
            return .rendered
        }
        publishFieldEvidence(original)
    }

    func finish(requestID: UUID, completed: Bool) {
        guard let value = pending, value.source.requestID == requestID else { return }
        pending = nil
        if completed { completedSource = value.source } else { value.source.valid = false }
    }
    func releaseSource(requestID: UUID) {
        guard let source = activeSource, source.requestID == requestID else { return }
        if pending?.source === source { retire() }
        if completedSource !== source { source.valid = false }
        activeSource = nil
    }
    func retire() {
        activeSource?.valid = false; completedSource?.valid = false
        pending = nil; completedSource = nil
        owner.retirePresentation()
    }
    func unmount() {
        retire()
        if let registration { owner.detach(viewID: registration.token) }
        registration = nil; activeSource = nil; presentationOwner = nil
    }

    /// Evidence from the actual original UITextField and every clipped ancestor.
    /// A requested anchor, successful setter or first-responder return is not visibility.
    static func isVisible(_ field: UISearchTextField, in expectedScene: UIStableID) -> Bool {
        guard field.isEnabled, field.canBecomeFirstResponder, let window = field.window,
              window.isKeyWindow, !window.isHidden, let scene = window.windowScene,
              scene.activationState == .foregroundActive,
              scene.session.persistentIdentifier == expectedScene.rawValue else { return false }
        let target = field.convert(field.bounds, to: window), area = target.width * target.height
        guard !target.isEmpty, area.isFinite, area > 0 else { return false }
        var visible = target.intersection(window.bounds), alpha: CGFloat = 1
        var current: UIView? = field
        while let view = current {
            guard !view.isHidden else { return false }
            alpha *= view.alpha
            if view.clipsToBounds { visible = visible.intersection(view.convert(view.bounds, to: window)) }
            if let scroll = view as? UIScrollView {
                guard !scroll.isDragging, !scroll.isDecelerating else { return false }
                visible = visible.intersection(scroll.convert(scroll.bounds.inset(by: scroll.adjustedContentInset), to: window))
            }
            current = view.superview
        }
        guard alpha >= 0.95, !visible.isNull, visible.width * visible.height >= area * 0.98 else { return false }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        if let top {
            guard !top.isBeingPresented, !top.isBeingDismissed, top.transitionCoordinator == nil else { return false }
            if top !== window.rootViewController, !field.isDescendant(of: top.view) { return false }
        }
        return true
    }
}

// Explicit fixture initialization only. The production source above has no
// seed/reset API; this same-file extension exercises exhaustion without loops.
extension MaktabahNativeRootPublicationSource {
    convenience init(boundarySelection: UInt64?, boundarySettings: UInt64?) {
        self.init()
        selectionRevision = boundarySelection; settingsRevision = boundarySettings
    }
}
