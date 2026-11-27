#if os(iOS)
import Foundation
import SwiftUI
import UIKit
import OtzariaUIRouting

@MainActor enum MaktabahNativeWorkspaceComponents {
    typealias Parent = MaktabahNativeWorkspacePresentationBinding.Parent

    enum Profiles: String, CaseIterable {
        case list = "native.workspace.profiles.list"
        case groups = "native.workspace.profiles.groups"
        case newProfile = "native.workspace.profiles.newProfile"
        var id: UIDestinationID { UIDestinationID(rawValue: rawValue)! }
        var title: String {
            let text = StudyWorkspaceText(locale: .current)
            switch self {
            case .list: return text("Study Profiles", "פרופילי לימוד")
            case .groups: return text("Manage Tab Groups", "ניהול קבוצות כרטיסיות")
            case .newProfile: return text("New Study Profile", "פרופיל לימוד חדש")
            }
        }
    }

    enum Overview: String, CaseIterable {
        case groups = "native.workspace.overview.groups"
        case grid = "native.workspace.overview.grid"
        case list = "native.workspace.overview.list"
        case layout = "native.workspace.overview.layout"
        case actions = "native.workspace.overview.actions"
        case profileMenu = "native.workspace.overview.profileMenu"
        var id: UIDestinationID { UIDestinationID(rawValue: rawValue)! }
        var title: String {
            let text = StudyWorkspaceText(locale: .current)
            switch self {
            case .groups: return text("Tab Groups", "קבוצות כרטיסיות")
            case .grid: return text("Grid view", "תצוגת רשת")
            case .list: return text("List view", "תצוגת רשימה")
            case .layout: return text("Tab layout", "תצוגת כרטיסיות")
            case .actions: return text("Tab group actions", "פעולות בקבוצת הכרטיסיות")
            case .profileMenu: return text("Study Profiles menu", "תפריט פרופילי לימוד")
            }
        }
    }

    static func makeOwners(binding: MaktabahNativeWorkspacePresentationBinding) -> [MaktabahNativeComponentOwner] {
        let profiles = MaktabahNativeComponentOwner(
            destination: Parent.profiles.destination, presentation: .sheet,
            descriptors: Profiles.allCases.map { .init(anchor: $0.id, title: $0.title) },
            available: { [weak binding] id in
                Profiles(rawValue: id.rawValue) != nil && binding?.isAvailable(parent: .profiles) == true
            }, captureSource: { [weak binding] id in
                guard let binding, Profiles(rawValue: id.rawValue) != nil else {
                    throw UIRouteError(.unavailable, "native_workspace_profile_component_unavailable")
                }
                return try binding.captureComponentSource(parent: .profiles, anchor: id)
            })
        let overview = MaktabahNativeComponentOwner(
            destination: Parent.overview.destination, presentation: .sheet,
            descriptors: Overview.allCases.map { .init(anchor: $0.id, title: $0.title) },
            available: { [weak binding] id in
                guard let binding, let anchor = Overview(rawValue: id.rawValue) else { return false }
                return overviewAvailable(anchor, binding: binding)
            }, captureSource: { [weak binding] id in
                guard let binding, let anchor = Overview(rawValue: id.rawValue),
                      overviewAvailable(anchor, binding: binding) else {
                    throw UIRouteError(.unavailable, "native_workspace_overview_component_unavailable")
                }
                let validate = try binding.captureComponentSource(parent: .overview, anchor: id)
                return { [weak binding] in
                    try validate()
                    guard let binding, overviewAvailable(anchor, binding: binding) else {
                        throw UIRouteError(.staleState, "native_workspace_overview_component_changed")
                    }
                }
            })
        return [profiles, overview]
    }

    private static func overviewAvailable(_ anchor: Overview,
                                           binding: MaktabahNativeWorkspacePresentationBinding) -> Bool {
        guard binding.isAvailable(parent: .overview) else { return false }
        switch anchor {
        case .grid: return binding.hasOriginalTabs && binding.originalOverviewLayout == .grid
        case .list: return binding.hasOriginalTabs && binding.originalOverviewLayout == .list
        case .profileMenu: return !MaktabahApp.isIpad
        case .groups, .layout, .actions: return true
        }
    }
}

