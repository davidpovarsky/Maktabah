#!/usr/bin/env python3
import copy
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path.cwd()


def run(args, *, check=True, text=True, input=None):
    return subprocess.run(args, check=check, text=text, input=input, capture_output=True)


def git_show(stage: int, path: str) -> str:
    result = run(["git", "show", f":{stage}:{path}"], check=False)
    if result.returncode != 0:
        raise RuntimeError(f"missing stage {stage} for {path}: {result.stderr}")
    return result.stdout


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str):
    (ROOT / path).write_text(content, encoding="utf-8")


def resolve_markers(path: str, choice: str):
    if choice not in {"ours", "theirs"}:
        raise ValueError(choice)
    text = read(path)
    lines = text.splitlines(keepends=True)
    out = []
    ours = []
    theirs = []
    state = "normal"
    for line in lines:
        if state == "normal":
            if line.startswith("<<<<<<< "):
                state = "ours"
                ours = []
                theirs = []
            else:
                out.append(line)
        elif state == "ours":
            if line.startswith("||||||| "):
                state = "base"
            elif line.startswith("======="):
                state = "theirs"
            else:
                ours.append(line)
        elif state == "base":
            if line.startswith("======="):
                state = "theirs"
        elif state == "theirs":
            if line.startswith(">>>>>>> "):
                out.extend(ours if choice == "ours" else theirs)
                state = "normal"
            else:
                theirs.append(line)
    if state != "normal":
        raise RuntimeError(f"unterminated conflict in {path}: {state}")
    write(path, "".join(out))


def checkout_theirs(path: str):
    write(path, git_show(3, path))


def merge_union(path: str):
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        ours = td / "ours"
        base = td / "base"
        theirs = td / "theirs"
        ours.write_text(git_show(2, path), encoding="utf-8")
        base.write_text(git_show(1, path), encoding="utf-8")
        theirs.write_text(git_show(3, path), encoding="utf-8")
        result = run(["git", "merge-file", "--union", "-p", str(ours), str(base), str(theirs)], check=False)
        if result.returncode not in (0, 1):
            raise RuntimeError(f"merge-file failed for {path}: {result.stderr}")
        write(path, result.stdout)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one occurrence, found {count}")
    return text.replace(old, new, 1)


def replace_function(text: str, signature: str, replacement: str) -> str:
    start = text.find(signature)
    if start < 0:
        raise RuntimeError(f"function signature not found: {signature}")
    brace = text.find("{", start)
    if brace < 0:
        raise RuntimeError(f"opening brace not found: {signature}")
    depth = 0
    i = brace
    in_string = False
    escaped = False
    while i < len(text):
        ch = text[i]
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
        else:
            if ch == '"':
                in_string = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return text[:start] + replacement + text[i + 1:]
        i += 1
    raise RuntimeError(f"unterminated function: {signature}")


def merge_localizations():
    path = "Source/Localizable.xcstrings"
    ours = json.loads(git_show(2, path))
    upstream = json.loads(git_show(3, path))
    merged = copy.deepcopy(upstream)
    merged_strings = merged.setdefault("strings", {})
    ours_strings = ours.get("strings", {})
    for key, ours_entry in ours_strings.items():
        if key not in merged_strings:
            merged_strings[key] = copy.deepcopy(ours_entry)
            continue
        ours_he = ours_entry.get("localizations", {}).get("he")
        if ours_he is not None:
            merged_strings[key].setdefault("localizations", {})["he"] = copy.deepcopy(ours_he)
    write(path, json.dumps(merged, ensure_ascii=False, indent=2, sort_keys=False) + "\n")


def patch_codeql():
    path = ".github/workflows/codeql.yml"
    resolve_markers(path, "theirs")
    text = read(path)
    if "workflow_dispatch:" not in text:
        text = replace_once(text, "on:\n", "on:\n  workflow_dispatch:\n", "codeql workflow_dispatch")
    write(path, text)


