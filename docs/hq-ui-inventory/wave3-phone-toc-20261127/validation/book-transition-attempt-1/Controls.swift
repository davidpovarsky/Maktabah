@main
struct Controls {
    @MainActor static func main() throws {
        var results: [[String: Any]] = []
        func check(_ name: String, _ value: @autoclosure () -> Bool) {
            let passed = value()
            print("\(passed ? "PASS" : "FAIL") \(name)")
            results.append(["name": name, "passed": passed])
        }
        func rejects(_ operation: () throws -> Void) -> Bool {
            do { try operation(); return false } catch { return true }
        }
        let book = BooksData(), other = BooksData()
        let cold = iOSNavigationManager()
        cold.currentMode = .history
        let coldProof = try MaktabahNativePhoneTOCBookTransition(manager: cold, book: book)
        check("cold original nil declares exactly one setter", coldProof.assignsBook && coldProof.beforeRevision == 0 && coldProof.afterRevision == 1)
        try coldProof.validateBefore(cold)
        cold.currentMode = .viewer; cold.selectedBook = book
        check("canonical cold transition preserves didSet presentation owner", cold.selectedBookPresentationMode == .viewer && cold.selectedBook === book)
        check("canonical exact +1 passes", !rejects { try coldProof.validateAfter(cold) })
        cold.selectedBook = book
        check("equal-value original setter still advances metadata", cold.selectedBookPresentationRevision == 2)
        check("unexpected equal-value write is rejected after canonical apply", rejects { try coldProof.validateAfter(cold) })

        let warm = iOSNavigationManager()
        warm.selectedBook = book
        let warmProof = try MaktabahNativePhoneTOCBookTransition(manager: warm, book: book)
        check("same original viewer book declares zero setters", !warmProof.assignsBook && warmProof.beforeRevision == warmProof.afterRevision)
        check("true canonical no-op is accepted", !rejects { try warmProof.validateAfter(warm) })
        warm.selectedBook = book
        check("redundant assignment is not a permitted no-op", rejects { try warmProof.validateAfter(warm) })

        let beforeABA = iOSNavigationManager()
        let beforeProof = try MaktabahNativePhoneTOCBookTransition(manager: beforeABA, book: book)
        beforeABA.selectedBook = other; beforeABA.selectedBook = nil
        check("nil-other-nil before apply cannot inherit source", rejects { try beforeProof.validateBefore(beforeABA) })

        let reentrant = iOSNavigationManager()
        let reentrantProof = try MaktabahNativePhoneTOCBookTransition(manager: reentrant, book: book)
        reentrant.selectedBook = book; reentrant.selectedBook = other; reentrant.selectedBook = book
        check("one intended setter plus reentrant ABA is rejected", rejects { try reentrantProof.validateAfter(reentrant) })

        let wrongMode = iOSNavigationManager()
        wrongMode.currentMode = .history; wrongMode.selectedBook = book
        let modeProof = try MaktabahNativePhoneTOCBookTransition(manager: wrongMode, book: book)
        check("same book in another original stack requires exactly one setter", modeProof.assignsBook)
        wrongMode.currentMode = .viewer
        check("mode assignment alone cannot silently repair original presentation ownership", rejects { try modeProof.validateAfter(wrongMode) })
        wrongMode.selectedBook = book
        check("same book owning-stack correction matches +1 and original didSet", !rejects { try modeProof.validateAfter(wrongMode) })

        let different = iOSNavigationManager(); different.selectedBook = other
        check("another existing selected book is unavailable", rejects { _ = try MaktabahNativePhoneTOCBookTransition(manager: different, book: book) })

        let maximum = iOSNavigationManager(revision: .max)
        check("required assignment at exhausted counter is refused before mutation", rejects { _ = try MaktabahNativePhoneTOCBookTransition(manager: maximum, book: book) })
        maximum.selectedBook = book
        check("overflow becomes permanent unavailable instead of wrapping", maximum.selectedBookPresentationRevision == nil)
        check("original overflow setter still preserves original didSet behavior", maximum.selectedBookPresentationMode == .viewer && maximum.selectedBook === book)
        maximum.selectedBook = nil; maximum.selectedBook = book
        check("subsequent assignments never reset exhausted ownership metadata", maximum.selectedBookPresentationRevision == nil)
        check("exhausted same-book route also fails closed", rejects { _ = try MaktabahNativePhoneTOCBookTransition(manager: maximum, book: book) })

        let data = try JSONSerialization.data(withJSONObject: [
            "status": "VERBATIM_ORIGINAL_SETTER_AND_PRESENTATION_POLICY_CONTROLS_ONLY",
            "passed": results.filter { $0["passed"] as? Bool == true }.count,
            "failed": results.filter { $0["passed"] as? Bool == false }.count,
            "controls": results, "native_ui_executed": 0,
            "boundary": "Synthetic AppMode/BooksData/error and manager shell; exact actual original setter plus actual policy"],
            options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        if results.contains(where: { $0["passed"] as? Bool == false }) { exit(1) }
    }
}
