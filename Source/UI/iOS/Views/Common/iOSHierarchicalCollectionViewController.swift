import SwiftUI
import UIKit

// MARK: - Shared Types

struct LibraryTreeItemIdentifier: Hashable, Sendable {
    struct Component: Hashable, Sendable {
        enum Kind: String, Hashable, Sendable { case category, book }

        let kind: Kind
        let canonicalID: Int
        let canonicalLocator: String?
        let title: String
        let siblingOccurrence: Int
    }

    let path: [Component]
}

enum LibraryItem: Hashable, @unchecked Sendable {
    case category(LibraryTreeItemIdentifier, CategoryData)
    case book(LibraryTreeItemIdentifier, BooksData)
    case loadMore

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .category(identifier, _): hasher.combine("cat"); hasher.combine(identifier)
        case let .book(identifier, _): hasher.combine("book"); hasher.combine(identifier)
        case .loadMore: hasher.combine("loadMore")
        }
    }

    static func == (lhs: LibraryItem, rhs: LibraryItem) -> Bool {
        switch (lhs, rhs) {
        case let (.category(a, _), .category(b, _)): a == b
        case let (.book(a, _), .book(b, _)): a == b
        case (.loadMore, .loadMore): true
        default: false
        }
    }
}

// These model conformances remain canonical-ID based for existing non-tree UI
// consumers. LibraryItem deliberately does not use them: diffable identity is
// the stable LibraryTreeItemIdentifier for each presentation occurrence.
extension CategoryData: Hashable {
    public static func == (lhs: CategoryData, rhs: CategoryData) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension BooksData: Hashable {
    public static func == (lhs: BooksData, rhs: BooksData) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Controller

class iOSHierarchicalCollectionViewController: BaseHierarchicalListViewController<LibraryItem> {

    private(set) var expandedCategories: Set<LibraryTreeItemIdentifier> = []
    private var previousExpandedCategories: Set<LibraryTreeItemIdentifier> = []
    private var pendingCategories: [CategoryData]?
    private(set) var lastSnapshotError: Error?
    private(set) var lastAppliedItemCount = 0
    var onSnapshotError: ((Error) -> Void)?

    var loadMoreCount: Int = 0
    var showLoadMore: Bool = false
    var onLoadMore: (() -> Void)?
    var onShowBookInfo: ((BooksData) -> Void)?

    func makeBookInfoAction(for book: BooksData) -> UIAction {
        UIAction.bookInfo { [weak self] _ in
            self?.onShowBookInfo?(book)
        }
    }

    open func contextMenuActions(for book: BooksData) -> [UIAction] {
        [makeBookInfoAction(for: book)]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        if let pending = pendingCategories {
            applyCategories(pending)
            pendingCategories = nil
        }
    }

    override func trailingOffset(for item: LibraryItem) -> CGFloat {
        let root: Bool
        let indentationLevel: Int

        switch item {
        case .category(_, let category):
            root = true
            indentationLevel = category.level
        case .book(_, let book):
            root = false
            let level = LibraryDataManager.shared.categoryLevel(for: book)
            indentationLevel = level == 0 ? 1 : 2
        case .loadMore:
            return 16
        }
        // Menggunakan fungsi kalkulator dari Base Class
        return calculateTrailingOffset(isRoot: root, indentationLevel: indentationLevel)
    }

    // MARK: - Cell Registrations (Wajib di-override subclass seperti iOSSearchFilterViewController)

    func makeCategoryCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, CategoryData> {
        fatalError("\(type(of: self)) harus override makeCategoryCellRegistration()")
    }

    func makeBookCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, BooksData> {
        fatalError("\(type(of: self)) harus override makeBookCellRegistration()")
    }

    lazy var loadMoreCellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, LibraryItem> = UICollectionView.CellRegistration { [weak self] cell, _, item in
        var content = cell.defaultContentConfiguration()
        content.text = "Load More... (\(self?.loadMoreCount ?? 0) remaining)"
        content.textProperties.color = .tintColor
        content.textProperties.alignment = .center
        cell.contentConfiguration = content
        cell.accessories = []
        cell.applyThemeConfigurationUpdateHandler()
    }

    // MARK: - Data Source

    override func configureDataSource() {
        let categoryCellReg = makeCategoryCellRegistration()
        let bookCellReg = makeBookCellRegistration()
        let loadMoreReg = loadMoreCellRegistration

        dataSource = UICollectionViewDiffableDataSource<Int, LibraryItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            switch item {
            case let .category(_, category):
                collectionView.dequeueConfiguredReusableCell(
                    using: categoryCellReg, for: indexPath, item: category
                )
            case let .book(_, book):
                collectionView.dequeueConfiguredReusableCell(
                    using: bookCellReg, for: indexPath, item: book
                )
            case .loadMore:
                collectionView.dequeueConfiguredReusableCell(
                    using: loadMoreReg, for: indexPath, item: item
                )
            }
        }
        // Note: We handle expand/collapse manually since we use custom chevron instead of outlineDisclosure.
    }

    // MARK: - Data Loading

    func applyCategories(_ categories: [CategoryData]) {
        guard isViewLoaded else {
            pendingCategories = categories
            return
        }

        let plan: LibrarySnapshotPlan
        do {
            plan = try LibrarySnapshotPlan(categories: categories, expandedCategories: expandedCategories)
        } catch {
            lastSnapshotError = error
            showSnapshotError(error, retrying: categories)
            onSnapshotError?(error)
            return
        }

        lastSnapshotError = nil
        collectionView.backgroundView = nil

        if dataSource.snapshot().numberOfSections == 0 {
            var rootSnapshot = NSDiffableDataSourceSnapshot<Int, LibraryItem>()
            rootSnapshot.appendSections([0])
            dataSource.apply(rootSnapshot, animatingDifferences: false)
        }

        var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<LibraryItem>()
        for operation in plan.appendOperations {
            if let parent = operation.parent {
                sectionSnapshot.append([operation.item], to: parent)
            } else {
                sectionSnapshot.append([operation.item])
            }
        }
        if !plan.expandedItems.isEmpty {
            sectionSnapshot.expand(plan.expandedItems)
        }

        // Add Load More if needed
        if showLoadMore {
            sectionSnapshot.append([.loadMore])
        }

        lastAppliedItemCount = sectionSnapshot.items.count
        dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: false) { [weak self] in
            guard let self else { return }
            // Sync chevrons and update item UI states for all visible items.
            // Needed when applyCategories is called after sorting/filter changes or integration state updates.
            syncVisibleItems()
            NotificationCenter.default.post(
                name: .librarySnapshotDidApply,
                object: self,
                userInfo: ["itemCount": lastAppliedItemCount]
            )
        }
    }

