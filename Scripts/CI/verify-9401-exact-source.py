#!/usr/bin/env python3
"""Git-object provenance inventory and fail-closed, simulator-free upload gate.

The inventory deliberately includes ALL original Source files: a conservative
superset of the active iPad closure, not a claim that lexical analysis proves
every SwiftUI runtime behavior. No approval is manufactured by this script.
"""
import argparse
from collections import Counter
import difflib
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/ipad-ui-rebuild"
BASE = "f243d06603cbe506de8f27ea8b9a479af4415e2e"
FEATURE = "905439c9b41144ab34e7071e067ec09bc474d4f3"
UPSTREAM = "46e893c65139fbb1e582d6595b0d220ea912324a"
IPAD = "Source/UI/iOS/Views/iPadLayout.swift"
READER = "Source/Features/Reader/iOS/iOSReaderView.swift"
WORKSPACE = "Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift"
SIDEBAR = "Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift"
COMPACT = "Source/ChavrusaText/ReaderHost/CompactStudyWorkspaceHostModifier.swift"
TOC = "Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift"
ROWS = "Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift"
TABS = "Source/Features/Reader/iOS/iOSReaderTabView.swift"
PALETTE = "Source/ChavrusaText/ToolbarSearch/LibraryCommandPaletteAdapter.swift"
PROFILE_MENU = "Source/ChavrusaText/StudyWorkspace/UI/StudyProfileMenu.swift"
PROFILE_MANAGEMENT = "Source/ChavrusaText/StudyWorkspace/UI/StudyProfileManagementView.swift"
APPROVAL = "docs/ipad-ui-rebuild/9401_pending_approval.json"
APPROVED_PATCH = "docs/ipad-ui-rebuild/9401_PENDING_OWNER_HOOK.diff"
APPROVED_READER_BLOB = "67146db4a47746c8412a8ee7d8b16328ff951e19"
PAGER = "Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift"
NATIVE_APPROVAL = "docs/ipad-ui-rebuild/native-sidebar-11001/pending-approval.json"
NATIVE_PATCH = "docs/ipad-ui-rebuild/native-sidebar-11001/PENDING_OWNER_iPadLayout.diff"
NATIVE_IPAD_BLOB = "e541d660cdeae48d5f378e1ee198147e6c7f8d85"
NATIVE_PAGER_BLOB = "6eb5f29afdf42cad7acbf5ef6ae3d535cb29c238"
NATIVE_PATCH_SHA256 = "fbc92c2d348514a7876b945e530dcc9c30d7a5135de63a24477dfd4454f5f2dc"
RELEASE_11001 = "0d2ac9c46fe33d5a650fcf9ee7e66b2aa8bd2a73"
NATIVE_OWNER_REPLY = "Owner response in this chat on 2026-11-10: מאשר את ה־diff המדויק ב־iPadLayout.swift. המשך לביצוע מלא לפי המסמך, כולל הבדיקות והעלאת build production ל־TestFlight לאחר שכל השערים עוברים."

