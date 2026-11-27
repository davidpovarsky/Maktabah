import Foundation

// These are declared UIKit/domain boundaries, not a UIKit implementation or
// acceptance emulator. The two exact original helper bodies are compiled over
// them solely to exercise synchronous callback and delayed-closure ownership.
struct SwiftUIAnnotationNode { let id: String }
enum AnnotationItem { case group(SwiftUIAnnotationNode) }
struct ListContentConfiguration { var isExpanded: Bool }

@MainActor final class Boundary {
    static var trace: [String] = []
    static var hooks: [String: () -> Void] = [:]
    static var heldAnimation: (() -> Void)?
    static var holdAnimation = false
    static func event(_ name: String) {
        trace.append(name)
        let callback = hooks.removeValue(forKey: name)
        callback?()
    }
    static func reset() { trace = []; hooks = [:]; heldAnimation = nil; holdAnimation = false }
}
struct OriginalSnapshot {
    mutating func expand(_ items: [AnnotationItem]) { }
    mutating func collapse(_ items: [AnnotationItem]) { }
}
@MainActor final class OriginalDataSource {
    func snapshot(for id: String) -> OriginalSnapshot { Boundary.event("snapshot"); return .init() }
    func apply(_ snapshot: OriginalSnapshot, to id: String, animatingDifferences: Bool) {
        Boundary.event("apply")
    }
    func indexPath(for item: AnnotationItem) -> Int? { Boundary.event("indexPath"); return 0 }
}
@MainActor final class OriginalCell {
    private var stored: Any? = ListContentConfiguration(isExpanded: false)
    private(set) var writes = 0
    var expanded: Bool { (stored as? ListContentConfiguration)?.isExpanded == true }
    var contentConfiguration: Any? {
        get { Boundary.event("config.get"); return stored }
        set { Boundary.event("config.set"); writes += 1; stored = newValue }
    }
}
@MainActor final class OriginalCollection {
    var cell = OriginalCell()
    func cellForItem(at index: Int) -> OriginalCell? { Boundary.event("cell"); return cell }
}
@MainActor enum UIView {
    enum Options { case curveEaseInOut }
    static func animate(withDuration: Double, delay: Double, options: Options,
                        animations: @escaping @MainActor () -> Void) {
        Boundary.event("animate")
        if Boundary.holdAnimation { Boundary.heldAnimation = animations }
        else { animations() }
    }
}
