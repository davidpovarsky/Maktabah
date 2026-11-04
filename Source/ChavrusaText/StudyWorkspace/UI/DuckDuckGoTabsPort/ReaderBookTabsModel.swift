import UIKit

/// Book-domain dependencies for the licensed DuckDuckGo source port.
@MainActor
final class ReaderBookTabAdapter: Equatable {
    let id: UUID
    var title: String
    init(id: UUID, title: String) { self.id = id; self.title = title }
    nonisolated static func == (lhs: ReaderBookTabAdapter, rhs: ReaderBookTabAdapter) -> Bool { lhs === rhs }
}

@MainActor
final class ReaderBookTabsModel {
    var tabs: [ReaderBookTabAdapter] = []
    var selectedID: UUID?
    var onMove: ((UUID, Int) -> Void)?
    init(tabs: [ReaderBookTabAdapter] = [], currentIndex: Int? = nil) {
        self.tabs = tabs
        self.selectedID = currentIndex.flatMap { tabs.indices.contains($0) ? tabs[$0].id : nil }
    }
    var count: Int { tabs.count }
    var currentIndex: Int? { tabs.firstIndex { $0.id == selectedID } }
    var currentTab: ReaderBookTabAdapter? { currentIndex.map { tabs[$0] } }
    func get(tabAt index: Int) -> ReaderBookTabAdapter? { tabs.indices.contains(index) ? tabs[index] : nil }
    func indexOf(tab: ReaderBookTabAdapter) -> Int? { tabs.firstIndex { $0.id == tab.id } }
    func select(tab: ReaderBookTabAdapter) { if tabs.contains(where: { $0.id == tab.id }) { selectedID = tab.id } }
    func move(tab: ReaderBookTabAdapter, to index: Int) {
        guard let old = indexOf(tab: tab), tabs.indices.contains(index) else { return }
        tabs.insert(tabs.remove(at: old), at: index)
        onMove?(tab.id, index)
    }
}

struct ReaderTabsTheme {
    var tabsBarBackgroundColor: UIColor = .systemBackground
    var omniBarBackgroundColor: UIColor = .systemBackground
    var barTintColor: UIColor = .label
    var tabsBarSeparatorColor: UIColor = .separator
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat { min(max(self, range.lowerBound), range.upperBound) }
}
