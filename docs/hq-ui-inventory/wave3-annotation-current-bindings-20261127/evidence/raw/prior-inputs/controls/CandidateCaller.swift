import Foundation
import OtzariaUIRouting

// Actual finite controller extension/expansion bodies; UIKit/data-source implementations
// and the surrounding original controller lifecycle are explicit test boundaries.
@MainActor final class iOSAnnotationViewController {
    weak var viewModel: AnnotationViewModel? {
        willSet {
            if viewModel !== newValue { nativeRoutingPublication.willPublish() }
        }
    }
    let nativeRoutingPublication = MaktabahNativeAnnotationListPublication()
    private weak var nativeRoutingBinding: MaktabahNativeAnnotationSelectionBinding?
    private var nativeRoutingOwner: UUID?
    private var nativeRoutingLastLayout: String?

    var isViewLoaded = true
    var viewIfLoaded: UIView?
    var isBeingDismissed = false
    var isMovingFromParent = false
    private(set) var collectionView: UICollectionView!
    private var dataSource: DataSource!
    private var expandedGroups: Set<String> = []
    init(window: UIWindow, model: AnnotationViewModel) {
        viewModel = model; viewIfLoaded = UIView(window)
        collectionView = UICollectionView(window); collectionView.parent = viewIfLoaded
        dataSource = DataSource()
    }
    func controlSeed(_ groups: [(String, Annotation)]) {
        dataSource.sections.removeAll(); collectionView.cells.removeAll()
        for (position, value) in groups.sorted(by: { $0.0 < $1.0 }).enumerated() {
            let group = SwiftUIAnnotationNode(id: value.0, title: value.0, kind: .tag, annotation: nil)
            let item = SwiftUIAnnotationNode(id: value.0 + "-ann-" + String(value.1.id!), title: "Actual note row", kind: .annotation, annotation: value.1)
            dataSource.sections[value.0] = .init(items: [.group(group),.annotation(item)])
            let groupCell = UICollectionViewCell(collectionView.window); groupCell.parent = viewIfLoaded
            groupCell.contentConfiguration = ListContentConfiguration(isExpanded: false)
            collectionView.cells[IndexPath(indexes:[position,0])] = groupCell
            let cell = UICollectionViewCell(collectionView.window); cell.parent = viewIfLoaded
            cell.contentConfiguration = AnnotationContentConfiguration(annotation: value.1)
            collectionView.cells[IndexPath(indexes:[position,1])] = cell
        }
    }
    func controlOriginalToggle() { toggleGroup(dataSource.sections[dataSource.sections.keys.sorted()[0]]!.items[0].node) }
    func controlOnExpansion(_ body: @escaping () -> Void) { dataSource.onApply = body }
    var controlExpansionCount: Int { dataSource.applies }
    func controlDuplicateRow() {
        nativeRoutingPublication.willPublish()
        let first = dataSource.sections.keys.sorted()[0]
        dataSource.sections[first]!.items.append(dataSource.sections[first]!.items[1])
    }
    private func toggleGroup(_ node: SwiftUIAnnotationNode) {
        nativeRoutingPublication.willPublish()
        let wasExpanded = expandedGroups.contains(node.id)
        setOriginalGroupExpanded(node, willExpand: !wasExpanded, animated: true)
    }
    private func setOriginalGroupExpanded(_ node: SwiftUIAnnotationNode, willExpand: Bool, animated: Bool,
                                          validating isCurrent: (@MainActor () -> Bool)? = nil) {
        guard isCurrent?() ?? true else { return }
        let id = node.id

        if willExpand {
            expandedGroups.insert(id)
        } else {
            expandedGroups.remove(id)
        }

        let groupItem = AnnotationItem.group(node)
        var sectionSnapshot = dataSource.snapshot(for: id)

        guard isCurrent?() ?? true else { return }
        if willExpand {
            sectionSnapshot.expand([groupItem])
        } else {
            sectionSnapshot.collapse([groupItem])
        }

        dataSource.apply(sectionSnapshot, to: id, animatingDifferences: animated)
        guard isCurrent?() ?? true else { return }
        if let indexPath = dataSource.indexPath(for: groupItem),
           let cell = collectionView.cellForItem(at: indexPath)
        {
            guard isCurrent?() ?? true else { return }
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                guard isCurrent?() ?? true else { return }
                if var config = cell.contentConfiguration as? ListContentConfiguration {
                    guard isCurrent?() ?? true else { return }
                    config.isExpanded = willExpand
                    cell.contentConfiguration = config
                }
            }
        }
    }
}

extension iOSAnnotationViewController {
    struct NativeRoutingRow {
        let section: String
        let group: SwiftUIAnnotationNode
        let item: AnnotationItem
        let annotation: Annotation
        var itemIdentity: String { item.node.id }
    }

    func nativeRoutingAttach(binding: MaktabahNativeAnnotationSelectionBinding?, owner: UUID?,
                             blocked: @escaping @MainActor () -> Bool) {
        guard let binding, let owner, let model = viewModel else { nativeRoutingDetach(); return }
        if nativeRoutingBinding !== binding || nativeRoutingOwner != owner {
            nativeRoutingDetach()
            nativeRoutingBinding = binding; nativeRoutingOwner = owner
        }
        binding.attach(controller: self, model: model, owner: owner, blocked: blocked)
        guard nativeRoutingBinding === binding, nativeRoutingOwner == owner else { return }
        nativeRoutingPublishLayout()
    }

