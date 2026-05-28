import UIKit

// MARK: - Shared Types

enum LibraryItem: Hashable, @unchecked Sendable {
    case category(CategoryData)
    case book(BooksData)

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .category(c): hasher.combine("cat"); hasher.combine(c.id)
        case let .book(b): hasher.combine("book"); hasher.combine(b.id)
        }
    }

    static func == (lhs: LibraryItem, rhs: LibraryItem) -> Bool {
        switch (lhs, rhs) {
        case let (.category(a), .category(b)): a.id == b.id
        case let (.book(a), .book(b)): a.id == b.id
        default: false
        }
    }
}

// MARK: - Shared Hashable Conformances

extension CategoryData: Hashable {
    public static func == (lhs: CategoryData, rhs: CategoryData) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension BooksData: Hashable {
    public static func == (lhs: BooksData, rhs: BooksData) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - UICollectionViewListCell Helper

extension UICollectionViewListCell {
    /// Menerapkan warna background tema secara dinamis, dan mereset saat sel difokuskan (isFocused).
    func applyThemeConfigurationUpdateHandler() {
        if SettingsViewModel.shared.useDefaultTheme { return }
        configurationUpdateHandler = { cell, state in
            if state.isFocused {
                cell.backgroundConfiguration = UIBackgroundConfiguration.listCell()
                return
            }

            var backgroundConfig = UIBackgroundConfiguration.listCell()
            backgroundConfig.backgroundColor = .appCellBackground
            cell.backgroundConfiguration = backgroundConfig
        }
    }
}

// MARK: - Base Controller

/// Base class untuk UICollectionView dengan layout hierarkis (outline).
/// Subclass wajib override `makeCategoryCellRegistration()` dan `makeBookCellRegistration()`.
class iOSHierarchicalCollectionViewController: UIViewController {
    private(set) var collectionView: UICollectionView!
    private(set) var dataSource: UICollectionViewDiffableDataSource<Int, LibraryItem>!

    private(set) var expandedCategories: Set<Int> = []
    private var pendingCategories: [CategoryData]?

    let font = UIFont(name: ArabicFont.kfgqpcUthmanTahaNaskh.rawValue, size: 16) ??
        .preferredFont(forTextStyle: .body)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        configureDataSource()

        if let pending = pendingCategories {
            applyCategories(pending)
            pendingCategories = nil
        }
    }

    // MARK: - Layout (override untuk kustomisasi appearance)

    func makeListConfiguration() -> UICollectionLayoutListConfiguration {
        var config = UICollectionLayoutListConfiguration(
            appearance: .insetGrouped
        )
        config.showsSeparators = true
        config.backgroundColor = .appBackground
        return config
    }

    // MARK: - Cell Registrations (wajib di-override)

    func makeCategoryCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, CategoryData> {
        fatalError("\(type(of: self)) harus override makeCategoryCellRegistration()")
    }

    func makeBookCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, BooksData> {
        fatalError("\(type(of: self)) harus override makeBookCellRegistration()")
    }

    // MARK: - Private Setup

    private func setupCollectionView() {
        let config = makeListConfiguration()
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = SettingsViewModel.shared.useDefaultTheme ? .systemGroupedBackground : .appBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.contentInsetAdjustmentBehavior = .automatic
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func configureDataSource() {
        let categoryCellReg = makeCategoryCellRegistration()
        let bookCellReg = makeBookCellRegistration()

        dataSource = UICollectionViewDiffableDataSource<Int, LibraryItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            switch item {
            case let .category(category):
                collectionView.dequeueConfiguredReusableCell(
                    using: categoryCellReg, for: indexPath, item: category
                )
            case let .book(book):
                collectionView.dequeueConfiguredReusableCell(
                    using: bookCellReg, for: indexPath, item: book
                )
            }
        }

        dataSource.sectionSnapshotHandlers.willExpandItem = { [weak self] item in
            if case let .category(cat) = item { self?.expandedCategories.insert(cat.id) }
        }
        dataSource.sectionSnapshotHandlers.willCollapseItem = { [weak self] item in
            if case let .category(cat) = item { self?.expandedCategories.remove(cat.id) }
        }
    }

    // MARK: - Data Loading

    func applyCategories(_ categories: [CategoryData]) {
        guard isViewLoaded else {
            pendingCategories = categories
            return
        }

        var rootSnapshot = NSDiffableDataSourceSnapshot<Int, LibraryItem>()
        rootSnapshot.appendSections([0])
        dataSource.apply(rootSnapshot, animatingDifferences: false)

        var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<LibraryItem>()
        buildSnapshot(&sectionSnapshot, from: categories, parent: nil)
        dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: false)
    }

    private func buildSnapshot(
        _ snapshot: inout NSDiffableDataSourceSectionSnapshot<LibraryItem>,
        from categories: [CategoryData],
        parent: LibraryItem?
    ) {
        for category in categories {
            let catItem = LibraryItem.category(category)

            if let parent { snapshot.append([catItem], to: parent) }
            else { snapshot.append([catItem]) }

            if expandedCategories.contains(category.id) { snapshot.expand([catItem]) }

            var subCats: [CategoryData] = []
            var bookItems: [LibraryItem] = []

            for child in category.children {
                if let subCat = child as? CategoryData { subCats.append(subCat) }
                else if let book = child as? BooksData { bookItems.append(.book(book)) }
            }

            if !subCats.isEmpty { buildSnapshot(&snapshot, from: subCats, parent: catItem) }
            if !bookItems.isEmpty { snapshot.append(bookItems, to: catItem) }
        }
    }

    // MARK: - Helpers

    /// Mengambil semua BooksData secara rekursif dari sebuah kategori.
    func getAllBooks(in category: CategoryData) -> [BooksData] {
        var books: [BooksData] = []
        for child in category.children {
            if let book = child as? BooksData { books.append(book) }
            else if let sub = child as? CategoryData { books.append(contentsOf: getAllBooks(in: sub)) }
        }
        return books
    }

    /// Reconfigure hanya item yang sedang terlihat tanpa rebuild snapshot penuh.
    func reloadVisibleItems() {
        guard isViewLoaded, dataSource != nil else { return }
        let visible = collectionView.indexPathsForVisibleItems.compactMap {
            dataSource.itemIdentifier(for: $0)
        }
        guard !visible.isEmpty else { return }
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(visible)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}
