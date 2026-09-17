import SwiftUI
import UIKit

// MARK: - View Controller

class iOSSearchFilterViewController: iOSHierarchicalCollectionViewController {
    var selectedBookIds: Set<Int> = []

    var onSelectionChanged: ((Set<Int>) -> Void)?

    private var bookCache: [Int: [BooksData]] = [:] // key: category.id
    private var fullCategories: Set<Int> = [] // Cache untuk kategori yang semua bukunya terpilih

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
    }

    /// Reset cache saat categories berubah
    override func applyCategories(_ categories: [CategoryData]) {
        bookCache.removeAll()
        super.applyCategories(categories)
    }

    // MARK: - Cell Registrations

    override func makeCategoryCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, CategoryData> {
        UICollectionView.CellRegistration { [weak self] cell, _, category in
            guard let self else { return }

            let isExpanded = expandedCategories.contains(category.id)

            // Determine leading accessory: checkbox or folder icon
            let books = cachedBooks(for: category)
            let isSelected = !books.isEmpty && books.allSatisfy { [weak self] in
                guard let self else { return false }
                return selectedBookIds.contains($0.id)
            }
            let isPartial = !books.isEmpty && books.contains { [weak self] in
                guard let self else { return false }
                return selectedBookIds.contains($0.id)
            } && books.contains { [weak self] in
                guard let self else { return false }
                return !selectedBookIds.contains($0.id)
            }
            let checkboxState: CheckboxState = isPartial ? .partial : (isSelected ? .checked : .unchecked)
            let leadingAccessory: LeadingAccessoryType = .checkbox(checkboxState)

            let config = ListContentConfiguration(
                text: category.name,
                font: font,
                leadingAccessory: leadingAccessory,
                isExpanded: isExpanded,
                root: true,
                indentationLevel: category.level
            )
            cell.contentConfiguration = config
            cell.accessories = []

            // Wire up checkbox tap handler
            if let listContentView = cell.contentView as? ListContentView {
                listContentView.onCheckboxTap = { [weak self] in
                    guard let self else { return }
                    let currentBooks = cachedBooks(for: category)
                    let allSelected = currentBooks.allSatisfy { [weak self] in
                        guard let self else { return false }
                        return selectedBookIds.contains($0.id)
                    }

                    var newSelection = selectedBookIds
                    if allSelected {
                        currentBooks.forEach { newSelection.remove($0.id) }
                    } else {
                        currentBooks.forEach { newSelection.insert($0.id) }
                    }

                    selectedBookIds = newSelection
                    onSelectionChanged?(selectedBookIds)

                    // Reconfigure all categories so parents update their state
                    var items: [LibraryItem] = dataSource.snapshot().itemIdentifiers.filter {
                        if case .category = $0 { return true }
                        return false
                    }
                    items.append(contentsOf: currentBooks.map { .book($0) })
                    reconfigureItems(items)
                }
            }

            cell.applyThemeConfigurationUpdateHandler()
        }
    }

    override func makeBookCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, BooksData> {
        UICollectionView.CellRegistration { [weak self] cell, _, book in
            guard let self else { return }
            let isSelected = selectedBookIds.contains(book.id)
            let indentationLevel = LibraryDataManager.shared.categoryLevel(for: book)
            let config = ListContentConfiguration(
                text: book.book,
                font: font,
                leadingAccessory: .checkbox(isSelected ? .checked : .unchecked),
                isExpanded: false,
                root: false,
                indentationLevel: indentationLevel == 0 ? 1 : 2
            )
            cell.contentConfiguration = config
            cell.accessories = []

            // Wire up checkbox tap handler
            if let listContentView = cell.contentView as? ListContentView {
                listContentView.onCheckboxTap = { [weak self] in
                    guard let self else { return }
                    if selectedBookIds.contains(book.id) {
                        selectedBookIds.remove(book.id)
                    } else {
                        selectedBookIds.insert(book.id)
                    }
                    onSelectionChanged?(selectedBookIds)

                    // Reconfigure all categories to update parent states
                    var items: [LibraryItem] = dataSource.snapshot().itemIdentifiers.filter {
                        if case .category = $0 { return true }
                        return false
                    }
                    items.append(.book(book))
                    reconfigureItems(items)
                }
            }

            cell.applyThemeConfigurationUpdateHandler()
        }
    }

    func cachedBooks(for category: CategoryData) -> [BooksData] {
        if let cached = bookCache[category.id] { return cached }
        let books = getAllBooks(in: category)
        bookCache[category.id] = books
        return books
    }
}

// MARK: - UICollectionViewDelegate

extension iOSSearchFilterViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case let .category(category):
            toggleCategory(category)
        case let .book(book):
            if selectedBookIds.contains(book.id) { selectedBookIds.remove(book.id) }
            else { selectedBookIds.insert(book.id) }
            onSelectionChanged?(selectedBookIds)
            // Reconfigure all categories to update parent states
            var items: [LibraryItem] = dataSource.snapshot().itemIdentifiers.filter {
                if case .category = $0 { return true }
                return false
            }
            items.append(.book(book))
            reconfigureItems(items)
        case .loadMore:
            break
        }
    }

    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        !isGroup(dataSource.itemIdentifier(for: indexPath))
    }
}

// MARK: - SwiftUI Wrapper

