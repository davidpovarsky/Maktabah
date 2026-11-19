import Foundation

// Explicit model/backend boundary doubles. The retained binding below is copied
// byte-for-byte from production. These cases do not replace or certify UIKit,
// Core authorization, native visibility, a database or the actual inspector.
enum BackendID: String { case otzaria, sefaria }
struct TextLocator: Equatable { var backend: BackendID; var workKey: String; var line: Int }
struct LibraryReaderDestination: Equatable { var sectionLocator: TextLocator }
enum LibraryReaderTextMode { case line, chapter }
struct FixtureBook { let id: Int; let backendLocator: TextLocator? }
struct OtzariaLineAnchor: Equatable { var id: Int; var bookId: Int; var lineIndex: Int }
struct UIRouteError: Error {
    enum Status { case unavailable, staleState }
    let status: Status
    let code: String
    init(_ status: Status, _ code: String) { self.status = status; self.code = code }
}
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID: BackendID = .otzaria
}
@MainActor final class ReaderState { var selectedRange: NSRange? = NSRange(location: 2, length: 3) }
@MainActor final class ReaderViewModel {
    enum State { case loaded, loading }
    struct Section { var locator: TextLocator }
    var currentDestination: LibraryReaderDestination?
    var backendSection: Section?
    var contentText = "original fixture text"
    var state: State = .loaded
    var selectedSegmentLocator: TextLocator?
    var otzariaSelectedLineAnchor: OtzariaLineAnchor?
    var currentBook: FixtureBook?
    var readerState = ReaderState()
    var currentReaderTextMode: LibraryReaderTextMode = .line
    var currentContentId = 7
    var readerInspectorVisible = false
}
@MainActor final class iOSNavigationManager {
    enum Mode { case viewer, search }
    struct ReaderTab { let id: UUID; let book: FixtureBook; let viewModel: ReaderViewModel }
    var currentMode: Mode = .viewer
    var activeTabId: UUID?
    var openTabs: [ReaderTab] = []
}

// ACTUAL_INSPECTOR_BINDING

@main struct NativeInspectorOwnerAcceptance {
    @MainActor static func make() -> (iOSNavigationManager, ReaderViewModel) {
        BackendCoordinator.shared.activeBackendID = .otzaria
        let locator = TextLocator(backend: .otzaria, workKey: "book:9", line: 7)
        let reader = ReaderViewModel(), manager = iOSNavigationManager()
        reader.currentDestination = .init(sectionLocator: locator)
        reader.backendSection = .init(locator: locator)
        reader.selectedSegmentLocator = locator
        reader.otzariaSelectedLineAnchor = .init(id: 107, bookId: 9, lineIndex: 7)
        reader.currentBook = .init(id: 9, backendLocator: locator)
        let tab = iOSNavigationManager.ReaderTab(id: UUID(), book: reader.currentBook!, viewModel: reader)
        manager.activeTabId = tab.id; manager.openTabs = [tab]
        return (manager, reader)
    }

