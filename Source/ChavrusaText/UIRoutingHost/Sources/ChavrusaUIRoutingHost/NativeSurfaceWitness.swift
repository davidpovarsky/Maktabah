#if os(iOS)
import SwiftUI
import UIKit
import OtzariaUIRouting

/// Mount in the actual destination's background, with state read from that
/// destination's existing bindings/models. Not a root-level completion marker.
/// A layout callback is evidence only when the exact session is foreground and
/// the real surface occupies the window, with no unrelated modal above it.
public struct NativeSurfaceWitness: UIViewRepresentable {
    public struct Evidence: Sendable, Equatable {
        public let sceneID: UIStableID
        public let surface: NativeSurfaceState
        public let isVisible: Bool
        public let submissionID: UUID?
    }
    public let surface: NativeSurfaceState
    public let report: @MainActor (Evidence) -> Void
    public let submissionID: UUID?
    @Environment(\.scenePhase) private var scenePhase

    public init(surface: NativeSurfaceState, submissionID: UUID? = nil, report: @escaping @MainActor (Evidence) -> Void) {
        self.surface = surface; self.submissionID = submissionID; self.report = report
    }

    public func makeUIView(context: Context) -> MarkerView { MarkerView() }
    public func updateUIView(_ view: MarkerView, context: Context) {
        _ = scenePhase
        view.surface = surface; view.report = report; view.submissionID = submissionID
        view.setNeedsLayout()
    }
    public static func dismantleUIView(_ view: MarkerView, coordinator: ()) {
        view.publish(visible: false); view.report = nil; view.surface = nil
    }

    public final class MarkerView: UIView {
        fileprivate var surface: NativeSurfaceState?
        fileprivate var report: (@MainActor (Evidence) -> Void)?
        fileprivate var submissionID: UUID?
        private var previous: Evidence?
        private var lastScene: UIStableID?

        public override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false; isAccessibilityElement = false; backgroundColor = .clear
        }
        public required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        public override func didMoveToWindow() { super.didMoveToWindow(); setNeedsLayout(); if window == nil { publish(visible: false) } }
        public override func layoutSubviews() {
            super.layoutSubviews()
            guard let window, let scene = window.windowScene,
                  let id = UIStableID(rawValue: scene.session.persistentIdentifier) else { publish(visible: false); return }
            lastScene = id
            var visible = scene.activationState == .foregroundActive && !window.isHidden && window.alpha > 0
                && !bounds.isEmpty && convert(bounds, to: window).intersects(window.bounds)
            var current: UIView? = self
            while let view = current {
                visible = visible && !view.isHidden && view.alpha > 0
                current = view.superview
            }
            // Do not acknowledge a background destination under a native modal.
            var top = window.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            if let top, top !== window.rootViewController, !isDescendant(of: top.view) { visible = false }
            publish(visible: visible)
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
