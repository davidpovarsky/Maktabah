import Foundation
@MainActor final class OriginalStateFixture { var blocked = false }
struct UIStableID { let rawValue: String }
struct UIRouteError: Error { enum Kind { case unavailable }; init(_ kind: Kind, _ detail: String) {} }
@MainActor class UIView { weak var window: UIWindow? }
@MainActor final class UIWindow: UIView {
    var isKeyWindow = true; var isHidden = false; var alpha = 1.0
    var windowScene: UIWindowScene? = UIWindowScene()
    var rootViewController: UIViewController?
}
@MainActor final class UIWindowScene {
    enum Activation { case foregroundActive, foregroundInactive }
    struct Session { var persistentIdentifier = "scene-A" }
    var activationState = Activation.foregroundActive; var session = Session()
}
@MainActor final class UIViewController {
    var viewIfLoaded: UIView?; var presentedViewController: UIViewController?
    var isBeingPresented = false; var isBeingDismissed = false
    var transitionCoordinator: Int?; var children: [UIViewController] = []
}
@MainActor final class MaktabahNativeWindowSource {
    private weak var source: UIView?
    private weak var window: UIWindow?

    @discardableResult
    func observe(_ window: UIWindow?, from source: UIView) -> Bool {
        if window == nil {
            guard self.source === source else { return false }
            self.source = nil; self.window = nil
            return true
        }
        guard self.source !== source || self.window !== window else { return false }
        self.source = source; self.window = window
        return true
    }

    func isPresentationReady(in sceneID: UIStableID) -> Bool {
        guard let source, let window, source.window === window,
              window.isKeyWindow, !window.isHidden, window.alpha >= 0.95,
              let scene = window.windowScene, scene.activationState == .foregroundActive,
              scene.session.persistentIdentifier == sceneID.rawValue,
              let root = window.rootViewController, root.viewIfLoaded?.window === window else { return false }
        // Read the original controller tree now, including the dismissal
        // interval after a SwiftUI sheet binding has already become false.
        var controllers = [root]
        while let controller = controllers.popLast() {
            guard controller.presentedViewController == nil,
                  !controller.isBeingPresented, !controller.isBeingDismissed,
                  controller.transitionCoordinator == nil else { return false }
            controllers.append(contentsOf: controller.children)
        }
        return true
    }
}


@MainActor final class SearchPresentationFixture {
    var mounted = true
    weak var windowSource: MaktabahNativeWindowSource?
    var sceneID = UIStableID(rawValue: "scene-A")
    var searchPresentationOwner: UUID?
    var searchPresentationBlocked: (@MainActor () -> Bool)?
    func isReady() -> Bool { (try? validateSearchPresentation()) != nil }
    func observeSearchPresentation(owner: UUID, isBlocked: @escaping @MainActor () -> Bool) {
        guard mounted else { return }
        searchPresentationOwner = owner; searchPresentationBlocked = isBlocked
    }
    func removeSearchPresentation(owner: UUID) {
        guard searchPresentationOwner == owner else { return }
        // A hidden Search tab can retain its opaque FTS overlay state. Keep
        // that original blocker until the actual owner clears/replaces it;
        // reopening Search semantically must not submit behind a restored mask.
        guard searchPresentationBlocked?() != true else { return }
        searchPresentationOwner = nil; searchPresentationBlocked = nil
    }
    private func validateSearchPresentation() throws {
        guard windowSource?.isPresentationReady(in: sceneID) == true,
              searchPresentationBlocked?() != true else {
            throw UIRouteError(.unavailable, "native_search_presentation_in_progress")
        }
    }

}

