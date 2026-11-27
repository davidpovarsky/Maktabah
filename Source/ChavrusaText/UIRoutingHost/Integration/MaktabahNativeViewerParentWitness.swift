#if os(iOS)
import SwiftUI
import UIKit
import OtzariaUIRouting

/// A passive background on the ORIGINAL Viewer container, outside its library
/// or Reader child. The common outer routing host cannot prove which UIKit tab
/// actually became selected. This adds no navigation/presentation UI.
struct MaktabahNativeViewerParentSurface: ViewModifier {
    let manager: iOSNavigationManager
    let selectedTab: iOSTab
    @Environment(\.maktabahNativeRoutingSession) private var session

    func body(content: Content) -> some View {
        content.background {
            MaktabahNativeViewerParentWitness(host: session?.viewerParentHost,
                manager: manager, selectedTab: selectedTab, mode: manager.currentMode)
                .accessibilityHidden(true)
        }
    }
}

struct MaktabahNativeViewerParentWitness: UIViewControllerRepresentable {
    let host: MaktabahNativeViewerParentHost?
    let manager: iOSNavigationManager
    let selectedTab: iOSTab
    let mode: AppMode

    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        // Reading these original values makes state publication observable to
        // the existing container. They are never cached as visibility proof.
        _ = selectedTab; _ = mode
        controller.attach(host: host, manager: manager)
        // No setNeedsLayout, timer, Task.yield, synthetic appearance or forced
        // passive-marker layout. Only ORIGINAL UIKit events advance evidence.
    }
    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) { controller.detach() }

    @MainActor final class Controller: UIViewController {
        let identity = UUID()
        private weak var host: MaktabahNativeViewerParentHost?
        private weak var manager: iOSNavigationManager?
        private var attachmentID = UUID()
        private var appeared = false
        private var hadOriginalWindow = false
        private let marker = Marker()

        override func loadView() {
            view = marker
            marker.windowDidChange = { [weak self] in
                guard let self else { return }
                let attached = marker.window != nil
                let disappeared = hadOriginalWindow && !attached
                hadOriginalWindow = attached
                // A freshly allocated original container may receive an
                // initial nil-window callback before its first real mount.
                // That is neither appearance nor disappearance evidence.
                if attached || disappeared {
                    host?.originalPresentationDidChange(self, disappeared: disappeared)
                }
            }
        }
        func attach(host: MaktabahNativeViewerParentHost?, manager: iOSNavigationManager) {
            if self.host !== host || self.manager !== manager {
                // Retire old coordinator callbacks BEFORE detaching the old
                // host. A return to the same host cannot restore this token.
                attachmentID = UUID()
                self.host?.detach(self)
                self.host = host; self.manager = manager
            }
            host?.attach(self, manager: manager)
        }
        func detach() {
            attachmentID = UUID()
            appeared = false
            hadOriginalWindow = false
            host?.detach(self); host = nil; manager = nil
            marker.windowDidChange = nil
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            appeared = true
            let originalHost = host
            let originalAttachment = attachmentID
            originalHost?.originalPresentationDidChange(self)
            guard let originalHost, host === originalHost,
                  attachmentID == originalAttachment else { return }
            // A real transition completion can be later than didAppear. Use
            // that original coordinator's completion, never elapsed time.
            var current: UIViewController? = self
            while let controller = current {
                if let transition = controller.transitionCoordinator {
                    transition.animate(alongsideTransition: nil) { [weak self, weak originalHost] context in
                        guard let self, let originalHost,
                              self.host === originalHost,
                              self.attachmentID == originalAttachment else { return }
                        originalHost.originalPresentationDidChange(self, disappeared: context.isCancelled)
                    }
                    break
                }
                current = controller.parent
            }
        }
        override func viewWillDisappear(_ animated: Bool) {
            appeared = false
            host?.originalPresentationDidChange(self, disappeared: true)
            super.viewWillDisappear(animated)
        }
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            host?.originalPresentationDidChange(self)
        }

        /// Fresh synchronous ORIGINAL UIKit ownership/visibility. The marker's
        /// attachment, a requested SwiftUI tab or old geometry is insufficient.
        func currentOriginalWindow(in sceneID: UIStableID) -> UIWindow? {
            guard appeared, let view = viewIfLoaded, let window = view.window,
                  window.isKeyWindow, !window.isHidden, window.alpha >= 0.95,
                  let scene = window.windowScene, scene.activationState == .foregroundActive,
                  scene.session.persistentIdentifier == sceneID.rawValue,
                  let root = window.rootViewController, root.viewIfLoaded?.window === window else { return nil }
            let frame = view.convert(view.bounds, to: window)
            let area = frame.width * frame.height
            guard !view.bounds.isEmpty, area.isFinite, area > 0 else { return nil }
            var visible = frame.intersection(window.bounds)
            var ancestor: UIView? = view
            var alpha: CGFloat = 1
            while let current = ancestor {
                guard !current.isHidden else { return nil }
                alpha *= current.alpha
                if current.clipsToBounds { visible = visible.intersection(current.convert(current.bounds, to: window)) }
                ancestor = current.superview
            }
            guard alpha >= 0.95, !visible.isNull,
                  visible.width * visible.height >= area * 0.98 else { return nil }

            var controllers = [root]
            while let current = controllers.popLast() {
                guard current.presentedViewController == nil,
                      !current.isBeingPresented, !current.isBeingDismissed,
                      current.transitionCoordinator == nil else { return nil }
                controllers.append(contentsOf: current.children)
            }
            // Confirm the ORIGINAL selected UIKit child, independently of the
            // requested SwiftUI tab. A retained hidden sibling cannot qualify.
            var child: UIViewController = self
            var parent = self.parent
            var foundOriginalTab = false
            while let current = parent {
                if let tabs = current as? UITabBarController {
                    guard let selected = tabs.selectedViewController,
                          Self.contains(child, in: selected),
                          selected.viewIfLoaded?.window === window else { return nil }
                    foundOriginalTab = true
                }
                if let navigation = current as? UINavigationController {
                    guard let selected = navigation.visibleViewController,
                          Self.contains(child, in: selected) else { return nil }
                }
                child = current; parent = current.parent
            }
            return foundOriginalTab ? window : nil
        }
        private static func contains(_ child: UIViewController, in owner: UIViewController) -> Bool {
            var current: UIViewController? = child
            while let actual = current {
                if actual === owner { return true }
                current = actual.parent
            }
            return false
        }
    }

    @MainActor private final class Marker: UIView {
        var windowDidChange: (@MainActor () -> Void)?
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear; isUserInteractionEnabled = false; isAccessibilityElement = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        override func didMoveToWindow() { super.didMoveToWindow(); windowDidChange?() }
    }
}
#endif
