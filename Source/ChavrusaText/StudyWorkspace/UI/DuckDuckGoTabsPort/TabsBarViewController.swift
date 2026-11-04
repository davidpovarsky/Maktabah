//
//  TabsBarViewController.swift
//  DuckDuckGo
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit
import Combine

@MainActor
protocol TabsBarDelegate: AnyObject {
    func tabsBar(_ controller: TabsBarViewController, didSelectTabAtIndex index: Int)
    func tabsBar(_ controller: TabsBarViewController, didRemoveTabAtIndex index: Int)
    func tabsBar(_ controller: TabsBarViewController, didRequestCloseOtherTabsForTabAtIndex index: Int)
    func tabsBarDidRequestNewTab(_ controller: TabsBarViewController)
    func tabsBarDidRequestTabSwitcher(_ controller: TabsBarViewController)
}

class TabsBarViewController: UIViewController {
    static let viewDidLayoutNotification = Notification.Name("ChavrusaText.DocumentTabs.didLayout")
    struct Constants {

        static let buttonWidth: CGFloat = 44
        static let buttonHeight: CGFloat = 40
        static let stackSpacing: CGFloat = 12
        static let addTabButtonGap: CGFloat = 6
        static let minItemWidth: CGFloat = 120
        static let maxItemWidthFraction: CGFloat = 0.33
        static let narrowMaxItemWidthFraction: CGFloat = 0.5
        static let leadingInset: CGFloat = 16
        /// Wider than `leadingInset` so the active tab's flare clears the rounded address bar corner below.
        static let firstTabLeadingMargin: CGFloat = 24
        /// Active-tab bottom fillet size (Figma spec).
        static let tabRampSize = CGSize(width: 10, height: 10)
        static let windowControlsTabGap: CGFloat = 16
        static let aiChatMenuButtonCornerRadius: CGFloat = 9
        static let aiChatMenuButtonImagePadding: CGFloat = 6
        static let aiChatMenuButtonContentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
    }

