#if os(iOS)
import SwiftUI
import UIKit
import OtzariaUIRouting

/// Passive markers inside the ORIGINAL sheet/list/row. A scroll proxy is the
/// original List's own proxy; no marker creates, replaces or activates a row.
struct MaktabahNativeSavedResultsSheetWitness: View {
    let binding: MaktabahNativeSavedResultsBinding
    let access: MaktabahNativeSavedResultsBinding.SheetAccess
    var body: some View {
        let marker = MaktabahNativeSavedResultsWitness(binding: binding, owner: access.token,
            role: .sheet, model: access.model, access: access, reveal: nil)
        marker.id(marker.identity)
    }
}

struct MaktabahNativeSavedResultsPageWitness: View {
    let binding: MaktabahNativeSavedResultsBinding
    let owner: UUID
    let folder: FolderNode?
    let reveal: @MainActor (MaktabahNativeSavedResultsBinding.ScrollKey) -> Void
    var body: some View {
        let marker = MaktabahNativeSavedResultsWitness(binding: binding, owner: owner,
            role: .page(folder), model: nil, access: nil, reveal: reveal)
        marker.id(marker.identity)
    }
}

struct MaktabahNativeSavedResultsRowWitness: View {
    let binding: MaktabahNativeSavedResultsBinding
    let owner: UUID
    let folder: FolderNode?
    let node: MaktabahNativeSavedResultsSource.Node
    var body: some View {
        let marker = MaktabahNativeSavedResultsWitness(binding: binding, owner: owner,
            role: .row(folder, node), model: nil, access: nil, reveal: nil)
        marker.id(marker.identity)
    }
}

private struct MaktabahNativeSavedResultsWitness: UIViewRepresentable {
    struct Identity: Hashable {
        let binding: ObjectIdentifier
        let owner: UUID
        let role: MaktabahNativeSavedResultsMarker.Role.Identity
        let model: ObjectIdentifier?
    }
    let binding: MaktabahNativeSavedResultsBinding
    let owner: UUID
    let role: MaktabahNativeSavedResultsMarker.Role
    let model: ResultsViewModel?
    let access: MaktabahNativeSavedResultsBinding.SheetAccess?
    let reveal: (@MainActor (MaktabahNativeSavedResultsBinding.ScrollKey) -> Void)?
    var identity: Identity {
        .init(binding: ObjectIdentifier(binding), owner: owner, role: role.identity,
            model: model.map(ObjectIdentifier.init))
    }
    func makeUIView(context: Context) -> MaktabahNativeSavedResultsMarker {
        .init(binding: binding, owner: owner, role: role, model: model)
    }
    func updateUIView(_ view: MaktabahNativeSavedResultsMarker, context: Context) {
        guard view.matches(binding: binding, owner: owner, role: role, model: model) else { view.detach(); return }
        view.access = access; view.reveal = reveal
        view.register()
    }
    static func dismantleUIView(_ view: MaktabahNativeSavedResultsMarker, coordinator: ()) { view.detach() }
}

@MainActor final class MaktabahNativeSavedResultsMarker: UIView {
    enum Role {
        case sheet
        case page(FolderNode?)
        case row(FolderNode?, MaktabahNativeSavedResultsSource.Node)
        struct Identity: Hashable {
            let kind: Int
            let page: ObjectIdentifier?
            let row: MaktabahNativeSavedResultsBinding.RowKey?
        }
        var identity: Identity {
            switch self {
            case .sheet: return Identity(kind: 0, page: nil, row: nil)
            case .page(let folder): return Identity(kind: 1, page: folder.map(ObjectIdentifier.init), row: nil)
            case .row(let folder, let node):
                return Identity(kind: 2, page: folder.map(ObjectIdentifier.init),
                    row: MaktabahNativeSavedResultsBinding.RowKey(node))
            }
        }
    }
    let token = UUID()
    let owner: UUID
    let role: Role
    weak var binding: MaktabahNativeSavedResultsBinding?
    weak var model: ResultsViewModel?
    var access: MaktabahNativeSavedResultsBinding.SheetAccess?
    var reveal: (@MainActor (MaktabahNativeSavedResultsBinding.ScrollKey) -> Void)?
    private var active = true
    private var previous: MaktabahNativeSavedResultsGeometry.Evidence?
    private var waitingCoordinator: ObjectIdentifier?
    private var attachment = UUID()

