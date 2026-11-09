#if os(iOS) && canImport(UIKit)
import SwiftUI
import UIKit

/// The pinned browser presents its overview over the current browser context.
/// This context-sized anchor keeps the existing reader hierarchy in place;
/// it neither rehosts the reader nor writes its scroll/selection state.
struct ReaderOverviewPresentation<Overview: View>: View {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
    let overview: Overview

    init(isPresented: Binding<Bool>, onDismiss: @escaping () -> Void = {},
         @ViewBuilder overview: () -> Overview) {
        _isPresented = isPresented
        self.onDismiss = onDismiss
        self.overview = overview()
    }

    var body: some View {
        ReaderOverviewPresentationAnchor(isPresented: $isPresented, onDismiss: onDismiss, overview: overview)
            // A transparent representable still has a SwiftUI hosting layer.
            // The closed presentation must not intercept reader pan gestures.
            .allowsHitTesting(isPresented)
    }
}

private struct ReaderOverviewPresentationAnchor<Overview: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
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
            overview: AnyView(overview.environment(\.self, context.environment)),
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
    private var hostingController: UIHostingController<AnyView>?
    private var isTransitioning = false
    private var updateScheduled = false

    override func loadView() {
        let anchor = UIView()
        anchor.backgroundColor = .clear
        anchor.isOpaque = false
        // SwiftUI excludes the closed wrapper from hit testing. When open,
        // UIKit's context must permit interaction with its presented content.
        view = anchor
        definesPresentationContext = true
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

    func configure(isPresented: Bool, overview: AnyView, onDismiss: @escaping () -> Void) {
        wantsOverview = isPresented
        self.overview = overview
        self.onDismiss = onDismiss
        hostingController?.rootView = overview
        scheduleUpdate()
    }

    func tearDownPresentation() {
        wantsOverview = false
        onDismiss = nil
        overview = AnyView(EmptyView())
        if hostingController != nil {
            dismiss(animated: false)
            hostingController = nil
        }
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
        if wantsOverview, hostingController == nil, presentedViewController == nil {
            let controller = UIHostingController(rootView: overview)
            controller.modalPresentationStyle = .overCurrentContext
            controller.isModalInPresentation = true
            controller.view.backgroundColor = .systemBackground
            controller.view.accessibilityViewIsModal = true
            hostingController = controller
            isTransitioning = true
            // The browser's WebKit snapshot transition has no reader-domain
            // equivalent. Change the whole context without inventing motion.
            present(controller, animated: false) { [weak self] in
                self?.isTransitioning = false
                self?.scheduleUpdate()
            }
        } else if !wantsOverview, hostingController != nil {
            isTransitioning = true
            dismiss(animated: false) { [weak self] in
                guard let self else { return }
                self.hostingController = nil
                self.isTransitioning = false
                self.onDismiss?()
                self.scheduleUpdate()
            }
        }
    }

    #if DEBUG
    /// Read-only native facts for the existing acceptance observer. No UI or
    /// production reporter is installed, and no reader state is changed.
    var acceptancePresentationSnapshot: [String: Any] {
        ["wantsOverview": wantsOverview,
         "isViewLoaded": isViewLoaded,
         "isInWindow": viewIfLoaded?.window != nil,
         "boundsWidth": Double(viewIfLoaded?.bounds.width ?? 0),
         "boundsHeight": Double(viewIfLoaded?.bounds.height ?? 0),
         "parentClass": parent.map { String(describing: type(of: $0)) } ?? "none",
         "presentedClass": presentedViewController.map { String(describing: type(of: $0)) } ?? "none",
         "hasHostingController": hostingController != nil,
         "isTransitioning": isTransitioning]
    }
    #endif
}
#endif
