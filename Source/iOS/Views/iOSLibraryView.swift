import SwiftUI
import UIKit

// MARK: - View Controller

@MainActor
class iOSLibraryViewController: iOSHierarchicalCollectionViewController {
    var viewModel: iOSLibraryViewModel?
    var onBookSelected: ((BooksData) -> Void)?
    var onSelectionChanged: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self

        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        collectionView.addGestureRecognizer(longPress)
    }

    // MARK: - Cell Registrations

    override func makeCategoryCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, CategoryData> {
        UICollectionView.CellRegistration { [weak self] cell, _, category in
            guard let self else { return }
            var content = cell.defaultContentConfiguration()
            content.text = category.name
            content.textProperties.font = font
            content.textProperties.numberOfLines = 1

            if viewModel?.isSelectionMode == true {
                content.image = nil
            } else {
                content.image = UIImage(systemName: "folder.fill")
                content.imageProperties.tintColor = .tintColor
            }

            cell.contentConfiguration = content

            let disclosure = UICellAccessory.outlineDisclosure(options: .init(style: .header))
            if viewModel?.isSelectionMode == true {
                let isSelected = viewModel?.isCategorySelected(category) == true
                let isPartial = viewModel?.isCategoryPartiallySelected(category) == true
                let imageName = isSelected
                    ? "checkmark.circle.fill"
                    : (isPartial ? "minus.circle.fill" : "circle")
                let checkbox = UIButton(type: .system)
                checkbox.setImage(UIImage(systemName: imageName), for: .normal)
                checkbox.tintColor = isSelected || isPartial ? .tintColor : .secondaryLabel
                checkbox.addAction(UIAction { [weak self] _ in
                    self?.viewModel?.toggleCategorySelection(category)
                    self?.reloadVisibleItems()
                    self?.onSelectionChanged?()
                }, for: .touchUpInside)

                let customAccessory = UICellAccessory.customView(
                    configuration: .init(customView: checkbox, placement: .leading())
                )
                cell.accessories = [customAccessory, disclosure]
            } else {
                cell.accessories = [disclosure]
            }
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
            if viewModel?.isSelectionMode == true {
                content.image = nil
            } else {
                content.image = UIImage(systemName: isDownloaded ? "book.fill" : "icloud.and.arrow.down")
                content.imageProperties.tintColor = isDownloaded ? .tintColor : .secondaryLabel
            }

            cell.contentConfiguration = content

            if viewModel?.isSelectionMode == true {
                let isSelected = viewModel?.isBookSelected(book) == true
                let checkbox = UIButton(type: .system)
                checkbox.setImage(UIImage(systemName: isSelected ? "checkmark.square.fill" : "square"), for: .normal)
                checkbox.tintColor = isDownloaded
                    ? .tertiaryLabel
                    : (isSelected ? .tintColor : .secondaryLabel)
                checkbox.isEnabled = !isDownloaded
                checkbox.addAction(UIAction { [weak self] _ in
                    self?.viewModel?.toggleBookSelection(book)
                    self?.reloadVisibleItems()
                    self?.onSelectionChanged?()
                }, for: .touchUpInside)

                let customAccessory = UICellAccessory.customView(
                    configuration: .init(customView: checkbox, placement: .leading())
                )
                cell.accessories = [customAccessory]
            } else {
                cell.accessories = []
            }
        }
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              let viewModel
        else { return }

        let point = recognizer.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point),
              let item = dataSource.itemIdentifier(for: indexPath)
        else { return }

        viewModel.isSelectionMode = true
        switch item {
        case let .category(category):
            viewModel.toggleCategorySelection(category)
        case let .book(book):
            viewModel.toggleBookSelection(book)
        }

        reloadVisibleItems()
        onSelectionChanged?()
    }
}

// MARK: - UICollectionViewDelegate

extension iOSLibraryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        if viewModel?.isSelectionMode == true {
            switch item {
            case let .category(category):
                viewModel?.toggleCategorySelection(category)
            case let .book(book):
                viewModel?.toggleBookSelection(book)
            }
            reloadVisibleItems()
            onSelectionChanged?()
            return
        }

        guard case let .book(book) = item else { return }
        onBookSelected?(book)
    }
}

// MARK: - SwiftUI View