    private let tabsBarView = TabsBarView()
    var collectionView: UICollectionView { tabsBarView.collectionView }
    var buttonsStack: UIStackView { tabsBarView.buttonsStack }
    var buttonsBackground: UIView { tabsBarView.buttonsBackground }
    private var addTabButtonLeadingConstraint: NSLayoutConstraint?
    private var currentLayout: TabsBarLayout?
    private var draggedTabOriginalFrame: CGRect?
    private var draggedTabGrabOffset: CGFloat = 0
    private weak var draggedTabCell: TabsBarCell?
    private weak var reorderDropSession: UIDropSession?
    private var dragMembership: [UUID]?
    private weak var tabAwaitingSelection: ReaderBookTabAdapter?
    private var animatesSelectionReveal = false
    private let addTabButtonBackground = UIView()
    var theme = ReaderTabsTheme()
    private lazy var flareBackground = TabFlareBackgroundController(
        collectionView: collectionView,
        topCornerRadius: TabsBarCell.cornerRadius,
        rampSize: Constants.tabRampSize,
        currentIndex: { [weak self] in self?.currentIndex },
        fillColor: { [weak self] in self?.theme.omniBarBackgroundColor ?? .systemBackground }
    )
    lazy var addTabButton = createButton(image: UIImage(systemName: "plus")!)
    lazy var tabSwitcherButton = createButton(image: UIImage(systemName: "square.on.square")!)
    weak var delegate: TabsBarDelegate?
    private var tabsModel: ReaderBookTabsModel?
    private var cancellables = Set<AnyCancellable>()
    var tabsCount: Int { tabsModel?.count ?? 0 }
    var currentIndex: Int? { tabsModel?.currentIndex }
    private var isStripOverflowing: Bool { currentLayout?.isFloored ?? false }
    init() { super.init(nibName: nil, bundle: nil) }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
    override func loadView() { view = tabsBarView }
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpSubviews()
        decorate()
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.refreshVisibleCellStyles() }
            .store(in: &cancellables)
    }
    private func setUpSubviews() {
        collectionView.clipsToBounds = true
        collectionView.delegate = self
        collectionView.dataSource = self
        (collectionView.collectionViewLayout as? TabsBarCollectionViewLayout)?.currentIndex = { [weak self] in self?.currentIndex }
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        let tabClick = UITapGestureRecognizer(target: self, action: #selector(selectTabWithPointer))
        tabClick.delegate = self
        collectionView.addGestureRecognizer(tabClick)
        collectionView.isPrefetchingEnabled = false
        collectionView.register(TabsBarCell.self, forCellWithReuseIdentifier: TabsBarCell.reuseIdentifier)
        collectionView.contentInset.left = Constants.tabRampSize.width
        buttonsStack.spacing = Constants.stackSpacing
        buttonsStack.addArrangedSubview(tabSwitcherButton)
        addTabButtonBackground.translatesAutoresizingMaskIntoConstraints = false
        addTabButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addTabButtonBackground)
        view.addSubview(addTabButton)
        let leadingConstraint = addTabButton.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor)
        addTabButtonLeadingConstraint = leadingConstraint
        NSLayoutConstraint.activate([
            leadingConstraint,
            addTabButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            addTabButtonBackground.leadingAnchor.constraint(equalTo: addTabButton.leadingAnchor),
            addTabButtonBackground.trailingAnchor.constraint(equalTo: addTabButton.trailingAnchor),
            addTabButtonBackground.topAnchor.constraint(equalTo: view.topAnchor),
            addTabButtonBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        addTabButton.addTarget(self, action: #selector(onNewTabPressed), for: .touchUpInside)
        tabSwitcherButton.addTarget(self, action: #selector(onOverviewPressed), for: .touchUpInside)
        addTabButton.accessibilityLabel = "פתח ספר מהספרייה"
        [addTabButton, tabSwitcherButton].forEach { button in
            button.heightAnchor.constraint(equalToConstant: Constants.buttonHeight).isActive = true
            button.widthAnchor.constraint(equalToConstant: Constants.buttonWidth).isActive = true
            button.isPointerInteractionEnabled = true
        }
    }
    @objc private func onNewTabPressed() { delegate?.tabsBarDidRequestNewTab(self) }
    @objc private func onOverviewPressed() { delegate?.tabsBarDidRequestTabSwitcher(self) }
    private func refreshTabSwitcherButton() {
        tabSwitcherButton.accessibilityLabel = "כל הכרטיסיות"
        tabSwitcherButton.accessibilityValue = String(tabsCount)
    }
    static func create() -> TabsBarViewController {
        TabsBarViewController()
    }

    func setCurrentTabSelectionAlpha(_ alpha: CGFloat) {
        flareBackground.hideAlpha = alpha.clamped(to: 0...1)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabSwitcherButton.layoutSubviews()
        reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tabAwaitingSelection = nil
    }

    func refresh(tabsModel: ReaderBookTabsModel?, scrollToSelected: Bool = false) {
        self.tabsModel = tabsModel
        recomputeItemSize()
        reloadData()
        if scrollToSelected { scrollToSelectedTab() }
    }

    func refreshStyleInPlace(tabsModel: ReaderBookTabsModel?, scrollToSelected: Bool = false) {
        guard let tabsModel, collectionView.numberOfSections > 0, tabsModel.count == collectionView.numberOfItems(inSection: 0) else {
            refresh(tabsModel: tabsModel, scrollToSelected: scrollToSelected)
            return
        }
        self.tabsModel = tabsModel
        if animatesSelectionReveal, let currentIndex {
            // The page has already switched; animate only the strip's new selection and reveal.
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.18,
                           delay: 0, options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]) {
                self.refreshVisibleCellStyles()
                if scrollToSelected { self.scrollToTab(at: IndexPath(item: currentIndex, section: 0), animated: false) }
                self.collectionView.layoutIfNeeded()
            }
        } else {
            refreshVisibleCellStyles()
            if scrollToSelected { scrollToSelectedTab() }
        }
        refreshTabSwitcherButton()
    }

    private func scrollToSelectedTab() {
        DispatchQueue.main.async {
            guard let currentIndex = self.currentIndex else { return }
            self.scrollToTab(at: IndexPath(row: currentIndex, section: 0))
        }
    }

    private func scrollToTab(at indexPath: IndexPath, animated: Bool = true) {
        // Reveal the tab's original position with a glimpse of any neighbors beyond it.
        guard collectionView.numberOfSections > indexPath.section, indexPath.item >= 0,
              indexPath.item < collectionView.numberOfItems(inSection: indexPath.section),
              let layout = collectionView.collectionViewLayout as? TabsBarCollectionViewLayout,
              let frame = layout.frameForRevealingItem(at: indexPath) else { return }
        collectionView.scrollRectToVisible(frame, animated: animated)
    }

    func scrollCurrentTabIntoView() {
        DispatchQueue.main.async {
            guard let currentIndex = self.currentIndex else { return }
            let indexPath = IndexPath(row: currentIndex, section: 0)
            guard self.isPartiallyClipped(at: indexPath) else { return }
            self.scrollToTab(at: indexPath)
        }
    }

    private func isPartiallyClipped(at indexPath: IndexPath) -> Bool {
        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else { return false }
        if indexPath.item != currentIndex,
           let layout = collectionView.collectionViewLayout as? TabsBarCollectionViewLayout,
           layout.unpinnedFrameForItem(at: indexPath) != attributes.frame {
            return true
        }
        let visibleSize = CGSize(
            width: collectionView.bounds.width - collectionView.contentInset.right,
            height: collectionView.bounds.height
        )
        let visibleRect = CGRect(origin: collectionView.contentOffset, size: visibleSize)
        return visibleRect.intersects(attributes.frame) && !visibleRect.contains(attributes.frame)
    }

    private func recomputeItemSize() {
        let stripWidth = collectionView.frame.size.width
        guard stripWidth > 0 else { return }
        let leadingContentInset = collectionView.contentInset.left
        let availableStripWidth = max(0, stripWidth - leadingContentInset)

        let layout = TabsBarLayout(
            stripWidth: availableStripWidth,
            tabsCount: tabsCount,
            minItemWidth: Constants.minItemWidth,
            maxItemWidth: maxItemWidth(forStripWidth: availableStripWidth),
            buttonWidth: Constants.buttonWidth,
            buttonGap: Constants.addTabButtonGap
        )
        currentLayout = layout

        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout, tabsCount > 0 {
            flowLayout.itemSize = CGSize(width: layout.itemWidth, height: view.frame.size.height)
        }
        // Room before the add button so the last tab's trailing fillet clears its opaque backdrop.
        let rampWidth = Constants.tabRampSize.width
        let trailingFilletRoom = layout.isFloored ? 0 : max(0, rampWidth - Constants.addTabButtonGap)
        addTabButtonLeadingConstraint?.constant = layout.addTabButtonLeadingOffset + leadingContentInset + trailingFilletRoom
        collectionView.contentInset.right = layout.addTabButtonContentInsetRight + (layout.isFloored ? rampWidth : 0)
    }

    private func maxItemWidth(forStripWidth availableWidth: CGFloat) -> CGFloat {
        let half = availableWidth * Constants.narrowMaxItemWidthFraction
        guard let window = view.window, let windowScene = window.windowScene,
              windowScene.interfaceOrientation.isLandscape else {
            return half
        }
        let chrome = window.bounds.width - availableWidth
        let screenBounds = windowScene.screen.bounds
        let landscapeFullStripWidth = max(screenBounds.width, screenBounds.height) - chrome
        return min(half, landscapeFullStripWidth * Constants.maxItemWidthFraction)
    }

    private func reloadData() {
        tabAwaitingSelection = nil
        collectionView.reloadData()
        refreshTabSwitcherButton()
        collectionView.layoutIfNeeded()
        flareBackground.update()
    }

    private func createButton(image: UIImage) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(image, for: .normal)
        return button
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Catches layout passes (e.g. the first one) that land before refresh()/backgroundTabAdded().
        recomputeItemSize()
        flareBackground.update()
        NotificationCenter.default.post(name: TabsBarViewController.viewDidLayoutNotification, object: self)
    }

}

