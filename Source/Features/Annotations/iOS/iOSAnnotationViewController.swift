//
//  iOSAnnotationViewController.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 10/06/26.
//

import UIKit

class iOSAnnotationViewController: UIViewController {
    // MARK: - Public interface

    weak var viewModel: AnnotationViewModel? {
        willSet {
            if viewModel !== newValue { nativeRoutingPublication.willPublish() }
        }
    }
    let nativeRoutingPublication = MaktabahNativeAnnotationListPublication()
    private weak var nativeRoutingBinding: MaktabahNativeAnnotationSelectionBinding?
    private var nativeRoutingOwner: UUID?
    private var nativeRoutingLastLayout: String?
    var onAnnotationSelected: ((SwiftUIAnnotationNode) -> Void)?
    var onAnnotationDeleted: ((SwiftUIAnnotationNode) -> Void)?
    var onAnnotationEditRequested: ((Annotation) -> Void)?
    var onNeedFullReload: (() -> Void)?
    var onRefreshRequested: (() -> Void)?
    var onShowBookInfo: ((BooksData) -> Void)?

    // MARK: - Properties

    private(set) var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<String, AnnotationItem>!
    private var expandedGroups: Set<String> = []

    private let font = UIFont.arabicFont(size: 20)

    private var currentNodes: [SwiftUIAnnotationNode] = []
    private var currentGroupingMode: AnnotationGroupingMode = .book

