//
//  TabSwitcherPagePort.swift
//  ChavrusaText
//
//  Source-derived from DuckDuckGo Apple Browser at
//  f1d574485cf2f0586bcb284e8b3ca8c2f6ff7f32:
//  TabSwitcherPageViewController.swift, TabViewCell.swift,
//  TabViewGridCell.swift, and TabViewListCell.swift.
//
//  Copyright © 2017-2026 DuckDuckGo. All rights reserved.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI
import UIKit

/// Display-only bridge. Live tabs and reading state remain owned by the native
/// navigation manager and workspace; this port carries stable IDs and labels.
struct ReaderTabSwitcherDocument: Equatable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
}

enum ReaderTabSwitcherLayout: String, CaseIterable {
    case grid
    case list
}

// Original DesignResourcesKit/Fonts/Font.swift at the same DuckDuckGo pin.
// Keep the source text-style descriptors and Dynamic Type behavior exactly.
private extension UIFont {
    static func daxBodySemibold() -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        let newDescriptor = descriptor.addingAttributes([.traits: [
            UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]])
        return UIFont(descriptor: newDescriptor, size: descriptor.pointSize)
    }

    static func daxSubheadSemibold() -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
        let newDescriptor = descriptor.addingAttributes([.traits: [
            UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]])
        return UIFont(descriptor: newDescriptor, size: descriptor.pointSize)
    }

    static func daxFootnoteSemibold() -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .footnote)
        let newDescriptor = descriptor.addingAttributes([.traits: [
            UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]])
        return UIFont(descriptor: newDescriptor, size: descriptor.pointSize)
    }
}

enum TabSwitcherGridLayoutGeometry {
    static let spacing: CGFloat = 14
    static let minimumColumnWidth: CGFloat = 150
    static let maximumColumnCount = 4

    static var sectionInset: UIEdgeInsets {
        UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
    }

    static func columnWidth(for availableWidth: CGFloat) -> CGFloat {
        let contentWidth = max(0, availableWidth - spacing)
        let columnCount = min(maximumColumnCount, max(1, Int(contentWidth / minimumColumnWidth)))
        return max(0, contentWidth / CGFloat(columnCount) - spacing)
    }
}

@MainActor
protocol TabViewCellDelegate: AnyObject {
    func deleteTab(id: UUID)
    func tabViewCellDidBeginSwipe(_ cell: TabViewCell)
    func tabViewCellDidEndSwipe(_ cell: TabViewCell)
}

/// The original DuckDuckGo card interaction and geometry with browser-only
/// favicon, tracker, telemetry, and screenshot services replaced by book data.
@MainActor
class TabViewCell: UICollectionViewCell, UIGestureRecognizerDelegate {
    enum Constants {
        static let swipeToDeleteAlpha: CGFloat = 0.5
        static let borderRadius: CGFloat = 28
        static let cellCornerRadius: CGFloat = 26
        static let cellHeaderHeight: CGFloat = 40
        static let selectedBorderWidth: CGFloat = 2
        static let previewPadding: CGFloat = 4
        static let previewCornerRadius: CGFloat = cellCornerRadius - previewPadding
        static let removeButtonTextSpacingRegular: CGFloat = -12
        static let removeButtonTextSpacingHighlighted: CGFloat = 2
        static let shadowRadius: CGFloat = 12
        static let shadowOffset = CGSize(width: 0, height: 4)
        static let swipeAnimationDuration: TimeInterval = 0.2
        static let highlightAnimationDuration: TimeInterval = 0.15
    }

    weak var delegate: (any TabViewCellDelegate)?
    private(set) var documentID: UUID?
    private var canDelete = false
    private var isDeleting = false
    private var startX: CGFloat = 0

