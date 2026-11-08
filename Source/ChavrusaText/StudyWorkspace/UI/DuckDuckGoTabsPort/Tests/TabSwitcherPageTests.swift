import XCTest
@testable import DuckDuckGoBookTabs

@MainActor
final class TabSwitcherPageTests: XCTestCase {
    private func documents(_ count: Int) -> [ReaderTabSwitcherDocument] {
        (0..<count).map { .init(id: UUID(), title: "ספר \($0)", subtitle: "אוצריא") }
    }

    func testRepeatedMembershipLayoutAndWidthTransitions() {
        let controller = TabSwitcherPageViewController()
        controller.loadViewIfNeeded()
        for _ in 0..<20 {
            for count in [0, 1, 2, 30, 1, 0] {
                let items = documents(count)
                for width: CGFloat in [320, 375, 834, 1200] {
                    controller.view.frame = CGRect(x: 0, y: 0, width: width, height: 600)
                    for mode in ReaderTabSwitcherLayout.allCases {
                        controller.update(documents: items, selectedID: items.last?.id, layoutMode: mode)
                        controller.view.layoutIfNeeded()
                        XCTAssertEqual(controller.collectionView.numberOfItems(inSection: 0), count)
                        guard count > 0 else { continue }
                        let size = controller.collectionView(controller.collectionView,
                            layout: controller.collectionView.collectionViewLayout,
                            sizeForItemAt: IndexPath(item: 0, section: 0))
                        XCTAssertGreaterThan(size.width, 0)
                        XCTAssertLessThanOrEqual(size.width, width - 28)
                        if mode == .list {
                            XCTAssertEqual(size.height, 70)
                            XCTAssertLessThanOrEqual(size.width, 664)
                        } else {
                            XCTAssertGreaterThanOrEqual(size.height, 140)
                            XCTAssertLessThanOrEqual(size.height, 209)
                        }
                    }
                }
            }
        }
    }

    func testGridKeepsOriginalColumnAndHeightPolicy() {
        let controller = TabSwitcherPageViewController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 1200, height: 600)
        controller.update(documents: documents(4), selectedID: nil, layoutMode: .grid)
        controller.view.layoutIfNeeded()
        XCTAssertEqual(TabSwitcherGridLayoutGeometry.columnWidth(for: 1200), (1200 - 14) / 4 - 14)
        let size = controller.collectionView(controller.collectionView,
            layout: controller.collectionView.collectionViewLayout, sizeForItemAt: IndexPath(item: 0, section: 0))
        let originalHeight: CGFloat = floor(min(209, max(140, min(600 / 2.7, ((1200 - 14) / 4 - 14) / 2 + 40))))
        XCTAssertEqual(size.height, originalHeight)
    }

    func testListCloseSpacingAndReusePreserveOriginalHierarchy() {
        let cell = TabViewListCell(frame: CGRect(x: 0, y: 0, width: 320, height: 70))
        let item = documents(1)[0]
        cell.configure(document: item, isCurrent: true)
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.textButtonSpacing?.constant, -12)
        XCTAssertEqual(cell.removeButton.bounds.size, CGSize(width: 44, height: 44))
        XCTAssertFalse(cell.hasAmbiguousLayout)
        XCTAssertTrue(cell.title.isAccessibilityElement)
        XCTAssertEqual(cell.accessibilityElements?.count, 2)
        cell.transform = CGAffineTransform(translationX: -90, y: 0)
        cell.alpha = 0.5
        cell.prepareForReuse()
        cell.configure(document: documents(1)[0], isCurrent: false)
        XCTAssertEqual(cell.transform, .identity)
        XCTAssertEqual(cell.alpha, 1)
        XCTAssertNotEqual(cell.documentID, item.id)
    }
}