    private let sectionInsets: NSDirectionalEdgeInsets = .init(
        top: 5, leading: ListLayoutMetrics.defaultPadding, bottom: 5, trailing: ListLayoutMetrics.defaultPadding
    )

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        configureDataSource()
        if !currentNodes.isEmpty {
            rebuildSnapshot(animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nativeRoutingPublishLayout()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        nativeRoutingPublishLayout()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        nativeRoutingPublishLayout()
    }

    // MARK: - Full Rebuild (nodes passed from ViewModel)

    func handleTreeUpdate(nodes: [SwiftUIAnnotationNode], groupingMode: AnnotationGroupingMode) {
        nativeRoutingPublication.willPublish()
        currentNodes = nodes
        currentGroupingMode = groupingMode
        guard isViewLoaded, dataSource != nil else { return }
        rebuildSnapshot(animated: true)
    }

    // MARK: - Incremental Update Entry Point

    func handleIncrementalUpdate(diff: AnnotationTreeDiff) {
        nativeRoutingPublication.willPublish()
        guard isViewLoaded, dataSource != nil else {
            onNeedFullReload?()
            return
        }

        switch diff.changeType {
        case .added:
            handleAddedAnnotation(annotationId: diff.annotationId, diff: diff.tagDiff, oldParentIndex: diff.oldParentIndex, newParentIndex: diff.newParentIndex)
        case .updated:
            handleUpdatedAnnotation(annotationId: diff.annotationId, diff: diff.tagDiff)
        case .deleted:
            handleDeletedAnnotation(annotationId: diff.annotationId, oldParentIndex: diff.oldParentIndex, newParentIndex: diff.newParentIndex)
        }
    }

    // MARK: - Incremental Updates

    private func handleAddedAnnotation(annotationId: Int64?, diff: TagUpdateDiff?, oldParentIndex: Int?, newParentIndex: Int?) {
        if let diff {
            handleTagDiff(diff)
            return
        }

        // Book mode fallback
        onNeedFullReload?()
    }

    private func handleUpdatedAnnotation(annotationId: Int64?, diff: TagUpdateDiff?) {
        if let diff {
            handleTagDiff(diff)
            return
        }

        // Book mode fallback
        if let annotationId {
            guard let updatedAnnotation = AnnotationStore.shared.loadAnnotationById(annotationId) else {
                onNeedFullReload?()
                return
            }

            updateItemInSections(with: updatedAnnotation)
        } else {
            onNeedFullReload?()
        }
    }

    private func handleTagDiff(_ diff: TagUpdateDiff) {
        processTagDiffRemovals(diff.removed)
        processTagDiffAdditions(diff.added)

        for node in diff.updated {
            if let ann = node.annotation {
                updateItemInSections(with: ann)
            }
        }
    }

    private func processTagDiffRemovals(_ removed: [TagUpdateDiff.RemovedEntry]) {
        for entry in removed {
            let sectionID = SwiftUIAnnotationNode.id(from: entry.tagNode)
            var sectionSnap = dataSource.snapshot(for: sectionID)
            let targetAnnotationId = entry.annotationNode.annotation?.id

            let itemsToDelete = sectionSnap.items.filter {
                if case let .annotation(node) = $0 {
                    return node.annotation?.id == targetAnnotationId
                }
                return false
            }

            if !itemsToDelete.isEmpty {
                sectionSnap.delete(itemsToDelete)
                dataSource.apply(sectionSnap, to: sectionID, animatingDifferences: true)
            }

            if entry.tagNodeBecomesEmpty {
                var rootSnap = dataSource.snapshot()
                rootSnap.deleteSections([sectionID])
                expandedGroups.remove(sectionID)
                dataSource.apply(rootSnap, animatingDifferences: true)
            }
        }
    }

    private func processTagDiffAdditions(_ added: [TagUpdateDiff.AddedEntry]) {
        for entry in added {
            let sectionID = SwiftUIAnnotationNode.id(from: entry.tagNode)

            var rootSnap = dataSource.snapshot()
            if !rootSnap.sectionIdentifiers.contains(sectionID) {
                if let rootNodes = AnnotationTreeBuilder.shared.currentRootNode()?.children,
                   let newIndex = rootNodes.firstIndex(where: { $0 === entry.tagNode }),
                   newIndex + 1 < rootNodes.count
                {
                    let nextNode = rootNodes[newIndex + 1]
                    let nextSectionID = SwiftUIAnnotationNode.id(from: nextNode)
                    if rootSnap.sectionIdentifiers.contains(nextSectionID) {
                        rootSnap.insertSections([sectionID], beforeSection: nextSectionID)
                    } else {
                        rootSnap.appendSections([sectionID])
                    }
                } else {
                    rootSnap.appendSections([sectionID])
                }
                dataSource.apply(rootSnap, animatingDifferences: true)
            }

            var sectionSnap = dataSource.snapshot(for: sectionID)
            let existingGroupItem = sectionSnap.items.first {
                if case .group = $0 {
                    return true
                }
                return false
            }

            let groupItem: AnnotationItem
            if let existing = existingGroupItem {
                groupItem = existing
            } else {
                let groupNode = SwiftUIAnnotationNode(
                    id: sectionID,
                    title: entry.tagNode.title,
                    kind: entry.tagNode.kind,
                    annotation: nil,
                    children: nil
                )
                groupItem = AnnotationItem.group(groupNode)
                sectionSnap.append([groupItem])
            }

            let newNode = SwiftUIAnnotationNode(from: entry.annotationNode, parentId: sectionID)
            let newItem = AnnotationItem.annotation(newNode)

            if !sectionSnap.items.contains(where: { $0.node.annotation?.id == newNode.annotation?.id }) {
                sectionSnap.append([newItem], to: groupItem)
                dataSource.apply(sectionSnap, to: sectionID, animatingDifferences: true)
            }
        }
    }

    private func handleDeletedAnnotation(annotationId: Int64?, oldParentIndex: Int?, newParentIndex: Int?) {
        guard let annotationId else {
            onNeedFullReload?()
            return
        }

        for sectionID in dataSource.snapshot().sectionIdentifiers {
            var sectionSnap = dataSource.snapshot(for: sectionID)

            let itemsToDelete = sectionSnap.items.filter {
                if case let .annotation(node) = $0 {
                    return node.annotation?.id == annotationId
                }
                return false
            }

            guard !itemsToDelete.isEmpty else { continue }

            sectionSnap.delete(itemsToDelete)
            dataSource.apply(sectionSnap, to: sectionID, animatingDifferences: true)

            // Remove section if no annotations remain
            let hasAnnotations = dataSource.snapshot(for: sectionID).items.contains {
                if case .annotation = $0 {
                    return true
                }
                return false
            }
            if !hasAnnotations {
                var rootSnap = dataSource.snapshot()
                rootSnap.deleteSections([sectionID])
                expandedGroups.remove(sectionID)
                dataSource.apply(rootSnap, animatingDifferences: true)
            }
        }

        onNeedFullReload?()
    }

    // MARK: - Reconfigure Items Helper

    /// Mengganti item lama dengan yang baru langsung di section snapshot untuk memastikan struktur hierarki terjaga
    private func updateItemInSections(with updatedAnnotation: Annotation) {
        var found = false
        for sectionID in dataSource.snapshot().sectionIdentifiers {
            var sectionSnapshot = dataSource.snapshot(for: sectionID)

            let oldItems = sectionSnapshot.items.filter {
                $0.node.annotation?.id == updatedAnnotation.id
            }

            if !oldItems.isEmpty {
                for oldItem in oldItems {
                    let updatedNode = SwiftUIAnnotationNode(
                        id: oldItem.node.id, // Pertahankan ID unik yang ada (termasuk parent ID)
                        title: updatedAnnotation.note?.isEmpty == false ? updatedAnnotation.note! : updatedAnnotation.context,
                        kind: .annotation,
                        annotation: updatedAnnotation,
                        children: nil
                    )
                    let updatedItem = AnnotationItem.annotation(updatedNode)

                    if oldItem == updatedItem {
                        continue
                    }

                    sectionSnapshot.insert([updatedItem], after: oldItem)
                    sectionSnapshot.delete([oldItem])
                }
                dataSource.apply(sectionSnapshot, to: sectionID, animatingDifferences: true)
                found = true
            }
        }

        if !found {
            onNeedFullReload?()
        }
    }

    // MARK: - Setup

    private func setupCollectionView() {
        let layout = createCompositionalLayout()

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(
            iOSTagFilterHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: iOSTagFilterHeaderView.reuseIdentifier
        )
        collectionView.backgroundColor = SettingsViewModel.shared.useDefaultTheme
            ? .systemGroupedBackground : .appBackground
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.semanticContentAttribute = .forceLeftToRight
        collectionView.delegate = self

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl

        collectionView.pinToEdges(of: view)
    }

    private func createCompositionalLayout() -> UICollectionViewLayout {
        let listConfig = createListLayoutConfiguration()
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(40)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        header.pinToVisibleBounds = false

        let layoutConfig = UICollectionViewCompositionalLayoutConfiguration()
        layoutConfig.boundarySupplementaryItems = [header]

        return UICollectionViewCompositionalLayout(sectionProvider: { [weak self] _, environment in
            guard let self else {
                return NSCollectionLayoutSection.list(using: listConfig, layoutEnvironment: environment)
            }
            let section = NSCollectionLayoutSection.list(using: listConfig, layoutEnvironment: environment)
            section.contentInsets = sectionInsets
            return section
        }, configuration: layoutConfig)
    }

    private func createListLayoutConfiguration() -> UICollectionLayoutListConfiguration {
        var listConfig = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        listConfig.showsSeparators = true
        listConfig.backgroundColor = .appBackground
        listConfig.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self,
                  let dataSource,
                  let item = dataSource.itemIdentifier(for: indexPath),
                  case let .annotation(node) = item
            else { return nil }

            let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, _ in
                guard let self else { return }
                nativeRoutingPublication.willPublish()
                var snap = dataSource.snapshot()
                snap.deleteItems([item])
                dataSource.apply(snap, animatingDifferences: true)
                onAnnotationDeleted?(node)
            }
            delete.image = UIImage(systemName: "trash")
            return UISwipeActionsConfiguration(actions: [delete])
        }

