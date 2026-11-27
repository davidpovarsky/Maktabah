#if os(iOS)
import Foundation
import SwiftUI
import UIKit
import Observation
import ChavrusaUIRoutingHost
import OtzariaUIRouting

/// Fixed controls in the original TOC. Private node identity is never a public
/// component token. Node reveal is added only with its own retained source.
@MainActor enum MaktabahNativeTOCComponents {
    enum Anchor: String, CaseIterable {
        case contents = "native.reader.toc.contents"
        case structure = "native.reader.toc.structure"
        case currentSelection = "native.reader.toc.currentSelection"

        var id: UIDestinationID { UIDestinationID(rawValue: rawValue)! }
        var title: String {
            switch self {
            case .contents: String(localized: "Table of contents list")
            case .structure: String(localized: "Structure")
            case .currentSelection: String(localized: "Current Table of Contents Entry")
            }
        }
    }

    static let destination = UIDestinationID(rawValue: "native.reader.toc")!
    static var descriptors: [MaktabahNativeComponentDescriptor] {
        Anchor.allCases.map { .init(anchor: $0.id, title: $0.title) }
    }

    static func makeOwner(manager: iOSNavigationManager) -> MaktabahNativeComponentOwner {
        MaktabahNativeComponentOwner(
            destination: destination, presentation: .currentTab, descriptors: descriptors,
            available: { [weak manager] id in
                guard let manager, let anchor = Anchor(rawValue: id.rawValue) else { return false }
                return isAvailable(anchor, manager: manager)
            },
            captureSource: { [weak manager] id in
                guard let manager, let anchor = Anchor(rawValue: id.rawValue) else {
                    throw UIRouteError(.unavailable, "native_toc_component_unavailable")
                }
                return try captureSource(anchor, manager: manager)
            }
        )
    }

    static func owns(_ model: BookTOCViewModel, manager: iOSNavigationManager) -> Bool {
        currentReader(manager)?.tocViewModel === model
    }

    private static func currentReader(_ manager: iOSNavigationManager) -> ReaderViewModel? {
        guard MaktabahApp.isIpad, let id = manager.activeTabId,
              let tab = manager.openTabs.first(where: { $0.id == id }),
              let book = tab.book.backendLocator,
              let section = tab.viewModel.backendSection?.locator,
              book.backend == BackendCoordinator.shared.activeBackendID,
              section.backend == book.backend, section.workKey == book.workKey else { return nil }
        let model = tab.viewModel.tocViewModel
        guard !model.isLoading, model.loadingStatus == .loaded,
              model.loadFailure == nil, !model.tocNodes.isEmpty else { return nil }
        return tab.viewModel
    }

    /// Use the same original node lookup as the iPad TOC parent, then the
    /// original deepest-node cache used by computeExpandedPaths(). No private
    /// node ID or locator is accepted from the public component token.
    static func currentSelection(manager: iOSNavigationManager) -> TOCNode? {
        guard let reader = currentReader(manager) else { return nil }
        let model = reader.tocViewModel
        let displayed = reader.backendSection.flatMap { model.findNode(for: $0.locator) }
            ?? model.findNode(forContentId: reader.currentContentId)
        guard let displayed, let exact = model.findNodeById(displayed.id),
              model.pathToNode(exact) != nil else { return nil }
        return exact
    }

    private static func isAvailable(_ anchor: Anchor, manager: iOSNavigationManager) -> Bool {
        guard let reader = currentReader(manager) else { return false }
        switch anchor {
        case .contents: return true
        case .structure: return reader.tocViewModel.navigationStructures.count > 1
        case .currentSelection: return currentSelection(manager: manager) != nil
        }
    }

    private struct NodeIdentity: Equatable {
        let object: ObjectIdentifier
        let start: Int
        let end: Int
        let locator: TextLocator?
        let children: [ObjectIdentifier]

        init(_ range: TOCRange) {
            object = ObjectIdentifier(range.node)
            start = range.start; end = range.end
            locator = range.node.backendLocator
            children = range.node.children.map(ObjectIdentifier.init)
        }
    }

    private struct StructureIdentity: Equatable {
        let id: String
        let title: String
    }