    let card = UIView()
    let border = UIView()
    let icon = UIImageView()
    let title = ReaderTabFadeOutLabel()
    let subtitle = ReaderTabFadeOutLabel()
    let removeButton = UIButton(type: .system)
    let buttonContainer = UIView()
    var textButtonSpacing: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupSharedLayout() {
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.withAlphaComponent(0.16).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = Constants.shadowRadius
        layer.shadowOffset = Constants.shadowOffset
        backgroundColor = .clear

        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = Constants.cellCornerRadius
        card.layer.cornerCurve = .continuous
        card.backgroundColor = .secondarySystemBackground
        contentView.addSubview(card)

        border.translatesAutoresizingMaskIntoConstraints = false
        border.isUserInteractionEnabled = false
        border.layer.cornerRadius = Constants.borderRadius
        border.layer.cornerCurve = .continuous
        contentView.addSubview(border)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            border.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            border.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            border.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: 4),
            border.heightAnchor.constraint(equalTo: contentView.heightAnchor, constant: 4),
        ])

        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .secondaryLabel
        icon.image = UIImage(systemName: "book.closed")

        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .preferredFont(forTextStyle: .headline)
        title.adjustsFontForContentSizeCategory = true
        title.lineBreakMode = .byClipping
        title.primaryColor = .label

        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = .preferredFont(forTextStyle: .caption1)
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.lineBreakMode = .byClipping
        subtitle.primaryColor = .secondaryLabel

        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)), for: .normal)
        removeButton.tintColor = .label
        removeButton.addTarget(self, action: #selector(deleteTab), for: .touchUpInside)
        removeButton.addTarget(self, action: #selector(removeButtonValueChange), for: .allTouchEvents)

        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.setContentHuggingPriority(.required, for: .horizontal)
        buttonContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        buttonContainer.setContentCompressionResistancePriority(.required, for: .vertical)
        buttonContainer.addSubview(removeButton)

        let swipe = UIPanGestureRecognizer(target: self, action: #selector(handleSwipe(recognizer:)))
        swipe.delegate = self
        addGestureRecognizer(swipe)
    }

    func configure(document: ReaderTabSwitcherDocument, isCurrent: Bool) {
        documentID = document.id
        title.text = document.title
        subtitle.text = document.subtitle
        title.accessibilityLabel = title.text
        title.isAccessibilityElement = true
        title.accessibilityTraits = isCurrent ? [.button, .staticText, .selected] : [.button, .staticText]
        accessibilityElements = [title, removeButton]
        removeButton.accessibilityLabel = String(localized: "Close") + " " + (title.text ?? "")
        accessibilityLabel = [title.text, subtitle.text].compactMap { $0 }.joined(separator: ", ")
        accessibilityTraits = isCurrent ? [.button, .selected] : .button
        border.layer.borderColor = UIColor.label.withAlphaComponent(0.55).cgColor
        border.layer.borderWidth = isCurrent ? Constants.selectedBorderWidth : 0
        if !isDeleting { isHidden = false }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        documentID = nil
        isDeleting = false
        canDelete = false
        alpha = 1
        transform = .identity
        isHidden = false
    }

    override func dragStateDidChange(_ dragState: UICollectionViewCell.DragState) {
        super.dragStateDidChange(dragState)
        border.isHidden = dragState != .none
    }

    @objc private func deleteTab() {
        guard let documentID else { return }
        delegate?.deleteTab(id: documentID)
    }

    @objc private func removeButtonValueChange() {
        let spacing = removeButton.isHighlighted
            ? Constants.removeButtonTextSpacingHighlighted
            : Constants.removeButtonTextSpacingRegular
        layoutIfNeeded()
        textButtonSpacing?.constant = spacing
        UIView.animate(withDuration: Constants.highlightAnimationDuration,
                       delay: 0,
                       options: [.beginFromCurrentState, .curveEaseInOut]) {
            self.layoutIfNeeded()
        }
    }

    @objc private func handleSwipe(recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: window)
        let rtl = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let signedDistance = rtl ? location.x - startX : startX - location.x

        switch recognizer.state {
        case .began:
            startX = location.x
            delegate?.tabViewCellDidBeginSwipe(self)
        case .changed:
            let offset = max(0, signedDistance)
            transform = CGAffineTransform(translationX: rtl ? offset : -offset, y: 0)
            let crossed = offset > bounds.width / 3
            if crossed != canDelete {
                canDelete = crossed
                if crossed { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            }
            UIView.animate(withDuration: Constants.swipeAnimationDuration) {
                self.alpha = crossed ? Constants.swipeToDeleteAlpha : 1
            }
        case .ended:
            if canDelete {
                isDeleting = true
                deleteTab()
                UIView.animate(withDuration: Constants.swipeAnimationDuration) {
                    self.transform = CGAffineTransform(translationX: rtl ? self.bounds.width : -self.bounds.width, y: 0)
                } completion: { _ in
                    if self.isDeleting { self.isHidden = true }
                }
            } else {
                cancelSwipe()
            }
            canDelete = false
            delegate?.tabViewCellDidEndSwipe(self)
        case .cancelled, .failed:
            cancelSwipe()
            canDelete = false
            delegate?.tabViewCellDidEndSwipe(self)
        default:
            break
        }
    }

    private func cancelSwipe() {
        UIView.animate(withDuration: Constants.swipeAnimationDuration) {
            self.transform = .identity
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self)
        return abs(velocity.y) < abs(velocity.x)
    }
}

@MainActor
final class TabViewGridCell: TabViewCell {
    enum GridConstants {
        static let headerHeight: CGFloat = 44
        static let iconSize: CGFloat = 16
        static let leadingPadding: CGFloat = 12
        static let trailingPadding: CGFloat = 8
        static let previewHorizontalInset: CGFloat = 8
        static let previewBottomPadding: CGFloat = 4
    }

    static let reuseIdentifier = "TabViewGridCell"
    private let preview = UIView()
    private let previewIcon = UIImageView(image: UIImage(systemName: "text.book.closed"))
    private let unavailable = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSharedLayout()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupLayout() {
        title.font = .daxFootnoteSemibold()
        let header = UIStackView(arrangedSubviews: [icon, title])
        header.translatesAutoresizingMaskIntoConstraints = false
        header.axis = .horizontal
        header.spacing = GridConstants.trailingPadding
        header.alignment = .center
        card.addSubview(header)
        card.addSubview(buttonContainer)

        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.clipsToBounds = true
        preview.layer.cornerRadius = Constants.previewCornerRadius
        preview.layer.cornerCurve = .continuous
        preview.backgroundColor = .tertiarySystemBackground
        card.addSubview(preview)

        previewIcon.translatesAutoresizingMaskIntoConstraints = false
        previewIcon.contentMode = .scaleAspectFit
        previewIcon.tintColor = .tertiaryLabel
        preview.addSubview(previewIcon)

        unavailable.translatesAutoresizingMaskIntoConstraints = false
        unavailable.text = "תצוגה מקדימה אינה זמינה"
        unavailable.font = .preferredFont(forTextStyle: .caption2)
        unavailable.adjustsFontForContentSizeCategory = true
        unavailable.textColor = .secondaryLabel
        unavailable.textAlignment = .center
        unavailable.numberOfLines = 2
        preview.addSubview(unavailable)

        let spacing = buttonContainer.leadingAnchor.constraint(equalTo: header.trailingAnchor,
                                                                constant: Constants.removeButtonTextSpacingRegular)
        textButtonSpacing = spacing
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: GridConstants.leadingPadding),
            header.heightAnchor.constraint(equalToConstant: GridConstants.headerHeight),
            icon.widthAnchor.constraint(equalToConstant: GridConstants.iconSize),
            icon.heightAnchor.constraint(equalToConstant: GridConstants.iconSize),
            buttonContainer.widthAnchor.constraint(equalToConstant: GridConstants.headerHeight),
            buttonContainer.heightAnchor.constraint(equalToConstant: GridConstants.headerHeight),
            buttonContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            buttonContainer.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            spacing,
            removeButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            removeButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            removeButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            removeButton.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
            preview.topAnchor.constraint(equalTo: header.bottomAnchor),
            preview.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: GridConstants.previewHorizontalInset / 2),
            preview.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -GridConstants.previewHorizontalInset / 2),
            preview.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -GridConstants.previewBottomPadding),
            previewIcon.centerXAnchor.constraint(equalTo: preview.centerXAnchor),
            previewIcon.centerYAnchor.constraint(equalTo: preview.centerYAnchor, constant: -14),
            previewIcon.widthAnchor.constraint(equalToConstant: 42),
            previewIcon.heightAnchor.constraint(equalToConstant: 42),
            unavailable.topAnchor.constraint(equalTo: previewIcon.bottomAnchor, constant: 8),
            unavailable.leadingAnchor.constraint(equalTo: preview.leadingAnchor, constant: 8),
            unavailable.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -8),
        ])
    }
}

