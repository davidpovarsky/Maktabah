#if os(iOS)
import Foundation
import Combine
import SwiftUI
import UIKit
import OtzariaUIRouting
import ChavrusaUIRoutingHost

typealias MaktabahNativeComponentDescriptor = NativeComponentDescriptor
typealias MaktabahNativeComponentOwner = NativeComponentRevealOwner

/// Application lifetime bridge for the actual backend publisher and original
/// @Observable feature fields. The portable one-shot latch never changes a
/// coordinator, feature value, canonical route, grant or source generation.
@MainActor final class MaktabahNativeComponentSourceObservation {
    private let observation: NativeComponentSourceObservation
    private let coordinator: BackendCoordinator
    private let backend: BackendID
    private let generation: UInt64
    private let backendChanges: AnyCancellable

    init(read: @MainActor () -> Void) {
        let coordinator = BackendCoordinator.shared
        let observation = NativeComponentSourceObservation(read: read)
        self.coordinator = coordinator
        self.observation = observation
        backend = coordinator.activeBackendID
        generation = coordinator.generation
        backendChanges = coordinator.objectWillChange.sink { _ in
            observation.invalidate()
        }
    }

    func validate() throws {
        try observation.validate()
        guard BackendCoordinator.shared === coordinator, !coordinator.isTransitioning,
              coordinator.activeBackendID == backend, coordinator.generation == generation else {
            throw UIRouteError(.staleState, "native_component_backend_changed")
        }
    }
}

/// A passive view inside the real original control. UIKit computes clipping in
/// EVERY ancestor, key-window ownership, foreground, alpha, and modal coverage.
/// This marker is neither interactive nor an accessibility element.
struct MaktabahNativeComponentWitness: UIViewRepresentable {
    typealias Evidence = NativeComponentEvidence
    let anchor: UIDestinationID
    let owner: MaktabahNativeComponentOwner

    func makeUIView(context: Context) -> Marker { Marker(anchor: anchor, owner: owner) }
    func updateUIView(_ view: Marker, context: Context) { view.register(); view.setNeedsLayout() }
    static func dismantleUIView(_ view: Marker, coordinator: ()) {
        view.owner?.remove(anchor: view.anchor, token: view.token)
    }

    final class Marker: UIView {
        let anchor: UIDestinationID
        let token = UUID()
        weak var owner: MaktabahNativeComponentOwner?
        private var previous: Evidence?
        init(anchor: UIDestinationID, owner: MaktabahNativeComponentOwner) {
            self.anchor = anchor; self.owner = owner
            super.init(frame: .zero)
            isUserInteractionEnabled = false; isAccessibilityElement = false; backgroundColor = .clear
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        func register() {
            owner?.observe(anchor: anchor, token: token) { [weak self] in self?.evidence() }
        }
        override func didMoveToWindow() { super.didMoveToWindow(); register(); publish() }
        override func layoutSubviews() { super.layoutSubviews(); publish() }
        private func publish() {
            let actual = evidence()
            guard actual != previous else { return }
            previous = actual; owner?.geometryChanged()
        }
        func evidence() -> Evidence? {
            guard let window, let scene = window.windowScene,
                  let sceneID = UIStableID(rawValue: scene.session.persistentIdentifier) else { return nil }
            let rect = convert(bounds, to: window)
            let area = rect.width * rect.height
            var visibleRect = rect.intersection(window.bounds)
            var alpha: CGFloat = 1
            var visible = window.isKeyWindow && !window.isHidden
                && scene.activationState == .foregroundActive
                && !rect.isEmpty && area.isFinite && area > 0
            var ancestor: UIView? = self
            while let view = ancestor {
                visible = visible && !view.isHidden
                alpha *= view.alpha
                if view.clipsToBounds {
                    visibleRect = visibleRect.intersection(view.convert(view.bounds, to: window))
                }
                if let scroll = view as? UIScrollView {
                    // Respect adjusted safe-area/keyboard content insets as well
                    // as clipping; a row below that viewport is not revealed.
                    let viewport = scroll.bounds.inset(by: scroll.adjustedContentInset)
                    visibleRect = visibleRect.intersection(scroll.convert(viewport, to: window))
                    if scroll.isDragging || scroll.isDecelerating { visible = false }
                }
                ancestor = view.superview
            }
            visible = visible && alpha >= 0.95 && !visibleRect.isNull
                && visibleRect.width * visibleRect.height >= area * 0.98
            var top = window.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            if let top, top !== window.rootViewController, !isDescendant(of: top.view) { visible = false }
            if let top, top.isBeingPresented || top.isBeingDismissed || top.transitionCoordinator != nil { visible = false }
            return .init(anchor: anchor, sceneID: sceneID, isVisible: visible)
        }
    }
}

/// Downstream features use their original ScrollViewReader and ORIGINAL state
/// setters here. The destination is a fixed source declaration, not a URL string.
struct MaktabahNativeComponentContainer: ViewModifier {
    let owner: MaktabahNativeComponentOwner?
    let blocked: @MainActor () -> Bool
    let reveal: @MainActor (UIDestinationID) -> Void
    @State private var viewID = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear {
                owner?.attach(viewID: viewID, blocked: blocked)
                owner?.render(viewID: viewID, reveal: reveal)
            }
            .onChange(of: owner?.renderRevision) { _, _ in
                owner?.render(viewID: viewID, reveal: reveal)
            }
            .onDisappear { owner?.detach(viewID: viewID) }
    }
}
#endif
