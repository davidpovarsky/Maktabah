import SwiftUI
import UIKit

// MARK: - View Controller

class iOSSearchFilterViewController: iOSHierarchicalCollectionViewController {
    var selectedBookIds: Set<Int> = [] {
        didSet {
            reloadVisibleItems()
        }
    }

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

            var content = cell.defaultContentConfiguration()
            content.text = category.name
            content.textProperties.font = font
            content.textProperties.numberOfLines = 1
            cell.contentConfiguration = content

            // Satu kali lookup, di-cache
            let books = cachedBooks(for: category)
            // Cek apakah semua buku dalam kategori ini ada di selectedBookIds
            let isSelected = !books.isEmpty && books.allSatisfy { self.selectedBookIds.contains($0.id) }

            var checkboxConfig = UIButton.Configuration.plain()
            checkboxConfig.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            checkboxConfig.baseForegroundColor = isSelected ? .tintColor : .secondaryLabel

            let button = UIButton(configuration: checkboxConfig, primaryAction: UIAction { [weak self] _ in
                guard let self else { return }
                let currentBooks = cachedBooks(for: category)
                let allSelected = currentBooks.allSatisfy { self.selectedBookIds.contains($0.id) }

                var newSelection = selectedBookIds
                if allSelected {
                    currentBooks.forEach { newSelection.remove($0.id) }
                } else {
                    currentBooks.forEach { newSelection.insert($0.id) }
                }

                selectedBookIds = newSelection
                onSelectionChanged?(selectedBookIds)
            })

            cell.accessories = [
                .customView(configuration: .init(
                    customView: button,
                    placement: .leading(displayed: .always)
                )),
                .outlineDisclosure(options: .init(style: .header)),
            ]
        }
    }

    override func makeBookCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, BooksData> {
        UICollectionView.CellRegistration { [weak self] cell, _, book in
            guard let self else { return }
            var content = cell.defaultContentConfiguration()
            content.text = book.book
            content.textProperties.font = font
            content.textProperties.numberOfLines = 1
            let isSelected = selectedBookIds.contains(book.id)
            content.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            content.imageProperties.tintColor = isSelected ? .tintColor : .secondaryLabel

            cell.contentConfiguration = content
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
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case let .book(book) = item else { return }

        if selectedBookIds.contains(book.id) { selectedBookIds.remove(book.id) }
        else { selectedBookIds.insert(book.id) }
        onSelectionChanged?(selectedBookIds)
    }
}

// MARK: - SwiftUI Wrapper

struct SearchFilterUIKitView: UIViewControllerRepresentable {
    @Bindable var viewModel: iOSSearchViewModel

    func makeUIViewController(context: Context) -> iOSSearchFilterViewController {
        let vc = iOSSearchFilterViewController()
        vc.selectedBookIds = viewModel.selectedBookIds
        vc.onSelectionChanged = { ids in
            viewModel.selectedBookIds = ids
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: iOSSearchFilterViewController, context: Context) {
        // Hanya rebuild snapshot kalau categories berubah
        if context.coordinator.lastCategories != viewModel.displayedCategories {
            context.coordinator.lastCategories = viewModel.displayedCategories
            uiViewController.applyCategories(viewModel.displayedCategories)
        }

        if uiViewController.selectedBookIds != viewModel.selectedBookIds {
            uiViewController.selectedBookIds = viewModel.selectedBookIds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var lastCategories: [CategoryData] = []
    }
}
