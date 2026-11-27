#if os(iOS)
import Foundation
import SwiftUI
import OtzariaUIRouting

/// Fixed controls in the original TOC. Private node identity is never a public
/// component token. Node reveal is added only with its own retained source.
@MainActor enum MaktabahNativeTOCComponents {
    enum Anchor: String, CaseIterable {
        case contents = "native.reader.toc.contents"
        case structure = "native.reader.toc.structure"

        var id: UIDestinationID { UIDestinationID(rawValue: rawValue)! }
        var title: String {
            switch self {
            case .contents: String(localized: "Table of Contents")
            case .structure: String(localized: "Structure")
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

    private static func isAvailable(_ anchor: Anchor, manager: iOSNavigationManager) -> Bool {
        guard let reader = currentReader(manager) else { return false }
        switch anchor {
        case .contents: return true
        case .structure: return reader.tocViewModel.navigationStructures.count > 1
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
        let backend = BackendCoordinator.shared.activeBackendID
        let generation = BackendCoordinator.shared.generation
        let destination = reader.currentDestination
        let contentID = reader.currentContentId
        let structureID = model.selectedStructureID
        let roots = model.tocNodes.map(ObjectIdentifier.init)
        let nodes = model.tocRanges.map(NodeIdentity.init)
        let structures = model.navigationStructures.map { StructureIdentity(id: $0.id, title: $0.title) }

        return { [weak manager, weak reader, weak model] in
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

/// The existing TOC already exposes these controls without changing its search,
/// structure or selected node. Parent presentation remains the original route.
struct MaktabahNativeTOCComponentContainer: ViewModifier {
    let model: BookTOCViewModel
    @Environment(iOSNavigationManager.self) private var manager
    @Environment(\.maktabahNativeRoutingSession) private var session

    func body(content: Content) -> some View {
        content.modifier(MaktabahNativeComponentContainer(
            owner: session?.componentOwner(for: MaktabahNativeTOCComponents.destination),
            blocked: { !MaktabahNativeTOCComponents.owns(model, manager: manager) },
            reveal: { _ in }
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
#endif