extension TabsBarViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        // Use the click itself, so a finger tap still reveals first while a pointer is hovering.
        event.buttonMask == .primary
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let cell = tabCell(at: gestureRecognizer.location(in: collectionView)),
              collectionView.indexPath(for: cell)?.item != currentIndex else { return false }
        return cell.visiblePointerRect(in: cell).width <= cell.bounds.width / 2 + 0.001
    }

    @objc func selectTabWithPointer(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended,
              let cell = tabCell(at: recognizer.location(in: collectionView)),
              let indexPath = collectionView.indexPath(for: cell) else { return }
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        collectionView(collectionView, didSelectItemAt: indexPath)
    }

    private func tabCell(at point: CGPoint) -> TabsBarCell? {
        collectionView.visibleCells.compactMap { $0 as? TabsBarCell }.first {
            $0.visiblePointerRect(in: collectionView).contains(point)
        }
    }
}

extension TabsBarViewController: UICollectionViewDelegate {

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        tabAwaitingSelection = nil
        let pan = scrollView.panGestureRecognizer
        let location = pan.location(in: view)
        let translation = pan.translation(in: view)
        let start = CGPoint(x: location.x - translation.x, y: location.y - translation.y)
        flareBackground.beginScrolling(at: pan.numberOfTouches > 0 ? collectionView.convert(start, from: view) : nil)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        flareBackground.endScrolling()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Apply the pinned cell frames before positioning the selection background.
        collectionView.layoutIfNeeded()
        flareBackground.update()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        tabAwaitingSelection = nil
        if indexPath.item != currentIndex, let cell = collectionView.cellForItem(at: indexPath) as? TabsBarCell {
            let exposedWidth = cell.visiblePointerRect(in: cell).width
            animatesSelectionReveal = exposedWidth < cell.bounds.width - 0.001
        }
        defer { animatesSelectionReveal = false }
        delegate?.tabsBar(self, didSelectTabAtIndex: indexPath.row)
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let tab = tabsModel?.get(tabAt: indexPath.item) else { return false }
        let wasRevealed = tab == tabAwaitingSelection
        tabAwaitingSelection = nil
        guard tab != tabsModel?.currentTab, !wasRevealed,
              let cell = collectionView.cellForItem(at: indexPath) as? TabsBarCell,
              cell.bounds.width > 0,
              cell.visiblePointerRect(in: cell).width <= cell.bounds.width / 2 + 0.001 else { return true }