@MainActor
final class TabViewListCell: TabViewCell {
    enum ListConstants {
        static let leadingPadding: CGFloat = 16
        static let trailingPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 8
        static let iconSize: CGFloat = 24
        static let iconTrailingPadding: CGFloat = 8
        static let rowHeight: CGFloat = 44
    }

    static let reuseIdentifier = "TabViewListCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSharedLayout()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupLayout() {
        title.font = .daxBodySemibold()
        title.setContentHuggingPriority(.defaultLow, for: .vertical)
        title.setContentCompressionResistancePriority(.init(751), for: .vertical)
        subtitle.font = .daxSubheadSemibold()
        subtitle.isAccessibilityElement = false
        subtitle.setContentHuggingPriority(.init(252), for: .vertical)

        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(icon)
        let titleButtonsContainer = UIView()
        titleButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        let main = UIStackView(arrangedSubviews: [iconContainer, titleButtonsContainer])
        main.translatesAutoresizingMaskIntoConstraints = false
        main.axis = .horizontal
        card.addSubview(main)
        let labels = UIStackView(arrangedSubviews: [title, subtitle])
        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.axis = .vertical
        labels.spacing = 2
        titleButtonsContainer.addSubview(labels)
        titleButtonsContainer.addSubview(buttonContainer)
        let spacing = buttonContainer.leadingAnchor.constraint(equalTo: labels.trailingAnchor,
                                                                constant: Constants.removeButtonTextSpacingRegular)
        textButtonSpacing = spacing
        NSLayoutConstraint.activate([
            main.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: ListConstants.leadingPadding),
            main.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -ListConstants.trailingPadding),
            main.topAnchor.constraint(equalTo: card.topAnchor, constant: ListConstants.verticalPadding),
            main.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -ListConstants.verticalPadding),
            main.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: ListConstants.iconSize),
            icon.heightAnchor.constraint(equalToConstant: ListConstants.iconSize),
            icon.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconContainer.trailingAnchor.constraint(equalTo: icon.trailingAnchor, constant: ListConstants.iconTrailingPadding),
            iconContainer.heightAnchor.constraint(equalToConstant: ListConstants.rowHeight),
            labels.leadingAnchor.constraint(equalTo: titleButtonsContainer.leadingAnchor),
            labels.topAnchor.constraint(equalTo: titleButtonsContainer.topAnchor, constant: ListConstants.verticalPadding),
            titleButtonsContainer.bottomAnchor.constraint(equalTo: labels.bottomAnchor, constant: ListConstants.verticalPadding),
            buttonContainer.topAnchor.constraint(equalTo: titleButtonsContainer.topAnchor),
            buttonContainer.bottomAnchor.constraint(equalTo: titleButtonsContainer.bottomAnchor),
            buttonContainer.trailingAnchor.constraint(equalTo: titleButtonsContainer.trailingAnchor),
            spacing,
            removeButton.widthAnchor.constraint(equalToConstant: ListConstants.rowHeight),
            removeButton.heightAnchor.constraint(equalToConstant: ListConstants.rowHeight),
            removeButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            removeButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            removeButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
        ])
    }
}

