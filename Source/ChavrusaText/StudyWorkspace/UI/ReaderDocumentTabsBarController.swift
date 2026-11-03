//
//  ReaderDocumentTabsBarController.swift
//  Maktabah
//
//  Downstream-owned UIViewController hosting the DuckDuckGo-inspired iPad document tab strip (Plan C2).
//
//  Attribution:
//  Adapted from duckduckgo/apple-browsers @ f1d574485cf2f0586bcb284e8b3ca8c2f6ff7f32
//  License: Apache License 2.0 (Copyright (c) DuckDuckGo)
//

#if os(iOS)
import UIKit

/// Actions emitted by `ReaderDocumentTabsBarController` to its SwiftUI coordinator/adapter.
struct ReaderTabStripCallbacks {
    var onSelectTab: (UUID) -> Void = { _ in }
    var onCloseTab: (UUID) -> Void = { _ in }
    var onCloseOtherTabs: (UUID) -> Void = { _ in }
    var onDuplicateTab: (UUID) -> Void = { _ in }
    var onMoveTabToGroup: (UUID, UUID) -> Void = { _, _ in }
    var onCopyTabToGroup: (UUID, UUID) -> Void = { _, _ in }
    var onReorderTab: (Int, Int) -> Void = { _, _ in }
    var onNewTabRequested: () -> Void = {}
}