struct SearchFilterUIKitView: UIViewControllerRepresentable {
    @Bindable var viewModel: SearchViewModel
    var displayedCategories: [CategoryData]
    var updateTrigger: Int = 0
    var onTap: () -> Void = {}

    func makeUIViewController(context: Context) -> iOSSearchFilterViewController {
        let vc = iOSSearchFilterViewController()
        vc.selectedBookIds = viewModel.selectedBookIds
        vc.onSelectionChanged = { ids in
            viewModel.setSelectedBooks(ids)
        }
        vc.additionalSafeAreaInsets.bottom = 50

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap)
        )
        tap.cancelsTouchesInView = false
        vc.view.addGestureRecognizer(tap)

        // Terapkan kategori awal
        context.coordinator.lastTrigger = updateTrigger
        vc.applyCategories(displayedCategories)

        return vc
    }

    func updateUIViewController(_ uiViewController: iOSSearchFilterViewController, context: Context) {
        context.coordinator.onTap = onTap

        let structureChanged = context.coordinator.hasChanged(trigger: updateTrigger)

        if structureChanged {
            uiViewController.selectedBookIds = viewModel.selectedBookIds
            uiViewController.applyCategories(displayedCategories)
        } else if uiViewController.selectedBookIds != viewModel.selectedBookIds {
            uiViewController.selectedBookIds = viewModel.selectedBookIds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    // MARK: - Coordinator

    class Coordinator {
        var lastTrigger: Int = -1
        var onTap: () -> Void

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap() { onTap() }

        func hasChanged(trigger: Int) -> Bool {
            if trigger != lastTrigger {
                lastTrigger = trigger
                return true
            }
            return false
        }
    }
}

// MARK: - Search Filter Modal View

struct SearchFilterModalView: UIViewControllerRepresentable {
    @Bindable var session: UnifiedSearchSessionController
    @Bindable var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let filterVC = iOSSearchFilterViewController()
        filterVC.title = "סינון לפי ספרים"
        filterVC.selectedBookIds = session.selectedBookIds
        filterVC.onSelectionChanged = { ids in
            session.selectedBookIds = ids
            viewModel.setSelectedBooks(ids)
            context.coordinator.updateToolbar(in: filterVC)
        }
        filterVC.applyCategories(viewModel.displayedCategories)

        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "חיפוש ספר"
        searchController.searchResultsUpdater = context.coordinator
        filterVC.navigationItem.searchController = searchController
        filterVC.navigationItem.hidesSearchBarWhenScrolling = false
        filterVC.definesPresentationContext = true

        let navController = UINavigationController(rootViewController: filterVC)
        context.coordinator.filterVC = filterVC
        context.coordinator.navController = navController
        context.coordinator.session = session
        context.coordinator.viewModel = viewModel
        context.coordinator.dismiss = { [weak navController] in
            navController?.dismiss(animated: true)
        }
        context.coordinator.updateToolbar(in: filterVC)

        return navController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        context.coordinator.session = session
        context.coordinator.viewModel = viewModel
        guard let filterVC = context.coordinator.filterVC else { return }

        let structureChanged = context.coordinator.hasChanged(trigger: viewModel.updateTrigger)
        if structureChanged {
            filterVC.selectedBookIds = session.selectedBookIds
            filterVC.applyCategories(viewModel.displayedCategories)
            context.coordinator.updateToolbar(in: filterVC)
        } else if filterVC.selectedBookIds != session.selectedBookIds {
            filterVC.selectedBookIds = session.selectedBookIds
            context.coordinator.updateToolbar(in: filterVC)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UISearchResultsUpdating {
        weak var filterVC: iOSSearchFilterViewController?
        weak var navController: UINavigationController?
        var session: UnifiedSearchSessionController?
        var viewModel: SearchViewModel?
        var dismiss: (() -> Void)?
        var lastTrigger: Int = -1

        func hasChanged(trigger: Int) -> Bool {
            if trigger != lastTrigger {
                lastTrigger = trigger
                return true
            }
            return false
        }

        func updateSearchResults(for searchController: UISearchController) {
            let text = searchController.searchBar.text ?? ""
            if viewModel?.filterText != text {
                viewModel?.filterText = text
            }
        }

        func updateToolbar(in vc: iOSSearchFilterViewController) {
            let doneButton = UIBarButtonItem(
                title: "אישור",
                style: .done,
                target: self,
                action: #selector(handleDone)
            )
            vc.navigationItem.rightBarButtonItem = doneButton

            if !(session?.selectedBookIds.isEmpty ?? true) {
                let clearButton = UIBarButtonItem(
                    title: "נקה הכל",
                    style: .plain,
                    target: self,
                    action: #selector(handleClear)
                )
                clearButton.tintColor = .systemRed
                vc.navigationItem.leftBarButtonItem = clearButton
            } else {
                vc.navigationItem.leftBarButtonItem = nil
            }
        }

        @objc func handleDone() {
            session?.showsBookFilterSheet = false
            dismiss?()
        }

        @objc func handleClear() {
            session?.clearFilter()
            viewModel?.setSelectedBooks([])
            if let filterVC {
                filterVC.selectedBookIds = []
                updateToolbar(in: filterVC)
                let snapshot = filterVC.dataSource.snapshot()
                filterVC.reconfigureItems(snapshot.itemIdentifiers)
            }
        }
    }
}
