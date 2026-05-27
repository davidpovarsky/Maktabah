import SwiftUI
import UIKit

struct LibraryViewControllerWrapper: UIViewControllerRepresentable {
    let navigationManager: iOSNavigationManager
    let viewModel: iOSLibraryViewModel
    @Binding var showOnlyDownloaded: Bool
    var onDeleteSingleBook: ((BooksData) -> Void)?
    var onDownloadSingleBook: ((BooksData) -> Void)?

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

        Task {
            await context.coordinator.viewModel.loadLibrary()
            await MainActor.run {
                context.coordinator.viewModel._showOnlyDownloadedTracker = context.coordinator.viewModel.showOnlyDownloaded
                let categories = context.coordinator.viewModel.displayedCategories
                context.coordinator.lastUpdateTrigger = context.coordinator.viewModel.updateTrigger
                vc.applyCategories(categories)
            }
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: iOSLibraryViewController, context: Context) {
        uiViewController.viewModel = context.coordinator.viewModel
        uiViewController.onDeleteBook = onDeleteSingleBook
        uiViewController.onDownloadBook = onDownloadSingleBook

        guard !context.coordinator.viewModel.isLoading else { return }

        let categories = context.coordinator.viewModel.displayedCategories
        let currentTrigger = context.coordinator.viewModel.updateTrigger

        if currentTrigger != context.coordinator.lastUpdateTrigger {
            context.coordinator.lastUpdateTrigger = currentTrigger
            uiViewController.applyCategories(categories)
        } else {
            uiViewController.reloadVisibleItems()
        }
    }

    class Coordinator {
        let navigationManager: iOSNavigationManager
        let viewModel: iOSLibraryViewModel
        var lastUpdateTrigger: Int = -1

        init(navigationManager: iOSNavigationManager, viewModel: iOSLibraryViewModel) {
            self.navigationManager = navigationManager
            self.viewModel = viewModel
        }
    }
}