    private func syncVisibleItems() {
        let visibleItems = collectionView.indexPathsForVisibleItems.compactMap {
            dataSource.itemIdentifier(for: $0)
        }
        guard !visibleItems.isEmpty else { return }
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(visibleItems)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Expand/Collapse

    /// Toggles the expanded state of a CategoryData and animates the chevron.
    func toggleCategory(_ item: LibraryItem) {
        guard case let .category(identifier, _) = item else { return }
        let willBeExpanded = !expandedCategories.contains(identifier)

        if willBeExpanded {
            expandedCategories.insert(identifier)
            previousExpandedCategories.insert(identifier)
        } else {
            expandedCategories.remove(identifier)
            previousExpandedCategories.remove(identifier)
        }

        toggleExpansion(for: item, isExpanding: willBeExpanded)
    }

    func isCategoryExpanded(at indexPath: IndexPath) -> Bool {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case let .category(identifier, _) = item else { return false }
        return expandedCategories.contains(identifier)
    }

    func snapshotItems(for book: BooksData) -> [LibraryItem] {
        dataSource.snapshot().itemIdentifiers.filter {
            guard case let .book(_, candidate) = $0 else { return false }
            if let locator = book.backendLocator, let candidateLocator = candidate.backendLocator {
                return locator.backend == candidateLocator.backend && locator.workKey == candidateLocator.workKey
            }
            return candidate.id == book.id
        }
    }

    private func showSnapshotError(_ error: Error, retrying categories: [CategoryData]) {
        let label = UILabel()
        label.text = String(localized: "The library catalog could not be displayed safely.")
        label.textAlignment = .center
        label.numberOfLines = 0

        let button = UIButton(type: .system)
        button.setTitle(String(localized: "Try Again"), for: .normal)
        button.addAction(UIAction { [weak self] _ in self?.applyCategories(categories) }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [label, button])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.accessibilityIdentifier = "library-catalog-recovery"
        collectionView.backgroundView = stack

        #if DEBUG
        print("Rejected unsafe library snapshot: \(error.localizedDescription)")
        #endif
    }

    // MARK: - Helpers

    func getAllBooks(in category: CategoryData) -> [BooksData] {
        category.allBooks
    }

    func getAllCategories(in category: CategoryData) -> [CategoryData] {
        category.allSubcategories
    }

    func reconfigureCategories(including extraItems: [LibraryItem] = []) {
        var items: [LibraryItem] = dataSource.snapshot().itemIdentifiers.filter {
            if case .category = $0 { return true }
            return false
        }
        items.append(contentsOf: extraItems)
        reconfigureItems(items)
    }

    func reconfigureCategories(includingBook book: BooksData) {
        reconfigureCategories(including: snapshotItems(for: book))
    }

    func reconfigureCategories(includingBooks books: [BooksData]) {
        let items = books.flatMap { snapshotItems(for: $0) }
        reconfigureCategories(including: items)
    }



    // MARK: - Selection Hooks

    open func didSelectBook(_ book: BooksData) {}
    open func didSelectLoadMore() {}
}

extension Notification.Name {
    static let librarySnapshotDidApply = Notification.Name("librarySnapshotDidApply")
}

private struct LibrarySnapshotPlan {
    struct AppendOperation {
        let item: LibraryItem
        let parent: LibraryItem?
    }

    let appendOperations: [AppendOperation]
    let expandedItems: [LibraryItem]