    /// Retain the original owner before Core suspension. A different tab, TOC
    /// reload, structure or canonical Reader position cannot inherit the route.
    private static func captureSource(_ anchor: Anchor, manager: iOSNavigationManager) throws
        -> @MainActor () throws -> Void {
        guard isAvailable(anchor, manager: manager),
              let tabID = manager.activeTabId, let reader = currentReader(manager) else {
            throw UIRouteError(.unavailable, "native_toc_component_unavailable")
        }
        let model = reader.tocViewModel
        // One-shot original Observation detects a change even if values return
        // to their captured state before Core resumes. It never refreshes source.
        let observation = MaktabahNativeComponentSourceObservation {
            _ = manager.activeTabId
            _ = manager.openTabs
            _ = reader.backendSection
            _ = reader.currentDestination
            _ = reader.currentContentId
            _ = model.tocNodes
            _ = model.tocRanges
            _ = model.navigationStructures
            _ = model.selectedStructureID
            _ = model.isLoading
            _ = model.loadingStatus
            _ = model.loadFailure
        }
        let backend = BackendCoordinator.shared.activeBackendID
        let generation = BackendCoordinator.shared.generation
        let destination = reader.currentDestination
        let contentID = reader.currentContentId
        let structureID = model.selectedStructureID
        let roots = model.tocNodes.map(ObjectIdentifier.init)
        let nodes = model.tocRanges.map(NodeIdentity.init)
        let structures = model.navigationStructures.map { StructureIdentity(id: $0.id, title: $0.title) }
        let selection = anchor == .currentSelection ? currentSelection(manager: manager) : nil
        let selectionPath = selection.flatMap { model.pathToNode($0) }?.map(ObjectIdentifier.init)
        if anchor == .currentSelection && (selection == nil || selectionPath == nil) {
            throw UIRouteError(.unavailable, "native_toc_selection_unavailable")
        }

        return { [weak manager, weak reader, weak model] in
            try observation.validate()
            if anchor == .currentSelection {
                guard let manager, let model, let selection,
                      currentSelection(manager: manager) === selection,
                      model.pathToNode(selection)?.map(ObjectIdentifier.init) == selectionPath else {
                    throw UIRouteError(.staleState, "native_toc_selection_source_changed")
                }
            }
            guard let manager, let reader, let model,
                  manager.activeTabId == tabID, currentReader(manager) === reader,
                  reader.tocViewModel === model,
                  BackendCoordinator.shared.activeBackendID == backend,
                  BackendCoordinator.shared.generation == generation,
                  reader.currentDestination == destination, reader.currentContentId == contentID,
                  model.selectedStructureID == structureID,
                  model.tocNodes.map(ObjectIdentifier.init) == roots,
                  model.tocRanges.map(NodeIdentity.init) == nodes,
                  model.navigationStructures.map({ StructureIdentity(id: $0.id, title: $0.title) }) == structures,
                  isAvailable(anchor, manager: manager) else {
                throw UIRouteError(.staleState, "native_toc_component_source_changed")
            }
        }
    }
}

/// The original list owns expansion and scrolling. These callbacks expose its
/// rendering only; the shared owner retains the one original command/admission.
struct MaktabahNativeTOCComponentContainer: ViewModifier {
    let model: BookTOCViewModel
    let selectedId: Int?
    let searchText: String
    @Binding var expandedPaths: Set<ObjectIdentifier>
    let proxy: ScrollViewProxy
    let cancelPendingSelectionScroll: @MainActor () -> Void
    @Environment(iOSNavigationManager.self) private var manager
    @Environment(\.maktabahNativeRoutingSession) private var session
    @State private var presentation = MaktabahNativeTOCLayoutPresentation()

    private var selectedNode: TOCNode? {
        guard MaktabahNativeTOCComponents.owns(model, manager: manager),
              let node = MaktabahNativeTOCComponents.currentSelection(manager: manager),
              selectedId == node.id, model.findNodeById(node.id) === node else { return nil }
        return node
    }