        // A second tap can select even when a narrow window cannot expose the entire tab.
        tabAwaitingSelection = tab
        scrollToTab(at: indexPath)
        return false
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        tabAwaitingSelection = nil
        guard tabsModel?.get(tabAt: indexPath.row) != nil else { return nil }

        return UIContextMenuConfiguration(identifier: NSNumber(value: indexPath.row), previewProvider: nil) { [weak self] _ in
            self?.makeTabContextMenu(forTabAt: indexPath.row)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return tabMenuPreview(for: configuration)
    }

    func collectionView(_ collectionView: UICollectionView,
                        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        // Fires on every preview dismissal; `willEndContextMenu` may not (e.g. when the lift converts
        // into a drag), so restore from here.
        flareBackground.endPreview()
        return tabMenuPreview(for: configuration)
    }

    func collectionView(_ collectionView: UICollectionView,
                        willDisplayContextMenu configuration: UIContextMenuConfiguration,
                        animator: UIContextMenuInteractionAnimating?) {
        flareBackground.beginPreview(forRow: (configuration.identifier as? NSNumber)?.intValue, animator: animator)
    }

    func collectionView(_ collectionView: UICollectionView,
                        willEndContextMenu configuration: UIContextMenuConfiguration,
                        animator: UIContextMenuInteractionAnimating?) {
        // Fallback; `previewForDismissing` handles the rest.
        flareBackground.endPreview()
    }