@MainActor
protocol TabSwitcherPageDelegate: AnyObject {
    func page(_ page: TabSwitcherPageViewController, didSelectTabAt index: Int)
    func page(_ page: TabSwitcherPageViewController, didDeleteTab id: UUID)
    func page(_ page: TabSwitcherPageViewController, didReorderTab id: UUID, to index: Int)
    func page(_ page: TabSwitcherPageViewController, contextMenuForTabAt index: Int) -> UIMenu?
}

/// Source-faithful collection controller. Browser-only services are removed;
/// collection geometry, list/grid cells, selection, swipe close, drag reorder,
/// and context-menu behavior remain UIKit-native.
@MainActor
final class TabSwitcherPageViewController: UIViewController {
    private(set) var collectionView: UICollectionView!
    weak var pageDelegate: (any TabSwitcherPageDelegate)?
    private var documents: [ReaderTabSwitcherDocument] = []
    private var selectedID: UUID?
    private var layoutMode: ReaderTabSwitcherLayout = .grid
    private var lastLayoutSize: CGSize = .zero
    private var dragMembership: [UUID]?

    override func viewDidLoad() {
        super.viewDidLoad()
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = TabSwitcherGridLayoutGeometry.spacing
        layout.minimumInteritemSpacing = TabSwitcherGridLayoutGeometry.spacing
        layout.sectionInset = TabSwitcherGridLayoutGeometry.sectionInset

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.clipsToBounds = true
        collectionView.isMultipleTouchEnabled = true
        if #available(iOS 17.0, *) {
            collectionView.allowsKeyboardScrolling = false
        }
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.allowsSelection = true
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dragInteractionEnabled = true
        collectionView.register(TabViewGridCell.self, forCellWithReuseIdentifier: TabViewGridCell.reuseIdentifier)
        collectionView.register(TabViewListCell.self, forCellWithReuseIdentifier: TabViewListCell.reuseIdentifier)
        view.addSubview(collectionView)
        collectionView.backgroundView = UIView(frame: collectionView.frame)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        view.accessibilityIdentifier = "duckduckgo-tab-switcher-page"
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.size != lastLayoutSize, view.bounds.size != .zero else { return }
        lastLayoutSize = view.bounds.size
        collectionView.collectionViewLayout.invalidateLayout()
    }

    func update(documents: [ReaderTabSwitcherDocument], selectedID: UUID?, layoutMode: ReaderTabSwitcherLayout) {
        loadViewIfNeeded()
        let membershipChanged = self.documents.map(\.id) != documents.map(\.id)
        let contentChanged = zip(self.documents, documents).contains { old, new in
            old != new
        }
        let layoutChanged = self.layoutMode != layoutMode
        self.documents = documents
        self.selectedID = selectedID
        self.layoutMode = layoutMode
        if layoutChanged { collectionView.collectionViewLayout.invalidateLayout() }
        if membershipChanged || contentChanged || layoutChanged {
            collectionView.reloadData()
        } else {
            for cell in collectionView.visibleCells {
                guard let cell = cell as? TabViewCell,
                      let id = cell.documentID,
                      let document = documents.first(where: { $0.id == id }) else { continue }
                cell.configure(document: document, isCurrent: id == selectedID)
            }
        }
    }

    private func removeDocument(id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents.remove(at: index)
        collectionView.performBatchUpdates {
            collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
        } completion: { [weak self] _ in
            guard let self else { return }
            self.pageDelegate?.page(self, didDeleteTab: id)
        }
    }
}

