#if os(iOS) && canImport(UIKit)
import SwiftUI
import Combine
import UIKit
import XCTest
#if canImport(Maktabah_Debug)
@testable import Maktabah_Debug
#endif

final class ReaderOverviewPresentationTests: XCTestCase {
    private struct ScrollProbe: UIViewRepresentable {
        let scroll: UIScrollView
        func makeUIView(context: Context) -> UIScrollView { scroll }
        func updateUIView(_ view: UIScrollView, context: Context) {}
    }

    @MainActor private final class PresentationFlag: ObservableObject {
        @Published var isPresented = false
    }

    private struct SwiftUIPresentationProbe: View {
        @ObservedObject var flag: PresentationFlag
        let scroll: UIScrollView
        var body: some View {
            ScrollProbe(scroll: scroll).overlay {
                ReaderOverviewPresentation(isPresented: $flag.isPresented) {
                    Text("Source overview").frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
        }
    }

    @MainActor
    func testSwiftUIBindingActuallyPresentsTheContextAndReturnsToItsReader() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let oldKey = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let scroll = UIScrollView()
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentSize = CGSize(width: window.bounds.width, height: window.bounds.height * 5)
        let flag = PresentationFlag()
        let host = UIHostingController(rootView: SwiftUIPresentationProbe(flag: flag, scroll: scroll))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        defer { window.isHidden = true; oldKey?.makeKeyAndVisible() }
        @MainActor func findAnchor(_ controller: UIViewController) -> ReaderOverviewPresentationController? {
            if let anchor = controller as? ReaderOverviewPresentationController { return anchor }
            for child in controller.children {
                if let anchor = findAnchor(child) { return anchor }
            }
            return nil
        }
        waitUntil("The real SwiftUI representable controller must attach") { findAnchor(host) != nil }
        let anchor = try XCTUnwrap(findAnchor(host))
        XCTAssertTrue(anchor.view.window === window)
        XCTAssertGreaterThan(anchor.view.bounds.width, 80)
        XCTAssertGreaterThan(anchor.view.bounds.height, 80)
        scroll.contentOffset = CGPoint(x: 0, y: 481)
        for _ in 0..<2 {
            flag.isPresented = true
            waitUntil("Changing the actual SwiftUI binding must present, with a real context-sized anchor") {
                anchor.presentedViewController?.view.window === window
            }
            let shown = try XCTUnwrap(anchor.presentedViewController)
            XCTAssertEqual(shown.modalPresentationStyle, .overCurrentContext)
            XCTAssertFalse(shown.presentationController is UISheetPresentationController)
            XCTAssertEqual(shown.view.bounds.width, window.bounds.width, accuracy: 1)
            XCTAssertEqual(shown.view.bounds.height, window.bounds.height, accuracy: 1)
            let hit = try XCTUnwrap(window.hitTest(CGPoint(x: window.bounds.midX, y: window.bounds.midY), with: nil))
            XCTAssertTrue(hit === shown.view || hit.isDescendant(of: shown.view))
            flag.isPresented = false
            waitUntil("The actual SwiftUI binding must return to its original reader") { anchor.presentedViewController == nil }
            XCTAssertTrue(scroll.window === window)
            XCTAssertEqual(scroll.contentOffset.y, 481, accuracy: 1)
        }
    }

    @MainActor
    func testClosedSwiftUIPresentationAllowsTouchesToReachTheReader() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let oldKey = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let scroll = UIScrollView()
        scroll.contentSize = CGSize(width: window.bounds.width, height: window.bounds.height * 5)
        let host = UIHostingController(rootView: ScrollProbe(scroll: scroll).overlay {
            ReaderOverviewPresentation(isPresented: .constant(false)) { Text("Overview") }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        })
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; oldKey?.makeKeyAndVisible() }
        waitUntil("The actual SwiftUI reader must attach before hit testing") {
            scroll.window === window && scroll.bounds.width > 80 && scroll.bounds.height > 80
        }
        let hit = try XCTUnwrap(window.hitTest(CGPoint(x: window.bounds.midX, y: window.bounds.midY), with: nil))
        XCTAssertTrue(hit === scroll || hit.isDescendant(of: scroll),
                      "The closed SwiftUI presentation layer must not block the original reader's gestures")
    }

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