    func collectionView(_ collectionView: UICollectionView,
                        willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                        animator: UIContextMenuInteractionCommitAnimating) {
        // Committing the preview also ends the menu without `willEndContextMenu`.
        flareBackground.endPreview()
    }

    private func tabMenuPreview(for configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let row = (configuration.identifier as? NSNumber)?.intValue,
              let cell = collectionView.cellForItem(at: IndexPath(item: row, section: 0)) else {
            return nil
        }
        let parameters = UIPreviewParameters()
        applyTabLiftStyle(to: parameters, cell: cell, backgroundColor: tabLiftBackgroundColor)
        return UITargetedPreview(view: cell, parameters: parameters)
    }

    /// Gives the lifted tab a card background.
    private var tabLiftBackgroundColor: UIColor {
        theme.omniBarBackgroundColor.withAlphaComponent(0.9)
    }

    private func applyTabLiftStyle(to parameters: UIPreviewParameters, cell: UICollectionViewCell, backgroundColor: UIColor) {
        parameters.backgroundColor = backgroundColor
        parameters.visiblePath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: TabsBarCell.cornerRadius)
        parameters.shadowPath = UIBezierPath()
    }

}

extension TabsBarViewController: UICollectionViewDragDelegate {

    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        dragMembership = tabsModel?.tabs.map(\.id)
        tabAwaitingSelection = nil
        guard tabsModel?.get(tabAt: indexPath.row) != nil,
              let cell = collectionView.cellForItem(at: indexPath) as? TabsBarCell else { return [] }
        // Don't start a reorder drag from the close button.
        if cell.removeButton.bounds.contains(session.location(in: cell.removeButton)) {
            return []
        }
        // Capture before UIKit moves the source cell to make room for an insertion slot.
        draggedTabOriginalFrame = (collectionView.collectionViewLayout as? TabsBarCollectionViewLayout)?.unpinnedFrameForItem(at: indexPath)
        draggedTabCell = cell
        draggedTabGrabOffset = session.location(in: cell).x
        let item = UIDragItem(itemProvider: NSItemProvider())
        item.localObject = indexPath
        return [item]
    }

    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        return tabDragPreviewParameters(at: indexPath, backgroundColor: tabLiftBackgroundColor)
    }

    func collectionView(_ collectionView: UICollectionView, dragSessionWillBegin session: UIDragSession) {
        collectionView.collectionViewLayout.invalidateLayout()
        flareBackground.beginReorder { [weak self] elapsedTime in
            self?.scrollDuringReorder(elapsedTime: elapsedTime)
        }
        let isInsideStrip = collectionView.bounds.contains(session.location(in: collectionView))
        draggedTabCell?.setDragPlaceholderHidden(isInsideStrip, animated: false)
        // A context-menu lift can become a drag after the finger has already left the strip.
        if !isInsideStrip, let frame = draggedTabOriginalFrame {
            collectionView.scrollRectToVisible(frame, animated: !UIAccessibility.isReduceMotionEnabled)
        }
    }

    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        reorderDropSession = nil
        draggedTabCell?.setDragPlaceholderHidden(false, animated: false)
        draggedTabCell = nil
        draggedTabOriginalFrame = nil
        collectionView.collectionViewLayout.invalidateLayout()
        flareBackground.endReorder()
    }

    private func tabDragPreviewParameters(at indexPath: IndexPath, backgroundColor: UIColor) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
        let parameters = UIDragPreviewParameters()
        applyTabLiftStyle(to: parameters, cell: cell, backgroundColor: backgroundColor)
        return parameters
    }

}