extension TabSwitcherPageViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        documents.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = layoutMode == .grid ? TabViewGridCell.reuseIdentifier : TabViewListCell.reuseIdentifier
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as? TabViewCell else {
            preconditionFailure("DuckDuckGo tab switcher cell registration is invalid")
        }
        cell.delegate = self
        if documents.indices.contains(indexPath.item) {
            let document = documents[indexPath.item]
            cell.configure(document: document, isCurrent: document.id == selectedID)
            cell.accessibilityIdentifier = "tab-switcher-\(layoutMode.rawValue)-cell-\(document.id.uuidString)"
        }
        return cell
    }
}

extension TabSwitcherPageViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard documents.indices.contains(indexPath.item) else { return }
        selectedID = documents[indexPath.item].id
        pageDelegate?.page(self, didSelectTabAt: indexPath.item)
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if layoutMode == .grid {
            let width = TabSwitcherGridLayoutGeometry.columnWidth(for: collectionView.bounds.width)
            let aspect = collectionView.bounds.width / max(collectionView.bounds.height, 1)
            let desired = width / max(aspect, .leastNonzeroMagnitude) + TabViewCell.Constants.cellHeaderHeight
            let preferred = min(collectionView.bounds.height / 2.7, desired)
            let height = min(209, max(140, preferred))
            return CGSize(width: floor(width), height: floor(height))
        }
        let spacing = (collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset.left ?? 0
        return CGSize(width: max(0, min(664, collectionView.bounds.width - 2 * spacing)), height: 70)
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard let index = indexPaths.first?.item, documents.indices.contains(index) else { return nil }
        let id = documents[index].id
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self, let currentIndex = self.documents.firstIndex(where: { $0.id == id }) else { return nil }
            return self.pageDelegate?.page(self, contextMenuForTabAt: currentIndex)
        }
    }
}