/// UIKit collection-view controller rendering the horizontal document tab strip (`40pt` height)
/// with drag-and-drop tab reordering, context menus (Move/Copy to Tab Group, Duplicate, Close Others),
/// and a trailing `"+"` button.
final class ReaderDocumentTabsBarController: UIViewController,
    UICollectionViewDelegate,
    UICollectionViewDragDelegate,
    UICollectionViewDropDelegate {

    private let layout = ReaderTabStripLayout()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private let newTabButton = UIButton(type: .system)
    private let bottomBorder = UIView()

    private var dataSource: UICollectionViewDiffableDataSource<Int, UUID>!
    private var itemsByID: [UUID: ReaderTabStripItemModel] = [:]
    private var orderedIDs: [UUID] = []
    private var availableGroups: [StudyTabGroup] = []
    private var activeGroupID: UUID?

    var callbacks = ReaderTabStripCallbacks()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        configureDataSource()
    }

    private func setupViews() {
        view.backgroundColor = .secondarySystemBackground

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.register(ReaderTabStripCell.self, forCellWithReuseIdentifier: ReaderTabStripCell.reuseIdentifier)

        newTabButton.translatesAutoresizingMaskIntoConstraints = false
        let plusConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        newTabButton.setImage(UIImage(systemName: "plus", withConfiguration: plusConfig), for: .normal)
        newTabButton.tintColor = .label
        newTabButton.layer.cornerRadius = 8
        newTabButton.layer.cornerCurve = .continuous
        newTabButton.backgroundColor = .tertiarySystemFill
        newTabButton.addTarget(self, action: #selector(handleNewTabTap), for: .touchUpInside)
        newTabButton.accessibilityLabel = "פתח ספר חדש מהספרייה"

        bottomBorder.translatesAutoresizingMaskIntoConstraints = false
        bottomBorder.backgroundColor = UIColor.separator.withAlphaComponent(0.45)

        view.addSubview(collectionView)
        view.addSubview(newTabButton)
        view.addSubview(bottomBorder)

        NSLayoutConstraint.activate([
            newTabButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            newTabButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            newTabButton.widthAnchor.constraint(equalToConstant: 30),
            newTabButton.heightAnchor.constraint(equalToConstant: 30),

            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: newTabButton.leadingAnchor, constant: -6),

            bottomBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBorder.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, UUID>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, tabID in
            guard let self,
                  let cell = collectionView.dequeueReusableCell(
                      withReuseIdentifier: ReaderTabStripCell.reuseIdentifier,
                      for: indexPath
                  ) as? ReaderTabStripCell,
                  let model = self.itemsByID[tabID] else {
                return UICollectionViewCell()
            }
            cell.configure(with: model) { [weak self] in
                self?.callbacks.onCloseTab(tabID)
            }
            return cell
        }
    }

    func apply(
        items: [ReaderTabStripItemModel],
        availableGroups: [StudyTabGroup],
        activeGroupID: UUID?,
        animated: Bool = true
    ) {
        self.availableGroups = availableGroups
        self.activeGroupID = activeGroupID

        let newIDs = items.map(\.id)
        var newMap: [UUID: ReaderTabStripItemModel] = [:]
        for item in items {
            newMap[item.id] = item
        }
        let previousSelectedID = orderedIDs.first { itemsByID[$0]?.isSelected == true }
        let newSelectedID = items.first(where: \.isSelected)?.id

        self.itemsByID = newMap
        self.orderedIDs = newIDs

        guard dataSource != nil else { return }

        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(newIDs, toSection: 0)
        snapshot.reconfigureItems(newIDs)
        dataSource.apply(snapshot, animatingDifferences: animated)
        layout.invalidateLayout()

        if let newSelectedID, newSelectedID != previousSelectedID,
           let selectedIndex = newIDs.firstIndex(of: newSelectedID) {
            let indexPath = IndexPath(item: selectedIndex, section: 0)
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      selectedIndex < self.collectionView.numberOfItems(inSection: 0) else { return }
                self.collectionView.scrollToItem(
                    at: indexPath,
                    at: .centeredHorizontally,
                    animated: animated
                )
            }
        }
    }

    @objc private func handleNewTabTap() {
        callbacks.onNewTabRequested()
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard orderedIDs.indices.contains(indexPath.item) else { return }
        let tabID = orderedIDs[indexPath.item]
        callbacks.onSelectTab(tabID)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first,
              orderedIDs.indices.contains(indexPath.item) else { return nil }
        let tabID = orderedIDs[indexPath.item]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return UIMenu() }

            let duplicateAction = UIAction(
                title: "שכפל כרטיסייה",
                image: UIImage(systemName: "plus.square.on.square")
            ) { _ in
                self.callbacks.onDuplicateTab(tabID)
            }

            let otherGroups = self.availableGroups.filter { $0.id != self.activeGroupID }
            var groupSubmenus: [UIMenuElement] = []

            if !otherGroups.isEmpty {
                let moveActions = otherGroups.map { group in
                    UIAction(title: group.name, image: UIImage(systemName: "arrow.right.square")) { _ in
                        self.callbacks.onMoveTabToGroup(tabID, group.id)
                    }
                }
                let copyActions = otherGroups.map { group in
                    UIAction(title: group.name, image: UIImage(systemName: "doc.on.doc")) { _ in
                        self.callbacks.onCopyTabToGroup(tabID, group.id)
                    }
                }
                groupSubmenus.append(
                    UIMenu(title: "העבר לקבוצת לימוד", image: UIImage(systemName: "folder"), children: moveActions)
                )
                groupSubmenus.append(
                    UIMenu(title: "העתק לקבוצת לימוד", image: UIImage(systemName: "doc.on.doc"), children: copyActions)
                )
            }

            let closeAction = UIAction(
                title: "סגור כרטיסייה",
                image: UIImage(systemName: "xmark"),
                attributes: .destructive
            ) { _ in
                self.callbacks.onCloseTab(tabID)
            }

            let closeOthersAction = UIAction(
                title: "סגור כרטיסיות אחרות",
                image: UIImage(systemName: "xmark.circle"),
                attributes: self.orderedIDs.count > 1 ? [.destructive] : [.disabled]
            ) { _ in
                self.callbacks.onCloseOtherTabs(tabID)
            }

            return UIMenu(title: "", children: [
                UIMenu(title: "", options: .displayInline, children: [duplicateAction] + groupSubmenus),
                UIMenu(title: "", options: .displayInline, children: [closeAction, closeOthersAction])
            ])
        }
    }

    // MARK: - Drag & Drop Reordering

    func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        guard orderedIDs.indices.contains(indexPath.item) else { return [] }
        let tabID = orderedIDs[indexPath.item]
        let itemProvider = NSItemProvider(object: tabID.uuidString as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = tabID
        return [dragItem]
    }

    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        guard collectionView.hasActiveDrag else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performDropWith coordinator: UICollectionViewDropCoordinator
    ) {
        guard let item = coordinator.items.first,
              let sourceIndexPath = item.sourceIndexPath,
              let destinationIndexPath = coordinator.destinationIndexPath else { return }

        callbacks.onReorderTab(sourceIndexPath.item, destinationIndexPath.item)
        coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
    }
}
#endif