    func body(content: Content) -> some View {
        let owner = session?.componentOwner(for: MaktabahNativeTOCComponents.destination)
        let node = selectedNode
        let key = MaktabahNativeTOCLayoutKey(
            model: ObjectIdentifier(model), selectedID: selectedId,
            selectedNode: node.map(ObjectIdentifier.init),
            structure: model.selectedStructureID, expanded: expandedPaths, search: searchText)
        let rowContext = owner.flatMap { owner in
            node.map { MaktabahNativeTOCRowContext(owner: owner, node: $0, viewID: presentation.viewID) }
        }
        content
            .environment(\.maktabahNativeTOCRowContext, searchText.isEmpty ? rowContext : nil)
            .background {
                if let owner {
                    MaktabahNativeTOCLayoutPublisher(owner: owner, presentation: presentation, key: key)
                }
            }
            .modifier(MaktabahNativeTOCScrollLayoutObserver(
                owner: owner, presentation: presentation, key: key))
            .modifier(MaktabahNativeComponentContainer(
                owner: owner, blocked: { !MaktabahNativeTOCComponents.owns(model, manager: manager) },
                viewID: presentation.viewID, layoutRevision: presentation.layoutRevision,
                revealPhase: { anchor, phase in
                    guard anchor == MaktabahNativeTOCComponents.Anchor.currentSelection.id else { return .rendered }
                    guard let owner, searchText.isEmpty, let node = selectedNode,
                          let path = model.pathToNode(node), !path.isEmpty else {
                        owner?.retirePresentation()
                        return .awaitingOriginalLayout
                    }
                    cancelPendingSelectionScroll()
                    let ancestors = Set(path.dropLast().map(ObjectIdentifier.init))
                    switch phase {
                    case .initial:
                        guard ancestors.isSubset(of: expandedPaths), presentation.hasPublication(for: key) else {
                            expandedPaths.formUnion(ancestors)
                            return .awaitingOriginalLayout
                        }
                    case .afterOriginalLayout:
                        guard ancestors.isSubset(of: expandedPaths), presentation.hasPublication(for: key) else {
                            return .awaitingOriginalLayout
                        }
                    }
                    // Exact private source identity, distinct from possibly
                    // duplicate legacy integer IDs. This never selects a node.
                    proxy.scrollTo(MaktabahNativeTOCRowIdentity(
                        viewID: presentation.viewID, node: ObjectIdentifier(node)), anchor: .center)
                    return .rendered
                }
            ))
    }
}

struct MaktabahNativeTOCComponentMarker: View {
    let anchor: MaktabahNativeTOCComponents.Anchor
    let model: BookTOCViewModel
    @Environment(iOSNavigationManager.self) private var manager
    @Environment(\.maktabahNativeRoutingSession) private var session

    var body: some View {
        if MaktabahNativeTOCComponents.owns(model, manager: manager),
           let owner = session?.componentOwner(for: MaktabahNativeTOCComponents.destination) {
            MaktabahNativeComponentWitness(anchor: anchor.id, owner: owner)
        }
    }
}
/// Private identity is attached in the background of the exact ORIGINAL row.
/// Its existing label, action, selected trait and toc-row-<id> remain untouched.
private struct MaktabahNativeTOCRowIdentity: Hashable {
    let viewID: UUID
    let node: ObjectIdentifier
}

private struct MaktabahNativeTOCRowContext {
    let owner: MaktabahNativeComponentOwner
    let node: TOCNode
    let viewID: UUID
}
private struct MaktabahNativeTOCRowContextKey: EnvironmentKey {
    static var defaultValue: MaktabahNativeTOCRowContext? { nil }
}
private extension EnvironmentValues {
    var maktabahNativeTOCRowContext: MaktabahNativeTOCRowContext? {
        get { self[MaktabahNativeTOCRowContextKey.self] }
        set { self[MaktabahNativeTOCRowContextKey.self] = newValue }
    }
}

struct MaktabahNativeTOCSelectedRowMarker: View {
    let item: TOCNode
    @Environment(\.maktabahNativeTOCRowContext) private var context

    var body: some View {
        if let context, context.node === item {
            MaktabahNativeComponentWitness(
                anchor: MaktabahNativeTOCComponents.Anchor.currentSelection.id, owner: context.owner)
                .id(MaktabahNativeTOCRowIdentity(viewID: context.viewID, node: ObjectIdentifier(item)))
        }
    }
}

