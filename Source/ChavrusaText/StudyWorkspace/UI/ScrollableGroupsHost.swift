import SwiftUI

/// Original ScrollableTabBar membership contract with its original public AdaptiveTabContent.
struct ScrollableGroupsHost: UIViewRepresentable {
    let groups: [StudyTabGroup]
    let selectedID: UUID?
    var isEnabled = true
    let onSelect: (UUID) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onSelect) }
    func makeUIView(context: Context) -> ScrollableTabBar<UUID> {
        let bar = ScrollableTabBar<UUID>()
        bar.delegate = context.coordinator
        bar.accessibilityLabel = "קבוצות כרטיסיות"
        bar.accessibilityIdentifier = "study-group-selector"
        return bar
    }
    func updateUIView(_ bar: ScrollableTabBar<UUID>, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.canonicalSelection = selectedID
        bar.isEnabled = isEnabled
        let items = groups.map { ScrollableTabBar<UUID>.Item(id: $0.id, title: $0.name) }
        bar.setItems(items, selectedID: groups.contains { $0.id == selectedID } ? selectedID : nil)
    }
    final class Coordinator: NSObject, ScrollableTabBarDelegate {
        var onSelect: (UUID) -> Void
        var canonicalSelection: UUID?
        init(_ action: @escaping (UUID) -> Void) { onSelect = action }
        func scrollableTabBar(_ tabBar: ScrollableTabBar<UUID>, didSelect selectedID: UUID) {
            onSelect(selectedID)
            // Selection belongs to the committed workspace. A failed asynchronous group
            // switch must not leave the UIKit control highlighting an uncommitted group.
            if canonicalSelection == nil || tabBar.items.contains(where: { $0.id == canonicalSelection }) {
                tabBar.selectedID = canonicalSelection
            }
        }
    }
}
