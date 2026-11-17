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
        print("PASS: \(assertions) actual sidebar width/RTL/gesture policy assertions; no device UI claim")
    }
}
