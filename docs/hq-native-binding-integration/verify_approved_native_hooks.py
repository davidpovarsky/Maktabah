"""Verify actual approved property/lifetime hook bodies with portable shells.

This is not an Apple SDK or full native-manager build. No app or user data runs.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "approved-hook-checks"
OUT.mkdir(exist_ok=True)
SOURCE = "Source/UI/iOS/Managers/iOSNavigationManager.swift"
BASE = "f2b4ea3a6b0646330ebdd07d1ae4726800e960a1"


def block(text, marker):
    start = text.index(marker)
    end = text.index("{", start) + 1
    depth = 1
    while depth:
        depth += (text[end] == "{") - (text[end] == "}")
        end += 1
    return text[start:end]


SHELL = r'''
import Foundation
import Observation
struct BooksData { let id: Int }
@MainActor final class ReaderViewModel {}
@MainActor final class SearchViewModel {}
@MainActor final class UnifiedSearchSessionController {
    var searchViewModel: SearchViewModel?
}
@MainActor protocol BackendSwitchParticipant: AnyObject {}
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var registered = Set<ObjectIdentifier>()
    func addSwitchParticipant(_ owner: iOSNavigationManager) {
        registered.insert(ObjectIdentifier(owner))
    }
}
@MainActor enum StudyWorkspaceNavigationAdapter {
    static var events: [String] = []
    static func nativeMappingOwnerInitialized(_ owner: iOSNavigationManager) {
        events.append(BackendCoordinator.shared.registered.contains(ObjectIdentifier(owner))
            ? "init-after-registration" : "wrong-init-order")
    }
    static func nativeMappingTabsWillChange(_ owner: iOSNavigationManager,
        to tabs: [iOSNavigationManager.ReaderTab]) {
        events.append("tabs-before:\(owner.openTabs.count)->\(tabs.count)")
    }
    static func nativeMappingSelectionWillChange(_ owner: iOSNavigationManager, to id: UUID?) {
        events.append("selection-before:\(owner.activeTabId == nil ? "nil" : "set")->\(id == nil ? "nil" : "set")")
    }
    static func nativeMappingDidChange(_ owner: iOSNavigationManager) {
        events.append("after:\(owner.openTabs.count):\(owner.activeTabId == nil ? "nil" : "set")")
    }
    static func nativeMappingOwnerWillDeinitialize(_ owner: iOSNavigationManager) {
        events.append("owner-deinit")
    }
}
'''

TESTS = r'''
@main struct ApprovedHookChecks {
    @MainActor static func main() {
        var failures = 0
        func check(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL") \(name)")
            if !value { failures += 1 }
        }
        var owner: iOSNavigationManager? = iOSNavigationManager()
        check(StudyWorkspaceNavigationAdapter.events == ["init-after-registration"],
              "actual initializer publishes coverage after original registration")
        StudyWorkspaceNavigationAdapter.events = []
        let first = iOSNavigationManager.ReaderTab(id: UUID(), book: BooksData(id: 1),
            initialContentId: nil, viewModel: ReaderViewModel())
        owner!.openTabs = [first]
        check(StudyWorkspaceNavigationAdapter.events == ["tabs-before:0->1", "after:1:nil"],
              "actual observed setter brackets real reference publication")
        StudyWorkspaceNavigationAdapter.events = []
        owner!.activeTabId = first.id
        check(StudyWorkspaceNavigationAdapter.events == ["selection-before:nil->set", "after:1:set"],
              "actual selection setter brackets publication")
        StudyWorkspaceNavigationAdapter.events = []
        owner!.openTabs.append(.init(id: UUID(), book: BooksData(id: 2),
            initialContentId: nil, viewModel: ReaderViewModel()))
        check(StudyWorkspaceNavigationAdapter.events == ["tabs-before:1->2", "after:2:set"],
              "actual Observation modify accessor preserves append notifications")
        StudyWorkspaceNavigationAdapter.events = []
        owner!.openTabs[0] = .init(id: first.id, book: BooksData(id: 3),
            initialContentId: nil, viewModel: ReaderViewModel())
        check(StudyWorkspaceNavigationAdapter.events == ["tabs-before:2->2", "after:2:set"]
            && owner!.openTabs[0].book.id == 3,
              "same UUID target replacement still traverses actual hook")
        StudyWorkspaceNavigationAdapter.events = []
        owner!.activeTabId = nil
        check(StudyWorkspaceNavigationAdapter.events == ["selection-before:set->nil", "after:2:nil"],
              "actual nil selection is synchronously published")
        StudyWorkspaceNavigationAdapter.events = []
        weak let weakOwner = owner
        owner = nil
        check(weakOwner == nil && StudyWorkspaceNavigationAdapter.events == ["owner-deinit"],
              "actual isolated deinit retires owner without retaining it")
        print("ASSERTIONS=7 FAILURES=\(failures) PORTABLE_SHELLS_NOT_APPLE_SDK")
        exit(failures == 0 ? 0 : 1)
    }
}
'''


def generated(text):
    reader = block(text, "    struct ReaderTab:")
    if "var openTabs: [ReaderTab] = [] {" in text:
        tabs = block(text, "    var openTabs:")
        selection = block(text, "    var activeTabId:")
    else:
        tabs = "    var openTabs: [ReaderTab] = []"
        selection = "    var activeTabId: UUID?"
    initializer = block(text, "    init()")
    destructor = block(text, "    isolated deinit" if "    isolated deinit" in text else "    deinit")
    bodies = dict(reader=reader, tabs=tabs, selection=selection,
                  initializer=initializer, destructor=destructor)
    code = (SHELL + "\n@MainActor\n@Observable\nclass iOSNavigationManager: BackendSwitchParticipant {\n"
            + "\n".join(bodies.values())
            + "\n    var unifiedSearchSession = UnifiedSearchSessionController()"
            + "\n    var searchViewModel = SearchViewModel()"
            + "\n    private func setupObservers() {}\n}\n" + TESTS)
    return code, {k: hashlib.sha256(v.encode()).hexdigest() for k, v in bodies.items()}


baseline = subprocess.check_output(["git", "show", BASE + ":" + SOURCE], cwd=ROOT).decode()
candidate = (ROOT / SOURCE).read_text(encoding="utf-8")
report = {"scope": "Actual property/initializer/deinit bodies and real portable Observation; native dependent classes are explicit shells",
          "base": BASE, "AppleSDK": "NOT_RUN", "results": {}}
with tempfile.TemporaryDirectory(prefix="approved-native-hooks-") as temporary:
    for label, source in [("before", baseline), ("after", candidate)]:
        code, hashes = generated(source)
        path = Path(temporary) / (label + ".swift")
        executable = Path(temporary) / (label + ".exe")
        path.write_text(code, encoding="utf-8", newline="\n")
        (OUT / (label + "-compiled-input.swift")).write_text(code, encoding="utf-8", newline="\n")
        compile_result = subprocess.run(["swiftc", "-swift-version", "6", "-strict-concurrency=complete",
            "-warnings-as-errors", "-parse-as-library", str(path), "-o", str(executable)],
            cwd=ROOT, capture_output=True, timeout=180)
        (OUT / (label + "-compile.log")).write_bytes(compile_result.stdout + compile_result.stderr)
        result = {"bodyHashes": hashes, "generatedSHA256": hashlib.sha256(code.encode()).hexdigest(),
                  "compileExit": compile_result.returncode}
        if compile_result.returncode == 0:
            run = subprocess.run([str(executable)], capture_output=True, timeout=30)
            (OUT / (label + "-run.log")).write_bytes(run.stdout + run.stderr)
            result.update(runExit=run.returncode, output=(run.stdout + run.stderr).decode(errors="replace"))
        report["results"][label] = result
        print(label, json.dumps(result))
    (OUT / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8", newline="\n")
    assert report["results"]["before"]["compileExit"] == 0
    assert report["results"]["before"]["runExit"] == 1
    assert report["results"]["after"]["compileExit"] == 0
    assert report["results"]["after"]["runExit"] == 0
