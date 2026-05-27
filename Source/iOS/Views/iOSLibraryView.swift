import SwiftUI
import UIKit

// MARK: - View Controller

@MainActor
class iOSLibraryViewController: iOSHierarchicalCollectionViewController {
    var viewModel: iOSLibraryViewModel?
    var onBookSelected: ((BooksData) -> Void)?
    var onSelectionChanged: (() -> Void)?
    var onDeleteBook: ((BooksData) -> Void)?
    var onDownloadBook: ((BooksData) -> Void)?

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

            cell.applyThemeConfigurationUpdateHandler()
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

            cell.applyThemeConfigurationUpdateHandler()
        }
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

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first,
              let item = dataSource.itemIdentifier(for: indexPath),
              case let .book(book) = item,
              let viewModel = viewModel
        else {
            return nil
        }

        let isDownloaded = BookArchiveIntegrator.shared.isBookIntegrated(book)

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let selectAction = UIAction(
                title: String(localized: "Select") + "...",
                image: UIImage(systemName: "checkmark.circle")
            ) { _ in
                viewModel.enterSelectionMode(selecting: book)
                self?.reloadVisibleItems()
                self?.onSelectionChanged?()
            }

            let mainAction: UIAction
            if isDownloaded {
                mainAction = UIAction(
                    title: String(localized: "Delete Download"),
                    image: UIImage(systemName: "trash"),
                    attributes: .destructive
                ) { _ in
                    self?.onDeleteBook?(book)
                }
            } else {
                mainAction = UIAction(title: String(localized: "Download"), image: UIImage(systemName: "icloud.and.arrow.down")) { _ in
                    self?.onDownloadBook?(book)
                }
            }

            return UIMenu(title: "", children: [mainAction, selectAction])
        }
    }
}

// MARK: - SwiftUI View