        listConfig.setStandardItemSeparatorHandler { [weak self] indexPath in
            guard let self,
                  let item = dataSource?.itemIdentifier(for: indexPath)
            else { return 16 }
            return trailingOffset(for: item)
        }

        return listConfig
    }

    private func configureDataSource() {
        let groupCellReg = makeGroupCellRegistration()
        let annotationCellReg = makeAnnotationCellRegistration()

        dataSource = UICollectionViewDiffableDataSource<String, AnnotationItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(
                using: item.isGroup ? groupCellReg : annotationCellReg,
                for: indexPath, item: item.node
            )
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader else { return nil }
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: iOSTagFilterHeaderView.reuseIdentifier,
                for: indexPath
            ) as? iOSTagFilterHeaderView
            self?.configureTagFilterHeader(header)
            return header
        }
    }

    private func makeGroupCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, SwiftUIAnnotationNode> {
        UICollectionView.CellRegistration<UICollectionViewListCell, SwiftUIAnnotationNode> { [weak self] cell, _, node in
            guard let self else { return }
            let isExpanded = expandedGroups.contains(node.id)
            let iconName = iconForKind(node.kind)

            let config = ListContentConfiguration(
                text: node.title,
                font: font,
                leadingAccessory: .icon(iconName),
                isExpanded: isExpanded,
                root: true,
                indentationLevel: 0
            )
            cell.contentConfiguration = config
            cell.accessories = []
            cell.applyThemeConfigurationUpdateHandler()
        }
    }

    private func makeAnnotationCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, SwiftUIAnnotationNode> {
        UICollectionView.CellRegistration<UICollectionViewListCell, SwiftUIAnnotationNode> { [weak self] cell, _, node in
            guard let self else { return }
            let config = AnnotationContentConfiguration(
                annotation: node.annotation,
                bookTitle: node.bookTitle,
                groupingMode: currentGroupingMode
            )
            cell.contentConfiguration = config
            cell.accessories = []
            cell.applyThemeConfigurationUpdateHandler()
        }
    }

    // MARK: - Data

    func applyNodes(_ nodes: [SwiftUIAnnotationNode], groupingMode: AnnotationGroupingMode, animated: Bool = false) {
        nativeRoutingPublication.willPublish()
        currentNodes = nodes
        currentGroupingMode = groupingMode

        guard isViewLoaded, dataSource != nil else {
            return
        }
        rebuildSnapshot(animated: animated)
    }

    private func rebuildSnapshot(animated: Bool) {
        let newSectionIDs = currentNodes.map(\.id)
        let currentSectionIDs = dataSource.snapshot().sectionIdentifiers

        if newSectionIDs != currentSectionIDs {
            var rootSnapshot = NSDiffableDataSourceSnapshot<String, AnnotationItem>()
            rootSnapshot.appendSections(newSectionIDs)
            dataSource.apply(rootSnapshot, animatingDifferences: false)
        }

        for node in currentNodes {
            let sectionID = node.id
            let existing = dataSource.snapshot(for: sectionID)

            var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<AnnotationItem>()
            let groupItem = AnnotationItem.group(node)
            sectionSnapshot.append([groupItem])

            let isSearching = !(viewModel?.searchText.isEmpty ?? true)
            let isExpanded = isSearching || expandedGroups.contains(sectionID)

            if let children = node.children, !children.isEmpty {
                let childItems = children.map { AnnotationItem.annotation($0) }
                sectionSnapshot.append(childItems, to: groupItem)
                if isExpanded {
                    sectionSnapshot.expand([groupItem])
                }
            }

            // Ambil expanded state dari existing snapshot agar tidak konflik
            if !isSearching, !existing.items.isEmpty {
                let existingExpanded = existing.isExpanded(groupItem)
                if existingExpanded != isExpanded {
                    if existingExpanded {
                        expandedGroups.insert(sectionID)
                        sectionSnapshot.expand([groupItem])
                    } else {
                        expandedGroups.remove(sectionID)
                    }
                }
            }

            guard existing.items != sectionSnapshot.items ||
                existing.visibleItems != sectionSnapshot.visibleItems
            else {
                continue
            }

            dataSource.apply(sectionSnapshot, to: sectionID, animatingDifferences: animated)
        }
    }

    // MARK: - Expand / Collapse

    private func toggleGroup(_ node: SwiftUIAnnotationNode) {
        nativeRoutingPublication.willPublish()
        let wasExpanded = expandedGroups.contains(node.id)
        setOriginalGroupExpanded(node, willExpand: !wasExpanded, animated: true)
    }

    /// The existing expansion owner serves both ordinary taps and the single
    /// canonical reveal. Ordinary toggle arguments and effects are unchanged.
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

    // MARK: - Helpers

    private func iconForKind(_ kind: AnnotationNodeKind) -> String {
        switch kind {
        case .book: "book.pages.fill"
        case .tag: "tag.fill"
        case .untagged: "tag.slash.fill"
        case .dateBucket: "calendar"
        default: "folder.fill"
        }
    }

    private func trailingOffset(for item: AnnotationItem) -> CGFloat {
        item.isGroup
            ? ListLayoutMetrics.separatorTrailingOffset(isRoot: true, indentationLevel: 0)
            : ListLayoutMetrics.defaultPadding * 2
    }

    @objc private func handleRefresh() {
        nativeRoutingPublication.willPublish()
        onRefreshRequested?()
    }

    func endRefreshing() {
        collectionView.refreshControl?.endRefreshing()
    }
}

