#if os(iOS)
import SwiftUI
import UIKit
import OtzariaUIRouting

@MainActor enum MaktabahNativeAnnotationEditorGeometry {
    /// Read-only ownership, also usable before foreground activation. Actual
    /// receipt visibility remains the stricter original clipped-geometry check.
    static func ownsTopSheet(_ view: UIView, sceneID: UIStableID) -> Bool {
        guard let window = view.window,
              window.windowScene?.session.persistentIdentifier == sceneID.rawValue,
              let root = window.rootViewController, root.viewIfLoaded?.window === window else { return false }
        var top = root
        while let presented = top.presentedViewController {
            guard !top.isBeingPresented, !top.isBeingDismissed, top.transitionCoordinator == nil else { return false }
            top = presented
        }
        guard top !== root, !top.isBeingPresented, !top.isBeingDismissed,
              top.transitionCoordinator == nil, let original = top.viewIfLoaded else { return false }
        return view.isDescendant(of: original)
    }
}

/// These modifiers wrap the existing Form/controls only when the original List
/// forwards its exact scene-owned attachment. Other editor presenters are unchanged.
struct MaktabahNativeAnnotationEditorForm: ViewModifier {
    let attachment: MaktabahNativeAnnotationEditorControls.Attachment?
    let viewID: UUID
    let snapshot: @MainActor () -> MaktabahNativeAnnotationEditorControls.Snapshot
    let bodyTextView: @MainActor () -> UITextView?
    let focusTags: @MainActor () -> Void
    @ViewBuilder func body(content: Content) -> some View {
        if let attachment {
            let controls = attachment.controls
            let access = MaktabahNativeAnnotationEditorControls.Access(viewID: viewID,
                attachment: attachment, snapshot: snapshot, bodyTextView: bodyTextView)
            ScrollViewReader { scroll in
                content
                    .background { MaktabahNativeAnnotationEditorFormWitness(access: access) }
                    .modifier(MaktabahNativeComponentContainer(owner: controls.componentOwner,
                        blocked: { !attachment.parentCurrent() || snapshot().blocked },
                        viewID: viewID, layoutRevision: controls.layoutRevision,
                        componentAvailable: { _ in snapshot().initialized && snapshot().allowsPlainEditing },
                        revealPhase: { anchor, _ in
                            controls.reveal(anchor: anchor, viewID: viewID,
                                scroll: { scroll.scrollTo($0.rawValue, anchor: .center) }, focusTags: focusTags)
                        }))
            }
        } else { content }
    }
}

struct MaktabahNativeAnnotationEditorControl: ViewModifier {
    let attachment: MaktabahNativeAnnotationEditorControls.Attachment?
    let viewID: UUID
    let anchor: MaktabahNativeAnnotationEditorControls.Anchor
    var bodyTextView: @MainActor () -> UITextView? = { nil }
    @ViewBuilder func body(content: Content) -> some View {
        if let attachment {
            content.id(anchor.rawValue)
                .background {
                    MaktabahNativeAnnotationEditorControlWitness(controls: attachment.controls,
                        viewID: viewID, anchor: anchor, bodyTextView: bodyTextView)
                }
        } else { content }
    }
}

struct MaktabahNativeAnnotationEditorTagsFocus: ViewModifier {
    let enabled: Bool
    let focused: FocusState<Bool>.Binding
    @ViewBuilder func body(content: Content) -> some View {
        if enabled { content.focused(focused) } else { content }
    }
}

private struct MaktabahNativeAnnotationEditorFormWitness: UIViewRepresentable {
    let access: MaktabahNativeAnnotationEditorControls.Access
    func makeUIView(context: Context) -> MaktabahNativeAnnotationEditorMarker {
        .init(controls: access.attachment.controls, viewID: access.viewID, anchor: nil)
    }
    func updateUIView(_ view: MaktabahNativeAnnotationEditorMarker, context: Context) {
        guard view.matches(controls: access.attachment.controls, viewID: access.viewID, anchor: nil) else {
            view.detach(); return
        }
        view.access = access; view.register()
    }
    static func dismantleUIView(_ view: MaktabahNativeAnnotationEditorMarker, coordinator: ()) { view.detach() }
}

private struct MaktabahNativeAnnotationEditorControlWitness: UIViewRepresentable {
    let controls: MaktabahNativeAnnotationEditorControls
    let viewID: UUID
    let anchor: MaktabahNativeAnnotationEditorControls.Anchor
    let bodyTextView: @MainActor () -> UITextView?
    func makeUIView(context: Context) -> MaktabahNativeAnnotationEditorMarker {
        .init(controls: controls, viewID: viewID, anchor: anchor)
    }
    func updateUIView(_ view: MaktabahNativeAnnotationEditorMarker, context: Context) {
        guard view.matches(controls: controls, viewID: viewID, anchor: anchor) else { view.detach(); return }
        view.bodyTextView = bodyTextView; view.register()
    }
    static func dismantleUIView(_ view: MaktabahNativeAnnotationEditorMarker, coordinator: ()) { view.detach() }
}