    init(binding: MaktabahNativeSavedResultsBinding, owner: UUID, role: Role, model: ResultsViewModel? = nil) {
        self.binding = binding; self.owner = owner; self.role = role; self.model = model
        super.init(frame: .zero)
        backgroundColor = .clear; isUserInteractionEnabled = false; isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func matches(binding: MaktabahNativeSavedResultsBinding, owner: UUID, role: Role,
                 model: ResultsViewModel? = nil) -> Bool {
        active && self.binding === binding && self.owner == owner
            && self.role.identity == role.identity && self.model === model
    }
    func register() {
        guard active, let binding, window != nil else { return }
        switch role {
        case .sheet:
            guard let access, access.model === model else { return }
            binding.attachSheet(access: access, view: self)
        case .page(let folder):
            guard let reveal else { return }
            binding.attachPage(token: token, sheet: owner, folder: folder, view: self, reveal: reveal)
        case .row(let folder, let node):
            binding.attachRow(token: token, sheet: owner, page: folder, node: node, view: self)
        }
        publishLayout()
    }
    func detach() {
        guard active else { return }
        active = false
        attachment = UUID()
        removeRegistration()
        binding = nil; access = nil; reveal = nil; waitingCoordinator = nil
    }
    private func removeRegistration() {
        switch role {
        case .sheet: binding?.detachSheet(owner: owner, view: self)
        case .page(let folder): binding?.detachPage(token: token, sheet: owner, folder: folder, view: self)
        case .row(_, let node): binding?.detachRow(token: token, node: node, view: self)
        }
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            // Preserve the actual marker identity for SwiftUI's possible
            // reattachment, but retire any captured request immediately.
            attachment = UUID(); waitingCoordinator = nil
            removeRegistration(); previous = nil
        } else { register() }
    }
    override func didMoveToSuperview() { super.didMoveToSuperview(); register() }
    override func layoutSubviews() { super.layoutSubviews(); register() }
    private func publishLayout() {
        guard active, let binding else { return }
        let actual = MaktabahNativeSavedResultsGeometry.evidence(self)
        if actual != previous { previous = actual; binding.originalLayoutDidChange() }
        // A real UIKit completion can publish newly stable geometry. Bind the
        // callback to the EXACT attachment; no callback may transfer to a new
        // binding after replacement, detach or A -> B -> A.
        guard let coordinator = MaktabahNativeSavedResultsGeometry.transitionCoordinator(self) else {
            waitingCoordinator = nil; return
        }
        let identity = ObjectIdentifier(coordinator as AnyObject)
        guard waitingCoordinator != identity else { return }
        waitingCoordinator = identity
        let originalAttachment = attachment
        coordinator.animate(alongsideTransition: nil) { [weak self, weak binding] _ in
            guard let self, let binding, self.active, self.binding === binding,
                  self.attachment == originalAttachment,
                  self.waitingCoordinator == identity else { return }
            self.publishLayout()
        }
    }
}

@MainActor enum MaktabahNativeSavedResultsGeometry {
    struct Evidence: Equatable {
        let window: ObjectIdentifier?
        let frame: CGRect
        let visible: CGRect
        let alpha: CGFloat
        let hidden: Bool
        let transitioning: Bool
        let foreground: Bool
    }
    static func evidence(_ view: UIView) -> Evidence {
        let window = view.window
        let rect = window.map { view.convert(view.bounds, to: $0) } ?? .null
        var visible = window.map { rect.intersection($0.bounds) } ?? .null
        var alpha: CGFloat = 1, hidden = false
        var current: UIView? = view
        while let node = current {
            hidden = hidden || node.isHidden; alpha *= node.alpha
            if let window, node.clipsToBounds { visible = visible.intersection(node.convert(node.bounds, to: window)) }
            if let scroll = node as? UIScrollView, let window {
                hidden = hidden || scroll.isDragging || scroll.isDecelerating
                visible = visible.intersection(scroll.convert(scroll.bounds.inset(by: scroll.adjustedContentInset), to: window))
            }
            current = node.superview
        }
        return Evidence(window: window.map(ObjectIdentifier.init), frame: rect, visible: visible,
            alpha: alpha, hidden: hidden, transitioning: transitionCoordinator(view) != nil,
            foreground: window?.isKeyWindow == true && window?.isHidden == false
                && window?.windowScene?.activationState == .foregroundActive)
    }
    static func transitionCoordinator(_ view: UIView) -> UIViewControllerTransitionCoordinator? {
        var responder: UIResponder? = view
        while let current = responder {
            if let controller = current as? UIViewController, let transition = controller.transitionCoordinator { return transition }
            responder = current.next
        }
        return nil
    }
    static func isVisible(_ view: UIView, in sheet: UIView, window: UIWindow, sceneID: UIStableID) -> Bool {
        guard view.window === window, sheet.window === window,
              window.windowScene?.session.persistentIdentifier == sceneID.rawValue,
              let root = window.rootViewController, root.viewIfLoaded?.window === window else { return false }
        let value = evidence(view)
        guard value.foreground, !value.hidden, !value.transitioning, value.alpha >= 0.95,
              value.frame.origin.x.isFinite, value.frame.origin.y.isFinite,
              value.frame.width.isFinite, value.frame.height.isFinite,
              value.frame.width > 1, value.frame.height > 1, !value.visible.isNull,
              value.visible.width * value.visible.height >= value.frame.width * value.frame.height * 0.98 else { return false }
        var controllers = [root], visited: Set<ObjectIdentifier> = [], originalSheetFound = false
        while let controller = controllers.popLast() {
            guard visited.insert(ObjectIdentifier(controller)).inserted else { continue }
            guard !controller.isBeingPresented, !controller.isBeingDismissed,
                  controller.transitionCoordinator == nil else { return false }
            if let presented = controller.presentedViewController {
                guard let presentedView = presented.viewIfLoaded,
                      sheet.isDescendant(of: presentedView), view.isDescendant(of: presentedView) else { return false }
                originalSheetFound = true; controllers.append(presented)
            }
            controllers.append(contentsOf: controller.children)
        }
        return originalSheetFound
    }
}
#endif