extension TabSwitcherPageViewController: TabViewCellDelegate {
    func deleteTab(id: UUID) { removeDocument(id: id) }
    func tabViewCellDidBeginSwipe(_ cell: TabViewCell) { collectionView.isScrollEnabled = false }
    func tabViewCellDidEndSwipe(_ cell: TabViewCell) { collectionView.isScrollEnabled = true }
}

extension TabSwitcherPageViewController: UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        guard documents.indices.contains(indexPath.item) else { return [] }
        session.localContext = self
        dragMembership = documents.map(\.id)
        let item = UIDragItem(itemProvider: NSItemProvider())
        item.localObject = documents[indexPath.item].id
        return [item]
    }

    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        dragMembership = nil
    }

    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        (session.localDragSession?.localContext as? TabSwitcherPageViewController) === self
    }

    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        let ownsSession = (session.localDragSession?.localContext as? TabSwitcherPageViewController) === self
        return UICollectionViewDropProposal(operation: ownsSession && dragMembership == documents.map(\.id) ? .move : .forbidden,
                                            intent: .insertAtDestinationIndexPath)
    }

    func collectionView(_ collectionView: UICollectionView,
                        performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard (coordinator.session.localDragSession?.localContext as? TabSwitcherPageViewController) === self,
              dragMembership == documents.map(\.id),
              let item = coordinator.items.first,
              let source = item.sourceIndexPath,
              source.section == 0, documents.indices.contains(source.item),
              let id = item.dragItem.localObject as? UUID,
              documents[source.item].id == id,
              let proposedDestination = coordinator.destinationIndexPath,
              proposedDestination.section == 0 else { return }
        let destinationItem = max(0, min(proposedDestination.item, documents.count - 1))
        let destination = IndexPath(item: destinationItem, section: 0)
        let document = documents.remove(at: source.item)
        documents.insert(document, at: destinationItem)
        collectionView.performBatchUpdates {
            collectionView.deleteItems(at: [source])
            collectionView.insertItems(at: [destination])
        } completion: { [weak self] _ in
            guard let self else { return }
            self.pageDelegate?.page(self, didReorderTab: document.id, to: destinationItem)
            coordinator.drop(item.dragItem, toItemAt: destination)
        }
    }
}

struct TabSwitcherPageHost: UIViewControllerRepresentable {
    let documents: [ReaderTabSwitcherDocument]
    let selectedID: UUID?
    let layoutMode: ReaderTabSwitcherLayout
    let onSelect: (ReaderTabSwitcherDocument) -> Void
    let onClose: (ReaderTabSwitcherDocument) -> Void
    let onReorder: (ReaderTabSwitcherDocument, Int) -> Void
    let contextMenu: (ReaderTabSwitcherDocument) -> UIMenu?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> TabSwitcherPageViewController {
        let controller = TabSwitcherPageViewController()
        controller.pageDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: TabSwitcherPageViewController, context: Context) {
        context.coordinator.parent = self
        controller.update(documents: documents, selectedID: selectedID, layoutMode: layoutMode)
    }

    @MainActor
    final class Coordinator: NSObject, TabSwitcherPageDelegate {
        var parent: TabSwitcherPageHost
        init(parent: TabSwitcherPageHost) { self.parent = parent }

        func page(_ page: TabSwitcherPageViewController, didSelectTabAt index: Int) {
            guard parent.documents.indices.contains(index) else { return }
            parent.onSelect(parent.documents[index])
        }

        func page(_ page: TabSwitcherPageViewController, didDeleteTab id: UUID) {
            guard let document = parent.documents.first(where: { $0.id == id }) else { return }
            parent.onClose(document)
        }

        func page(_ page: TabSwitcherPageViewController, didReorderTab id: UUID, to index: Int) {
            guard let document = parent.documents.first(where: { $0.id == id }) else { return }
            parent.onReorder(document, index)
        }

        func page(_ page: TabSwitcherPageViewController, contextMenuForTabAt index: Int) -> UIMenu? {
            guard parent.documents.indices.contains(index) else { return nil }
            return parent.contextMenu(parent.documents[index])
        }
    }
}