# Reasons concern retained feature-base code, not permission to edit it.
RETAINED_EXCEPTIONS = {
    "Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift":
        "Canonical navigation label and showingSearch popover-state correctness.",
    "Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift":
        "Canonical backend navigation references; native geometry unchanged.",
    "Source/Features/Search/iOS/SearchComponents.swift":
        "Actual FocusState binding and search-history visibility correction.",
    "Source/Features/Search/iOS/SearchModeView.swift":
        "Pass the actual FocusState binding to the current search input.",
    "Source/Features/Search/iOS/SearchResultsListView.swift":
        "Retain required dynamic theme surface corrections; list structure unchanged.",
    "Source/UI/iOS/Views/iOSMainView.swift":
        "Preserve compact iPad route, original iPad tabs sheet, and current phone behavior.",
}
SEAM_REASONS = {
    IPAD: "Directive exceptions A/B plus owner follow-up C (2026-11-10): alternate sidebar pages, compact close, original reader, native search/profile toolbar attachment.",
    WORKSPACE: "Directive exception A: shared TOC action and one stable original reader HStack; original native inspector/resize geometry and FloatingPanel configuration.",
}
RESTORE_REASONS = {
    "iOSLibraryView.swift": "Restore original toolbar; remove grouped replacement.",
    "iOSBookSearchView.swift": "Restore original search history overlay; retain engine.",
    "iOSReaderTabView.swift": "Restore original ReaderTabsView and its placement.",
    "iOSReaderView.swift": "Restore original toolbar buttons; propose TOC state hook separately.",
    "iOSReaderWorkspaceView.swift": "Restore actual original workspace functions; additional hook pending.",
    "OtzariaReaderSourcesInspectorHost.swift": "Restore original inspector headings and chrome.",
    "iOSTabBarVisibilityPolicy.swift": "Restore always-visible iPad tabs; preserve phone branch.",
    "iOSIbarotTextView.swift": "Remove scroll reporting used to hide replacement chrome.",
    "iPadLayout.swift": "Original root/five tabs; only exceptions A/B at viewer composition.",
}
INACTIVE_PREFIXES = (
    "Source/ChavrusaText/StudyWorkspace/UI/",
    "Source/ChavrusaText/ToolbarSearch/SafariToolbarSourcePort.swift",
    "Source/ChavrusaText/ToolbarSearch/ReaderToolbarActionAdapter.swift",
    "Source/ChavrusaText/ReaderHost/ChavrusaReaderHost.swift",
    "Source/ChavrusaText/ReaderHost/ChavrusaReaderWorkspaceLayout.swift",
    "Source/ChavrusaText/ReaderHost/ReaderNavigationChromeState.swift",
)


def git(*args, binary=False):
    result = subprocess.check_output(["git", *args], cwd=ROOT)
    return result if binary else result.decode("utf-8")


@lru_cache(maxsize=None)
def tree(ref):
    entries = {}
    for line in git("ls-tree", "-r", ref).splitlines():
        meta, path = line.split("\t", 1)
        mode, kind, blob = meta.split()
        entries[path] = {"mode": mode, "kind": kind, "blob": blob}
    return entries


@lru_cache(maxsize=None)
def content(ref, path):
    return git("cat-file", "blob", f"{ref}:{path}", binary=True)


def swift_snapshot(ref):
    paths = [p for p in tree(ref) if p.startswith("Source/") and p.endswith(".swift")]
    queries = "".join(f"{ref}:{p}\n" for p in paths).encode()
    result = subprocess.run(["git", "cat-file", "--batch"], cwd=ROOT,
                            input=queries, stdout=subprocess.PIPE, check=True).stdout
    offset, files = 0, {}
    for path in paths:
        end = result.index(b"\n", offset)
        blob, kind, size = result[offset:end].split()
        if kind != b"blob":
            raise ValueError("Expected Git blob: " + path)
        offset = end + 1
        files[path] = result[offset:offset + int(size)]
        offset += int(size) + 1
    return files


