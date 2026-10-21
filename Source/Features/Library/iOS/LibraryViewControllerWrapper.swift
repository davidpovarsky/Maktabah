import SwiftUI
import UIKit

struct LibraryViewControllerWrapper: UIViewControllerRepresentable {
    let navigationManager: iOSNavigationManager
    let viewModel: LibraryViewModel
    @Binding var showOnlyDownloaded: Bool
    var onDeleteSingleBook: ((BooksData) -> Void)?
    var onDownloadSingleBook: ((BooksData) -> Void)?
    var onShowBookInfo: ((BooksData) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(navigationManager: navigationManager, viewModel: viewModel)
    }

    func makeUIViewController(context: Context) -> iOSLibraryViewController {
        let vc = iOSLibraryViewController()
        vc.viewModel = viewModel
        vc.onBookSelected = { book in
            viewModel.selectBook(book, using: navigationManager)
        }
        vc.onSelectionChanged = {
            viewModel.notifySelectionChanged()
        }
        vc.onDeleteBook = onDeleteSingleBook
        vc.onDownloadBook = onDownloadSingleBook
        vc.onShowBookInfo = onShowBookInfo
        vc.onSnapshotError = { [weak viewModel] error in
            viewModel?.state = .error(error.localizedDescription)
        }
        vc.showLoadMore = viewModel.hasMoreAuthors
        vc.loadMoreCount = viewModel.totalAuthorCount - viewModel.displayedCategories.count

        let coordinator = context.coordinator
        let backendID = BackendCoordinator.shared.activeBackendID
        let backendGeneration = BackendCoordinator.shared.generation
        coordinator.loadTask?.cancel()
        coordinator.loadTask = Task { @MainActor in
            await coordinator.viewModel.loadLibrary()
            guard !Task.isCancelled,
                  BackendCoordinator.shared.activeBackendID == backendID,
                  BackendCoordinator.shared.generation == backendGeneration,
                  coordinator.viewModel.loadedBackendID == backendID,
                  coordinator.viewModel.loadedBackendGeneration == backendGeneration else { return }
            coordinator.viewModel._showOnlyDownloadedTracker = coordinator.viewModel.showOnlyDownloaded
            let categories = coordinator.viewModel.displayedCategories
            let showLoadMore = coordinator.viewModel.hasMoreAuthors
            vc.showLoadMore = showLoadMore
            vc.loadMoreCount = coordinator.viewModel.totalAuthorCount - categories.count
            coordinator.lastUpdateTrigger = coordinator.viewModel.updateTrigger
            coordinator.lastSelectionMode = coordinator.viewModel.isSelectionMode
            coordinator.lastShowLoadMore = showLoadMore
            vc.applyCategories(categories)
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: iOSLibraryViewController, context: Context) {
        uiViewController.viewModel = context.coordinator.viewModel
        uiViewController.onDeleteBook = onDeleteSingleBook
        uiViewController.onDownloadBook = onDownloadSingleBook
        uiViewController.onShowBookInfo = onShowBookInfo

        let showLoadMore = context.coordinator.viewModel.hasMoreAuthors
        let loadMoreCount = context.coordinator.viewModel.totalAuthorCount - context.coordinator.viewModel.displayedCategories.count
        uiViewController.showLoadMore = showLoadMore
        uiViewController.loadMoreCount = loadMoreCount

        guard context.coordinator.viewModel.state != .loading,
              context.coordinator.viewModel.loadedBackendID == BackendCoordinator.shared.activeBackendID,
              context.coordinator.viewModel.loadedBackendGeneration == BackendCoordinator.shared.generation else { return }

        let categories = context.coordinator.viewModel.displayedCategories
        let currentTrigger = context.coordinator.viewModel.updateTrigger
        let currentSelectionMode = context.coordinator.viewModel.isSelectionMode

        if currentTrigger != context.coordinator.lastUpdateTrigger || showLoadMore != context.coordinator.lastShowLoadMore {
            context.coordinator.lastUpdateTrigger = currentTrigger
            context.coordinator.lastSelectionMode = currentSelectionMode
            context.coordinator.lastShowLoadMore = showLoadMore
            uiViewController.applyCategories(categories)
        } else if currentSelectionMode != context.coordinator.lastSelectionMode {
            context.coordinator.lastSelectionMode = currentSelectionMode
            uiViewController.reloadVisibleItems()
        }
    }

    static func dismantleUIViewController(_ uiViewController: iOSLibraryViewController, coordinator: Coordinator) {
        coordinator.loadTask?.cancel()
        coordinator.loadTask = nil
    }

    class Coordinator {
        let navigationManager: iOSNavigationManager
        let viewModel: LibraryViewModel
        var lastUpdateTrigger: Int = -1
        var lastSelectionMode: Bool = false
        var lastShowLoadMore: Bool = false
        var loadTask: Task<Void, Never>?

        init(navigationManager: iOSNavigationManager, viewModel: LibraryViewModel) {
            self.navigationManager = navigationManager
            self.viewModel = viewModel
        }
    }
}
