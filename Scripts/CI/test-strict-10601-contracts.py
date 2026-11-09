#!/usr/bin/env python3
"""Fail closed on the 10601 toolbar contract; no Apple runtime is simulated."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = "cd5e8fef38ea2f8cfc9e3f27fbc995ade94934ec"
HOST = "Source/ChavrusaText/ReaderHost/ChavrusaReaderHost.swift"
TABS = "Source/ChavrusaText/StudyWorkspace/UI/DocumentTabsHost.swift"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def toolbar(source):
    start = source.index("    private func safariToolbar(compact:")
    return source[start:source.index("    private func toolbarButton", start)]


def check_toolbar(source, tabs):
    block = toolbar(source)
    # Exact frozen section, including enclosing control flow and callbacks.
    # A conditional, hidden modifier, reordered action or removed group fails.
    expected = '''        HStack(spacing: compact ? 6 : 11) {
            GlassButtonGroup {
                toolbarButton("square.on.square", title: "כל הכרטיסיות", identifier: "reader-tabs-overview") {
                    withAnimation(.smooth(duration: 0.25)) { showsOverview = true }
                }
                toolbarButton("plus", title: "פתח ספר מהספרייה", identifier: "reader-open-book", action: openLibrary)
            }
            collapsedSearchField'''
    assert expected in block, "Frozen unconditional toolbar group/order/callbacks changed"
    assert block.count("GlassButtonGroup {") == 1
    assert '.frame(height: 54)' in block
    assert source.count('identifier: "reader-tabs-overview"') == 1
    assert source.count('identifier: "reader-open-book"') == 1
    assert tabs.count("TabsBarViewController(showsToolbarButtons: false)") == 1
    assert "showsToolbarButtons: true" not in tabs and ".glass(" not in tabs
    assert 'func tabsBarDidRequestNewTab(_ controller: TabsBarViewController) {}' in tabs
    assert 'func tabsBarDidRequestTabSwitcher(_ controller: TabsBarViewController) {}' in tabs


def main():
    source, tabs = read(HOST), read(TABS)
    check_toolbar(source, tabs)
    baseline = subprocess.check_output(["git", "show", f"{BASE}:{HOST}"], cwd=ROOT).decode("utf-8")
    assert source == baseline, "The frozen host/call site must remain 10601-identical"
    assert toolbar(source) == toolbar(baseline), "Entire toolbar must remain baseline-identical"
    # Prove the guard rejects the concrete regressions, rather than matching
    # tokens that could still exist in an incorrectly positioned toolbar.
    mutants = [
        source.replace("            GlassButtonGroup {", "            if manager.openTabs.isEmpty { GlassButtonGroup {", 1),
        source.replace('toolbarButton("plus",', 'toolbarButton("minus",', 1),
        source.replace('            GlassButtonGroup {', '            collapsedSearchField\n            GlassButtonGroup {', 1),
        source.replace('showsOverview = true', 'showsOverview = false', 1),
        source.replace('action: openLibrary)', 'action: closeSearch)', 1),
        source.replace('            }\n            collapsedSearchField', '            }.hidden()\n            collapsedSearchField', 1),
    ]
    for mutant in mutants:
        try:
            check_toolbar(mutant, tabs)
        except AssertionError:
            pass
        else:
            raise AssertionError("Toolbar guard accepted a regression mutant")
    try:
        check_toolbar(source, tabs.replace("showsToolbarButtons: false", "showsToolbarButtons: true"))
    except AssertionError:
        pass
    else:
        raise AssertionError("Toolbar guard accepted embedded source buttons")

    search = read("Source/Features/Search/iOS/SearchResultsListView.swift")
    assert search.count(".listRowBackground(Color.appBackground)") == 3
    assert ".scrollContentBackground(.hidden)" in search
    assert ".background(Color.appBackground)" in search
    workspace = read("Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift")
    assert "geometry.size.width - minimumReaderWidth - 18" in workspace
    assert "detailWidth: detailColumnWidth, minimumReaderWidth: minimumReaderWidth" in workspace
    assert ".onChange(of: shouldPresentPanelInContent)" in workspace
    assert 'if shouldPresentPanelInContent, newState == .hidden, showPanel' in workspace
    assert workspace.count("ChavrusaReaderWorkspaceLayout(") == 1
    adapter = read("Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift")
    staging = adapter[adapter.index("let staged: [iOSNavigationManager.ReaderTab]"):adapter.index("beforeCommit:")]
    assert staging.index("resolveBook(") < staging.index("retained.first"), "Cached books must still exist in the prepared target catalog"
    assert staging.count("existing.book.backendLocator?.workKey == resolved.backendLocator?.workKey") == 2
    switching = adapter[adapter.index("func switchGroup("):adapter.index("private func matches(")]
    assert switching.index("beforeCommit:") < switching.index("let outgoingDocuments = capture("), "Capture the latest outgoing position after awaited target preparation"
    ipad = read("Source/UI/iOS/Views/iPadLayout.swift")
    assert 'iOSLibraryView(groupsToolbarActions: true)\n                        .navigationTitle(iOSTab.viewer.title)\n                        .navigationBarTitleDisplayMode(.inline)' in ipad
    layout = read("Source/ChavrusaText/ReaderHost/ChavrusaReaderWorkspaceLayout.swift")
    assert layout.count("            reader\n") == 1
    assert layout.index("            reader\n") < layout.index("            if showPanel")
    overview = read("Source/ChavrusaText/ReaderHost/ReaderOverviewPresentation.swift")
    assert ".overCurrentContext" in overview
    assert "setContentOffset" not in overview
    for name in ["TabsBarView.swift", "TabsBarViewController.swift", "TabsBarCell.swift", "TabsBarLayout.swift",
                 "TabFlareBackgroundController.swift", "TabFlaredBackgroundView.swift", "TabSwitcherPagePort.swift"]:
        path = "Source/ChavrusaText/StudyWorkspace/UI/DuckDuckGoTabsPort/" + name
        expected_port = subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT).decode("utf-8")
        assert read(path) == expected_port, f"Frozen original UIKit port changed: {name}"
    print("PASS: frozen toolbar, 7 rejected mutants, search row families, docking seam, reader mounting, full-context overview")


if __name__ == "__main__":
    main()