struct iOSLibraryView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager
    @State private var showingDeleteConfirmation = false
    @State private var singleBookToDelete: BooksData?
    @State private var showingImportSheet = false

    var body: some View {
        let viewModel = navigationManager.libraryViewModel

        ZStack {
            LibraryViewControllerWrapper(
                navigationManager: navigationManager,
                viewModel: viewModel,
                showOnlyDownloaded: Binding(
                    get: { viewModel.showOnlyDownloaded },
                    set: { viewModel.showOnlyDownloaded = $0 }
                ),
                onDeleteSingleBook: { book in
                    singleBookToDelete = book
                },
                onDownloadSingleBook: { book in
                    navigationManager.showBookIntegrationConfirmation(
                        for: book,
                        initialContentId: nil
                    )
                }
            )
            .themeTint()
            .ignoresSafeArea(edges: [.vertical])

            if viewModel.isLoading {
                ProgressView("Loading Library...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themeBackground()
            }

            if !navigationManager.activeIntegrationStates.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    ActiveIntegrationStatesView()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: navigationManager.activeIntegrationStates.count)
        .onChange(of: viewModel.selectedBookIds) { _, _ in
            guard !viewModel.isBulkDownloading else { return }

            let downloadBooks = viewModel.selectedDownloadBooks
            if !downloadBooks.isEmpty {
                // Hanya update/tampilkan jika belum ada proses bulk confirmation aktif.
                let hasBulkConfirmation = navigationManager.activeIntegrationStates.contains { state in
                    if case .bulk = state.pendingData, state.mode == .confirmation { return true }
                    return false
                }

                if !hasBulkConfirmation {
                    navigationManager.showBulkDownloadConfirmation(books: downloadBooks)
                } else {
                    // Update existing bulk confirmation with new selection
                    if let bulkState = navigationManager.activeIntegrationStates.first(where: {
                        if case .bulk = $0.pendingData, $0.mode == .confirmation { return true }
                        return false
                    }) {
                        // We need to re-show or update it.
                        // Simplest is to remove and re-add or just update the state if possible.
                        // For now, let's remove the old confirmation and add new one to refresh size.
                        navigationManager.activeIntegrationStates.removeAll { $0.id == bulkState.id }
                        navigationManager.showBulkDownloadConfirmation(books: downloadBooks)
                    }
                }
            } else {
                // Jika seleksi download kosong, hapus bar konfirmasi bulk
                navigationManager.activeIntegrationStates.removeAll { state in
                    if case .bulk = state.pendingData, state.mode == .confirmation { return true }
                    return false
                }
            }
        }
        .toolbar {
            if viewModel.isSelectionMode {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.exitSelectionMode()
                    }
                    .disabled(viewModel.isBulkDownloading)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Label(
                            "Delete",
                            systemImage: "trash"
                        )
                    }
                    .disabled(viewModel.selectedDeleteCount == 0 || viewModel.isBulkDownloading)
                    .tint(.red)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: Binding(
                        get: { viewModel.showOnlyDownloaded },
                        set: { viewModel.showOnlyDownloaded = $0 }
                    )) {
                        Label("Downloaded", systemImage: "line.3.horizontal.decrease")
                    }
                    .labelStyle(.iconOnly)
                    .toggleStyle(.button)
                }

                CustomToolbarSpacer(placement: .topBarTrailing)

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.enterSelectionMode()
                        } label: {
                            Label("Select".localized + "...", systemImage: "checkmark.circle")
                        }

                        Button {
                            showingImportSheet = true
                        } label: {
                            Label("Import Book", systemImage: "plus.viewfinder")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel(String(localized: "Library Options"))
                    .help(String(localized: "Library Options"))
                }
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            NavigationView {
                OfflineImportFormView { url, metadata, authorRow in
                    // Handle the import here using BookUpdateManager
                    let updateManager = BookUpdateManager.shared
                    do {
                        let result = try await updateManager.importOfflineUpdate(
                            from: url,
                            providedMetadata: metadata,
                            authorRow: authorRow
                        )
                        try await LibraryDataManager.shared.processBookUpdates([result])
                        updateManager.integrateBooks(metadata: metadata)

                        showingImportSheet = false

                        ReusableFunc.showAlert(
                            title: String(localized: .importSuccessTitle),
                            message: String(localized: .importSuccessDesc)
                        )
                    } catch {
                        ReusableFunc.showAlert(
                            title: "Import Error",
                            message: error.localizedDescription
                        )
                    }
                }
            }
        }
        .alert("Delete Download", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.startBulkDeletion {
                    // Refreshed
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete the downloaded content for \(viewModel.selectedDeleteCount) books?")
        }
        .alert("Delete Download", isPresented: Binding(
            get: { singleBookToDelete != nil },
            set: { if !$0 { singleBookToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let book = singleBookToDelete {
                    Task {
                        try? await BookArchiveIntegrator.shared.removeBookFromArchive(book)
                        await viewModel.refreshLibrary()
                        await MainActor.run {
                            SettingsViewModel.shared.refreshPaths()
                        }
                        singleBookToDelete = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete the downloaded content for \"\(singleBookToDelete?.book ?? "")\"?")
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
        navigationManager.activeIntegrationStates.append(state)

        viewModel.startBulkDownload(progressState: state) { message in
            navigationManager.activeIntegrationStates.removeAll { $0.id == state.id }
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
    var onDeleteSingleBook: ((BooksData) -> Void)?
    var onDownloadSingleBook: ((BooksData) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(navigationManager: navigationManager, viewModel: viewModel)
    }

    func makeUIViewController(context: Context) -> iOSLibraryViewController {
        let vc = iOSLibraryViewController()
        vc.viewModel = viewModel
        vc.onBookSelected = { book in
            let lastId = HistoryViewModel.shared.entriesByBookId[book.id]?.lastContentId
            context.coordinator.navigationManager.openBook(book, initialContentId: lastId)
        }
        vc.onSelectionChanged = {
            context.coordinator.viewModel.selectedBookIds = context.coordinator.viewModel.selectedBookIds
        }
        vc.onDeleteBook = onDeleteSingleBook
        vc.onDownloadBook = onDownloadSingleBook

        Task {
            await context.coordinator.viewModel.loadLibrary()
            await MainActor.run {
                // Saat awal load, init tracker dari UserDefaults
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

        // Hanya proses jika tidak sedang loading
        guard !context.coordinator.viewModel.isLoading else { return }

        let categories = context.coordinator.viewModel.displayedCategories
        let currentTrigger = context.coordinator.viewModel.updateTrigger

        // Gunakan updateTrigger O(1) untuk mendeteksi perubahan struktur (tambah/hapus/filter)
        if currentTrigger != context.coordinator.lastUpdateTrigger {
            context.coordinator.lastUpdateTrigger = currentTrigger
            uiViewController.applyCategories(categories)
        } else {
            // Jika hanya seleksi yang berubah (ID yang sama), reconfigure item yang terlihat saja.
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