/// Values come from original view state; changing this key is never itself a
/// layout publication. Only the native callbacks below advance the revision.
private struct MaktabahNativeTOCLayoutKey: Equatable {
    let model: ObjectIdentifier
    let selectedID: Int?
    let selectedNode: ObjectIdentifier?
    let structure: String
    let expanded: Set<ObjectIdentifier>
    let search: String
}
private struct MaktabahNativeTOCScrollGeometry: Equatable {
    let contentSize: CGSize
    let containerSize: CGSize
    let visibleRect: CGRect
}

@MainActor @Observable
private final class MaktabahNativeTOCLayoutPresentation {
    let viewID = UUID()
    private(set) var layoutRevision: UInt64 = 0
    private(set) var publisherToken: UUID?
    @ObservationIgnored private var activeToken: UUID?
    @ObservationIgnored private weak var owner: MaktabahNativeComponentOwner?
    @ObservationIgnored private var currentKey: MaktabahNativeTOCLayoutKey?
    @ObservationIgnored private var publishedKey: MaktabahNativeTOCLayoutKey?
    @ObservationIgnored private var previousFrame: CGRect?
    @ObservationIgnored private var previousGeometry: MaktabahNativeTOCScrollGeometry?

    func activate(token: UUID, owner: MaktabahNativeComponentOwner, key: MaktabahNativeTOCLayoutKey) {
        guard owner.owns(viewID: viewID) else { return }
        if activeToken != token || self.owner !== owner {
            publishedKey = nil; previousFrame = nil; previousGeometry = nil
        }
        self.owner = owner; activeToken = token; currentKey = key
        publisherToken = token
    }

    func update(token: UUID, key: MaktabahNativeTOCLayoutKey) {
        guard activeToken == token else { return }
        currentKey = key
    }

    func invalidate(token: UUID) {
        guard activeToken == token else { return }
        activeToken = nil; currentKey = nil; publishedKey = nil
        previousFrame = nil; previousGeometry = nil
        // Immediate token retirement blocks old callbacks. This UI notification
        // is posted outside dismantle/update; it creates no render authority.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.activeToken == nil, self.publisherToken == token else { return }
            self.publisherToken = nil
        }
    }

    private func accepts(token: UUID, owner: MaktabahNativeComponentOwner, key: MaktabahNativeTOCLayoutKey) -> Bool {
        activeToken == token && self.owner === owner && currentKey == key && owner.owns(viewID: viewID)
    }

    func publishLayout(token: UUID, owner: MaktabahNativeComponentOwner,
                       key: MaktabahNativeTOCLayoutKey, frame: CGRect) {
        guard accepts(token: token, owner: owner, key: key),
              frame.width.isFinite, frame.height.isFinite, frame.width > 0, frame.height > 0,
              publishedKey != key || previousFrame != frame else { return }
        publishedKey = key; previousFrame = frame
        layoutRevision &+= 1
    }

    func publishScroll(token: UUID, owner: MaktabahNativeComponentOwner,
                       key: MaktabahNativeTOCLayoutKey, geometry: MaktabahNativeTOCScrollGeometry) {
        guard accepts(token: token, owner: owner, key: key),
              geometry.contentSize.width.isFinite, geometry.contentSize.height.isFinite,
              geometry.containerSize.width.isFinite, geometry.containerSize.height.isFinite,
              geometry.visibleRect.width.isFinite, geometry.visibleRect.height.isFinite,
              geometry.contentSize.width > 0, geometry.contentSize.height > 0,
              geometry.containerSize.width > 0, geometry.containerSize.height > 0,
              geometry.visibleRect.width > 0, geometry.visibleRect.height > 0,
              publishedKey != key || previousGeometry != geometry else { return }
        publishedKey = key; previousGeometry = geometry
        layoutRevision &+= 1
    }

    func hasPublication(for key: MaktabahNativeTOCLayoutKey) -> Bool {
        guard let activeToken, let owner else { return false }
        return accepts(token: activeToken, owner: owner, key: key) && publishedKey == key
    }
}