/// A passive marker with an immutable original attachment. No global text-field
/// lookup, synthetic control or delayed callback may substitute another editor.
@MainActor private final class MaktabahNativeAnnotationEditorMarker: UIView {
    private struct Evidence: Equatable {
        let marker: MaktabahNativeSavedResultsGeometry.Evidence
        let field: ObjectIdentifier?
        let fieldGeometry: MaktabahNativeSavedResultsGeometry.Evidence?
        let firstResponder: Bool
    }
    let token = UUID()
    let viewID: UUID
    let anchor: MaktabahNativeAnnotationEditorControls.Anchor?
    weak var controls: MaktabahNativeAnnotationEditorControls?
    var access: MaktabahNativeAnnotationEditorControls.Access?
    var bodyTextView: @MainActor () -> UITextView? = { nil }
    private var active = true
    private var attachment = UUID()
    private var previous: Evidence?
    private weak var field: UIView?
    private var waitingCoordinator: ObjectIdentifier?

    init(controls: MaktabahNativeAnnotationEditorControls, viewID: UUID,
         anchor: MaktabahNativeAnnotationEditorControls.Anchor?) {
        self.controls = controls; self.viewID = viewID; self.anchor = anchor
        super.init(frame: .zero)
        backgroundColor = .clear; isUserInteractionEnabled = false; isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func matches(controls: MaktabahNativeAnnotationEditorControls, viewID: UUID,
                 anchor: MaktabahNativeAnnotationEditorControls.Anchor?) -> Bool {
        active && self.controls === controls && self.viewID == viewID && self.anchor == anchor
    }
    func register() {
        guard active, let controls, window != nil else { return }
        if let anchor {
            let actual: UIView?
            switch anchor {
            case .body: actual = bodyTextView()
            case .tags: actual = originalTagsField()
            case .style: actual = self
            }
            if field !== actual {
                NotificationCenter.default.removeObserver(self)
                field = actual
                if let actual, anchor != .style {
                    let begin = anchor == .body ? UITextView.textDidBeginEditingNotification : UITextField.textDidBeginEditingNotification
                    let end = anchor == .body ? UITextView.textDidEndEditingNotification : UITextField.textDidEndEditingNotification
                    NotificationCenter.default.addObserver(self, selector: #selector(editingChanged(_:)), name: begin, object: actual)
                    NotificationCenter.default.addObserver(self, selector: #selector(editingChanged(_:)), name: end, object: actual)
                }
            }
            controls.observeControl(viewID: viewID, anchor: anchor, token: token, marker: self, field: actual)
        } else if let access {
            controls.attach(access: access, token: token, view: self)
        }
        publishLayout()
    }
    func detach() {
        guard active else { return }
        active = false; attachment = UUID(); waitingCoordinator = nil
        removeRegistration(); NotificationCenter.default.removeObserver(self)
        controls = nil; access = nil; field = nil; bodyTextView = { nil }
    }
    private func removeRegistration() {
        if let anchor { controls?.removeControl(viewID: viewID, anchor: anchor, token: token) }
        else { controls?.detach(viewID: viewID, token: token, view: self) }
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            attachment = UUID(); waitingCoordinator = nil; previous = nil
            removeRegistration(); NotificationCenter.default.removeObserver(self); field = nil
        } else { register() }
    }
    override func didMoveToSuperview() { super.didMoveToSuperview(); register() }
    override func layoutSubviews() { super.layoutSubviews(); register() }
    @objc private func editingChanged(_ note: Notification) {
        guard active, let actual = note.object as? UIView, field === actual else { return }
        publishLayout()
    }
    private func publishLayout() {
        guard active, let controls else { return }
        let value = Evidence(marker: MaktabahNativeSavedResultsGeometry.evidence(self),
            field: field.map(ObjectIdentifier.init), fieldGeometry: field.map(MaktabahNativeSavedResultsGeometry.evidence),
            firstResponder: field?.isFirstResponder == true)
        if previous != value { previous = value; controls.originalLayoutDidChange(viewID: viewID) }
        guard active, self.controls === controls,
              let coordinator = MaktabahNativeSavedResultsGeometry.transitionCoordinator(self) else { return }
        let identity = ObjectIdentifier(coordinator as AnyObject)
        guard waitingCoordinator != identity else { return }
        waitingCoordinator = identity
        let originalAttachment = attachment
        _ = coordinator.animate(alongsideTransition: nil) { [weak self, weak controls] _ in
            guard let self, let controls, self.active, self.controls === controls,
                  self.attachment == originalAttachment, self.waitingCoordinator == identity else { return }
            self.waitingCoordinator = nil
            self.register()
        }
    }

    /// The ORIGINAL Tags TextField is inside this marker's original Form row.
    /// Public UIKit hierarchy and geometry must identify one actual field. A
    /// window-wide/AX-name search, guessed index or newly allocated field is forbidden.
    private func originalTagsField() -> UITextField? {
        guard let window, bounds.width > 1, bounds.height > 1 else { return nil }
        let target = convert(bounds, to: window)
        guard target.origin.x.isFinite, target.origin.y.isFinite,
              target.width.isFinite, target.height.isFinite else { return nil }
        var container = superview
        while let current = container {
            // Do not escape the original row into the collection's other rows.
            if current is UIScrollView { return nil }
            var stack = current.subviews
            var matches: [UITextField] = []
            while let view = stack.popLast() {
                if let field = view as? UITextField, field.window === window {
                    let rect = field.convert(field.bounds, to: window)
                    let overlap = rect.intersection(target)
                    if rect.width > 1, rect.height > 1, !overlap.isNull,
                       overlap.width * overlap.height >= min(rect.width * rect.height, target.width * target.height) * 0.98 {
                        matches.append(field)
                    }
                } else if !(view is UIScrollView) { stack.append(contentsOf: view.subviews) }
            }
            if !matches.isEmpty { return matches.count == 1 ? matches[0] : nil }
            container = current.superview
        }
        return nil
    }
}
#endif