    init(categories: [CategoryData], expandedCategories: Set<LibraryTreeItemIdentifier>) throws {
        var operations: [AppendOperation] = []
        var expanded: [LibraryItem] = []
        var identifiers = Set<LibraryTreeItemIdentifier>()

        func appendCategories(
            _ categories: [CategoryData],
            parent: LibraryItem?,
            parentPath: [LibraryTreeItemIdentifier.Component],
            ancestors: Set<ObjectIdentifier>
        ) throws {
            var siblingOccurrences: [LibraryTreeItemIdentifier.Component: Int] = [:]

            for category in categories {
                let objectID = ObjectIdentifier(category)
                guard !ancestors.contains(objectID) else {
                    throw LibrarySnapshotBuildError.categoryCycle(name: category.name)
                }

                let base = LibraryTreeItemIdentifier.Component(
                    kind: .category,
                    canonicalID: category.id,
                    canonicalLocator: nil,
                    title: category.name,
                    siblingOccurrence: 0
                )
                let occurrence = siblingOccurrences[base, default: 0]
                siblingOccurrences[base] = occurrence + 1
                let component = LibraryTreeItemIdentifier.Component(
                    kind: .category,
                    canonicalID: category.id,
                    canonicalLocator: nil,
                    title: category.name,
                    siblingOccurrence: occurrence
                )
                let path = parentPath + [component]
                let identifier = LibraryTreeItemIdentifier(path: path)
                guard identifiers.insert(identifier).inserted else {
                    throw LibrarySnapshotBuildError.duplicateOccurrence(identifier)
                }

                let categoryItem = LibraryItem.category(identifier, category)
                operations.append(.init(item: categoryItem, parent: parent))
                if expandedCategories.contains(identifier) { expanded.append(categoryItem) }

                var subcategories: [CategoryData] = []
                var books: [BooksData] = []
                for child in category.children {
                    if let subcategory = child as? CategoryData {
                        subcategories.append(subcategory)
                    } else if let book = child as? BooksData {
                        books.append(book)
                    } else {
                        throw LibrarySnapshotBuildError.unsupportedChild(category: category.name)
                    }
                }

                var nextAncestors = ancestors
                nextAncestors.insert(objectID)
                try appendCategories(
                    subcategories,
                    parent: categoryItem,
                    parentPath: path,
                    ancestors: nextAncestors
                )

                var bookOccurrences: [LibraryTreeItemIdentifier.Component: Int] = [:]
                for book in books {
                    let base = LibraryTreeItemIdentifier.Component(
                        kind: .book,
                        canonicalID: book.id,
                        canonicalLocator: book.backendLocator?.persistenceKey,
                        title: book.book,
                        siblingOccurrence: 0
                    )
                    let occurrence = bookOccurrences[base, default: 0]
                    bookOccurrences[base] = occurrence + 1
                    let component = LibraryTreeItemIdentifier.Component(
                        kind: .book,
                        canonicalID: book.id,
                        canonicalLocator: book.backendLocator?.persistenceKey,
                        title: book.book,
                        siblingOccurrence: occurrence
                    )
                    let identifier = LibraryTreeItemIdentifier(path: path + [component])
                    guard identifiers.insert(identifier).inserted else {
                        throw LibrarySnapshotBuildError.duplicateOccurrence(identifier)
                    }
                    operations.append(.init(item: .book(identifier, book), parent: categoryItem))
                }
            }
        }

        try appendCategories(categories, parent: nil, parentPath: [], ancestors: [])
        guard identifiers.count == operations.count else {
            throw LibrarySnapshotBuildError.identifierCountMismatch
        }
        appendOperations = operations
        expandedItems = expanded
    }
}

// MARK: - UICollectionViewDelegate

extension iOSHierarchicalCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .category:
            toggleCategory(item)
        case let .book(_, book):
            didSelectBook(book)
        case .loadMore:
            didSelectLoadMore()
        }
    }

    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        !isGroup(dataSource.itemIdentifier(for: indexPath))
    }

    open func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first,
              let item = dataSource.itemIdentifier(for: indexPath),
              case let .book(_, book) = item
        else { return nil }

        let actions = contextMenuActions(for: book)
        guard !actions.isEmpty else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(title: "", children: actions)
        }
    }
}

private enum LibrarySnapshotBuildError: LocalizedError {
    case categoryCycle(name: String)
    case duplicateOccurrence(LibraryTreeItemIdentifier)
    case unsupportedChild(category: String)
    case identifierCountMismatch

    var errorDescription: String? {
        switch self {
        case .categoryCycle(let name): "Category cycle detected at \(name)."
        case .duplicateOccurrence: "The catalog produced a duplicate presentation identity."
        case .unsupportedChild(let category): "Unsupported catalog item under \(category)."
        case .identifierCountMismatch: "The catalog presentation identities are incomplete."
        }
    }
}

// MARK: - Book Info Helpers

extension UIAction {
    static func bookInfo(handler: @escaping (UIAction) -> Void) -> UIAction {
        UIAction(
            title: String(localized: .Library.bookInfo),
            image: UIImage(systemName: "info.circle"),
            handler: handler
        )
    }
}

struct BookInfoLabel: View {
    var body: some View {
        Label(String(localized: .Library.bookInfo), systemImage: "info.circle")
    }
}