/// The actual original List's native geometry supplies offscreen expansion
/// publication. Route/expansion values are deliberately absent from transform.
private struct MaktabahNativeTOCScrollLayoutObserver: ViewModifier {
    let owner: MaktabahNativeComponentOwner?
    let presentation: MaktabahNativeTOCLayoutPresentation
    let key: MaktabahNativeTOCLayoutKey

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            let token = presentation.publisherToken
            content.onScrollGeometryChange(for: MaktabahNativeTOCScrollGeometry.self) { geometry in
                MaktabahNativeTOCScrollGeometry(contentSize: geometry.contentSize,
                    containerSize: geometry.containerSize, visibleRect: geometry.visibleRect)
            } action: { _, geometry in
                guard let owner, let token else { return }
                presentation.publishScroll(token: token, owner: owner, key: key, geometry: geometry)
            }
        } else {
            // The original passive UIKit layout publication remains available.
            content
        }
    }
}

/// A passive background of the ORIGINAL ThemeList, with its own mount token.
/// It does not force layout, search UIKit trees, create a scroll view, receive
/// touches, appear in accessibility, synthesize a receipt or schedule a timer.
private struct MaktabahNativeTOCLayoutPublisher: UIViewRepresentable {
    let owner: MaktabahNativeComponentOwner
    let presentation: MaktabahNativeTOCLayoutPresentation
    let key: MaktabahNativeTOCLayoutKey

    func makeUIView(context: Context) -> Marker {
        Marker(owner: owner, presentation: presentation, key: key)
    }
    func updateUIView(_ view: Marker, context: Context) {
        view.update(owner: owner, key: key)
    }
    static func dismantleUIView(_ view: Marker, coordinator: ()) { view.retire() }

    final class Marker: UIView {
        private(set) var token = UUID()
        private weak var owner: MaktabahNativeComponentOwner?
        private weak var presentation: MaktabahNativeTOCLayoutPresentation?
        private var key: MaktabahNativeTOCLayoutKey
        private var retired = false
        private var lastLayout: (MaktabahNativeTOCLayoutKey, CGRect)?

        init(owner: MaktabahNativeComponentOwner, presentation: MaktabahNativeTOCLayoutPresentation,
             key: MaktabahNativeTOCLayoutKey) {
            self.owner = owner; self.presentation = presentation; self.key = key
            super.init(frame: .zero)
            isUserInteractionEnabled = false; isAccessibilityElement = false; backgroundColor = .clear
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        func update(owner: MaktabahNativeComponentOwner, key: MaktabahNativeTOCLayoutKey) {
            if self.owner !== owner {
                presentation?.invalidate(token: token)
                token = UUID(); lastLayout = nil
            }
            self.owner = owner; self.key = key
            presentation?.update(token: token, key: key)
        }
        func retire() {
            retired = true; lastLayout = nil
            presentation?.invalidate(token: token)
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            // A surviving UIView can detach and reattach to the same window.
            // Its prior layout/callback must not become the new mount's proof.
            presentation?.invalidate(token: token)
            token = UUID(); lastLayout = nil
            if window != nil { dispatchActualPublication() }
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            guard !retired, let window else { return }
            lastLayout = (key, convert(bounds, to: window))
            dispatchActualPublication()
        }
        private func dispatchActualPublication() {
            guard !retired, let originalWindow = window else { return }
            let event = lastLayout
            let capturedKey = key
            let capturedToken = token
            // Delivery is from a real UIKit mount/layout callback. Before
            // publishing, recheck the actual same marker/window/owner/source.
            DispatchQueue.main.async { [weak self, weak originalWindow] in
                guard let self, !self.retired, let originalWindow,
                      self.window === originalWindow, self.token == capturedToken,
                      self.key == capturedKey,
                      let owner = self.owner, let presentation = self.presentation,
                      owner.owns(viewID: presentation.viewID) else { return }
                presentation.activate(token: capturedToken, owner: owner, key: capturedKey)
                guard let event, event.0 == capturedKey else { return }
                presentation.publishLayout(token: capturedToken, owner: owner, key: event.0, frame: event.1)
            }
        }
    }
}
#endif