    @MainActor static func main() throws {
        var checks: [(String, Bool)] = []
        func check(_ name: String, _ body: () throws -> Bool) {
            do { checks.append((name, try body())) } catch { checks.append((name, false)) }
        }
        func rejected(_ body: () throws -> Void) -> Bool {
            do { try body(); return false } catch is UIRouteError { return true } catch { return false }
        }
        check("Creating a binding does not open the panel or change selection") {
            let (manager, reader) = make()
            _ = try MaktabahNativeInspectorBinding(manager: manager)
            return !reader.readerInspectorVisible && reader.readerState.selectedRange == NSRange(location: 2, length: 3)
        }
        check("Opening the existing panel preserves source, selection and original Reader identity") {
            let (manager, reader) = make(), original = manager.openTabs[0]
            let selected = reader.selectedSegmentLocator, anchor = reader.otzariaSelectedLineAnchor
            let binding = try MaktabahNativeInspectorBinding(manager: manager)
            try binding.apply(); try binding.validate()
            return reader.readerInspectorVisible && manager.openTabs.count == 1
                && manager.activeTabId == original.id && manager.openTabs[0].viewModel === reader
                && reader.selectedSegmentLocator == selected && reader.otzariaSelectedLineAnchor == anchor
                && reader.readerState.selectedRange == NSRange(location: 2, length: 3)
                && reader.contentText == "original fixture text" && reader.currentContentId == 7
        }
        check("Repeated presentation stays on the same original panel and selection") {
            let (manager, reader) = make()
            let binding = try MaktabahNativeInspectorBinding(manager: manager)
            try binding.apply(); try binding.apply()
            return reader.readerInspectorVisible && reader.otzariaSelectedLineAnchor?.id == 107 && manager.openTabs.count == 1
        }
        check("Missing active identity cannot fall back to the first Reader") {
            let (manager, reader) = make(); manager.activeTabId = UUID()
            return rejected { _ = try MaktabahNativeInspectorBinding(manager: manager) } && !reader.readerInspectorVisible
        }
        check("Non-Reader app mode cannot supply an inspector owner") {
            let (manager, reader) = make(); manager.currentMode = .search
            return rejected { _ = try MaktabahNativeInspectorBinding(manager: manager) } && !reader.readerInspectorVisible
        }
        check("Loading content cannot advertise a ready inspector") {
            let (manager, reader) = make(); reader.state = .loading
            return rejected { _ = try MaktabahNativeInspectorBinding(manager: manager) }
        }
        check("A section from another book cannot bind the active Reader") {
            let (manager, reader) = make(); reader.backendSection?.locator.workKey = "book:10"
            return rejected { _ = try MaktabahNativeInspectorBinding(manager: manager) }
        }
        check("An unrelated retained line anchor cannot select another book") {
            let (manager, reader) = make(); reader.otzariaSelectedLineAnchor?.bookId = 10
            return rejected { _ = try MaktabahNativeInspectorBinding(manager: manager) }
        }
        check("An unrelated selected locator cannot select another backend") {
            let (manager, reader) = make(); reader.selectedSegmentLocator?.backend = .sefaria
            return rejected { _ = try MaktabahNativeInspectorBinding(manager: manager) }
        }
        check("Closing the retained tab before commit prevents the effect") {
            let (manager, reader) = make(); let binding = try MaktabahNativeInspectorBinding(manager: manager)
            manager.openTabs = []
            return rejected { try binding.apply() } && !reader.readerInspectorVisible
        }
        check("Replacing a Reader under the same tab UUID prevents the effect") {
            let (manager, reader) = make(); let binding = try MaktabahNativeInspectorBinding(manager: manager)
            let (_, replacement) = make(); let original = manager.openTabs[0]
            manager.openTabs = [.init(id: original.id, book: original.book, viewModel: replacement)]
            return rejected { try binding.apply() } && !reader.readerInspectorVisible && !replacement.readerInspectorVisible
        }
        check("Switching the active tab before commit prevents the effect") {
            let (manager, reader) = make(); let binding = try MaktabahNativeInspectorBinding(manager: manager)
            manager.activeTabId = UUID()
            return rejected { try binding.apply() } && !reader.readerInspectorVisible
        }
        check("A new content destination invalidates the old inspector request") {
            let (manager, reader) = make(); let binding = try MaktabahNativeInspectorBinding(manager: manager)
            reader.currentDestination?.sectionLocator.line = 8; reader.backendSection?.locator.line = 8
            return rejected { try binding.apply() } && !reader.readerInspectorVisible
        }
        check("A changed private selection invalidates the old inspector request") {
            let (manager, reader) = make(); let binding = try MaktabahNativeInspectorBinding(manager: manager)
            reader.readerState.selectedRange = NSRange(location: 9, length: 2)
            return rejected { try binding.apply() } && !reader.readerInspectorVisible
        }
        check("A changed source anchor invalidates the old inspector request") {
            let (manager, reader) = make(); let binding = try MaktabahNativeInspectorBinding(manager: manager)
            reader.otzariaSelectedLineAnchor?.id = 108
            return rejected { try binding.apply() } && !reader.readerInspectorVisible
        }
        check("A changed reading mode invalidates the old inspector request") {
            let (manager, reader) = make(); let binding = try MaktabahNativeInspectorBinding(manager: manager)
            reader.currentReaderTextMode = .chapter
            return rejected { try binding.apply() } && !reader.readerInspectorVisible
        }
        check("A changed backend invalidates the old inspector request") {
            let (manager, reader) = make(); let binding = try MaktabahNativeInspectorBinding(manager: manager)
            BackendCoordinator.shared.activeBackendID = .sefaria
            return rejected { try binding.apply() } && !reader.readerInspectorVisible
        }
        for (name, passed) in checks { print("\(passed ? "PASS" : "FAIL") \(name)") }
        print("TOTAL \(checks.count) PASS \(checks.filter(\.1).count) FAIL \(checks.filter { !$0.1 }.count)")
        exit(checks.allSatisfy(\.1) ? 0 : 1)
    }
}
