#if os(iOS)
import SwiftUI
import UIKit
import OtzariaUIRouting

/// Mount in the actual destination's background, with state read from that
/// destination's existing bindings/models. Not a root-level completion marker.
/// A layout callback is evidence only when the exact session is foreground and
/// the real surface occupies the window, with no unrelated modal above it.
public struct NativeSurfaceWitness: UIViewControllerRepresentable {
    public struct Evidence: Sendable, Equatable {
        public let sceneID: UIStableID
        public let surface: NativeSurfaceState
        public let isVisible: Bool
        public let submissionID: UUID?
    }
    public let surface: NativeSurfaceState
    public let report: @MainActor (Evidence) -> Void
    public let observeVisibility: @MainActor (@escaping @MainActor () -> Evidence?) -> Void
    public let submissionID: UUID?
    public let diagnose: @MainActor (String) -> Void
    @Environment(\.scenePhase) private var scenePhase

    public init(surface: NativeSurfaceState, submissionID: UUID? = nil,
                observeVisibility: @escaping @MainActor (@escaping @MainActor () -> Evidence?) -> Void = { _ in },
                diagnose: @escaping @MainActor (String) -> Void = { _ in },
                report: @escaping @MainActor (Evidence) -> Void) {
        self.surface = surface; self.submissionID = submissionID; self.report = report
        self.observeVisibility = observeVisibility
        self.diagnose = diagnose
    }

    public func makeUIViewController(context: Context) -> MarkerController {
        #if DEBUG
        diagnose("lifecycle=make")
        #endif
        return MarkerController()
    }
    public func updateUIViewController(_ controller: MarkerController, context: Context) {
        _ = scenePhase
        let view = controller.marker
        view.surface = surface; view.report = report; view.submissionID = submissionID
        view.diagnose = diagnose
        observeVisibility { [weak view] in view?.currentEvidence() }
        #if DEBUG
        diagnose("lifecycle=update registered=1")
        #endif
        view.setNeedsLayout()
    }
    public static func dismantleUIViewController(_ controller: MarkerController, coordinator: ()) {
        let view = controller.marker
        view.hasAppeared = false
        view.publish(visible: false); view.report = nil; view.diagnose = nil; view.surface = nil
    }

    /// Native appearance completion is required: SwiftUI onAppear and a
    /// pre-animation layout are not evidence of a completed visible transition.
    public final class MarkerController: UIViewController {
        fileprivate let marker = MarkerView()
        public override func loadView() { view = marker }
        public override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            marker.hasAppeared = true; marker.setNeedsLayout()
        }
        public override func viewWillDisappear(_ animated: Bool) {
            marker.hasAppeared = false; marker.publish(visible: false)
            super.viewWillDisappear(animated)
        }
    }

    public final class MarkerView: UIView {
        fileprivate var surface: NativeSurfaceState?
        fileprivate var report: (@MainActor (Evidence) -> Void)?
        fileprivate var submissionID: UUID?
        private var previous: Evidence?
        private var lastScene: UIStableID?
        fileprivate var hasAppeared = false
        fileprivate var diagnose: (@MainActor (String) -> Void)?
        private var previousDiagnostic: String?

        public override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false; isAccessibilityElement = false; backgroundColor = .clear
        }
        public required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        public override func didMoveToWindow() { super.didMoveToWindow(); setNeedsLayout(); if window == nil { publish(visible: false) } }
        public override func layoutSubviews() {
            super.layoutSubviews()
            guard let evidence = currentEvidence() else { publish(visible: false); return }
            lastScene = evidence.sceneID
            publish(visible: evidence.isVisible)
        }
        /// Re-read actual UIKit state immediately at each scene observation.
        /// A previously visible layout is not proof after a modal/window change.
        fileprivate func currentEvidence() -> Evidence? {
            guard let window, let scene = window.windowScene,
                  let surface, let id = UIStableID(rawValue: scene.session.persistentIdentifier) else {
                diagnostic("attached=0 appeared=\(hasAppeared)"); return nil
            }
            let target = convert(bounds, to: window), intersection = target.intersection(window.bounds)
            let area = target.width * target.height
            var visible = hasAppeared && scene.activationState == .foregroundActive && !window.isHidden
                && !bounds.isEmpty && area.isFinite && area > 0 && !intersection.isNull
                && intersection.width * intersection.height >= area * 0.98
            var current: UIView? = self
            var effectiveAlpha: CGFloat = 1
            while let view = current {
                visible = visible && !view.isHidden
                effectiveAlpha *= view.alpha
                current = view.superview
            }
            visible = visible && effectiveAlpha >= 0.95
            // Do not acknowledge a background destination under a native modal.
            var top = window.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            if let top, top !== window.rootViewController, !isDescendant(of: top.view) { visible = false }
            diagnostic("attached=1 appeared=\(hasAppeared) activation=\(scene.activationState.rawValue) bounds=\(!bounds.isEmpty) contained=\(!intersection.isNull && intersection.width * intersection.height >= area * 0.98) alpha=\(effectiveAlpha >= 0.95) modal=\(top !== window.rootViewController) visible=\(visible) pending=\(submissionID != nil)")
            return Evidence(sceneID: id, surface: surface, isVisible: visible, submissionID: submissionID)
        }
        private func diagnostic(_ value: String) {
            guard value != previousDiagnostic else { return }
            previousDiagnostic = value; diagnose?(value)
        }
        fileprivate func publish(visible: Bool) {
            guard let surface, let id = lastScene else { return }
            let evidence = Evidence(sceneID: id, surface: surface, isVisible: visible, submissionID: submissionID)
            guard evidence != previous else { return }
            previous = evidence; report?(evidence)
        }
    }
}
#endif
