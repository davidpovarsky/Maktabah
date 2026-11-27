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
    struct SemanticEvidence: Equatable {
        let target: SefariaEmbeddedSemanticTarget
        let language: String
        let hostToken: UUID
        let originalViews: [ObjectIdentifier]
        let frames: [CGRect]
    }
    let identity: SefariaEmbeddedSurfaceIdentity
    let token = UUID()
    private(set) var observer: (any SefariaEmbeddedNativeSurfaceObserver)?
    private(set) var reactView: UIView?
    private var appeared = false
    private var attached = false
    private var detached = false
    private var previous: Evidence?
    private var semanticObservation: (target: SefariaEmbeddedSemanticTarget, language: String)?
    private var previousSemantic: SemanticEvidence?
    private var semanticDisplayLink: CADisplayLink?
    private let semanticFrameObserver = SemanticFrameObserver()

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
        let semantic = semanticObservation.flatMap { semanticEvidence(target: $0.target, language: $0.language) }
        guard actual != previous || semantic != previousSemantic else { return }
        previous = actual; previousSemantic = semantic; observer?.surfaceDidChange(self)
    }
    /// A bounded passive frame observer reads actual original descendant views.
    /// It never manufactures layout, scrolls, mutates React or reports success.
    func observeSemanticTarget(_ target: SefariaEmbeddedSemanticTarget, language: String) {
        guard !detached else { return }
        semanticObservation = (target, language); previousSemantic = nil
        if semanticDisplayLink == nil {
            semanticFrameObserver.owner = self
            let link = CADisplayLink(target: semanticFrameObserver, selector: #selector(SemanticFrameObserver.frame))
            semanticDisplayLink = link; link.add(to: .main, forMode: .common)
        }
        publishActualLayout()
    }
    func stopSemanticObservation() {
        semanticDisplayLink?.invalidate(); semanticDisplayLink = nil
        semanticFrameObserver.owner = nil; semanticObservation = nil; previousSemantic = nil
    }
    @MainActor private final class SemanticFrameObserver: NSObject {
        weak var owner: SefariaEmbeddedNativeSurfaceController?
        @objc func frame() { owner?.publishActualLayout() }
    }
    func rejectReplacement() {
        observer?.surfaceDidFail(self, error: SefariaRPCError(code: "SURFACE_HOST_REPLACED",
            message: "The original Sefaria surface owner changed."))
    }
    func detach() {
        guard !detached else { return }
        stopSemanticObservation()
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

    /// No injected marker or echoed route label satisfies this witness. Only
    /// actual original UIKit text/AX descendants in this React root are read.
    /// Ambiguous, unavailable or occluded original renderer evidence refuses.
    func semanticEvidence(target: SefariaEmbeddedSemanticTarget, language: String) -> SemanticEvidence? {
        guard evidence()?.visible == true, let original = reactView, let window = original.window,
              let expected = target.originalVisibleTexts(language: language), !expected.isEmpty else { return nil }
        var remaining = [original], originals: [UIView] = []
        while let view = remaining.popLast() {
            guard originals.count < 8192 else { return nil }
            originals.append(view); remaining.append(contentsOf: view.subviews)
        }
        var witnesses: [UIView] = [], frames: [CGRect] = []
        for text in expected {
            let matches = originals.filter { view in
                guard view.window === window else { return false }
                if let label = view as? UILabel, label.text == text { return true }
                if let textView = view as? UITextView, textView.text == text { return true }
                return view.isAccessibilityElement && view.accessibilityLabel == text
            }
            // Some original renderers expose an AX wrapper and its own UIKit
            // text child. They describe one original view, not two siblings.
            let leaves = matches.filter { outer in
                !matches.contains { inner in inner !== outer && inner.isDescendant(of: outer) }
            }
            guard leaves.count == 1, let actual = leaves.first,
                  let rect = visibleOriginalText(actual, in: original, window: window) else { return nil }
            witnesses.append(actual); frames.append(rect)
        }
        guard Set(witnesses.map(ObjectIdentifier.init)).count == expected.count else { return nil }
        return .init(target: target, language: language, hostToken: token,
            originalViews: witnesses.map(ObjectIdentifier.init), frames: frames)
    }

    private func visibleOriginalText(_ text: UIView, in original: UIView, window: UIWindow) -> CGRect? {
        guard text.isDescendant(of: original), text.window === window else { return nil }
        let rect = text.convert(text.bounds, to: window), area = text.bounds.width * text.bounds.height
        guard !rect.isEmpty, area.isFinite, area > 0 else { return nil }
        var clipped = rect.intersection(window.bounds), alpha: CGFloat = 1
        var ancestor: UIView? = text
        while let view = ancestor {
            guard !view.isHidden else { return nil }
            alpha *= view.alpha
            if view.clipsToBounds { clipped = clipped.intersection(view.convert(view.bounds, to: window)) }
            if let scroll = view as? UIScrollView {
                guard !scroll.isDragging, !scroll.isDecelerating else { return nil }
                clipped = clipped.intersection(scroll.convert(scroll.bounds.inset(by: scroll.adjustedContentInset), to: window))
            }
            ancestor = view.superview
        }
        guard alpha >= 0.95, !clipped.isNull, clipped.width * clipped.height >= rect.width * rect.height * 0.98 else { return nil }
        let inset = min(1, min(rect.width, rect.height) / 4)
        let samples = [CGPoint(x: rect.midX, y: rect.midY),
            CGPoint(x: rect.minX + inset, y: rect.minY + inset), CGPoint(x: rect.maxX - inset, y: rect.minY + inset),
            CGPoint(x: rect.minX + inset, y: rect.maxY - inset), CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)]
        for point in samples {
            guard let hit = window.hitTest(point, with: nil),
                  hit === text || hit.isDescendant(of: text) || text.isDescendant(of: hit) else { return nil }
        }
        return rect
    }
}
#endif