def patch_book_connection():
    path = "Source/Managers/Database/BookConnection.swift"
    resolve_markers(path, "theirs")
    text = read(path)
    if "OtzariaBookConnectionAdapter.isEnabled, Int(bkid) != nil" not in text:
        pattern = re.compile(r"(\s+func getContent\(bkid: String, contentId: Int, quran: Bool = false\)\s*\n\s*-> BookContent\?\s*\n\s*\{\n)")
        m = pattern.search(text)
        if not m:
            raise RuntimeError("BookConnection getContent signature not found")
        hook = (
            "        if OtzariaBookConnectionAdapter.isEnabled, Int(bkid) != nil {\n"
            "            return OtzariaBookConnectionAdapter.getContent(\n"
            "                bkid: bkid,\n"
            "                contentId: contentId\n"
            "            )\n"
            "        }\n\n"
        )
        text = text[:m.end()] + hook + text[m.end():]
    for function, adapter in (("getNextPage", "getNextPage"), ("getPrevPage", "getPrevPage")):
        needle = f"return OtzariaBookConnectionAdapter.{adapter}("
        if needle in text:
            continue
        pattern = re.compile(
            rf"(\s+func {function}\(\n\s*from currentBook: BooksData,\n\s*contentId: Int,\n\s*quran: Bool = false\n\s*\) -> BookContent\? \{{\n)"
        )
        m = pattern.search(text)
        if not m:
            raise RuntimeError(f"BookConnection {function} signature not found")
        hook = (
            "        if OtzariaBookConnectionAdapter.isEnabled {\n"
            f"            return OtzariaBookConnectionAdapter.{adapter}(\n"
            "                from: currentBook,\n"
            "                contentId: contentId\n"
            "            )\n"
            "        }\n\n"
        )
        text = text[:m.end()] + hook + text[m.end():]
    write(path, text)


def patch_library_data_manager():
    path = "Source/Managers/Database/LibraryDataManager.swift"
    resolve_markers(path, "theirs")
    text = read(path)
    if "OtzariaLibraryDataAdapter.performSearchIfEnabled" not in text:
        marker = "        let allowed = tableToScan\n"
        hook = """

        if await OtzariaLibraryDataAdapter.performSearchIfEnabled(
            tableToScan: allowed,
            query: query,
            mode: mode,
            onInitialize: onInitialize,
            onTableProgress: onTableProgress,
            onRowProgress: onRowProgress,
            completion: completion,
            onComplete: onComplete
        ) {
            return
        }
"""
        text = replace_once(text, marker, marker + hook, "LibraryDataManager Otzaria search hook")
    write(path, text)


def patch_reader_view_model():
    path = "Source/Managers/ViewModels/ReaderViewModel.swift"
    resolve_markers(path, "theirs")
    text = read(path)
    if "func getCopyReference(for selectedText: String)" not in text:
        anchor = """    var currentBookContent: BookContent? {
        guard let bkId = currentBook?.id else { return nil }
        return BookPageCache.shared.get(bookId: bkId, contentId: currentContentId)
    }
"""
        helpers = r'''

    /// Helper for copy functionality, preserving Otzaria Hebrew references.
    func getCopyReference(for selectedText: String) -> String {
        let bookName = currentBook?.book ?? ""
        var referencePage: [String] = []

        if let otzariaReference = otzariaCurrentReferencePage() {
            referencePage.append(otzariaReference)
        } else {
            if let part = currentPart, part != -1 {
                referencePage.append("ج: \(part)".convertToArabicDigits())
            }
            if let page = currentPage {
                referencePage.append("ص: \(page)".convertToArabicDigits())
            }
        }

        let referenceLines = "~ \(bookName) - \(referencePage.joined(separator: " • "))"
        return "\(selectedText)\n\n__________\n\(referenceLines)"
    }

    /// Helper for share functionality, preserving Otzaria Hebrew references.
    func getShareReference(for selectedText: String) -> String {
        let bookName = currentBook?.book ?? ""
        var referencePage: [String] = []

        if let otzariaReference = otzariaCurrentReferencePage() {
            referencePage.append(otzariaReference)
        } else {
            if let part = currentPart, part != -1 {
                referencePage.append("ج: \(part)".convertToArabicDigits())
            }
            if let page = currentPage {
                referencePage.append("ص: \(page)".convertToArabicDigits())
            }
        }

        let referenceLines = "~ \(bookName) - \(referencePage.joined(separator: " • "))"
        return "\(selectedText)\n\n\(referenceLines)"
    }
'''
        text = replace_once(text, anchor, anchor + helpers, "ReaderViewModel reference helpers")
    func_marker = "    func updateContentState(with content: BookContent) {\n"
    if "let previousContentId = currentContentId" not in text[text.find(func_marker):text.find(func_marker) + 500]:
        text = replace_once(
            text,
            func_marker,
            func_marker + "        let start = Date()\n        let previousContentId = currentContentId\n",
            "ReaderViewModel update logging state",
        )
    if "currentHeRef = content.heRef" not in text:
        text = replace_once(text, "        currentPage = content.page\n", "        currentPage = content.page\n        currentHeRef = content.heRef\n", "ReaderViewModel heRef")
    write(path, text)


