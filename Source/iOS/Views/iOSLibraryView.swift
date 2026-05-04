import SwiftUI
import UIKit

// MARK: - View Controller

class iOSLibraryViewController: iOSHierarchicalCollectionViewController {
    var onBookSelected: ((BooksData) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
    }

    // MARK: - Cell Registrations

    override func makeCategoryCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, CategoryData> {
        UICollectionView.CellRegistration { [weak self] cell, _, category in
            guard let self else { return }
            var content = cell.defaultContentConfiguration()
            content.text = category.name
            content.textProperties.font = font
            content.textProperties.numberOfLines = 1
            content.image = UIImage(systemName: "folder.fill")
            content.imageProperties.tintColor = .tintColor
            cell.contentConfiguration = content
            cell.accessories = [.outlineDisclosure(options: .init(style: .header))]
        }
    }

    override func makeBookCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, BooksData> {
        UICollectionView.CellRegistration { [weak self] cell, _, book in
            guard let self else { return }
            var content = cell.defaultContentConfiguration()
            content.text = book.book
            content.textProperties.font = font
            content.textProperties.numberOfLines = 1
            let isDownloaded = BookArchiveIntegrator.shared.isBookIntegrated(book)
            content.image = UIImage(systemName: isDownloaded ? "book.fill" : "icloud.and.arrow.down")
            content.imageProperties.tintColor = isDownloaded ? .tintColor : .secondaryLabel
            cell.accessories = []
            cell.contentConfiguration = content
        }
    }
}

// MARK: - UICollectionViewDelegate

extension iOSLibraryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case let .book(book) = item else { return }
        onBookSelected?(book)
    }
}

// MARK: - SwiftUI View

struct iOSLibraryView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager

    var body: some View {
        ZStack {
            LibraryViewControllerWrapper(
                navigationManager: navigationManager,
                viewModel: navigationManager.libraryViewModel,
                showOnlyDownloaded: Binding(
                    get: { navigationManager.libraryViewModel.showOnlyDownloaded },
                    set: { navigationManager.libraryViewModel.showOnlyDownloaded = $0 }
                )
            )
            .ignoresSafeArea(edges: [.vertical])
            .onChange(of: navigationManager.searchText) { _, newValue in
                navigationManager.libraryViewModel.searchText = newValue
            }

            if navigationManager.libraryViewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Loading Library...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).opacity(0.6))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navigationManager.libraryViewModel.showOnlyDownloaded.toggle()
                } label: {
                    Image(systemName: navigationManager.libraryViewModel.showOnlyDownloaded
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
}

// MARK: - UIViewControllerRepresentable Wrapper

private struct LibraryViewControllerWrapper: UIViewControllerRepresentable {
    let navigationManager: iOSNavigationManager
    let viewModel: iOSLibraryViewModel
    @Binding var showOnlyDownloaded: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(navigationManager: navigationManager, viewModel: viewModel)
    }

    func makeUIViewController(context: Context) -> iOSLibraryViewController {
        let vc = iOSLibraryViewController()
        vc.onBookSelected = { book in
            context.coordinator.navigationManager.openBook(book)
        }

        Task {
            await context.coordinator.viewModel.loadLibrary()
            await MainActor.run {
                // Saat awal load, init tracker dari UserDefaults
                context.coordinator.viewModel._showOnlyDownloadedTracker = context.coordinator.viewModel.showOnlyDownloaded
                vc.applyCategories(context.coordinator.viewModel.displayedCategories)
            }
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: iOSLibraryViewController, context: Context) {
        // Ini akan dipanggil SwiftUI ketika state berubah.
        // viewModel.displayedCategories akan dihitung ulang karena dependensi `_showOnlyDownloadedTracker`
        if !context.coordinator.viewModel.isLoading {
            uiViewController.applyCategories(context.coordinator.viewModel.displayedCategories)
        }
    }

    class Coordinator {
        let navigationManager: iOSNavigationManager
        let viewModel: iOSLibraryViewModel

        init(navigationManager: iOSNavigationManager, viewModel: iOSLibraryViewModel) {
            self.navigationManager = navigationManager
            self.viewModel = viewModel
        }
    }
}