// MARK: - UICollectionViewDelegate

extension iOSAnnotationViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        nativeRoutingPublication.willPublish()
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        item.isGroup ? toggleGroup(item.node) : onAnnotationSelected?(item.node)
    }

    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        dataSource.itemIdentifier(for: indexPath)?.isGroup == true ? false : true
    }

    private func resolveBook(for groupNode: SwiftUIAnnotationNode) -> BooksData? {
        if let bkId = groupNode.children?.first(where: { $0.annotation != nil })?.annotation?.bkId {
            return LibraryDataManager.shared.booksById[bkId] ?? LibraryDataManager.shared.getBook([bkId]).first
        }
        for sectionID in dataSource.snapshot().sectionIdentifiers {
            let items = dataSource.snapshot(for: sectionID).items
            if items.contains(where: { $0.node.id == groupNode.id }) {
                if let ann = items.compactMap(\.node.annotation).first {
                    return LibraryDataManager.shared.booksById[ann.bkId] ?? LibraryDataManager.shared.getBook([ann.bkId]).first
                }
            }
        }
        return nil
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }

        if case let .group(node) = item, node.kind == .book {
            guard let book = resolveBook(for: node) else { return nil }
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                let infoAction = UIAction.bookInfo { _ in
                    self?.onShowBookInfo?(book)
                }
                return UIMenu(title: node.title, children: [infoAction])
            }
        }

        guard case let .annotation(node) = item,
              let annotation = node.annotation
        else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let editAction = UIAction(
                title: String(localized: .Annotation.editAnnotation),
                image: UIImage(systemName: "pencil")
            ) { _ in
                self?.onAnnotationEditRequested?(annotation)
            }

            let deleteAction = UIAction(
                title: String(localized: "Delete"),
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                guard let self else { return }
                self.nativeRoutingPublication.willPublish()
                var snap = self.dataSource.snapshot()
                snap.deleteItems([item])
                self.dataSource.apply(snap, animatingDifferences: true)
                self.onAnnotationDeleted?(node)
            }

            return UIMenu(children: [editAction, deleteAction])
        }
    }
}

extension Notification.Name {
    static let annotationMissingBook = Notification.Name("annotationMissingBook")
}

// MARK: - Original list navigation observation

import OtzariaUIRouting

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

    /// Passive prepublication for the ORIGINAL UIKit tag sheet. The caller
    /// always performs its original present operation, even without a binding.
    func nativeRoutingOriginalModalWillPresent() {
        guard let binding = nativeRoutingBinding, let owner = nativeRoutingOwner else { return }
        binding.originalUIKitPresentationWillChange(controller: self, owner: owner)
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