def patch_app_delegate():
    path = "Source/Protocols/AppDelegate.swift"
    resolve_markers(path, "ours")
    text = read(path)
    old = """    func applicationDidBecomeActive(_ notification: Notification) {
        guard AppConfig.useICloud else { return }
        CloudKitSyncManager.shared.fetchChanges()
        DonationManager.shared.recordActivation()
        DonationManager.shared.checkAndPromptMacOSSheet(on: keyWindow ?? mainWindowController?.window)
    }
"""
    new = """    func applicationDidBecomeActive(_ notification: Notification) {
        if AppConfig.useICloud {
            CloudKitSyncManager.shared.fetchChanges()
        }
        DonationManager.shared.recordActivation()
        DonationManager.shared.checkAndPromptMacOSSheet(on: keyWindow ?? mainWindowController?.window)
    }
"""
    if old in text:
        text = text.replace(old, new, 1)
    write(path, text)


def patch_settings_view():
    path = "Source/View/SettingsView.swift"
    resolve_markers(path, "theirs")
    text = read(path)
    body_anchor = """            appearanceSection
                .listRowBackground(Color.appCellBackground)
"""
    zayit_row = """            zayitCreditsSection
                .listRowBackground(Color.appCellBackground)
"""
    form_start = text.find("        Form {")
    form_end = text.find("        }", form_start)
    body = text[form_start:form_end if form_end > form_start else form_start + 3000]
    if "zayitCreditsSection" not in body:
        text = replace_once(text, body_anchor, body_anchor + zayit_row, "SettingsView Zayit credits row")
    write(path, text)


def patch_maktabah_app():
    path = "Source/iOS/MaktabahApp.swift"
    resolve_markers(path, "theirs")
    text = read(path)
    duplicate = """    func applicationWillTerminate(_ application: UIApplication) {
        CloudKitCoreManager.shared.syncWorker()
    }
    func applicationWillTerminate(_ application: UIApplication) {
        CloudKitCoreManager.shared.syncWorker()
    }
"""
    if duplicate in text:
        text = text.replace(duplicate, """    func applicationWillTerminate(_ application: UIApplication) {
        CloudKitCoreManager.shared.syncWorker()
    }
""", 1)
    write(path, text)


def patch_bootstrap_view():
    path = "Source/iOS/Views/Bootstrap/BootstrapView.swift"
    resolve_markers(path, "ours")
    text = read(path)
    block_re = re.compile(
        r"\n\s*\.onReceive\(NotificationCenter\.default\.publisher\(for: \.requireCoreDownload\)\) \{ notification in\n"
        r"\s*let isCancellable = notification\.userInfo\?\[\"isCancellable\"\] as\? Bool \?\? false\n"
        r"\s*bootstrapManager\.reloadLibrary\(isCancellable: isCancellable\)\n\s*\}"
    )
    matches = list(block_re.finditer(text))
    if len(matches) > 1:
        for m in reversed(matches[1:]):
            text = text[:m.start()] + text[m.end():]
    text = text.replace(
        """            if newValue {
                CloudKitSyncManager.shared.fetchChanges()
            }
""",
        """            if newValue, AppConfig.useICloud {
                CloudKitSyncManager.shared.fetchChanges()
            }
""",
    )
    write(path, text)


def patch_navigation_manager():
    path = "Source/iOS/Managers/iOSNavigationManager.swift"
    resolve_markers(path, "theirs")
    text = read(path)
    if "OtzariaNavigationAdapter.openBookIfEnabled" not in text:
        signature = "    private func openBookAsync(_ book: BooksData, initialContentId: Int?, searchText: String? = nil, searchMode: SearchMode? = nil, nearDistance: Int = 10, targetAnnotation: Annotation? = nil, recordHistory: Bool = true) async {\n"
        hook = """        if OtzariaNavigationAdapter.openBookIfEnabled(
            book,
            initialContentId: initialContentId,
            searchText: searchText,
            targetAnnotation: targetAnnotation,
            presentReader: { [weak self] book, initialContentId, searchText, targetAnnotation in
                self?.presentReader(
                    book,
                    initialContentId: initialContentId,
                    searchText: searchText,
                    searchMode: searchMode,
                    nearDistance: nearDistance,
                    targetAnnotation: targetAnnotation,
                    recordHistory: recordHistory
                )
            }
        ) {
            return
        }

"""
        text = replace_once(text, signature, signature + hook, "iOSNavigationManager Otzaria open hook")
    write(path, text)