struct iOSLibraryView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager

    var body: some View {
        let viewModel = navigationManager.libraryViewModel

        ZStack {
            LibraryViewControllerWrapper(
                navigationManager: navigationManager,
                viewModel: viewModel,
                showOnlyDownloaded: Binding(
                    get: { viewModel.showOnlyDownloaded },
                    set: { viewModel.showOnlyDownloaded = $0 }
                )
            )
            .ignoresSafeArea(edges: [.vertical])
            .onChange(of: navigationManager.searchText) { _, newValue in
                viewModel.searchText = newValue
            }

            if viewModel.isLoading {
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
            if viewModel.isSelectionMode {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.exitSelectionMode()
                    }
                    .disabled(viewModel.isBulkDownloading)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startSelectedDownloads(using: viewModel)
                    } label: {
                        Label(
                            "Download" + " (\(viewModel.selectedDownloadCount))",
                            systemImage: "tray.and.arrow.down.fill"
                        )
                    }
                    .disabled(viewModel.selectedDownloadCount == 0 || viewModel.isBulkDownloading)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showOnlyDownloaded.toggle()
                    } label: {
                        Image(systemName: viewModel.showOnlyDownloaded
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }

    private func startSelectedDownloads(using viewModel: iOSLibraryViewModel) {
        let state = BundleArchiveDownloadProgressState(
            title: NSLocalizedString(
                "Download Book",
                comment: "Bulk download window title"
            ),
            message: String(localized: "Begin downloading..."),
            mode: .downloading
        )
        navigationManager.bookIntegrationState = state

        viewModel.startBulkDownload(progressState: state) { message in
            navigationManager.bookIntegrationState = nil
            viewModel.exitSelectionMode()

            if let message {
                navigationManager.alertMessage = iOSNavigationManager.AlertMessage(
                    title: NSLocalizedString(
                        "Download Book",
                        comment: "Bulk download window title"
                    ),
                    message: message
                )
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
        vc.viewModel = viewModel
        vc.onBookSelected = { book in
            context.coordinator.navigationManager.openBook(book)
        }
        vc.onSelectionChanged = {
            context.coordinator.viewModel.selectedBookIds = context.coordinator.viewModel.selectedBookIds
        }

        Task {
            await context.coordinator.viewModel.loadLibrary()
            await MainActor.run {
                // Saat awal load, init tracker dari UserDefaults
                context.coordinator.viewModel._showOnlyDownloadedTracker = context.coordinator.viewModel.showOnlyDownloaded
                let categories = context.coordinator.viewModel.displayedCategories
                context.coordinator.lastAppliedCategoriesSignature = context.coordinator.categoriesSignature(categories)
                vc.applyCategories(categories)
            }
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: iOSLibraryViewController, context: Context) {
        uiViewController.viewModel = context.coordinator.viewModel
        // Ini akan dipanggil SwiftUI ketika state berubah.
        // Rebuild snapshot hanya saat data/filter/search mengubah isi tree.
        // Perubahan seleksi cukup reconfigure item visible agar scroll tidak reset ke atas.
        if !context.coordinator.viewModel.isLoading {
            let categories = context.coordinator.viewModel.displayedCategories
            let signature = context.coordinator.categoriesSignature(categories)
            if signature != context.coordinator.lastAppliedCategoriesSignature {
                context.coordinator.lastAppliedCategoriesSignature = signature
                uiViewController.applyCategories(categories)
            } else {
                uiViewController.reloadVisibleItems()
            }
        }
    }

    class Coordinator {
        let navigationManager: iOSNavigationManager
        let viewModel: iOSLibraryViewModel
        var lastAppliedCategoriesSignature: [String] = []

        init(navigationManager: iOSNavigationManager, viewModel: iOSLibraryViewModel) {
            self.navigationManager = navigationManager
            self.viewModel = viewModel
        }

        func categoriesSignature(_ categories: [CategoryData]) -> [String] {
            var result: [String] = []

            func appendCategory(_ category: CategoryData) {
                result.append("category-\(category.id)")
                for child in category.children {
                    if let book = child as? BooksData {
                        result.append("book-\(book.id)")
                    } else if let subCategory = child as? CategoryData {
                        appendCategory(subCategory)
                    }
                }
            }

            categories.forEach { appendCategory($0) }
            return result
        }
    }
}