@main struct GuardChecks {
    @MainActor static func main() {
        var count = 0
        func check(_ value: Bool, _ description: String) {
            precondition(value, description); count += 1
        }
        let scene = UIStableID(rawValue: "scene-A")
        let window = UIWindow(), root = UIViewController(), rootView = UIView()
        rootView.window = window; root.viewIfLoaded = rootView; window.rootViewController = root
        let owner = UIView(); owner.window = window
        let source = MaktabahNativeWindowSource()
        check(source.observe(window, from: owner), "first actual owner registers")
        check(source.isPresentationReady(in: scene), "actual foreground root is ready")
        check(!source.isPresentationReady(in: .init(rawValue: "scene-B")), "different scene refused")
        window.windowScene!.activationState = .foregroundInactive
        check(!source.isPresentationReady(in: scene), "inactive scene refused")
        window.windowScene!.activationState = .foregroundActive
        window.isKeyWindow = false; check(!source.isPresentationReady(in: scene), "non-key window refused"); window.isKeyWindow = true
        window.isHidden = true; check(!source.isPresentationReady(in: scene), "hidden window refused"); window.isHidden = false
        window.alpha = 0.4; check(!source.isPresentationReady(in: scene), "transparent window refused"); window.alpha = 1
        root.viewIfLoaded = nil; check(!source.isPresentationReady(in: scene), "unloaded root refused"); root.viewIfLoaded = rootView
        owner.window = nil; check(!source.isPresentationReady(in: scene), "detachment is read synchronously"); owner.window = window
        let modal = UIViewController()
        root.presentedViewController = modal; check(!source.isPresentationReady(in: scene), "presented sheet refused"); root.presentedViewController = nil
        root.isBeingPresented = true; check(!source.isPresentationReady(in: scene), "pending presentation refused"); root.isBeingPresented = false
        root.isBeingDismissed = true; check(!source.isPresentationReady(in: scene), "dismissal refused"); root.isBeingDismissed = false
        root.transitionCoordinator = 1; check(!source.isPresentationReady(in: scene), "dismissal transition remains blocked after binding false"); root.transitionCoordinator = nil
        let child = UIViewController(); root.children = [child]
        child.presentedViewController = modal; check(!source.isPresentationReady(in: scene), "child-owned modal refused"); child.presentedViewController = nil
        child.transitionCoordinator = 1; check(!source.isPresentationReady(in: scene), "child transition refused"); child.transitionCoordinator = nil
        check(source.isPresentationReady(in: scene), "actual completed dismissal is ready")
        let newerOwner = UIView(); newerOwner.window = window
        check(source.observe(window, from: newerOwner), "new actual owner replaces old one")
        check(!source.observe(nil, from: owner), "old owner cleanup ignored")
        check(source.isPresentationReady(in: scene), "new owner remains ready after old cleanup")
        check(source.observe(nil, from: newerOwner), "current owner cleanup accepted")
        check(!source.isPresentationReady(in: scene), "current detachment removes readiness")
        var transientOwner: UIView? = UIView(); transientOwner!.window = window
        source.observe(window, from: transientOwner!)
        transientOwner = nil
        check(!source.isPresentationReady(in: scene), "source view is not retained")
        source.observe(window, from: owner)
        let fixture = SearchPresentationFixture(); fixture.windowSource = source
        let first = UUID(), second = UUID()
        let originalState = OriginalStateFixture()
        fixture.observeSearchPresentation(owner: first) { originalState.blocked }
        check(fixture.isReady(), "unblocked original state is ready")
        originalState.blocked = true
        check(!fixture.isReady(), "live original State blocks without a render callback")
        fixture.observeSearchPresentation(owner: second) { true }
        fixture.removeSearchPresentation(owner: first)
        check(!fixture.isReady(), "old presentation cleanup cannot erase new owner")
        fixture.removeSearchPresentation(owner: second)
        check(!fixture.isReady(), "hidden original blocked State remains authoritative")
        fixture.observeSearchPresentation(owner: second) { false }
        check(fixture.isReady(), "actual owner clears its original blocker")
        fixture.removeSearchPresentation(owner: second)
        check(fixture.searchPresentationOwner == nil, "unblocked current owner can detach")
        root.presentedViewController = modal
        check(!fixture.isReady(), "no flags still cannot bypass original UIKit modal")
        root.presentedViewController = nil
        fixture.mounted = false
        fixture.observeSearchPresentation(owner: UUID()) { true }
        check(fixture.searchPresentationOwner == nil, "unmounted session cannot accept registration")
        print("PASS: \(count) portable ownership/presentation assertions; UIKit behavior itself NOT_RUN")
    }
}