def patch_search_mode():
    path = "Source/iOS/Views/SearchModeView.swift"
    resolve_markers(path, "theirs")
    text = read(path)
    section = text[text.find("private func handleSelection"):]
    if "initialContentId: item.bookId" in section:
        before = text[:text.find("private func handleSelection")]
        section = section.replace("initialContentId: item.bookId", "initialContentId: contentId", 1)
        text = before + section
    write(path, text)


def patch_ios_library():
    path = "Source/iOS/Views/iOSLibraryView.swift"
    resolve_markers(path, "theirs")
    text = read(path)
    sig = "    private func standardToolbarItems(viewModel: LibraryViewModel) -> some ToolbarContent {"
    pos = text.find(sig)
    if pos < 0:
        raise RuntimeError("iOSLibraryView standardToolbarItems not found")
    tail = text[pos:]
    tail = tail.replace("if AppConfig.isUsingBundleMode {", "if !OtzariaLibraryImportActions.isEnabled && AppConfig.isUsingBundleMode {", 1)
    text = text[:pos] + tail
    replacement = """    private func optionsMenu(viewModel: LibraryViewModel) -> some View {
        Menu {
            Button {
                showingOtzariaImporter = true
            } label: {
                Label(String(localized: "Choose Otzaria Database"), systemImage: "externaldrive")
            }

            if OtzariaLibraryImportActions.isEnabled {
                Button(role: .destructive) {
                    OtzariaLibraryImportActions.disconnectDatabase(viewModel: viewModel)
                } label: {
                    Label(String(localized: "Disconnect Otzaria Database"), systemImage: "xmark.circle")
                }
            } else {
                Divider()

                Button {
                    viewModel.enterSelectionMode()
                } label: {
                    Label("Select".localized + "...", systemImage: "checkmark.circle")
                }

                Button {
                    viewModel.showingUpdateSheet = true
                } label: {
                    Label(
                        viewModel.availableUpdateCount > 0
                            ? "\("Update Books".localized) (\(viewModel.availableUpdateCount))"
                            : "Update Books".localized,
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }

                Button {
                    viewModel.showingImportSheet = true
                } label: {
                    Label("Import Book", systemImage: "plus.viewfinder")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(String(localized: "Library Options"))
        .help(String(localized: "Library Options"))
    }"""
    text = replace_function(text, "    private func optionsMenu(viewModel: LibraryViewModel) -> some View {", replacement)
    write(path, text)


def patch_ios_main():
    path = "Source/iOS/Views/iOSMainView.swift"
    resolve_markers(path, "theirs")
    text = read(path)
    text = text.replace(
        """            if newPhase == .active {
                CloudKitSyncManager.shared.fetchChanges()
                DonationManager.shared.recordActivation()
""",
        """            if newPhase == .active {
                if AppConfig.useICloud {
                    CloudKitSyncManager.shared.fetchChanges()
                }
                DonationManager.shared.recordActivation()
""",
        1,
    )
    write(path, text)


def patch_ipad_layout():
    path = "Source/iOS/Views/iPadLayout.swift"
    resolve_markers(path, "ours")
    text = read(path)
    if "@ObservedObject private var donationManager" not in text:
        text = replace_once(
            text,
            "    @StateObject private var historyViewModel = HistoryViewModel.shared\n",
            "    @StateObject private var historyViewModel = HistoryViewModel.shared\n    @ObservedObject private var donationManager = DonationManager.shared\n",
            "iPad donation manager",
        )
    if "DonationHistoryButton" not in text:
        anchor = "\n    @ViewBuilder\n    private var detailContent: some View {"
        idx = text.find(anchor)
        if idx < 0:
            raise RuntimeError("iPad detailContent anchor not found")
        prefix = text[:idx]
        close = prefix.rfind("        }\n    }")
        if close < 0:
            raise RuntimeError("iPad sidebar closing anchor not found")
        donation = """

            if donationManager.shouldShowDonation {
                Section {
                    DonationHistoryButton {
                        donationManager.showDonationSheet = true
                    }
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
"""
        text = text[:close] + donation + text[close:]
    write(path, text)