extension TabsBarViewController: UICollectionViewDropDelegate {

    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.localDragSession != nil
    }

    func collectionView(_ collectionView: UICollectionView, dropPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        return tabDragPreviewParameters(at: indexPath, backgroundColor: .clear)
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnter session: UIDropSession) {
        guard session.localDragSession != nil, draggedTabOriginalFrame != nil else { return }
        reorderDropSession = session
        draggedTabCell?.setDragPlaceholderHidden(true, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if session.localDragSession != nil, draggedTabOriginalFrame != nil {
            reorderDropSession = session
        }
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        reorderDropSession = nil
        guard session.localDragSession != nil, let frame = draggedTabOriginalFrame else { return }
        draggedTabCell?.setDragPlaceholderHidden(false, animated: true)
        collectionView.scrollRectToVisible(frame, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        reorderDropSession = nil
        guard dragMembership == tabsModel?.tabs.map(\.id),
              let item = coordinator.items.first,
              let sourceIndexPath = item.sourceIndexPath,
              let proposedDestination = coordinator.destinationIndexPath,
              let tabsModel,
              sourceIndexPath.section == 0, proposedDestination.section == 0, tabsModel.count > 0,
              let tab = tabsModel.get(tabAt: sourceIndexPath.row) else { return }

        draggedTabCell?.setDragPlaceholderHidden(false, animated: false)
        draggedTabOriginalFrame = nil
        let destinationIndexPath = IndexPath(item: max(0, min(proposedDestination.item, tabsModel.count - 1)), section: 0)
        collectionView.performBatchUpdates({
            tabsModel.move(tab: tab, to: destinationIndexPath.row)
            collectionView.moveItem(at: sourceIndexPath, to: destinationIndexPath)
        }, completion: { [weak self] _ in
            self?.refreshVisibleCellStyles()
        })
        coordinator.drop(item.dragItem, toItemAt: destinationIndexPath).addCompletion { [weak self] position in
            guard position == .end else { return }
            DispatchQueue.main.async {
                guard let self, let index = self.tabsModel?.indexOf(tab: tab) else { return }
                self.scrollToTab(at: IndexPath(item: index, section: 0))
            }
        }
    }

    func scrollDuringReorder(elapsedTime: TimeInterval) {
        guard let session = reorderDropSession,
              let layout = collectionView.collectionViewLayout as? TabsBarCollectionViewLayout else { return }
        let location = session.location(in: collectionView)
        guard collectionView.bounds.contains(location) else { return }
        let visibleBounds = collectionView.bounds.inset(by: collectionView.adjustedContentInset)
        let tabWidth = layout.itemSize.width
        guard tabWidth > 0, visibleBounds.width > 0 else { return }
        let draggedMinX = location.x - draggedTabGrabOffset
        let draggedMaxX = draggedMinX + tabWidth
        // Look ahead from the dragged tab's edge by one full tab and a third of its neighbor.
        let lookahead = min(tabWidth * 4 / 3, max(0, (visibleBounds.width - tabWidth) / 2))
        let leading = max(0, visibleBounds.minX + lookahead - draggedMinX)
        let trailing = max(0, draggedMaxX + lookahead - visibleBounds.maxX)
        let distance = (trailing - leading) * elapsedTime / 0.25
        guard distance != 0 else { return }
        let minimum = -collectionView.adjustedContentInset.left
        let maximum = max(minimum, collectionView.contentSize.width - collectionView.bounds.width + collectionView.adjustedContentInset.right)
        collectionView.contentOffset.x = (collectionView.contentOffset.x + distance).clamped(to: minimum...maximum)
    }

    private func refreshVisibleCellStyles() {
        tabAwaitingSelection = nil
        collectionView.collectionViewLayout.invalidateLayout()
        let current = currentIndex
        let hidesInactiveCloseButton = isStripOverflowing
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? TabsBarCell else { continue }
            cell.applyCurrentStyle(isCurrent: indexPath.row == current,
                                   isNextCurrent: indexPath.row + 1 == current,
                                   hidesInactiveCloseButton: hidesInactiveCloseButton,
                                   withTheme: theme)
        }
        // Selection unfolds the tab; apply its new frame before moving the flare.
        collectionView.layoutIfNeeded()
        flareBackground.update()
    }

}

