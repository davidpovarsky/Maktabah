#if os(iOS)
import SwiftUI
import UIKit
import OtzariaUIRouting
import ChavrusaUIRoutingHost

@MainActor struct MaktabahNativeHistoryRecordScope {
    let token: UUID
    weak var binding: MaktabahNativeHistoryRecordBinding?
    weak var model: HistoryViewModel?
}
private struct NativeHistoryRecordScopeKey: EnvironmentKey {
    static let defaultValue: MaktabahNativeHistoryRecordScope? = nil
}
private struct NativeHistoryScrollOwnerKey: EnvironmentKey {
    static let defaultValue: MaktabahNativeHistoryScrollOwner? = nil
}
extension EnvironmentValues {
    var nativeHistoryRecordScope: MaktabahNativeHistoryRecordScope? {
        get { self[NativeHistoryRecordScopeKey.self] }
        set { self[NativeHistoryRecordScopeKey.self] = newValue }
    }
    var nativeHistoryScrollOwner: MaktabahNativeHistoryScrollOwner? {
        get { self[NativeHistoryScrollOwnerKey.self] }
        set { self[NativeHistoryScrollOwnerKey.self] = newValue }
    }
}

/// Forward only the actual original horizontal UIScrollView and its existing
/// coordinator's scroll-state setter. No global view lookup or coordinate tap.
@MainActor final class MaktabahNativeHistoryScrollOwner {
    private weak var scrollView: UIScrollView?
    private weak var contentView: UIView?
    private var apply: (@MainActor (CGRect) -> Void)?

    func attach(scrollView: UIScrollView, contentView: UIView,
                reveal: @escaping @MainActor (CGRect) -> Void) {
        self.scrollView = scrollView; self.contentView = contentView; apply = reveal
    }
    func detach(_ view: UIScrollView) {
        guard scrollView === view else { return }
        scrollView = nil; contentView = nil; apply = nil
    }
    func canReveal(_ row: UIView, in sceneID: UIStableID) -> Bool {
        guard let scrollView, let contentView, let window = scrollView.window,
              row.window === window, row.isDescendant(of: contentView),
              window.windowScene?.session.persistentIdentifier == sceneID.rawValue,
              window.windowScene?.activationState == .foregroundActive,
              !scrollView.isDragging, !scrollView.isDecelerating,
              scrollView.bounds.width > 1, row.bounds.width > 1, row.bounds.height > 1,
              scrollView.contentSize.width.isFinite, scrollView.contentSize.width > 1,
              apply != nil else { return false }
        let rect = row.convert(row.bounds, to: scrollView)
        return !rect.isEmpty && rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.width.isFinite && rect.height.isFinite
    }
    func reveal(_ row: UIView, in sceneID: UIStableID) throws {
        guard canReveal(row, in: sceneID), let scrollView, let apply else {
            throw UIRouteError(.unavailable, "native_history_original_scroll_unavailable")
        }
        apply(row.convert(row.bounds, to: scrollView))
        guard self.scrollView === scrollView, canReveal(row, in: sceneID) else {
            throw UIRouteError(.staleState, "native_history_original_scroll_replaced")
        }
    }
}

/// Preserve each original Binding transaction while retiring a retained route
/// before a local popover/deletion State write, including equal-value or ABA.
@MainActor enum MaktabahNativeHistoryRecordState {
    static func binding<Value>(_ original: Binding<Value>, scope: MaktabahNativeHistoryRecordScope?) -> Binding<Value> {
        Binding(get: { original.wrappedValue }, set: { value, transaction in
            if let scope { scope.binding?.originalStateWillChange(root: scope.token) }
            original.transaction(transaction).wrappedValue = value
        })
    }
}

struct MaktabahNativeHistoryRecordContainer: ViewModifier {
    let model: HistoryViewModel
    let proxy: ScrollViewProxy
    @Environment(\.maktabahNativeRoutingSession) private var session
    @State private var ownerID = UUID()
    func body(content: Content) -> some View {
        let binding = session?.historyRecordBinding
        let scope = MaktabahNativeHistoryRecordScope(token: ownerID, binding: binding, model: model)
        content
            .environment(\.nativeHistoryRecordScope, scope)
            .background(MaktabahNativeHistoryRootMarker(scope: scope) { book, kind in
                if kind == .history {
                    proxy.scrollTo(MaktabahNativeHistoryRecords.originalGridID, anchor: .center)
                } else {
                    // FavoritesSection's ORIGINAL ForEach owns this numeric
                    // row ID; publication provenance refuses collisions.
                    proxy.scrollTo(book.id, anchor: .center)
                }
            })
    }
}

