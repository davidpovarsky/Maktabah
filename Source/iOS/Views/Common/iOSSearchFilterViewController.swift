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
            let isSelected = selectedBookIds.contains(book.id)
            content.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            content.imageProperties.tintColor = isSelected ? .tintColor : .secondaryLabel

            cell.contentConfiguration = content

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
    var displayedCategories: [CategoryData]
    var updateTrigger: Int = 0
    var onTap: () -> Void = {}

    func makeUIViewController(context: Context) -> iOSSearchFilterViewController {
        let vc = iOSSearchFilterViewController()
        vc.selectedBookIds = viewModel.selectedBookIds
        vc.onSelectionChanged = { ids in
            viewModel.selectedBookIds = ids
        }
        vc.additionalSafeAreaInsets.bottom = 50

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap)
        )
        tap.cancelsTouchesInView = false
        vc.view.addGestureRecognizer(tap)

        // Terapkan kategori awal
        let sig = context.coordinator.categoriesSignature(displayedCategories)
        context.coordinator.lastSignature = sig
        vc.applyCategories(displayedCategories)

        return vc
    }

    func updateUIViewController(_ uiViewController: iOSSearchFilterViewController, context: Context) {
        context.coordinator.onTap = onTap

        let structureChanged = context.coordinator.hasChanged(
            categories: displayedCategories,
            trigger: updateTrigger
        )

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
        var lastSignature: [String] = []
        var lastTrigger: Int = -1
        var onTap: () -> Void

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap() { onTap() }

        /// Deep signature — selalu deep karena filter/search selalu aktif di sini.
        func categoriesSignature(_ categories: [CategoryData]) -> [String] {
            var result: [String] = []
            func walk(_ cat: CategoryData) {
                result.append("c\(cat.id)")
                for child in cat.children {
                    if let b = child as? BooksData {
                        result.append("b\(b.id)")
                    } else if let sub = child as? CategoryData {
                        walk(sub)
                    }
                }
            }
            categories.forEach { walk($0) }
            return result
        }

        func hasChanged( categories: [CategoryData], trigger: Int) -> Bool {
            let newSig = categoriesSignature(categories)
            let changed = newSig != lastSignature || trigger != lastTrigger
            if changed {
                lastSignature = newSig
                lastTrigger = trigger
            }
            return changed
        }

    }
}