def patch_ibarot():
    path = "Source/iOS/Wrappers/iOSIbarotTextView.swift"
    resolve_markers(path, "theirs")
    text = read(path)
    old = """        // Restore Scroll & Selection exactly once per content ID
        if context.coordinator.restoredContentId != viewModel.currentContentId ||
            viewModel.needsScrollRestore
        {
            if let scroll = viewModel.readerState.scrollPosition {
                textView.setContentOffset(scroll, animated: false)
            } else {
                textView.setContentOffset(CGPoint(x: 0, y: -textView.adjustedContentInset.top), animated: false)
            }
            if let range = viewModel.readerState.selectedRange {
                textView.selectedRange = range
            }
            viewModel.needsScrollRestore = false
            context.coordinator.restoredContentId = viewModel.currentContentId
        }
"""
    new = """        if contentIdChanged {
            textView.selectedRange = NSRange(location: 0, length: 0)
        }

        if let pendingTarget = viewModel.consumePendingReaderScrollTarget() {
            switch pendingTarget {
            case .top:
                scrollTextViewToTop(textView)
            case .bottom:
                scrollTextViewToBottom(textView)
                let expectedContentId = viewModel.currentContentId
                DispatchQueue.main.async { [weak textView, weak viewModel] in
                    guard let textView, let viewModel, viewModel.currentContentId == expectedContentId else { return }
                    self.scrollTextViewToBottom(textView)
                }
            }
            viewModel.needsScrollRestore = false
            context.coordinator.restoredContentId = viewModel.currentContentId
        } else if context.coordinator.restoredContentId != viewModel.currentContentId ||
                    viewModel.needsScrollRestore
        {
            if let scroll = viewModel.readerState.scrollPosition {
                textView.setContentOffset(scroll, animated: false)
            } else {
                textView.setContentOffset(CGPoint(x: 0, y: -textView.adjustedContentInset.top), animated: false)
            }
            if let range = viewModel.readerState.selectedRange {
                textView.selectedRange = range
            }
            viewModel.needsScrollRestore = false
            context.coordinator.restoredContentId = viewModel.currentContentId
        }
"""
    text = replace_once(text, old, new, "iOSIbarot combined search/scroll restore")
    write(path, text)


def assert_contains(path: str, needle: str):
    if needle not in read(path):
        raise RuntimeError(f"required invariant missing from {path}: {needle}")


def assert_invariants():
    unmerged = run(["git", "diff", "--name-only", "--diff-filter=U"]).stdout.strip()
    if unmerged:
        raise RuntimeError(f"unmerged paths remain:\n{unmerged}")
    conflict_scan = run(["git", "grep", "-n", "^<<<<<<<\\|^=======\\|^>>>>>>>"], check=False)
    if conflict_scan.returncode == 0 and conflict_scan.stdout.strip():
        raise RuntimeError(f"conflict markers remain:\n{conflict_scan.stdout}")

    assert_contains("Source/Models/DataModel.swift", "heRef")
    assert_contains("Source/Models/DataModel.swift", "orderIndex")
    assert_contains("Source/Models/DataModel.swift", "totalLines")
    assert_contains("Source/Models/DataModel.swift", "entryId")
    assert_contains("Source/Managers/Engine/SearchEngine.swift", "workersLock")
    assert_contains("Source/Managers/Database/BookConnection.swift", "OtzariaBookConnectionAdapter.isEnabled")
    assert_contains("Source/Managers/Database/LibraryDataManager.swift", "OtzariaLibraryDataAdapter.performSearchIfEnabled")
    assert_contains("Source/iOS/Managers/BootstrapManager.swift", "OtzariaBootstrapAdapter.restoreForAppLaunch")
    assert_contains("Source/iOS/Managers/iOSNavigationManager.swift", "OtzariaNavigationAdapter.openBookIfEnabled")
    assert_contains("Source/iOS/Views/SearchModeView.swift", "otzaria:")
    assert_contains("Source/iOS/Views/iPadLayout.swift", "UnifiedSearchWorkspaceView")
    assert_contains("Source/iOS/Views/iPadLayout.swift", "ZayitSearchView")
    assert_contains("Source/iOS/MaktabahApp.swift", "UserDefaults.standard.set(false, forKey: AppConfig.useICloudKey)")
    assert_contains("Source/Localizable.xcstrings", '"he"')
    assert_contains("Source/Localizable.xcstrings", "Otzaria Library Required")
    assert_contains("Maktabah.xcodeproj/project.pbxproj", "OtzariaDatabaseBootstrapService.swift")
    assert_contains("Maktabah.xcodeproj/project.pbxproj", "UnifiedSearchWorkspaceView.swift")

    settings_defs = run(["git", "grep", "-n", "final class SettingsViewModel", "--", "Source"]).stdout.strip().splitlines()
    if len(settings_defs) != 1:
        raise RuntimeError(f"expected exactly one SettingsViewModel definition, found {len(settings_defs)}: {settings_defs}")

    catalog = json.loads(read("Source/Localizable.xcstrings"))
    he_count = sum(1 for entry in catalog.get("strings", {}).values() if "he" in entry.get("localizations", {}))
    if he_count < 10:
        raise RuntimeError(f"Hebrew localization merge looks suspicious: only {he_count} Hebrew entries")
    print(f"Hebrew localization entries preserved: {he_count}")