private struct MaktabahNativeHistoryRootMarker: UIViewRepresentable {
    let scope: MaktabahNativeHistoryRecordScope
    let reveal: @MainActor (BooksData, NativeHistoryRecordIntentService.Kind) -> Void
    func makeUIView(context: Context) -> Marker { Marker(frame: .zero) }
    func updateUIView(_ view: Marker, context: Context) { view.update(scope: scope, reveal: reveal) }
    static func dismantleUIView(_ view: Marker, coordinator: ()) { view.detach() }
    @MainActor final class Marker: UIView {
        private var scope: MaktabahNativeHistoryRecordScope?
        private var reveal: (@MainActor (BooksData, NativeHistoryRecordIntentService.Kind) -> Void)?
        private weak var attachedWindow: UIWindow?
        private var attached = false
        private var lastBounds = CGRect.null
        override init(frame: CGRect) {
            super.init(frame: frame); isUserInteractionEnabled = false; isAccessibilityElement = false
        }
        required init?(coder: NSCoder) { nil }
        func update(scope: MaktabahNativeHistoryRecordScope,
                    reveal: @escaping @MainActor (BooksData, NativeHistoryRecordIntentService.Kind) -> Void) {
            if let old = self.scope, old.token != scope.token || old.binding !== scope.binding || old.model !== scope.model {
                detach()
            }
            self.scope = scope; self.reveal = reveal
            attachIfReady()
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if attached, attachedWindow !== window { detach() }
            attachIfReady()
        }
        override func layoutSubviews() {
            super.layoutSubviews(); attachIfReady()
            if bounds != lastBounds { lastBounds = bounds; scope?.binding?.renderOriginalContainer() }
        }
        private func attachIfReady() {
            guard let window, let scope, let model = scope.model, let reveal else { return }
            // A detach retires the old request even if SwiftUI later reuses
            // this same state owner and native view.
            attachedWindow = window; attached = true
            scope.binding?.attachRoot(token: scope.token, view: self, model: model, reveal: reveal)
        }
        func detach() {
            if attached, let scope { scope.binding?.detachRoot(token: scope.token, view: self) }
            attached = false; attachedWindow = nil; lastBounds = .null
        }
    }
}

struct MaktabahNativeHistoryRecordWitness: UIViewRepresentable {
    let scope: MaktabahNativeHistoryRecordScope?
    let kind: NativeHistoryRecordIntentService.Kind
    let book: BooksData
    let scroll: MaktabahNativeHistoryScrollOwner?
    let blocked: Bool
    func makeUIView(context: Context) -> Marker { Marker(frame: .zero) }
    func updateUIView(_ view: Marker, context: Context) {
        view.update(scope: scope, kind: kind, book: book, scroll: scroll, blocked: blocked)
    }
    static func dismantleUIView(_ view: Marker, coordinator: ()) { view.detach() }
    @MainActor final class Marker: UIView {
        private var scope: MaktabahNativeHistoryRecordScope?
        private var kind: NativeHistoryRecordIntentService.Kind = .history
        private weak var book: BooksData?
        private weak var scroll: MaktabahNativeHistoryScrollOwner?
        private var blocked = false
        private var token = UUID()
        private var attached = false
        private weak var attachedWindow: UIWindow?
        private var lastGeometry: CGRect?
        override init(frame: CGRect) {
            super.init(frame: frame); isUserInteractionEnabled = false; isAccessibilityElement = false
        }
        required init?(coder: NSCoder) { nil }
        func update(scope: MaktabahNativeHistoryRecordScope?, kind: NativeHistoryRecordIntentService.Kind,
                    book: BooksData, scroll: MaktabahNativeHistoryScrollOwner?, blocked: Bool) {
            if self.scope?.token != scope?.token || self.scope?.binding !== scope?.binding
                || self.book !== book || self.kind != kind { detach() }
            self.scope = scope; self.kind = kind; self.book = book; self.scroll = scroll; self.blocked = blocked
            observe()
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if attached, attachedWindow !== window { detach() }
            observe()
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            guard let window else { return }
            let geometry = convert(bounds, to: window)
            if geometry != lastGeometry { lastGeometry = geometry; observe() }
        }
        private func observe() {
            guard let window, let scope, let book else { return }
            if !attached { token = UUID(); attached = true; attachedWindow = window }
            scope.binding?.observeRow(token: token, root: scope.token, kind: kind, book: book,
                view: self, scroll: scroll, blocked: blocked)
        }
        func detach() {
            if attached, let book { scope?.binding?.detachRow(token: token, kind: kind, book: book) }
            attached = false; attachedWindow = nil; lastGeometry = nil; token = UUID()
        }
    }
}

/// Passive evidence on the ORIGINAL BookCard background. A routing request,
/// scroll request, model object or root-only marker cannot satisfy this check.
@MainActor enum MaktabahNativeHistoryRecordGeometry {
    static func isVisible(_ view: UIView, sceneID: UIStableID) -> Bool {
        guard let window = view.window, window.isKeyWindow, !window.isHidden,
              window.windowScene?.session.persistentIdentifier == sceneID.rawValue,
              window.windowScene?.activationState == .foregroundActive,
              view.bounds.width > 1, view.bounds.height > 1 else { return false }
        let rect = view.convert(view.bounds, to: window)
        guard rect.origin.x.isFinite, rect.origin.y.isFinite, rect.width.isFinite, rect.height.isFinite else { return false }
        var visible = rect.intersection(window.bounds)
        var alpha: CGFloat = 1
        var current: UIView? = view
        while let node = current {
            guard !node.isHidden else { return false }
            alpha *= node.alpha
            if node.clipsToBounds { visible = visible.intersection(node.convert(node.bounds, to: window)) }
            if let scroll = node as? UIScrollView {
                guard !scroll.isDragging, !scroll.isDecelerating else { return false }
                visible = visible.intersection(scroll.convert(scroll.bounds.inset(by: scroll.adjustedContentInset), to: window))
            }
            current = node.superview
        }
        guard alpha >= 0.95, !visible.isNull,
              visible.width * visible.height >= rect.width * rect.height * 0.98,
              let root = window.rootViewController, root.viewIfLoaded?.window === window else { return false }
        var controllers = [root]
        while let controller = controllers.popLast() {
            guard controller.presentedViewController == nil, !controller.isBeingPresented,
                  !controller.isBeingDismissed, controller.transitionCoordinator == nil else { return false }
            controllers.append(contentsOf: controller.children)
        }
        return true
    }
}
#endif
