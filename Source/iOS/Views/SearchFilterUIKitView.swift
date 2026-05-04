import SwiftUI
import UIKit

// MARK: - Data Item

enum SearchFilterItem: Hashable {
    case category(CategoryData)
    case book(BooksData)

    var id: String {
        switch self {
        case let .category(c): "cat-\(c.id)"
        case let .book(b): "book-\(b.id)"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SearchFilterItem, rhs: SearchFilterItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - View Controller

class iOSSearchFilterViewController: UIViewController {
    var viewModel: iOSSearchViewModel!
    var onSelectionChanged: (() -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, SearchFilterItem>!
    private var expandedCategories: Set<Int> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        configureDataSource()
        applyData()
    }

    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .sidebar)
        config.showsSeparators = true

        let layout = UICollectionViewCompositionalLayout.list(using: config)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func configureDataSource() {
        // Category Cell
        let categoryCellReg = UICollectionView.CellRegistration<UICollectionViewListCell, CategoryData> { [weak self] cell, _, category in
            guard let self else { return }

            var content = cell.defaultContentConfiguration()
            content.text = category.name
            content.textProperties.font = .preferredFont(forTextStyle: .headline)
            cell.contentConfiguration = content

            // Checkbox Accessory
            let isSelected = isCategorySelected(category)
            let checkbox = UIButton(type: .system)
            let imageName = isSelected ? "checkmark.circle.fill" : "circle"
            checkbox.setImage(UIImage(systemName: imageName), for: .normal)
            checkbox.tag = category.id
            checkbox.addAction(UIAction { _ in
                self.toggleCategory(category)
            }, for: .touchUpInside)

            let customAccessory = UICellAccessory.customView(configuration: .init(customView: checkbox, placement: .leading(priority: .high)))

            cell.accessories = [customAccessory, .outlineDisclosure()]
        }

        // Book Cell
        let bookCellReg = UICollectionView.CellRegistration<UICollectionViewListCell, BooksData> { [weak self] cell, _, book in
            guard let self else { return }

            var content = cell.defaultContentConfiguration()
            content.text = book.book
            content.textProperties.font = .preferredFont(forTextStyle: .body)
            cell.contentConfiguration = content

            // Checkbox Accessory
            let isSelected = viewModel.selectedBookIds.contains(book.id)
            let checkbox = UIButton(type: .system)
            let imageName = isSelected ? "checkmark.square.fill" : "square"
            checkbox.setImage(UIImage(systemName: imageName), for: .normal)
            checkbox.addAction(UIAction { _ in
                self.toggleBook(book)
            }, for: .touchUpInside)

            let customAccessory = UICellAccessory.customView(configuration: .init(customView: checkbox, placement: .leading(priority: .high)))

            cell.accessories = [customAccessory]
        }

        dataSource = UICollectionViewDiffableDataSource<Int, SearchFilterItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            switch item {
            case let .category(cat):
                collectionView.dequeueConfiguredReusableCell(using: categoryCellReg, for: indexPath, item: cat)
            case let .book(book):
                collectionView.dequeueConfiguredReusableCell(using: bookCellReg, for: indexPath, item: book)
            }
        }
    }

    func applyData() {
        var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<SearchFilterItem>()
        buildSnapshot(&sectionSnapshot, from: viewModel.displayedCategories, parent: nil)
        dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: false)
    }

    private func buildSnapshot(
        _ snapshot: inout NSDiffableDataSourceSectionSnapshot<SearchFilterItem>,
        from categories: [CategoryData],
        parent: SearchFilterItem?
    ) {
        for category in categories {
            let catItem = SearchFilterItem.category(category)
            if let parent {
                snapshot.append([catItem], to: parent)
            } else {
                snapshot.append([catItem])
            }

            // Re-expand if it was expanded
            if expandedCategories.contains(category.id) {
                snapshot.expand([catItem])
            }

            var children: [SearchFilterItem] = []
            var subCats: [CategoryData] = []

            for child in category.children {
                if let sub = child as? CategoryData {
                    subCats.append(sub)
                } else if let book = child as? BooksData {
                    children.append(.book(book))
                }
            }

            if !subCats.isEmpty {
                buildSnapshot(&snapshot, from: subCats, parent: catItem)
            }
            if !children.isEmpty {
                snapshot.append(children, to: catItem)
            }
        }
    }

    // MARK: - Logic

    private func isCategorySelected(_ category: CategoryData) -> Bool {
        let books = getAllBooks(in: category)
        if books.isEmpty { return false }
        return books.allSatisfy { viewModel.selectedBookIds.contains($0.id) }
    }

    private func getAllBooks(in category: CategoryData) -> [BooksData] {
        var books: [BooksData] = []
        for child in category.children {
            if let book = child as? BooksData {
                books.append(book)
            } else if let sub = child as? CategoryData {
                books.append(contentsOf: getAllBooks(in: sub))
            }
        }
        return books
    }

    private func toggleCategory(_ category: CategoryData) {
        let books = getAllBooks(in: category)
        let currentlySelected = isCategorySelected(category)

        if currentlySelected {
            books.forEach { viewModel.selectedBookIds.remove($0.id) }
        } else {
            books.forEach { viewModel.selectedBookIds.insert($0.id) }
        }

        // Refresh visible cells
        collectionView.reloadData()
        onSelectionChanged?()
    }

    private func toggleBook(_ book: BooksData) {
        if viewModel.selectedBookIds.contains(book.id) {
            viewModel.selectedBookIds.remove(book.id)
        } else {
            viewModel.selectedBookIds.insert(book.id)
        }
        collectionView.reloadData()
        onSelectionChanged?()
    }
}

extension iOSSearchFilterViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        // In sidebar mode, tapping the row usually toggles expansion for categories
        if case let .category(cat) = item {
            var snapshot = dataSource.sectionSnapshot(for: 0)
            if snapshot.isExpanded(item) {
                snapshot.collapse([item])
                expandedCategories.remove(cat.id)
            } else {
                snapshot.expand([item])
                expandedCategories.insert(cat.id)
            }
            dataSource.apply(snapshot, to: 0)
        } else if case let .book(book) = item {
            toggleBook(book)
        }
    }
}

// MARK: - SwiftUI Wrapper

struct SearchFilterUIKitView: UIViewControllerRepresentable {
    @Bindable var viewModel: iOSSearchViewModel

    func makeUIViewController(context: Context) -> iOSSearchFilterViewController {
        let vc = iOSSearchFilterViewController()
        vc.viewModel = viewModel
        vc.onSelectionChanged = {
            // This triggers SwiftUI view update if needed
            viewModel.selectedBookIds = viewModel.selectedBookIds
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: iOSSearchFilterViewController, context: Context) {
        // Handle external updates if necessary
    }
}