struct MaktabahNativeWorkspaceComponentMarker: ViewModifier {
    let parent: MaktabahNativeWorkspacePresentationBinding.Parent
    let anchor: UIDestinationID
    let workspace: StudyWorkspaceNavigationAdapter
    let manager: iOSNavigationManager
    @Environment(\.maktabahNativeRoutingSession) private var session

    func body(content: Content) -> some View {
        content.background {
            if session?.workspacePresentation?.owns(workspace, manager: manager) == true,
               let owner = session?.componentOwner(for: parent.destination) {
                MaktabahNativeComponentWitness(anchor: anchor, owner: owner)
                    .id(anchor.rawValue)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func maktabahWorkspaceProfilesComponent(_ anchor: MaktabahNativeWorkspaceComponents.Profiles,
                                            workspace: StudyWorkspaceNavigationAdapter,
                                            manager: iOSNavigationManager) -> some View {
        id(anchor.id.rawValue).modifier(MaktabahNativeWorkspaceComponentMarker(
            parent: .profiles, anchor: anchor.id, workspace: workspace, manager: manager))
    }
    func maktabahWorkspaceOverviewComponent(_ anchor: MaktabahNativeWorkspaceComponents.Overview,
                                            workspace: StudyWorkspaceNavigationAdapter,
                                            manager: iOSNavigationManager) -> some View {
        modifier(MaktabahNativeWorkspaceComponentMarker(parent: .overview, anchor: anchor.id,
                                                        workspace: workspace, manager: manager))
    }
}

/// A real original page appearance/geometry publication for bounded reveal.
/// No requested route increments it, and this witness never forces a layout.
struct MaktabahNativeWorkspacePageLayoutWitness: UIViewControllerRepresentable {
    let page: String
    let ownerToken: UUID
    let sceneID: String
    let publish: @MainActor (String, UUID) -> Void

    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.page = page; controller.ownerToken = ownerToken
        controller.sceneID = sceneID; controller.publish = publish
    }
    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) { controller.publish = nil }

    final class Controller: UIViewController {
        var page = ""
        var ownerToken: UUID?
        var sceneID = ""
        var publish: (@MainActor (String, UUID) -> Void)?
        private var appeared = false
        private var appearance: UInt64 = 0
        private struct Layout: Equatable {
            let window: ObjectIdentifier
            let parent: ObjectIdentifier?
            let rect: CGRect
            let appearance: UInt64
        }
        private var previous: Layout?

        override func loadView() {
            view = UIView(); view.backgroundColor = .clear
            view.isUserInteractionEnabled = false; view.isAccessibilityElement = false
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated); appeared = true; appearance &+= 1; publishOriginalLayout()
        }
        override func viewWillDisappear(_ animated: Bool) {
            appeared = false; super.viewWillDisappear(animated)
        }
        override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); publishOriginalLayout() }
        private func publishOriginalLayout() {
            guard appeared, let ownerToken, let view = viewIfLoaded, let window = view.window,
                  window.isKeyWindow, !window.isHidden,
                  let scene = window.windowScene, scene.session.persistentIdentifier == sceneID,
                  scene.activationState == .foregroundActive else { return }
            let rect = view.convert(view.bounds, to: window)
            let area = rect.width * rect.height
            guard area.isFinite, area > 0 else { return }
            var clipped = rect.intersection(window.bounds), alpha: CGFloat = 1
            var ancestor: UIView? = view
            while let current = ancestor {
                guard !current.isHidden else { return }
                alpha *= current.alpha
                if current.clipsToBounds { clipped = clipped.intersection(current.convert(current.bounds, to: window)) }
                ancestor = current.superview
            }
            guard alpha >= 0.95, !clipped.isNull, clipped.width * clipped.height >= area * 0.98 else { return }
            var top = window.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            if let top, top !== window.rootViewController, !view.isDescendant(of: top.view) { return }
            var controller: UIViewController? = self
            while let current = controller {
                guard !current.isBeingPresented, !current.isBeingDismissed,
                      current.transitionCoordinator == nil else { return }
                controller = current.parent
            }
            if let top {
                guard !top.isBeingPresented, !top.isBeingDismissed,
                      top.transitionCoordinator == nil else { return }
            }
            let actual = Layout(window: ObjectIdentifier(window), parent: parent.map(ObjectIdentifier.init),
                                rect: rect, appearance: appearance)
            guard actual != previous else { return }
            previous = actual
            publish?(page, ownerToken)
        }
    }
}
#endif
