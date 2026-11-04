import SwiftUI

/// Original ScrollableTabBar membership contract with its original public AdaptiveTabContent.
struct ScrollableGroupsHost: UIViewRepresentable {
    let groups: [StudyTabGroup]
    let selectedID: UUID?
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
        let items = groups.map { ScrollableTabBar<UUID>.Item(id: $0.id, title: $0.name) }
        bar.setItems(items, selectedID: groups.contains { $0.id == selectedID } ? selectedID : nil)
    }
    final class Coordinator: NSObject, ScrollableTabBarDelegate {
        var onSelect: (UUID) -> Void
        init(_ action: @escaping (UUID) -> Void) { onSelect = action }
        func scrollableTabBar(_ tabBar: ScrollableTabBar<UUID>, didSelect selectedID: UUID) { onSelect(selectedID) }
    }
}
