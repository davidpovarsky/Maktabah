//
//  ReaderTabStripLayout.swift
//  Maktabah
//
//  Downstream-owned UICollectionViewFlowLayout for the iPad document tab strip (Plan C2).
//
//  Attribution:
//  Adapted from duckduckgo/apple-browsers @ f1d574485cf2f0586bcb284e8b3ca8c2f6ff7f32
//  https://github.com/duckduckgo/apple-browsers
//  License: Apache License 2.0 (Copyright (c) DuckDuckGo)
//

#if os(iOS)
import UIKit

/// Horizontal collection-view layout modeled after DuckDuckGo's iPad `TabsBarFlowLayout`.
/// Computes adaptive tab widths clamped to `[minTabWidth, maxTabWidth]` and supports RTL layout direction.
final class ReaderTabStripLayout: UICollectionViewFlowLayout {
    static let barHeight: CGFloat = 40
    static let tabCellHeight: CGFloat = 34
    static let minTabWidth: CGFloat = 124
    static let maxTabWidth: CGFloat = 240
    static let horizontalInset: CGFloat = 8
    static let interItemSpacing: CGFloat = 6

    override init() {
        super.init()
        scrollDirection = .horizontal
        minimumInteritemSpacing = Self.interItemSpacing
        minimumLineSpacing = Self.interItemSpacing
        sectionInset = UIEdgeInsets(top: 3, left: Self.horizontalInset, bottom: 3, right: Self.horizontalInset)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var flipsHorizontallyInOppositeLayoutDirection: Bool {
        true
    }

    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        let count = collectionView.numberOfItems(inSection: 0)
        let availableWidth = max(0, collectionView.bounds.width - (Self.horizontalInset * 2))
        let computedWidth = Self.calculateTabWidth(
            forTabCount: count,
            availableWidth: availableWidth
        )
        itemSize = CGSize(width: computedWidth, height: Self.tabCellHeight)
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return false }
        return newBounds.size != collectionView.bounds.size
    }

    /// Computes proportional tab width clamped between `minTabWidth` and `maxTabWidth`.
    static func calculateTabWidth(
        forTabCount count: Int,
        availableWidth: CGFloat,
        minWidth: CGFloat = ReaderTabStripLayout.minTabWidth,
        maxWidth: CGFloat = ReaderTabStripLayout.maxTabWidth,
        spacing: CGFloat = ReaderTabStripLayout.interItemSpacing
    ) -> CGFloat {
        guard count > 0, availableWidth > 0 else { return maxWidth }
        let totalSpacing = CGFloat(max(0, count - 1)) * spacing
        let rawWidth = floor((availableWidth - totalSpacing) / CGFloat(count))
        return min(max(rawWidth, minWidth), maxWidth)
    }
}
#endif