def main():
    expected_conflicts = {
        ".github/workflows/codeql.yml",
        ".github/workflows/release.yml",
        "Maktabah.xcodeproj/project.pbxproj",
        "Source/Localizable.xcstrings",
        "Source/Managers/App Config/SettingsActions.swift",
        "Source/Managers/CloudKit/CloudKitCoreManager.swift",
        "Source/Managers/Database/BookConnection.swift",
        "Source/Managers/Database/DatabaseManager.swift",
        "Source/Managers/Database/LibraryDataManager.swift",
        "Source/Managers/ViewModels/AnnotationViewModel.swift",
        "Source/Managers/ViewModels/LibraryViewModel.swift",
        "Source/Managers/ViewModels/ReaderViewModel.swift",
        "Source/Protocols/AppDelegate.swift",
        "Source/Reader/Annotations/AnnotationsVC.swift",
        "Source/View/CoreDownloadProgressView.swift",
        "Source/View/SettingsView.swift",
        "Source/iOS/MaktabahApp.swift",
        "Source/iOS/Managers/BootstrapManager.swift",
        "Source/iOS/Managers/iOSNavigationManager.swift",
        "Source/iOS/Views/Bootstrap/BootstrapView.swift",
        "Source/iOS/Views/HistoryFavoriteSections.swift",
        "Source/iOS/Views/SearchModeView.swift",
        "Source/iOS/Views/iOSHistoryView.swift",
        "Source/iOS/Views/iOSLibraryView.swift",
        "Source/iOS/Views/iOSMainView.swift",
        "Source/iOS/Views/iPadLayout.swift",
        "Source/iOS/Wrappers/iOSIbarotTextView.swift",
    }
    actual = set(run(["git", "diff", "--name-only", "--diff-filter=U"]).stdout.splitlines())
    if actual != expected_conflicts:
        missing = sorted(expected_conflicts - actual)
        extra = sorted(actual - expected_conflicts)
        raise RuntimeError(f"conflict set changed; refusing blind resolution. missing={missing}, extra={extra}")

    patch_codeql()
    resolve_markers(".github/workflows/release.yml", "theirs")
    merge_union("Maktabah.xcodeproj/project.pbxproj")
    merge_localizations()
    resolve_markers("Source/Managers/App Config/SettingsActions.swift", "theirs")
    checkout_theirs("Source/Managers/CloudKit/CloudKitCoreManager.swift")
    patch_book_connection()
    resolve_markers("Source/Managers/Database/DatabaseManager.swift", "theirs")
    patch_library_data_manager()
    resolve_markers("Source/Managers/ViewModels/AnnotationViewModel.swift", "theirs")
    resolve_markers("Source/Managers/ViewModels/LibraryViewModel.swift", "theirs")
    patch_reader_view_model()
    patch_app_delegate()
    resolve_markers("Source/Reader/Annotations/AnnotationsVC.swift", "theirs")
    resolve_markers("Source/View/CoreDownloadProgressView.swift", "ours")
    patch_settings_view()
    patch_maktabah_app()
    resolve_markers("Source/iOS/Managers/BootstrapManager.swift", "ours")
    patch_navigation_manager()
    patch_bootstrap_view()
    checkout_theirs("Source/iOS/Views/HistoryFavoriteSections.swift")
    patch_search_mode()
    checkout_theirs("Source/iOS/Views/iOSHistoryView.swift")
    patch_ios_library()
    patch_ios_main()
    patch_ipad_layout()
    patch_ibarot()

    run(["git", "add", "-A"])
    assert_invariants()
    run(["git", "diff", "--cached", "--check"])
    print("Semantic merge resolution completed successfully.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"RESOLVER ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
