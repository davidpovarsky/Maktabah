import SwiftUI

/// Original ScrollableTabBar membership contract with its original public AdaptiveTabContent.
struct ScrollableGroupsHost: UIViewRepresentable {
    let groups: [StudyTabGroup]
    let selectedID: UUID?
    var isEnabled = true
    let onSelect: (UUID) -> Void
    @Environment(\.locale) private var locale
    func makeCoordinator() -> Coordinator { Coordinator(onSelect) }
    func makeUIView(context: Context) -> ScrollableTabBar<UUID> {
        let bar = ScrollableTabBar<UUID>()
        bar.delegate = context.coordinator
        bar.accessibilityIdentifier = "study-group-selector"
        return bar
    }
    func updateUIView(_ bar: ScrollableTabBar<UUID>, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.canonicalSelection = selectedID
        if bar.isEnabled != isEnabled { bar.isEnabled = isEnabled }
        let label = StudyWorkspaceText(locale: locale)("Tab Groups", "קבוצות כרטיסיות")
        if bar.accessibilityLabel != label { bar.accessibilityLabel = label }

        let items = groups.map { ScrollableTabBar<UUID>.Item(id: $0.id, title: $0.name) }
        let selection = items.contains { $0.id == selectedID } ? selectedID : nil
        // Store observations often update the selected document without changing the groups.
        // Keep the original UIKit segments alive across selection-only updates.
        if !bar.items.elementsEqual(items, by: { $0.id == $1.id && $0.title == $1.title }) {
            bar.setItems(items, selectedID: selection)
        } else if bar.selectedID != selection {
            bar.selectedID = selection
        }
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
