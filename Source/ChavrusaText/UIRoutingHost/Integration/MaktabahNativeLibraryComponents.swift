#if os(iOS)
import Foundation
import SwiftUI
import OtzariaUIRouting

/// Navigation exposes original Library controls; it never invokes their actions
/// or writes search, grouping, downloaded filters, selection, imports or deletes.
@MainActor enum MaktabahNativeLibraryComponents {
    enum Anchor: String, CaseIterable {
        case contents = "native.library.contents"
        case grouping = "native.library.grouping"
        case downloadedFilter = "native.library.downloadedFilter"
        case options = "native.library.options"

        var id: UIDestinationID { UIDestinationID(rawValue: rawValue)! }
        var title: String {
            switch self {
            case .contents: String(localized: "Library contents")
            case .grouping: String(localized: "Group By")
            case .downloadedFilter: String(localized: .Library.downloaded)
            case .options: String(localized: .Library.libraryOptions)
            }
        }
    }

    static let destination = UIDestinationID(rawValue: "native.library")!
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
                    throw UIRouteError(.unavailable, "native_library_component_unavailable")
                }
                return try captureSource(anchor, manager: manager)
            }
        )
    }

    static func owns(_ model: LibraryViewModel, manager: iOSNavigationManager) -> Bool {
        manager.libraryViewModel === model && model.state == .loaded && model.hasLoadedLibrary
            && model.loadedBackendID == BackendCoordinator.shared.activeBackendID
            && model.loadedBackendGeneration == BackendCoordinator.shared.generation
    }

    static func hasBlockingPresentation(_ model: LibraryViewModel) -> Bool {
        model.showingImportSheet || model.showingUpdateSheet || model.showingDeleteConfirmation
            || model.singleBookToDelete != nil || model.importErrorMessage != nil
            || model.showImportSuccessAlert || model.isDownloadModal
    }

    private static func isAvailable(_ anchor: Anchor, manager: iOSNavigationManager) -> Bool {
        let model = manager.libraryViewModel
        guard owns(model, manager: manager), !hasBlockingPresentation(model) else { return false }
        switch anchor {
        case .contents: return true
        case .grouping, .options: return !model.isSelectionMode
        case .downloadedFilter: return !model.isSelectionMode && AppConfig.isUsingBundleMode
        }
    }

    /// The original list's generation and private filters are retained read-only.
    /// A load/replacement or selection edit during Core awaits invalidates focus.
    private static func captureSource(_ anchor: Anchor, manager: iOSNavigationManager) throws
        -> @MainActor () throws -> Void {
        guard isAvailable(anchor, manager: manager) else {
            throw UIRouteError(.unavailable, "native_library_component_unavailable")
        }
        let model = manager.libraryViewModel
        // One-shot original Observation detects a change even if values return
        // to their captured state before Core resumes. It never refreshes source.
        let observation = MaktabahNativeComponentSourceObservation {
            _ = manager.libraryViewModel
            _ = model.state
            _ = model.hasLoadedLibrary
            _ = model.loadedBackendID
            _ = model.loadedBackendGeneration
            _ = model.updateTrigger
            _ = model.searchQuery
            _ = model.viewMode
            _ = model.showOnlyDownloaded
            _ = model.filterMode
            _ = model.isFlatMode
            _ = model.selectedAuthorId
            _ = model.displayedCategories
            _ = model.isSelectionMode
            _ = model.selectedBookIds
            _ = model.showingImportSheet
            _ = model.showingUpdateSheet
            _ = model.showingDeleteConfirmation
            _ = model.singleBookToDelete
            _ = model.importErrorMessage
            _ = model.showImportSuccessAlert
            _ = model.isDownloadModal
        }
        let backend = BackendCoordinator.shared.activeBackendID
        let generation = BackendCoordinator.shared.generation
        let update = model.updateTrigger
        let query = model.searchQuery
        let mode = model.viewMode
        let downloaded = model.showOnlyDownloaded
        let selectionMode = model.isSelectionMode
        let selectedBooks = model.selectedBookIds

        return { [weak manager, weak model] in
            try observation.validate()
            guard let manager, let model, owns(model, manager: manager),
                  BackendCoordinator.shared.activeBackendID == backend,
                  BackendCoordinator.shared.generation == generation,
                  model.updateTrigger == update, model.searchQuery == query,
                  model.viewMode == mode, model.showOnlyDownloaded == downloaded,
                  model.isSelectionMode == selectionMode, model.selectedBookIds == selectedBooks,
                  isAvailable(anchor, manager: manager) else {
                throw UIRouteError(.staleState, "native_library_component_source_changed")
            }
        }
    }
}

struct MaktabahNativeLibraryComponentContainer: ViewModifier {
    let model: LibraryViewModel
    @Environment(iOSNavigationManager.self) private var manager
    @Environment(\.maktabahNativeRoutingSession) private var session

    func body(content: Content) -> some View {
        content.modifier(MaktabahNativeComponentContainer(
            owner: session?.componentOwner(for: MaktabahNativeLibraryComponents.destination),
            blocked: {
                !MaktabahNativeLibraryComponents.owns(model, manager: manager)
                    || MaktabahNativeLibraryComponents.hasBlockingPresentation(model)
            },
            reveal: { _ in }
        ))
    }
}

struct MaktabahNativeLibraryComponentMarker: View {
    let anchor: MaktabahNativeLibraryComponents.Anchor
    let model: LibraryViewModel
    @Environment(iOSNavigationManager.self) private var manager
    @Environment(\.maktabahNativeRoutingSession) private var session

    var body: some View {
        if MaktabahNativeLibraryComponents.owns(model, manager: manager),
           let owner = session?.componentOwner(for: MaktabahNativeLibraryComponents.destination) {
            MaktabahNativeComponentWitness(anchor: anchor.id, owner: owner)
        }
    }
}
#endif
