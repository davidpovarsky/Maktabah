#if os(iOS) && canImport(UIKit)
import SwiftUI
import UIKit

/// Optional owner-bound callbacks for the scene-owned iPad presentation.
/// Legacy phone callers keep the original binding/dismissal behavior.
@MainActor
struct ReaderOverviewPresentationLifecycle {
    let id: UUID
    let willPresent: () -> Bool
    let didPresent: () -> Void
    let didDismiss: () -> Void
    let didDismantle: () -> Void
}

/// The pinned browser presents its overview over the current browser context.
/// This context-sized anchor keeps the existing reader hierarchy in place;
/// it neither rehosts the reader nor writes its scroll/selection state.
struct ReaderOverviewPresentation<Overview: View>: View {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
    let lifecycle: ReaderOverviewPresentationLifecycle?
    let overview: Overview

    init(isPresented: Binding<Bool>, onDismiss: @escaping () -> Void = {},
         lifecycle: ReaderOverviewPresentationLifecycle? = nil,
         @ViewBuilder overview: () -> Overview) {
        _isPresented = isPresented
        self.onDismiss = onDismiss
        self.lifecycle = lifecycle
        self.overview = overview()
    }

    var body: some View {
        ReaderOverviewPresentationAnchor(isPresented: $isPresented, onDismiss: onDismiss,
                                         lifecycle: lifecycle, overview: overview)
            // A transparent representable still has a SwiftUI hosting layer.
            // The closed presentation must not intercept reader pan gestures.
            .allowsHitTesting(isPresented)
    }
}

private struct ReaderOverviewPresentationAnchor<Overview: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
    let lifecycle: ReaderOverviewPresentationLifecycle?
    let overview: Overview

    func makeUIViewController(context: Context) -> ReaderOverviewPresentationController {
        let controller = ReaderOverviewPresentationController()
        controller.loadViewIfNeeded()
        return controller
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: ReaderOverviewPresentationController,
                      context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height,
              width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
        // The clear UIKit anchor has no intrinsic content size. Its actual
        // view must accept the context proposal, not just its outer frame.
        return CGSize(width: width, height: height)
    }

    func updateUIViewController(_ controller: ReaderOverviewPresentationController, context: Context) {
        controller.configure(
            isPresented: isPresented,
            lifecycle: lifecycle,
            // A new hosting controller owns its own navigation/accessibility
            // graph. Forward only semantic public values, never the source
            // host's complete environment and private graph ownership.
            overview: AnyView(overview
                .environment(\.locale, context.environment.locale)
                .environment(\.layoutDirection, context.environment.layoutDirection)
                .environment(\.colorScheme, context.environment.colorScheme)
                .environment(\.dynamicTypeSize, context.environment.dynamicTypeSize)),
            onDismiss: {
                isPresented = false
                onDismiss()
            }
        )
    }

    static func dismantleUIViewController(_ controller: ReaderOverviewPresentationController, coordinator: ()) {
        controller.tearDownPresentation()
    }
}

final class ReaderOverviewPresentationController: UIViewController {
    private var wantsOverview = false
    private var overview = AnyView(EmptyView())
    private var onDismiss: (() -> Void)?
    private var lifecycle: ReaderOverviewPresentationLifecycle?
    private var activeLifecycle: ReaderOverviewPresentationLifecycle?
    private var activeOnDismiss: (() -> Void)?
    private var hostingController: UIHostingController<AnyView>?
    private weak var presentationContext: UIViewController?
    private var previousDefinesPresentationContext: Bool?
    private var isTransitioning = false
    private var updateScheduled = false

    override func loadView() {
        let anchor = UIView()
        anchor.backgroundColor = .clear
        anchor.isOpaque = false
        // SwiftUI excludes the closed wrapper from hit testing. When open,
        // UIKit's context must permit interaction with its presented content.
        view = anchor
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleUpdate()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        scheduleUpdate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scheduleUpdate()
    }

    func configure(isPresented: Bool, lifecycle: ReaderOverviewPresentationLifecycle? = nil,
                   overview: AnyView, onDismiss: @escaping () -> Void) {
        wantsOverview = isPresented
        self.overview = overview
        self.onDismiss = onDismiss
        self.lifecycle = lifecycle
        if activeLifecycle?.id == lifecycle?.id {
            hostingController?.rootView = overview
        }
        scheduleUpdate()
    }

    func tearDownPresentation() {
        wantsOverview = false
        onDismiss = nil
        overview = AnyView(EmptyView())
        let retired = activeLifecycle ?? lifecycle
        lifecycle = nil
        activeLifecycle = nil
        activeOnDismiss = nil
        if let controller = hostingController {
            // Retire this exact controller before its older dismissal callback
            // can touch a newer hosting controller or owner.
            hostingController = nil
            if controller.presentingViewController != nil {
                controller.dismiss(animated: false) { retired?.didDismantle() }
            } else {
                retired?.didDismantle()
            }
        } else {
            retired?.didDismantle()
        }
        restorePresentationContext()
    }

