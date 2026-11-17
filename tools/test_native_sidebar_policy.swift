@main
struct NativeSidebarPolicyTests {
    static func main() {
        var assertions = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            assertions += 1
        }
        check(!ReaderSidebarPolicy.canTile(availableWidth: 750, sidebarWidth: 320, isCompact: false), "Divider cannot consume the reader's minimum width")
        check(ReaderSidebarPolicy.canTile(availableWidth: 751, sidebarWidth: 320, isCompact: false), "Exact wide boundary tiles")
        check(ReaderSidebarPolicy.canTile(availableWidth: 1024, sidebarWidth: 320, isCompact: false), "Wide iPad has readable sibling columns")
        check(!ReaderSidebarPolicy.canTile(availableWidth: 1024, sidebarWidth: 320, isCompact: true), "Compact adaptation remains native even with stale wide bounds")
        check(!ReaderSidebarPolicy.canTile(availableWidth: 650, sidebarWidth: 0, isCompact: false), "Unmeasured sidebar cannot be assigned zero width")
        check(ReaderSidebarPolicy.canTile(availableWidth: 651, sidebarWidth: 0, isCompact: false), "Sidebar minimum and divider are included")
        check(!ReaderSidebarPolicy.canTile(availableWidth: 1024, sidebarWidth: 600, isCompact: false), "Larger native primary constraint is respected")
        check(!ReaderSidebarPolicy.canTile(availableWidth: 1024, sidebarWidth: 320, isCompact: false, readerWidth: 800), "Accessibility text can require wider reader")
        check(ReaderSidebarPolicy.canTile(availableWidth: 1151, sidebarWidth: 320, isCompact: false, readerWidth: 800), "Accessibility threshold permits sufficiently wide windows")
        check(!ReaderSidebarPolicy.canTile(availableWidth: .nan, sidebarWidth: 320, isCompact: false), "NaN width rejected")
        check(!ReaderSidebarPolicy.canTile(availableWidth: .infinity, sidebarWidth: 320, isCompact: false), "Unmeasured infinite width rejected")
        check(!ReaderSidebarPolicy.canTile(availableWidth: 1024, sidebarWidth: .nan, isCompact: false), "Invalid primary width rejected")
        check(!ReaderSidebarPolicy.canTile(availableWidth: 1024, sidebarWidth: 320, isCompact: false, readerWidth: .infinity), "Invalid scaled reader width rejected")
        for isRTL in [false, true] {
            let forward = isRTL ? 60.0 : -60.0
            check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: forward, vertical: 0, isRTL: isRTL) == true, "Library to TOC follows layout direction")
            check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: -forward, vertical: 0, isRTL: isRTL) == false, "TOC to library follows layout direction")
            check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: forward, vertical: 100, isRTL: isRTL) == nil, "Vertical list gesture must not switch page")
            check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: 43, vertical: 0, isRTL: isRTL) == nil, "Short touch does not switch page")
            check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: .nan, vertical: 0, isRTL: isRTL) == nil, "Invalid gesture rejected")
        }
        check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: 50, vertical: 40, isRTL: false) == nil, "Diagonal boundary remains untouched")
        check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: 44, vertical: 0, isRTL: false) == false, "Exact LTR return threshold selects library")
        check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: -44, vertical: 0, isRTL: false) == true, "Exact LTR forward threshold selects contents")
        check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: 44, vertical: 0, isRTL: true) == true, "Exact RTL forward threshold selects contents")
        check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: -44, vertical: 0, isRTL: true) == false, "Exact RTL return threshold selects library")
        check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: 51, vertical: 40, isRTL: false) == false, "Horizontal return just past 1.25 ratio selects library")
        check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: 51, vertical: 40, isRTL: true) == true, "Horizontal forward just past 1.25 ratio selects contents")
        check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: 60, vertical: .nan, isRTL: false) == nil, "Non-finite vertical translation rejected")
        check(ReaderSidebarPolicy.swipeSelectsContents(horizontal: .infinity, vertical: 0, isRTL: false) == nil, "Infinite horizontal translation rejected")
        // Rotation and scene reattachment evaluate current geometry; the policy
        // stores no visibility/page/reader state that could reopen or reset it.
        check(ReaderSidebarPolicy.canTile(availableWidth: 1024, sidebarWidth: 320, isCompact: false), "Wide launch")
        check(!ReaderSidebarPolicy.canTile(availableWidth: 500, sidebarWidth: 320, isCompact: true), "Window narrows")
        check(ReaderSidebarPolicy.canTile(availableWidth: 1024, sidebarWidth: 320, isCompact: false), "Wide restoration")
        check(ReaderSidebarPolicy.debugRounded(0.0) == "0", "Zero rounds to zero")
        check(ReaderSidebarPolicy.debugRounded(-0.0) == "0", "Negative zero rounds to zero")
        check(ReaderSidebarPolicy.debugRounded(0.4) == "0", "Positive sub-half rounds down")
        check(ReaderSidebarPolicy.debugRounded(-0.4) == "0", "Negative sub-half rounds toward zero")
        check(ReaderSidebarPolicy.debugRounded(0.5) == "1", "Positive half rounds away from zero")
        check(ReaderSidebarPolicy.debugRounded(-0.5) == "-1", "Negative half rounds away from zero")
        check(ReaderSidebarPolicy.debugRounded(1.5) == "2", "1.5 rounds away from zero")
        check(ReaderSidebarPolicy.debugRounded(-1.5) == "-2", "-1.5 rounds away from zero")
        check(ReaderSidebarPolicy.debugRounded(43.6) == "44", "Ordinary positive float rounds to nearest integer")
        check(ReaderSidebarPolicy.debugRounded(-120.2) == "-120", "Ordinary negative float rounds to nearest integer")
        let maxRepresentable = Double(Int.max).nextDown
        let expectedMaxRepresentable = Int(exactly: maxRepresentable.rounded()).map(String.init)
        check(expectedMaxRepresentable != nil && ReaderSidebarPolicy.debugRounded(maxRepresentable) == expectedMaxRepresentable, "Highest representable Double below Int.max formats as exact integer")
        check(ReaderSidebarPolicy.debugRounded(Double(Int.max)) == String(describing: Double(Int.max)), "Double(Int.max) falls back without trapping")
        check(ReaderSidebarPolicy.debugRounded(Double(Int.min)) == String(Int.min), "Exact Double(Int.min) formats as Int.min")
        check(ReaderSidebarPolicy.debugRounded(Double(Int.min).nextDown) == String(describing: Double(Int.min).nextDown), "Below Int.min falls back without trapping")
        check(ReaderSidebarPolicy.debugRounded(-1e20) == String(describing: -1e20), "Large negative finite value falls back without trapping")
        check(ReaderSidebarPolicy.debugRounded(.greatestFiniteMagnitude) == String(describing: Double.greatestFiniteMagnitude), "greatestFiniteMagnitude falls back without trapping")
        check(ReaderSidebarPolicy.debugRounded(-.greatestFiniteMagnitude) == String(describing: -Double.greatestFiniteMagnitude), "Negative greatestFiniteMagnitude falls back without trapping")
        check(ReaderSidebarPolicy.debugRounded(.nan) == String(describing: Double.nan), "NaN falls back cleanly")
        check(ReaderSidebarPolicy.debugRounded(.infinity) == String(describing: Double.infinity), "Positive infinity falls back cleanly")
        check(ReaderSidebarPolicy.debugRounded(-.infinity) == String(describing: -Double.infinity), "Negative infinity falls back cleanly")
        print("PASS: \(assertions) actual sidebar width/RTL/gesture policy assertions; no device UI claim")
    }
}