    func nativeRoutingDetach() {
        let previous = nativeRoutingBinding, owner = nativeRoutingOwner
        nativeRoutingPublication.willPublish()
        nativeRoutingBinding = nil; nativeRoutingOwner = nil; nativeRoutingLastLayout = nil
        if let owner { previous?.detach(controller: self, owner: owner) }
    }

    /// Metadata is derived from the ORIGINAL diffable snapshot, including its
    /// section path. One annotation appearing under two tags is two distinct
    /// original rows and is never collapsed to its numeric database ID.
    func nativeRoutingRows() throws -> [NativeRoutingRow] {
        guard isViewLoaded, let dataSource, let collectionView,
              collectionView.refreshControl?.isRefreshing != true else {
            throw UIRouteError(.unavailable, "native_annotation_list_not_ready")
        }
        let sections = dataSource.snapshot().sectionIdentifiers
        guard sections.count <= 1_000 else {
            throw UIRouteError(.unavailable, "native_annotation_catalog_limit")
        }
        var rows: [NativeRoutingRow] = []
        for section in sections {
            let items = dataSource.snapshot(for: section).items
            let groups = items.filter(\.isGroup)
            guard groups.count == 1, let group = groups.first, group.node.id == section else {
                throw UIRouteError(.staleState, "native_annotation_section_ambiguous")
            }
            var identities: Set<String> = []
            for item in items where !item.isGroup {
                guard let annotation = item.node.annotation, let id = annotation.id, id > 0,
                      identities.insert(item.node.id).inserted, rows.count < 1_000 else {
                    throw UIRouteError(.staleState, "native_annotation_row_ambiguous")
                }
                rows.append(.init(section: section, group: group.node, item: item, annotation: annotation))
            }
        }
        return rows
    }

    func nativeRoutingMatches(_ row: NativeRoutingRow) -> Bool {
        guard let rows = try? nativeRoutingRows() else { return false }
        let matches = rows.filter { $0.section == row.section && $0.itemIdentity == row.itemIdentity }
        guard matches.count == 1, let current = matches.first else { return false }
        return current.annotation == row.annotation && current.group.id == row.group.id
            && current.group.title.utf8.elementsEqual(row.group.title.utf8)
            && current.group.kind == row.group.kind
            && current.item.node.title.utf8.elementsEqual(row.item.node.title.utf8)
    }

    /// Called only by the retained binding during the ONE canonical apply.
    /// This never calls didSelectItemAt, onAnnotationSelected, or an editor/
    /// persistence callback. All effects finish synchronously; later layout
    /// observation is read-only and cannot resume a feature mutation.
    func nativeRoutingReveal(_ row: NativeRoutingRow, validate: @escaping @MainActor () throws -> Void) throws {
        func requireCurrent() throws {
            try validate()
            guard nativeRoutingMatches(row), isViewLoaded, dataSource != nil, collectionView != nil else {
                throw UIRouteError(.staleState, "native_annotation_row_changed")
            }
            try validate()
        }
        try requireCurrent()
        let group = AnnotationItem.group(row.group)
        if !dataSource.snapshot(for: row.section).isExpanded(group) {
            setOriginalGroupExpanded(row.group, willExpand: true, animated: false,
                validating: { (try? requireCurrent()) != nil })
            try requireCurrent()
        }
        collectionView.layoutIfNeeded()
        try requireCurrent()
        guard let indexPath = dataSource.indexPath(for: row.item),
              dataSource.itemIdentifier(for: indexPath)?.node.annotation == row.annotation else {
            throw UIRouteError(.unavailable, "native_annotation_index_not_published")
        }
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        try requireCurrent()
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        try requireCurrent()
        collectionView.layoutIfNeeded()
        try requireCurrent()
    }

    func nativeRoutingSelectedCell(_ row: NativeRoutingRow) -> UICollectionViewCell? {
        guard nativeRoutingMatches(row), let indexPath = dataSource.indexPath(for: row.item),
              collectionView.indexPathsForSelectedItems == [indexPath],
              let cell = collectionView.cellForItem(at: indexPath), cell.isSelected,
              let configured = cell.contentConfiguration as? AnnotationContentConfiguration,
              configured.annotation == row.annotation else { return nil }
        return cell
    }

    fileprivate func nativeRoutingPublishLayout() {
        guard let binding = nativeRoutingBinding, let owner = nativeRoutingOwner else { return }
        let original = viewIfLoaded
        let visible = collectionView?.visibleCells.sorted { ObjectIdentifier($0).hashValue < ObjectIdentifier($1).hashValue }
            .map { "\(ObjectIdentifier($0)):\($0.frame):\($0.isSelected)" }.joined(separator: "|") ?? ""
        let signature = "\(String(describing: original?.window.map(ObjectIdentifier.init)))|\(String(describing: original?.frame))|\(visible)|\(isBeingDismissed)|\(isMovingFromParent)"
        guard signature != nativeRoutingLastLayout else { return }
        nativeRoutingLastLayout = signature
        binding.hostLayoutChanged(controller: self, owner: owner)
    }
}