    private func scheduleUpdate() {
        guard !updateScheduled else { return }
        updateScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.updateScheduled = false
            self.updatePresentation()
        }
    }

    private func updatePresentation() {
        guard let view = viewIfLoaded, view.window != nil,
              view.bounds.width > 0, view.bounds.height > 0,
              !isTransitioning else { return }
        if let controller = hostingController,
           !wantsOverview || activeLifecycle?.id != lifecycle?.id {
            let completed = activeLifecycle
            let completedDismissal = activeOnDismiss
            isTransitioning = true
            controller.dismiss(animated: false) { [weak self, weak controller] in
                guard let self, let controller, self.hostingController === controller else { return }
                self.hostingController = nil
                self.activeLifecycle = nil
                self.activeOnDismiss = nil
                if self.lifecycle?.id == completed?.id { self.lifecycle = nil }
                self.restorePresentationContext()
                self.isTransitioning = false
                completedDismissal?()
                completed?.didDismiss()
                self.scheduleUpdate()
            }
        } else if wantsOverview, hostingController == nil {
            guard let context = parent, context.presentedViewController == nil else { return }
            if let lifecycle, !lifecycle.willPresent() { return }
            let controller = UIHostingController(rootView: overview)
            controller.modalPresentationStyle = .overCurrentContext
            controller.isModalInPresentation = true
            controller.view.backgroundColor = .systemBackground
            controller.view.accessibilityViewIsModal = true
            // Present from the actual reader host, not from the transparent
            // representable. Its platform-view subtree is not a separate
            // SwiftUI accessibility presentation context.
            presentationContext = context
            previousDefinesPresentationContext = context.definesPresentationContext
            context.definesPresentationContext = true
            activeLifecycle = lifecycle
            activeOnDismiss = onDismiss
            hostingController = controller
            isTransitioning = true
            // The browser's WebKit snapshot transition has no reader-domain
            // equivalent. Change the whole context without inventing motion.
            context.present(controller, animated: false) { [weak self, weak controller] in
                guard let self, let controller, self.hostingController === controller else { return }
                if let window = controller.viewIfLoaded?.window, window === self.viewIfLoaded?.window {
                    self.activeLifecycle?.didPresent()
                }
                self.isTransitioning = false
                self.scheduleUpdate()
            }
        } else if !wantsOverview, hostingController == nil, let cancelled = lifecycle {
            // A request can close before the anchor ever presents UIKit. This
            // callback still verifies the same original request identity.
            lifecycle = nil
            onDismiss?()
            cancelled.didDismiss()
        }
    }

    private func restorePresentationContext() {
        if let context = presentationContext, let previousDefinesPresentationContext {
            context.definesPresentationContext = previousDefinesPresentationContext
        }
        presentationContext = nil
        previousDefinesPresentationContext = nil
    }

    #if DEBUG
    /// Read-only native facts for the existing acceptance observer. No UI or
    /// production reporter is installed, and no reader state is changed.
    var acceptancePresentationSnapshot: [String: Any] {
        var ancestors: [[String: Any]] = []
        var current = hostingController?.viewIfLoaded
        for _ in 0..<8 {
            guard let view = current else { break }
            ancestors.append(["class": String(describing: type(of: view)),
                              "hidden": view.isHidden, "alpha": Double(view.alpha),
                              "accessibilityHidden": view.accessibilityElementsHidden,
                              "interactionEnabled": view.isUserInteractionEnabled])
            current = view.superview
        }
        return ["wantsOverview": wantsOverview,
         "isViewLoaded": isViewLoaded,
         "isInWindow": viewIfLoaded?.window != nil,
         "boundsWidth": Double(viewIfLoaded?.bounds.width ?? 0),
         "boundsHeight": Double(viewIfLoaded?.bounds.height ?? 0),
         "parentClass": parent.map { String(describing: type(of: $0)) } ?? "none",
         "presentedClass": presentationContext?.presentedViewController.map { String(describing: type(of: $0)) } ?? "none",
         "hasHostingController": hostingController != nil,
         "isTransitioning": isTransitioning,
         "presentedBoundsWidth": Double(hostingController?.viewIfLoaded?.bounds.width ?? 0),
         "presentedBoundsHeight": Double(hostingController?.viewIfLoaded?.bounds.height ?? 0),
         "presentedInWindow": hostingController?.viewIfLoaded?.window != nil,
         "presentedViewAncestors": ancestors]
    }
    #endif
}
#endif