extension TabsBarViewController {

    private func makeTabContextMenu(forTabAt index: Int) -> UIMenu? {
        guard let tab = tabsModel?.get(tabAt: index) else { return nil }

        let closeTab = UIAction(title: "סגור כרטיסייה",
                                image: UIImage(systemName: "xmark"),
                                attributes: .destructive) { [weak self] _ in
            self?.closeTabFromContextMenu(tab)
        }

        guard tabsCount > 1 else {
            return UIMenu(children: [closeTab])
        }

        let closeOtherTabs = UIAction(title: "סגור כרטיסיות אחרות",
                                      image: UIImage(systemName: "rectangle.stack.badge.minus"),
                                      attributes: .destructive) { [weak self] _ in
            self?.closeOtherTabsFromContextMenu(keeping: tab)
        }

        return UIMenu(children: [closeTab, closeOtherTabs])
    }

    private func closeTabFromContextMenu(_ tab: ReaderBookTabAdapter) {
        guard let index = tabsModel?.indexOf(tab: tab) else { return }
        closeTab(at: index)
    }

    private func closeTab(at index: Int) {
        delegate?.tabsBar(self, didRemoveTabAtIndex: index)
    }

    private func closeOtherTabsFromContextMenu(keeping tab: ReaderBookTabAdapter) {
        guard let index = tabsModel?.indexOf(tab: tab) else { return }
        delegate?.tabsBar(self, didRequestCloseOtherTabsForTabAtIndex: index)
    }

}

extension TabsBarViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabsCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabsBarCell.reuseIdentifier, for: indexPath) as? TabsBarCell else {
            fatalError("Unable to create TabBarCell")
        }
        
        guard let model = tabsModel?.get(tabAt: indexPath.row) else {
            assertionFailure("TabsBarViewController: failed to load tab at \(indexPath.row) of \(tabsCount)")
            cell.configurePlaceholder(withTheme: theme)
            return cell
        }
        let isCurrent = indexPath.row == currentIndex
        let isNextCurrent = indexPath.row + 1 == currentIndex
        cell.update(model: model, isCurrent: isCurrent, isNextCurrent: isNextCurrent, hidesInactiveCloseButton: isStripOverflowing, isFireModeEnabled: false, withTheme: theme)
        cell.onRemove = { [weak self, weak model] in
            guard let self = self, let model = model,
                let tabIndex = self.tabsModel?.indexOf(tab: model)
                else { return }
            let indexPath = IndexPath(row: tabIndex, section: 0)
            // Reveal a not-fully-visible tab instead of closing it, guards against accidental taps.
            guard !self.isPartiallyClipped(at: indexPath) else {
                self.scrollToTab(at: indexPath)
                return
            }
            self.closeTab(at: tabIndex)
        }
        return cell
    }

}

extension TabsBarViewController {

    private func decorate() {
        view.backgroundColor = theme.tabsBarBackgroundColor
        view.tintColor = theme.barTintColor
        // Clear so the flare behind the cells shows through.
        collectionView.backgroundColor = .clear
        buttonsBackground.backgroundColor = theme.tabsBarBackgroundColor
        addTabButtonBackground.backgroundColor = theme.tabsBarBackgroundColor

        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        flareBackground.update()
    }

}

