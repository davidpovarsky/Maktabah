#if os(iOS) && canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
#if canImport(Maktabah_Debug)
@testable import Maktabah_Debug
#endif

final class ReaderOverviewPresentationTests: XCTestCase {
    private struct Fixture {
        let window: UIWindow
        let previousKeyWindow: UIWindow?
        let root: UIViewController
        let scroll: UIScrollView
        let presenter: ReaderOverviewPresentationController
    }

    @MainActor
    private func fixture(presenter requestedPresenter: ReaderOverviewPresentationController? = nil) throws -> Fixture {
        let presenter = requestedPresenter ?? ReaderOverviewPresentationController()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let oldKey = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        window.rootViewController = root
        root.loadViewIfNeeded()
        let scroll = UIScrollView(frame: window.bounds)
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentSize = CGSize(width: window.bounds.width, height: window.bounds.height * 5)
        root.view.addSubview(scroll)
        scroll.contentOffset = CGPoint(x: 0, y: 481)
        root.addChild(presenter)
        presenter.view.frame = window.bounds
        presenter.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.view.addSubview(presenter.view)
        presenter.didMove(toParent: root)
        window.makeKeyAndVisible()
        root.view.layoutIfNeeded()
        return Fixture(window: window, previousKeyWindow: oldKey, root: root, scroll: scroll, presenter: presenter)
    }

    @MainActor
    private func cleanUp(_ fixture: Fixture) {
        fixture.presenter.tearDownPresentation()
        fixture.window.isHidden = true
        fixture.previousKeyWindow?.makeKeyAndVisible()
    }

    @MainActor
    private func waitUntil(_ message: String, _ predicate: @escaping @MainActor () -> Bool) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { predicate() }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed, message)
    }

    @MainActor
    func testCurrentContextCoversTheReaderAndPreservesItsScrollAcrossReturns() throws {
        let fixture = try fixture()
        defer { cleanUp(fixture) }
        let originalOffset = fixture.scroll.contentOffset
        var dismissals = 0
        let content = AnyView(Text("Original source overview").frame(maxWidth: .infinity, maxHeight: .infinity))
        for _ in 0..<3 {
            fixture.presenter.configure(isPresented: true, overview: content) { dismissals += 1 }
            waitUntil("The context presentation must actually attach") {
                fixture.presenter.presentedViewController?.view.window === fixture.window
            }
            let shown = try XCTUnwrap(fixture.presenter.presentedViewController)
            XCTAssertEqual(shown.modalPresentationStyle, .overCurrentContext)
            XCTAssertFalse(shown.presentationController is UISheetPresentationController)
            XCTAssertEqual(shown.view.bounds.width, fixture.presenter.view.bounds.width, accuracy: 1)
            XCTAssertEqual(shown.view.bounds.height, fixture.presenter.view.bounds.height, accuracy: 1)
            XCTAssertTrue(fixture.scroll.isDescendant(of: fixture.root.view), "Presentation must retain the original view")
            XCTAssertEqual(fixture.scroll.contentOffset, originalOffset)
            let point = CGPoint(x: fixture.window.bounds.midX, y: fixture.window.bounds.midY)
            let hit = try XCTUnwrap(fixture.window.hitTest(point, with: nil))
            XCTAssertTrue(hit === shown.view || hit.isDescendant(of: shown.view),
                          "The displayed overview must receive touches instead of the covered reader")
            fixture.presenter.configure(isPresented: false, overview: content) { dismissals += 1 }
            waitUntil("Closing must return to the same underlying context") {
                fixture.presenter.presentedViewController == nil
            }
            XCTAssertTrue(fixture.scroll.isDescendant(of: fixture.root.view))
            XCTAssertEqual(fixture.scroll.contentOffset, originalOffset)
        }
        XCTAssertEqual(dismissals, 3)
    }

    @MainActor
    func testClosingBeforeAttachmentCannotPresentAnObsoleteOverview() throws {
        let presenter = ReaderOverviewPresentationController()
        let content = AnyView(Text("Original source overview"))
        presenter.configure(isPresented: true, overview: content, onDismiss: {})
        presenter.configure(isPresented: false, overview: content, onDismiss: {})
        let fixture = try fixture(presenter: presenter)
        defer { cleanUp(fixture) }
        let obsolete = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { presenter.presentedViewController != nil }
        }, object: nil)
        obsolete.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [obsolete], timeout: 0.5), .completed)
        XCTAssertEqual(fixture.scroll.contentOffset.y, 481)
    }
}
#endif