def blob_id(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def visual(path):
    return (path.startswith("Source/UI/iOS/")
            or bool(re.match(r"Source/Features/[^/]+/iOS/", path))
            or path.startswith("Source/Otzaria/Reading/")
            or path.startswith("Source/Assets.xcassets/"))


def unchanged_blocks(before, after):
    a, b = before.splitlines(keepends=True), after.splitlines(keepends=True)
    return [{"baseline_start_line": match.a + 1, "final_start_line": match.b + 1,
             "line_count": match.size,
             "sha256": hashlib.sha256(b"".join(a[match.a:match.a + match.size])).hexdigest()}
            for match in difflib.SequenceMatcher(None, a, b, autojunk=False).get_matching_blocks()
            if match.size]


def before_inventory():
    original, upstream = tree(BASE), tree(UPSTREAM)
    entries = []
    for path in git("diff", "--name-only", BASE, FEATURE, "--", "Source").splitlines():
        if path not in original or not visual(path):
            continue
        diff = git("diff", "--no-ext-diff", "--unified=3", BASE, FEATURE, "--", path)
        hunks = []
        for hunk in re.split(r"(?=^@@ )", diff, flags=re.M)[1:]:
            classification = "visual"
            if path in RETAINED_EXCEPTIONS:
                classification = "nonvisual_backend_semantic"
            if path == IPAD or (path in (READER, WORKSPACE) and any(
                    token in hunk for token in ("presentContents", "closeContents", "contentsIsOpen", "chavrusaReaderSidebar"))):
                classification = "required_integration_hook"
            if path == WORKSPACE and any(token in hunk for token in
                    ("ChavrusaReaderWorkspaceLayout(", "ToolbarItem(placement: .principal)")):
                classification = "visual"
            hunks.append({"classification": classification, "diff": hunk})
        entries.append({"path": path,
                        "ownership": "UPSTREAM_OWNED" if path in upstream else "DOWNSTREAM_OWNED",
                        "upstream_blob": upstream.get(path, {}).get("blob"),
                        "baseline_blob": original[path]["blob"],
                        "feature_blob": git("rev-parse", f"{FEATURE}:{path}").strip(),
                        "action": RETAINED_EXCEPTIONS.get(path, RESTORE_REASONS.get(Path(path).name)),
                        "downstream_alternative": "Preserve engine/provider code; reuse downstream coordinators.",
                        "hunks": hunks})
    return {"baseline_sha": BASE, "feature_base_sha": FEATURE, "upstream_sha": UPSTREAM,
            "snapshot": "Immutable pre-edit Git objects; reproducible independently of working tree.",
            "changed_original_visual_files": entries}


def make_manifest(ref):
    final_sha = git("rev-parse", ref).strip()
    baseline, feature, final, upstream = tree(BASE), tree(FEATURE), tree(ref), tree(UPSTREAM)
    entries = []
    for path in sorted(set(baseline) | set(final)):
        # Full original Source superset, all new Source modules, plus unchanged
        # build/workflow/dependency/resource contracts outside Source.
        if not (path.startswith("Source/") or path.startswith((".github/workflows/", "Vendor/", "Packages/", "Maktabah.xcodeproj/"))
                or path in ("Podfile", "Podfile.lock", ".gitmodules") or path.endswith(("Package.resolved", "Cargo.lock"))):
            continue
        a = baseline.get(path, {}).get("blob")
        b = final.get(path, {}).get("blob")
        f = feature.get(path, {}).get("blob")
        entry = {"path": path, "ownership": "UPSTREAM_OWNED" if path in upstream else "DOWNSTREAM_OWNED",
                 "upstream_blob": upstream.get(path, {}).get("blob"),
                 "baseline_blob": a, "final_blob": b, "feature_blob": f}
        if a and visual(path):
            if a == b:
                entry["status"] = "EXACT_9401_BLOB"
            else:
                approved_reader = path == READER and b == APPROVED_READER_BLOB
                entry.update(status="DECLARED_EXCEPTION",
                             necessity="Exact four-line page-aware TOC state hook approved by owner." if approved_reader else SEAM_REASONS.get(path, RETAINED_EXCEPTIONS.get(path, "UNEXPLAINED")),
                             approval_state="EXPLICIT_OWNER_NATIVE_SIDEBAR_HUNK" if path == IPAD and b == NATIVE_IPAD_BLOB else "EXPLICIT_OWNER_EXACT_HUNK" if approved_reader else "SCOPED_DIRECTIVE_A_B" if path in SEAM_REASONS else "RETAINED_UNEDITED_FEATURE_BASE" if path in RETAINED_EXCEPTIONS and b == f else "OWNER_HUNK_REVIEW_REQUIRED",
                             approval_reference="Owner reply in this chat, 2026-11-10: מאשר את ה־diff המדויק; frozen patch and approval record committed." if approved_reader else "Owner request to execute attached 2026-11-09 directive, sections 2.2/3/4; profile toolbar follow-up 2026-11-10." if path in SEAM_REASONS else "Directive sections 2.2/5: retain necessary current semantics; no new protected edit applied." if path in RETAINED_EXCEPTIONS and b == f else None,
                             exact_diff=git("diff", "--no-ext-diff", BASE, ref, "--", path),
                             unchanged_blocks=unchanged_blocks(content(BASE, path), content(ref, path)) if b else [])
        elif path in (PROFILE_MENU, PROFILE_MANAGEMENT):
            entry.update(status="ACTIVE_PROFILE_UI", feature_identical=b == f,
                         approval_reference="Owner follow-up 2026-11-10: add study profiles to toolbar.",
                         qualification="Reuse original menu actions and unchanged management UI with a native toolbar label.")
        elif path.startswith(INACTIVE_PREFIXES):
            entry.update(status="INACTIVE_RETAINED_NEW_UI", feature_identical=b == f,
                         qualification="iPad replacement rendering types inactive; existing scene/checkpoint and gelatinMotionOnly helpers remain active. Phone overview remains active.")
        elif b == f:
            entry.update(status="BACKEND_RETAINED", feature_identical=True)
        else:
            entry.update(status="DOWNSTREAM_INTEGRATION" if path in (SIDEBAR, COMPACT, PAGER) else "UNEXPLAINED_CHANGE",
                         feature_identical=False)
        if path == IPAD and b == NATIVE_IPAD_BLOB:
            entry.update(approval_reference=NATIVE_OWNER_REPLY,
                         necessity="Original shared-sidebar composition plus exact newly approved native TOC/search/toggle ownership hook.")
        if path == PAGER:
            entry.update(necessity="One active original navigation owner and public native split configuration; no reader or toolbar replacement.",
                         reviewed_blob=NATIVE_PAGER_BLOB,
                         release_11001_diff=git("diff", "--no-ext-diff", RELEASE_11001, ref, "--", path))
        entries.append(entry)
    return {"schema_version": 1, "baseline_9401_sha": BASE, "feature_base_sha": FEATURE,
            "upstream_sha": UPSTREAM, "source_commit": final_sha,
            "source_commit_note": "Source/build blobs pinned to this commit. Later evidence-only commits must preserve every listed final_blob; verifier compares them to --ref.",
            "scope": "All original Source files (conservative superset of iPad visual dependencies), all current Source, vendor/build/workflow/lock contracts.",
            "status": "GIT_SOURCE_INVENTORY_NOT_DEVICE_ACCEPTANCE", "files": entries}


def source_issues(files, baseline):
    issues = []
    def string(path):
        return files.get(path, b"").decode("utf-8")
    ipad, reader, workspace, sidebar = map(string, (IPAD, READER, WORKSPACE, SIDEBAR))
    # Freeze the original shell and all unaffected original blocks. A declared
    # composition exception must never become permission for arbitrary edits.
    original_ipad = baseline[IPAD].decode("utf-8")
    def root_body(text):
        return text.split("    var body: some View {", 1)[-1].split("    // MARK: - Tab Contents", 1)[0]
    if root_body(ipad) != root_body(original_ipad):
        issues.append("ORIGINAL_GLOBAL_TABS_CHANGED")
    def member(text, name):
        match = re.search(r"^    private (?:var|func) " + re.escape(name) + r"\b", text, re.M)
        if not match:
            return None
        start = text.find("{", match.end())
        depth = 0
        for index in range(start, len(text)):
            if text[index] == "{":
                depth += 1
            elif text[index] == "}":
                depth -= 1
                if depth == 0:
                    return text[match.start():index + 1]
        return None
    for name in ("activeReaderTab", "selectedTOCNode", "closeTableOfContents", "searchTabContent", "searchSidebarContent",
                 "authorTabContent", "annotationsTabContent", "historyTabContent"):
        if member(ipad, name) != member(original_ipad, name):
            issues.append("UNAPPROVED_IPAD_BLOCK:" + name)
    original_workspace = baseline[WORKSPACE].decode("utf-8")
    for name in ("readerSurface", "floatingWorkspace", "panelResizeHandle", "inspectorPanel", "compactStudyPanel",
                 "readerHeaderTitle", "readerHeaderSubtitle", "selectedTOCNode", "annotationEditor", "annotationEditorBinding",
                 "selectTOCNode", "toggleStudyPanel", "compactPanelDidDismiss", "addNote", "openNote", "deleteNote", "finishEditingAnnotation"):
        if member(workspace, name) != member(original_workspace, name):
            issues.append("UNAPPROVED_WORKSPACE_BLOCK:" + name)
    viewer = ipad.split("private var viewerTabContent", 1)[-1].split("private var activeReaderTableOfContents", 1)[0]
    for name in ("ChavrusaReaderHost(", "DocumentTabsHost(", "TabsBarViewController(", "TabSwitcherPagePort(", "StudyGroupsOverview(", "SafariLibrarySearchField("):
        if name in viewer + workspace + reader + sidebar:
            issues.append("FORBIDDEN_ACTIVE_UI:" + name)
    for path in (TOC, ROWS, TABS, "Source/Features/Reader/iOS/Toolbar/ReaderTabItemView.swift",
                 "Source/Features/Reader/iOS/Toolbar/iOSReaderTabsPopoverView.swift",
                 "Source/UI/iOS/Theme/ThemeComponents.swift"):
        if files.get(path) != baseline.get(path):
            issues.append("EXACT_BLOB_REQUIRED:" + path)
    # Protect the complete original toolbar subtree, not just existence of one button.
    original_reader = baseline[READER].decode("utf-8")
    def toolbar(text):
        return text.split("        .toolbar {", 1)[-1].split("        .onChange(of: initialContentId)", 1)[0]
    if toolbar(reader) != toolbar(original_reader):
        issues.append("ORIGINAL_TOOLBAR_CHANGED")
    if "ToolbarItem(placement: .principal)" in viewer or ".navigationTitle(" in sidebar:
        issues.append("DUPLICATE_TITLE_BAR")
    if viewer.count("iOSReaderTabView(") != 1 or "} content: {" in viewer:
        issues.append("SINGLE_READER_TWO_COLUMN_REQUIRED")
    if "ReaderSidebarPager(coordinator: sidebar)" not in viewer or "iOSTOCView(" not in ipad:
        issues.append("ORIGINAL_SIDEBAR_COMPONENTS_MISSING")
    if sidebar.count('systemImage: "magnifyingglass"') != 1 or viewer.count("Exact9401ViewerToolbar(") != 1:
        issues.append("ONE_PALETTE_LAUNCHER_REQUIRED")
    if sidebar.count("LibraryCommandPaletteAdapter(") != 1 or files.get(PALETTE) != content(FEATURE, PALETTE):
        issues.append("CURRENT_PALETTE_MUST_BE_REUSED")
    if (sidebar.count("StudyProfileMenu(") != 1 or "usesNativeToolbar: true" not in sidebar
            or sidebar.count("StudyProfileManagementView(") != 1):
        issues.append("NATIVE_PROFILE_TOOLBAR_REQUIRED")
    def profile_actions(text):
        return re.sub(r"\s+", "", text.split("ForEach((workspace.store.snapshot?.profiles", 1)[-1].split("action: onManage)", 1)[0])
    if profile_actions(string(PROFILE_MENU)) != profile_actions(content(FEATURE, PROFILE_MENU).decode("utf-8")):
        issues.append("PROFILE_ACTIONS_CHANGED")
    if files.get(PROFILE_MANAGEMENT) != content(FEATURE, PROFILE_MANAGEMENT):
        issues.append("CURRENT_PROFILE_MANAGEMENT_CHANGED")
    compact = string(COMPACT)
    if (compact.count("Exact9401WorkspaceLifecycle(") != 1 or "await adapter.attach(manager)" not in sidebar
            or "StudyWorkspaceCheckpointObserver(manager: manager, workspace: workspace)" not in sidebar
            or "if MaktabahApp.isIpad" not in sidebar):
        issues.append("FEATURE_COORDINATOR_MISSING")
    if "sidebarCoordinator.page == .contents" not in reader or "sidebarCoordinator.showContents()" not in workspace:
        issues.append("BLOCKED_SHARED_TOC_ACTION_HOOK")
    if ("wideWorkspace(totalWidth: geometry.size.width)\n            } else if useWideLayout" not in workspace
            or ".modifier(SharedSidebarFloatingPanel(" not in workspace):
        issues.append("BLOCKED_STABLE_READER_GEOMETRY_HOOK")
    issues.extend(native_sidebar_issues(files))
    return issues


def native_sidebar_issues(files):
    """Static composition/configuration checks, never runtime geometry acceptance."""
    text = lambda path: files.get(path, b"").decode("utf-8")
    ipad, pager, toc, workspace = map(text, (IPAD, PAGER, TOC, WORKSPACE))
    active_toc = ipad.split("private var activeReaderTableOfContents", 1)[-1].split("private var activeReaderTab", 1)[0]
    viewer = ipad.split("private var viewerTabContent", 1)[-1].split("private var activeReaderTableOfContents", 1)[0]
    issues = []
    if ("embedsNavigationStack: true" not in active_toc
            or "embedsNavigationStack: false" in active_toc
            or ".toolbarVisibility(" in viewer
            or re.search(r"\bNavigationStack\s*\{", pager.split("struct ReaderSidebarPager", 1)[-1].split("private var sidebarSwipe", 1)[0].split("var body:", 1)[-1])):
        issues.append("NATIVE_TOC_NAVIGATION_OWNER_REQUIRED")
    if ('.searchable(text: $searchText, prompt: String(localized: "Search Contents"))' not in toc
            or "TOCNodeRow(" not in toc or "scrollSelected(proxy: proxy)" not in toc
            or 'prompt: String(localized: "Search Library")' not in viewer):
        issues.append("ORIGINAL_NATIVE_SEARCH_AND_TOC_REQUIRED")
    if not re.search(r"Group\s*\{\s*if coordinator\.page == \.library\s*\{\s*library\(true\)\s*\}\s*else\s*\{\s*contents\(true\)\s*\}\s*\}", pager):
        issues.append("ONE_ACTIVE_SIDEBAR_PAGE_REQUIRED")
    if any(token in pager for token in (".opacity(", "ZStack {", "NavigationSplitView(", "UISplitViewController(", "UIHostingController(", ".offset(", "UIScreen.main", "split.delegate =")):
        issues.append("NO_COMPETING_SIDEBAR_OR_READER_OVERLAY")
    if (".toolbar(removing: .sidebarToggle)" in viewer + active_toc
            or "split.displayModeButtonVisibility = .always" not in pager
            or "ToolbarItem(" in pager
            or not re.search(r"if #available\(iOS 27\.0, \*\)\s*\{\s*if split\.displayModeButtonVisibility != \.always\s*\{\s*split\.displayModeButtonVisibility = \.always\s*\}", pager)):
        issues.append("REACHABLE_SINGLE_NATIVE_SIDEBAR_TOGGLE_REQUIRED")
    if (".background { ReaderSidebarSplitConfiguration() }" not in pager
            or "guard let split = splitViewController, split.style == .doubleColumn" not in pager
            or "ReaderSidebarPolicy.canTile(" not in pager
            or "UISplitViewController.SplitBehavior.tile" not in pager
            or "split.preferredSplitBehavior = behavior" not in pager
            or "split.view.safeAreaLayoutGuide.layoutFrame.width" not in pager
            or "UIFontMetrics.default.scaledValue" not in pager
            or "split.isCollapsed" not in pager
            or "restoreConfiguration()" not in pager
            or "split.preferredDisplayMode =" in pager):
        issues.append("ADAPTIVE_NATIVE_TILE_CONFIGURATION_REQUIRED")
    controls = pager.split(".safeAreaInset(edge: .bottom, spacing: 0)", 1)
    if (len(controls) != 2 or ".simultaneousGesture(sidebarSwipe)" in controls[0]
            or controls[1].count(".simultaneousGesture(sidebarSwipe)") != 1
            or "isRTL: layoutDirection == .rightToLeft" not in pager):
        issues.append("PAGE_GESTURE_MUST_LEAVE_NATIVE_EDGE_AND_LIST_FREE")
    if (viewer.count("iOSReaderTabView(") != 1 or "} content: {" in viewer
            or "sidebarCoordinator.showContents()\n            preferredCompactColumn = .sidebar" not in workspace
            or "withAnimation(.snappy(duration: 0.34, extraBounce: 0)) { libraryColumnVisibility = .all }\n            return" not in workspace
            or "tab.viewModel.didSelectTOCNode(id: id)" not in active_toc):
        issues.append("SHARED_TOC_BINDING_AND_ORIGINAL_READER_REQUIRED")
    return issues


def native_approval_issues(record, patch):
    if (record.get("status") != "APPROVED_EXACT_HUNK" or record.get("applied") is not True
            or record.get("file") != IPAD or record.get("starting_sha") != "8632dd3165c9dabdee62931f0e011f542b4bc815"
            or record.get("before_blob") != "80154afddb61a6ef19b04044287851c396057e9e"
            or record.get("proposed_blob") != NATIVE_IPAD_BLOB
            or record.get("owner_approval_reference") != NATIVE_OWNER_REPLY
            or record.get("patch_sha256") != NATIVE_PATCH_SHA256
            or hashlib.sha256(patch).hexdigest() != NATIVE_PATCH_SHA256):
        return ["EXACT_NATIVE_SIDEBAR_APPROVAL_INVALID"]
    return []


def approval_issues(record, patch):
    if (record.get("status") != "APPROVED_EXACT_HUNK" or record.get("path") != READER
            or record.get("proposed_blob") != APPROVED_READER_BLOB or record.get("applied") is not True
            or not record.get("authorization_reference")
            or hashlib.sha256(patch).hexdigest() != record.get("diff_sha256")):
        return ["EXACT_READER_APPROVAL_INVALID"]
    return []


def verify(manifest, ref):
    final, original_tree, feature_tree = tree(ref), tree(BASE), tree(FEATURE)
    failures = []
    if (manifest.get("baseline_9401_sha") != BASE or manifest.get("feature_base_sha") != FEATURE
            or manifest.get("upstream_sha") != UPSTREAM):
        failures.append("PINNED_PROVENANCE_MISMATCH")
    paths = {entry["path"] for entry in manifest["files"]}
    for path in tree(BASE):
        if path.startswith("Source/") and path not in paths:
            failures.append("MISSING_ORIGINAL_INVENTORY:" + path)
    for path in final:
        if path.startswith("Source/") and path not in paths:
            failures.append("MISSING_CURRENT_INVENTORY:" + path)
    for entry in manifest["files"]:
        path, status = entry["path"], entry["status"]
        if entry["baseline_blob"] != original_tree.get(path, {}).get("blob") or entry["feature_blob"] != feature_tree.get(path, {}).get("blob"):
            failures.append("FORGED_PROVENANCE:" + path)
        if final.get(path, {}).get("blob") != entry["final_blob"]:
            failures.append("FINAL_BLOB_DRIFT:" + path)
        if status == "EXACT_9401_BLOB" and (not entry["baseline_blob"] or entry["baseline_blob"] != entry["final_blob"]):
            failures.append("FALSE_EXACT_CLAIM:" + path)
        if status == "DECLARED_EXCEPTION":
            scoped = path in SEAM_REASONS and entry.get("approval_state") == "SCOPED_DIRECTIVE_A_B"
            retained = (path in RETAINED_EXCEPTIONS and entry.get("approval_state") == "RETAINED_UNEDITED_FEATURE_BASE"
                        and entry["feature_blob"] == entry["final_blob"])
            approved_reader = (path == READER and entry.get("approval_state") == "EXPLICIT_OWNER_EXACT_HUNK"
                               and entry["final_blob"] == APPROVED_READER_BLOB)
            approved_native = (path == IPAD and entry.get("approval_state") == "EXPLICIT_OWNER_NATIVE_SIDEBAR_HUNK"
                               and entry["final_blob"] == NATIVE_IPAD_BLOB)
            if not (scoped or retained or approved_reader or approved_native):
                failures.append("OWNER_HUNK_REVIEW_REQUIRED:" + path)
            if entry.get("exact_diff") != git("diff", "--no-ext-diff", BASE, ref, "--", path):
                failures.append("EXCEPTION_DIFF_DRIFT:" + path)
            if entry.get("unchanged_blocks") != unchanged_blocks(content(BASE, path), content(ref, path)):
                failures.append("UNCHANGED_BLOCK_EVIDENCE_DRIFT:" + path)
        if status in ("BACKEND_RETAINED", "INACTIVE_RETAINED_NEW_UI") and entry["feature_blob"] != entry["final_blob"]:
            failures.append("FEATURE_RETENTION_FAILED:" + path)
        if status == "UNEXPLAINED_CHANGE":
            failures.append(status + ":" + path)
        if status == "ACTIVE_PROFILE_UI" and path not in (PROFILE_MENU, PROFILE_MANAGEMENT):
            failures.append("PROFILE_SCOPE_BYPASS:" + path)
        if path in original_tree and visual(path) and status not in ("EXACT_9401_BLOB", "DECLARED_EXCEPTION"):
            failures.append("VISUAL_CLASSIFICATION_BYPASS:" + path)
    files, original = swift_snapshot(ref), swift_snapshot(BASE)
    if final.get(READER, {}).get("blob") != original_tree[READER]["blob"]:
        if APPROVAL not in final or APPROVED_PATCH not in final:
            failures.append("EXACT_READER_APPROVAL_MISSING")
        else:
            failures.extend(approval_issues(json.loads(content(ref, APPROVAL)), content(ref, APPROVED_PATCH)))
    failures.extend(source_issues(files, original))
    if final.get(IPAD, {}).get("blob") != NATIVE_IPAD_BLOB:
        failures.append("EXACT_NATIVE_IPAD_HUNK_REQUIRED")
    if final.get(PAGER, {}).get("blob") != NATIVE_PAGER_BLOB:
        failures.append("NATIVE_PAGER_REVIEWED_SOURCE_DRIFT")
    if NATIVE_APPROVAL not in final or NATIVE_PATCH not in final:
        failures.append("EXACT_NATIVE_SIDEBAR_APPROVAL_MISSING")
    else:
        failures.extend(native_approval_issues(json.loads(content(ref, NATIVE_APPROVAL)), content(ref, NATIVE_PATCH)))
    release = tree(RELEASE_11001)
    for path in set(release) | set(final):
        if path not in (IPAD, PAGER) and (path.startswith(("Source/", "Vendor/", "Packages/", "Maktabah.xcodeproj/", ".github/workflows/"))
                or path in ("Podfile", "Podfile.lock", ".gitmodules") or path.endswith(("Package.resolved", "Cargo.lock"))):
            if release.get(path, {}).get("blob") != final.get(path, {}).get("blob"):
                failures.append("RETAINED_11001_CONTRACT_DRIFT:" + path)
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", default="HEAD")
    parser.add_argument("--generate", action="store_true", help="Generate evidence; never grants gate approval")
    parser.add_argument("--audit-only", action="store_true")
    args = parser.parse_args()
    DOCS.mkdir(exist_ok=True, parents=True)
    if args.audit_only:
        (DOCS / "9401_before_edit_ownership_matrix.json").write_text(
            json.dumps(before_inventory(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("Recorded all 15 changed original visual files and their exact pre-edit Git hunks.")
        return 0
    if args.generate:
        for name, value in (("9401_before_edit_ownership_matrix.json", before_inventory()),
                            ("9401_exact_source_manifest.json", make_manifest(args.ref))):
            (DOCS / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest = json.loads((DOCS / "9401_exact_source_manifest.json").read_text(encoding="utf-8"))
    failures = verify(manifest, args.ref)
    print(json.dumps({"ref": git("rev-parse", args.ref).strip(),
                      "inventory_counts": dict(Counter(e["status"] for e in manifest["files"])),
                      "gate": "FAIL_CLOSED" if failures else "PASS",
                      "failures": failures, "device_acceptance": "OWNER_DEVICE_ACCEPTANCE_PENDING"},
                     ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
