import XCTest
@testable import DuckDuckGoBookTabs

final class TabsLifecycleTests: XCTestCase {
    @MainActor
    func testToolbarHostedActionsLeaveTheOriginalStripOnlyBookCells() {
        let controller = TabsBarViewController(showsToolbarButtons: false)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 650, height: 40)
        let model = ReaderBookTabsModel()
        for count in [0, 1, 2, 30, 1, 0] {
            model.tabs = (0..<count).map { ReaderBookTabAdapter(id: UUID(), title: "ספר \($0)") }
            model.selectedID = model.tabs.last?.id
            controller.refresh(tabsModel: model)
            controller.view.layoutIfNeeded()
            XCTAssertTrue(controller.addTabButton.isHidden)
            XCTAssertTrue(controller.buttonsStack.isHidden)
            XCTAssertEqual(controller.buttonsStack.bounds.width, 0)
            XCTAssertEqual(controller.collectionView.frame.maxX, controller.view.bounds.maxX, accuracy: 0.5)
            XCTAssertEqual(controller.collectionView.numberOfItems(inSection: 0), count)
            if count > 0 {
                let layout = controller.collectionView.collectionViewLayout as! TabsBarCollectionViewLayout
                XCTAssertNotNil(layout.frameForCurrentTabAtRest())
            }
        }
    }

    @MainActor
    func testBookTitleChangesUpdateTheOriginalCellWithoutReloadingIt() throws {
        let model = ReaderBookTabAdapter(id: UUID(), title: "כותרת זמנית")
        let cell = TabsBarCell(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        cell.update(model: model, isCurrent: true, isNextCurrent: false, hidesInactiveCloseButton: false, isFireModeEnabled: false, withTheme: ReaderTabsTheme())
        let label = try XCTUnwrap(cell.accessibilityElements?.first as? UILabel)
        XCTAssertEqual(label.text, "כותרת זמנית")
        model.title = "בראשית"
        XCTAssertEqual(label.text, "בראשית")
        XCTAssertEqual(cell.removeButton.accessibilityLabel, "סגור בראשית")
    }

    @MainActor
    func testEmptySingleManyEmptyLifecycleAndStaleLayoutQueries() {
        let controller = TabsBarViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 650, height: 44)
        let model = ReaderBookTabsModel()
        for _ in 0..<20 {
            for count in [0, 1, 2, 30, 1, 0] {
                model.tabs = (0..<count).map { ReaderBookTabAdapter(id: UUID(), title: "ספר \($0)") }
                model.selectedID = model.tabs.last?.id
                controller.refresh(tabsModel: model, scrollToSelected: true)
                controller.view.layoutIfNeeded()
                XCTAssertEqual(controller.collectionView.numberOfItems(inSection: 0), count)
                guard let layout = controller.collectionView.collectionViewLayout as? TabsBarCollectionViewLayout else {
                    XCTFail("Original accordion layout must be retained"); return
                }
                XCTAssertNil(layout.layoutAttributesForItem(at: IndexPath(item: count + 1, section: 0)))
                XCTAssertNil(layout.layoutAttributesForItem(at: IndexPath(item: 0, section: 1)))
                if count == 0 { XCTAssertNil(layout.frameForCurrentTabAtRest()) }
                else { XCTAssertNotNil(layout.frameForCurrentTabAtRest()) }
            }
        }
    }

    @MainActor
    func testUnattachedCollectionViewHasNoSectionZeroCrash() {
        let view = TabsBarView(frame: CGRect(x: 0, y: 0, width: 600, height: 44))
        let layout = view.collectionView.collectionViewLayout as! TabsBarCollectionViewLayout
        layout.currentIndex = { 0 }
        XCTAssertNil(layout.frameForCurrentTabAtRest())
        XCTAssertNil(layout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)))
        _ = layout.layoutAttributesForElements(in: view.bounds)
    }
}
