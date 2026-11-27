import SwiftUI

#if os(iOS)
import UIKit

@MainActor protocol SefariaEmbeddedNativeSurfaceObserver: AnyObject {
    func surfaceWillAttach(_ controller: SefariaEmbeddedNativeSurfaceController) throws
    func surfaceDidChange(_ controller: SefariaEmbeddedNativeSurfaceController)
    func surfaceWillDisappear(_ controller: SefariaEmbeddedNativeSurfaceController)
    func surfaceDidDetach(_ controller: SefariaEmbeddedNativeSurfaceController)
    func surfaceDidFail(_ controller: SefariaEmbeddedNativeSurfaceController, error: any Error)
}

/// A fresh original React surface in the requesting native sheet. The bootstrap
/// window and its root view never become children of this view controller.
@MainActor struct SefariaEmbeddedNativeSurfaceHost: UIViewControllerRepresentable {
    let identity: SefariaEmbeddedSurfaceIdentity
    let observer: any SefariaEmbeddedNativeSurfaceObserver

    func makeUIViewController(context: Context) -> SefariaEmbeddedNativeSurfaceController {
        .init(identity: identity, observer: observer)
    }
    func updateUIViewController(_ controller: SefariaEmbeddedNativeSurfaceController, context: Context) {
        guard controller.identity == identity, controller.observer === observer else {
            controller.rejectReplacement(); return
        }
        controller.publishActualLayout()
    }
    static func dismantleUIViewController(_ controller: SefariaEmbeddedNativeSurfaceController, coordinator: ()) {
        controller.detach()
    }
}

@MainActor final class SefariaEmbeddedNativeSurfaceController: UIViewController {
    struct Evidence: Equatable {
        let sceneID: String
        let window: ObjectIdentifier
        let frame: CGRect
        let mounted: Bool
        let appeared: Bool
        let visible: Bool
        let transitioning: Bool
    }
    let identity: SefariaEmbeddedSurfaceIdentity
    let token = UUID()
    private(set) var observer: (any SefariaEmbeddedNativeSurfaceObserver)?
    private(set) var reactView: UIView?
    private var appeared = false
    private var attached = false
    private var detached = false
    private var previous: Evidence?

    init(identity: SefariaEmbeddedSurfaceIdentity, observer: any SefariaEmbeddedNativeSurfaceObserver) {
        self.identity = identity; self.observer = observer
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground
        do {
            guard identity.valid, let observer else {
                throw SefariaRPCError(code: "SURFACE_OWNER_MISSING", message: "The original Sefaria surface owner is unavailable.")
            }
            try observer.surfaceWillAttach(self)
            attached = true
            let original = try SefariaExpoLifecycleAdapter.shared.createSurfaceView(
                moduleName: "ChavrusaSefariaVisibleSurface", initialProperties: identity.properties)
            original.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            original.frame = view.bounds
            view.addSubview(original)
            reactView = original
            view.accessibilityIdentifier = "sefaria-original-native-host"
        } catch { observer?.surfaceDidFail(self, error: error) }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appeared = true; view.setNeedsLayout(); publishActualLayout()
    }
    override func viewWillDisappear(_ animated: Bool) {
        appeared = false
        observer?.surfaceWillDisappear(self)
        publishActualLayout()
        super.viewWillDisappear(animated)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); publishActualLayout()
    }
    func publishActualLayout() {
        let actual = evidence()
        guard actual != previous else { return }
        previous = actual; observer?.surfaceDidChange(self)
    }
    func rejectReplacement() {
        observer?.surfaceDidFail(self, error: SefariaRPCError(code: "SURFACE_HOST_REPLACED",
            message: "The original Sefaria surface owner changed."))
    }
    func detach() {
        guard !detached else { return }
        detached = true; appeared = false
        // Dropping this independently-created root stops its own React surface;
        // the persistent bootstrap factory/window remain untouched.
        reactView?.removeFromSuperview(); reactView = nil
        // A willAttach postcondition can fail after the owner retained this
        // token but before `attached` is set. The owner checks exact identity,
        // so always give it the chance to release that partial mount too.
        observer?.surfaceDidDetach(self)
        observer = nil
    }
    func evidence() -> Evidence? {
        guard !detached, let original = reactView, let container = viewIfLoaded,
              original.superview === container, let window = container.window,
              original.window === window, let scene = window.windowScene else { return nil }
        let rect = original.convert(original.bounds, to: window)
        let area = rect.width * rect.height
        var visibleRect = rect.intersection(window.bounds)
        var visible = appeared && attached && window.isKeyWindow && !window.isHidden
            && scene.activationState == .foregroundActive && !rect.isEmpty
            && area.isFinite && area > 0 && scene.session.persistentIdentifier == identity.sceneID
        var alpha: CGFloat = 1
        var ancestor: UIView? = original
        while let item = ancestor {
            visible = visible && !item.isHidden; alpha *= item.alpha
            if item.clipsToBounds { visibleRect = visibleRect.intersection(item.convert(item.bounds, to: window)) }
            ancestor = item.superview
        }
        var transitioning = false
        var controller: UIViewController? = self
        while let item = controller {
            transitioning = transitioning || item.isBeingPresented || item.isBeingDismissed || item.transitionCoordinator != nil
            controller = item.parent
        }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        if let top {
            if top !== window.rootViewController && !original.isDescendant(of: top.view) { visible = false }
            transitioning = transitioning || top.isBeingPresented || top.isBeingDismissed || top.transitionCoordinator != nil
        } else { visible = false }
        visible = visible && !transitioning && alpha >= 0.95 && !visibleRect.isNull
            && visibleRect.width * visibleRect.height >= area * 0.98
        return .init(sceneID: scene.session.persistentIdentifier, window: ObjectIdentifier(window), frame: rect,
                     mounted: attached, appeared: appeared, visible: visible, transitioning: transitioning)
    }
}
#endif
