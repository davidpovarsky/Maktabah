import UIKit

enum RowiItem: Hashable {
    case tabaqa(TabaqaGroup)
    case rowi(Rowi)
    case loadMore(TabaqaGroup)

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .tabaqa(t): hasher.combine("tabaqa"); hasher.combine(t.code)
        case let .rowi(r): hasher.combine("rowi"); hasher.combine(r.id)
        case let .loadMore(t): hasher.combine("loadMore"); hasher.combine(t.code)
        }
    }

    static func == (lhs: RowiItem, rhs: RowiItem) -> Bool {
        switch (lhs, rhs) {
        case let (.tabaqa(a), .tabaqa(b)): a.code == b.code
        case let (.rowi(a), .rowi(b)): a.id == b.id
        case let (.loadMore(a), .loadMore(b)): a.code == b.code
        default: false
        }
    }
}

extension TabaqaGroup: Hashable {
    public static func == (lhs: TabaqaGroup, rhs: TabaqaGroup) -> Bool {
        lhs.code == rhs.code
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
}

extension Rowi: Hashable {
    public static func == (lhs: Rowi, rhs: Rowi) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class iOSRowiHierarchicalCollectionViewController: UIViewController {
    private(set) var collectionView: UICollectionView!
    private(set) var dataSource: UICollectionViewDiffableDataSource<Int, RowiItem>!
    private(set) var expandedTabaqas: Set<String> = []
    private var pendingGroups: [TabaqaGroup]?

    var onLoadMore: ((TabaqaGroup) -> Void)?
    var onSelectRowi: ((Rowi) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        configureDataSource()

        if let pending = pendingGroups {
            applyGroups(pending)
            pendingGroups = nil
        }
    }

    func makeListConfiguration() -> UICollectionLayoutListConfiguration {
        var config = UICollectionLayoutListConfiguration(
            appearance: UIDevice.current.userInterfaceIdiom == .pad ? .sidebar : .insetGrouped
        )
        config.showsSeparators = true
        return config
    }

    private func setupCollectionView() {
        let config = makeListConfiguration()
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.delegate = self
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func configureDataSource() {
        let font = UIFont(name: ArabicFont.kfgqpcUthmanTahaNaskh.rawValue, size: 16) ??
            .preferredFont(forTextStyle: .body)

        let tabaqaCellReg = UICollectionView.CellRegistration<UICollectionViewListCell, TabaqaGroup> { cell, _, group in
            var content = cell.defaultContentConfiguration()
            content.text = group.name
            content.textProperties.font = font
            content.textProperties.numberOfLines = 1
            content.image = UIImage(systemName: "folder.fill")
            content.imageProperties.tintColor = .tintColor
            cell.contentConfiguration = content
            cell.accessories = [.outlineDisclosure(options: .init(style: .header))]
        }

        let rowiCellReg = UICollectionView.CellRegistration<UICollectionViewListCell, Rowi> { cell, _, rowi in
            var content = cell.defaultContentConfiguration()
            content.text = rowi.isoName
            content.textProperties.font = font
            content.textProperties.numberOfLines = 1
            content.image = UIImage(systemName: "person.text.rectangle.fill")
            cell.contentConfiguration = content
            cell.accessories = []
        }

        let loadMoreCellReg = UICollectionView.CellRegistration<UICollectionViewListCell, TabaqaGroup> { cell, _, group in
            var content = cell.defaultContentConfiguration()
            content.text = "Load More..."
            content.textProperties.color = .tintColor
            content.textProperties.alignment = .center
            cell.contentConfiguration = content
            cell.accessories = []
        }

        dataSource = UICollectionViewDiffableDataSource<Int, RowiItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            switch item {
            case let .tabaqa(group):
                collectionView.dequeueConfiguredReusableCell(using: tabaqaCellReg, for: indexPath, item: group)
            case let .rowi(rowi):
                collectionView.dequeueConfiguredReusableCell(using: rowiCellReg, for: indexPath, item: rowi)
            case let .loadMore(group):
                collectionView.dequeueConfiguredReusableCell(using: loadMoreCellReg, for: indexPath, item: group)
            }
        }

        dataSource.sectionSnapshotHandlers.willExpandItem = { [weak self] item in
            if case let .tabaqa(t) = item { self?.expandedTabaqas.insert(t.code) }
        }
        dataSource.sectionSnapshotHandlers.willCollapseItem = { [weak self] item in
            if case let .tabaqa(t) = item { self?.expandedTabaqas.remove(t.code) }
        }
    }

    func applyGroups(_ groups: [TabaqaGroup], isSearching: Bool = false) {
        guard isViewLoaded else {
            pendingGroups = groups
            return
        }

        if dataSource.snapshot().numberOfSections == 0 {
            var rootSnapshot = NSDiffableDataSourceSnapshot<Int, RowiItem>()
            rootSnapshot.appendSections([0])
            dataSource.apply(rootSnapshot, animatingDifferences: false)
        }

        var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<RowiItem>()
        for group in groups {
            let groupItem = RowiItem.tabaqa(group)
            sectionSnapshot.append([groupItem])

            if expandedTabaqas.contains(group.code) || isSearching {
                sectionSnapshot.expand([groupItem])
            }

            var childrenItems: [RowiItem] = group.displayedRowis.map { .rowi($0) }
            if group.hasMore {
                childrenItems.append(.loadMore(group))
            }
            sectionSnapshot.append(childrenItems, to: groupItem)
        }

        // Pass true to let Diffable Data Source animate the inserted items gracefully without losing scroll position
        dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: true)
    }
}

extension iOSRowiHierarchicalCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case let .rowi(rowi):
            onSelectRowi?(rowi)
        case let .loadMore(group):
            onLoadMore?(group)
        case .tabaqa:
            break
        }
    }
}
