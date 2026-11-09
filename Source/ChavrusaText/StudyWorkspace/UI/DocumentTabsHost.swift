import SwiftUI

struct DocumentTabsHost: UIViewControllerRepresentable {
    let tabs: [iOSNavigationManager.ReaderTab]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onReorder: (UUID, Int) -> Void
    let backgroundColor: UIColor
    let inactiveBackgroundColor: UIColor
    let onOpenLibrary: () -> Void
    let onOverview: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> TabsBarViewController {
        let controller = TabsBarViewController(showsToolbarButtons: true)
        controller.delegate = context.coordinator
        controller.addTabButton.accessibilityIdentifier = "reader-open-book"
        controller.tabSwitcherButton.accessibilityIdentifier = "reader-tabs-overview"
        // Public native glass belongs to each actual source UIButton, with no
        // extra group backing. Keep the original controller's targets/geometry.
        if #available(iOS 26.0, *) {
            for button in [controller.addTabButton, controller.tabSwitcherButton] {
                var configuration = UIButton.Configuration.glass()
                configuration.image = button.image(for: .normal)
                configuration.contentInsets = .zero
                button.configuration = configuration
            }
        }
        return controller
    }
    func updateUIViewController(_ controller: TabsBarViewController, context: Context) {
        let coordinator = context.coordinator
        let oldIDs = coordinator.model.tabs.map(\.id)
        coordinator.parent = self
        let old = Dictionary(uniqueKeysWithValues: coordinator.model.tabs.map { ($0.id, $0) })
        coordinator.model.tabs = tabs.map { tab in
            let item = old[tab.id] ?? ReaderBookTabAdapter(id: tab.id, title: tab.book.book)
            item.title = tab.book.book
            return item
        }
        coordinator.model.selectedID = selectedID
        coordinator.model.onMove = onReorder
        controller.loadViewIfNeeded()
        controller.theme = ReaderTabsTheme(tabsBarBackgroundColor: inactiveBackgroundColor, omniBarBackgroundColor: backgroundColor)
        if oldIDs == tabs.map(\.id) {
            controller.refreshStyleInPlace(tabsModel: coordinator.model, scrollToSelected: true)
        } else {
            // A single reload owns membership changes, including 0→1 and N→0. No diffable
            // reconfiguration or asynchronous scroll uses an obsolete item snapshot.
            controller.refresh(tabsModel: coordinator.model, scrollToSelected: true)
        }
    }

    final class Coordinator: NSObject, TabsBarDelegate {
        var parent: DocumentTabsHost
        let model = ReaderBookTabsModel()
        init(_ parent: DocumentTabsHost) { self.parent = parent }
        func tabsBar(_ controller: TabsBarViewController, didSelectTabAtIndex index: Int) {
            if let tab = model.get(tabAt: index) { parent.onSelect(tab.id) }
        }
        func tabsBar(_ controller: TabsBarViewController, didRemoveTabAtIndex index: Int) {
            if let tab = model.get(tabAt: index) { parent.onClose(tab.id) }
        }
        func tabsBar(_ controller: TabsBarViewController, didRequestCloseOtherTabsForTabAtIndex index: Int) {
            guard let kept = model.get(tabAt: index) else { return }
            for tab in model.tabs where tab.id != kept.id { parent.onClose(tab.id) }
        }
        // Original source controls own their layout, hover/press and hit targets.
        func tabsBarDidRequestNewTab(_ controller: TabsBarViewController) { parent.onOpenLibrary() }
        func tabsBarDidRequestTabSwitcher(_ controller: TabsBarViewController) { parent.onOverview() }
    }
}
