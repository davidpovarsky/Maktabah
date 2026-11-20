#!/usr/bin/env python3
"""Compile exact current Swift lifetime/window guards with explicit UIKit/Binding doubles.
This proves portable logic only. It does not typecheck Apple's SDK or run Native UI.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
DOCS = Path(__file__).resolve().parent
DEFAULT_BASE = "ca314e7cc5d5cdde2bb15a54a79c92541296349f"
COMPACT = "Source/ChavrusaText/ReaderHost/CompactStudyWorkspaceHostModifier.swift"
COORDINATOR = "Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift"
LAYOUT = "Source/UI/iOS/Views/iPadLayout.swift"
STATE = "Source/ChavrusaText/ReaderHost/ReaderOverviewPresentationState.swift"
CHROME = "Source/ChavrusaText/ReaderHost/ReaderNavigationChromeState.swift"

def block(source, needle):
    start = source.index(needle)
    opening = source.index("{", start)
    depth = 0
    for i in range(opening, len(source)):
        if source[i] == "{": depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0: return source[start:i+1]
    raise AssertionError("Unclosed source block: " + needle)

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

PREAMBLE = r"""
import Foundation

// Explicit substitute types: no UIKit, SwiftUI, UIApplication or real window is used.
enum Activation { case foregroundActive, foregroundInactive, background }
final class SceneSession { var persistentIdentifier = "scene-A" }
final class Scene { var activationState = Activation.foregroundActive; let session = SceneSession() }
class UIView: NSObject { weak var window: UIWindow? }
class UIScrollView: UIView {}
final class UIWindow: NSObject {
    var isKeyWindow = true
    var isHidden = false
    var alpha: CGFloat = 1
    var windowScene: Scene? = Scene()
}
final class ReaderViewModel: NSObject {
    var isPopoverPresented = false
    var readerInspectorVisible = false
}
final class Manager { var activeReaderViewModel: ReaderViewModel? }
final class Workspace { var attached = true; var sceneID = "scene-A" }
enum Tab { case viewer, search }
enum ScenePhase { case active, inactive, background }
@MainActor enum ChavrusaTextReaderUI { static var isEnabled = true }
@MainActor enum MaktabahApp { static var isIpad = true }
@MainActor func withAnimation(_ ignored: Int?, _ body: () -> Void) { body() }
struct Binding<Value> {
    let get: () -> Value
    let set: (Value) -> Void
    var wrappedValue: Value { get { get() } nonmutating set { set(newValue) } }
}
final class Box { var value = true }
@MainActor var checks: [[String: Any]] = []
@MainActor func check(_ name: String, _ value: @autoclosure () -> Bool) {
    checks.append(["name": name, "passed": value()])
}
@MainActor func finish() throws {
    let failed = checks.filter { ($0["passed"] as? Bool) != true }
    let result: [String: Any] = ["scope": "exact-source portable logic with explicit UIKit/Binding doubles; Native NOT_RUN",
        "checks": checks.count, "passed": checks.count - failed.count, "failed": failed.count, "results": checks]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
    if !failed.isEmpty { exit(1) }
}
"""

LEGACY_RUN = r"""
@MainActor func verifyLegacyBinding() {
    for ipad in [false, true] {
        for enabled in [false, true] {
            MaktabahApp.isIpad = ipad
            ChavrusaTextReaderUI.isEnabled = enabled
            let value = Box()
            let original = Binding<Bool>(get: { value.value }, set: { value.value = $0 })
            let projected = Legacy.legacyTabsPresentation(original)
            check("legacy.get.ipad=\(ipad).enabled=\(enabled)", projected.wrappedValue == !enabled)
            projected.wrappedValue = false
            check("legacy.set.ipad=\(ipad).enabled=\(enabled)", value.value == enabled)
        }
    }
    ChavrusaTextReaderUI.isEnabled = true
    MaktabahApp.isIpad = true
}
"""

LIFETIME_RUN = r"""
@MainActor func verifyLifetime() {
    var state = ReaderOverviewPresentationState()
    check("initial reader readiness", !state.blocksRouting)
    let a = state.request()
    check("request blocks before UIKit mount", state.blocksRouting && state.isRequested && state.mountedID == nil)
    check("same request does not create second presentation", state.request() == a)
    check("only current request can present", state.canPresent(a) && !state.canPresent(UUID()))
    check("stale mount rejected", !state.didMount(UUID()) && state.mountedID == nil)
    check("unexpected dismissal before close rejected", !state.didDismiss(a) && state.blocksRouting)
    check("actual current mount accepted", state.didMount(a) && state.mountedID == a)
    check("duplicate mount rejected", !state.didMount(a) && state.blocksRouting)
    check("stale close rejected", !state.requestClose(UUID()) && state.isRequested)
    check("close remains blocked until actual dismissal", state.requestClose(a) && state.blocksRouting && !state.isRequested)
    check("pending dismissal cannot reopen", state.request() == a && !state.isRequested && !state.canPresent(a))
    check("duplicate close rejected", !state.requestClose(a) && state.blocksRouting)
    check("stale dismissal cannot expose covered reader", !state.didDismiss(UUID()) && state.blocksRouting)
    check("matching actual dismissal releases reader", state.didDismiss(a) && !state.blocksRouting)
    check("duplicate dismissal rejected", !state.didDismiss(a))
    let b = state.request()
    check("new request has a new owner", b != a && state.blocksRouting)
    check("old callbacks cannot retire new owner", !state.didDismiss(a) && !state.didDismantle(a) && !state.didMount(a) && state.requestID == b)
    check("close-before-mount retains block", state.requestClose(b) && state.blocksRouting)
    check("late actual mount remains owned during close", state.didMount(b) && state.mountedID == b && state.blocksRouting)
    check("late mounted dismissal releases exact owner", state.didDismiss(b) && !state.blocksRouting)
    let c = state.request()
    _ = state.requestClose(c)
    check("cancel before any UIKit mount releases only matching request", state.didDismiss(c) && !state.blocksRouting)
    let d = state.request()
    check("dismantle unmounted anchor releases exact request", state.didDismantle(d) && !state.blocksRouting)
    let e = state.request()
    _ = state.didMount(e)
    check("dismantle actual owner releases mount and request", state.didDismantle(e) && !state.blocksRouting)
    check("duplicate dismantle rejected", !state.didDismantle(e))
}

@MainActor func verifyChromeThresholds() {
    var chrome = ReaderNavigationChromeState()
    chrome.beginDragging()
    chrome.consume(translationY: -31, isAtTop: false)
    check("original collapse threshold stays 32 points", chrome.isVisible)
    chrome.consume(translationY: -32, isAtTop: false)
    check("original downward pan collapses", !chrome.isVisible)
    chrome.consume(translationY: -15, isAtTop: false)
    check("original restore threshold stays 18 points", !chrome.isVisible)
    chrome.consume(translationY: -14, isAtTop: false)
    check("original upward pan restores", chrome.isVisible)
    chrome.beginDragging()
    chrome.consume(translationY: -.infinity, isAtTop: false)
    check("nonfinite pan does not change chrome", chrome.isVisible)
    chrome.consume(translationY: -40, isAtTop: false)
    chrome.consume(translationY: -40, isAtTop: true)
    check("original top-of-document reveal retained", chrome.isVisible)
}

@MainActor func verifyWindowOwner() {
    let c = Coordinator()
    let windowA = UIWindow(), windowB = UIWindow()
    let anchorA = UIView(), anchorB = UIView()
    let scrollA = UIScrollView(), scrollB = UIScrollView()
    anchorA.window = windowA; scrollA.window = windowA
    anchorB.window = windowB; scrollB.window = windowB
    c.observeNavigationChromeWindow(owner: anchorA, window: windowA)
    check("actual matching anchor and sender window accepted", c.ownsNavigationChromeWindow(scrollA, sceneID: "scene-A"))
    check("same scene but different actual window rejected", !c.ownsNavigationChromeWindow(scrollB, sceneID: "scene-A"))
    c.observeNavigationChromeWindow(owner: anchorB, window: windowB)
    c.observeNavigationChromeWindow(owner: anchorA, window: nil)
    check("old anchor detach cannot erase newer owner", c.ownsNavigationChromeWindow(scrollB, sceneID: "scene-A"))
    anchorB.window = windowA
    check("anchor moved after registration rejected", !c.ownsNavigationChromeWindow(scrollB, sceneID: "scene-A"))
    anchorB.window = windowB
    windowB.isKeyWindow = false
    check("nonkey window rejected", !c.ownsNavigationChromeWindow(scrollB, sceneID: "scene-A"))
    windowB.isKeyWindow = true; windowB.isHidden = true
    check("hidden window rejected", !c.ownsNavigationChromeWindow(scrollB, sceneID: "scene-A"))
    windowB.isHidden = false; windowB.alpha = 0
    check("transparent window rejected", !c.ownsNavigationChromeWindow(scrollB, sceneID: "scene-A"))
    windowB.alpha = 1; windowB.windowScene!.activationState = .background
    check("background scene rejected", !c.ownsNavigationChromeWindow(scrollB, sceneID: "scene-A"))
    windowB.windowScene!.activationState = .foregroundActive
    check("different scene session rejected", !c.ownsNavigationChromeWindow(scrollB, sceneID: "other"))
    scrollB.window = nil
    check("detached sender rejected", !c.ownsNavigationChromeWindow(scrollB, sceneID: "scene-A"))
    scrollB.window = windowB
    c.observeNavigationChromeWindow(owner: anchorB, window: nil)
    check("matching owner detach removes capability", !c.ownsNavigationChromeWindow(scrollB, sceneID: "scene-A"))
    var ephemeral: UIView? = UIView()
    ephemeral!.window = windowB
    c.observeNavigationChromeWindow(owner: ephemeral!, window: windowB)
    ephemeral = nil
    check("deallocated owner cannot qualify retained window", !c.ownsNavigationChromeWindow(scrollB, sceneID: "scene-A"))
}

@MainActor func verifyConsumer() {
    let host = ScrollHost()
    let window = UIWindow()
    let anchor = UIView()
    let scroll = UIScrollView()
    let reader = ReaderViewModel()
    anchor.window = window; scroll.window = window
    host.bManager.activeReaderViewModel = reader
    host.sidebar.observeNavigationChromeWindow(owner: anchor, window: window)
    func event(reader source: ReaderViewModel? = nil, view: UIScrollView? = nil, begin: Bool = false) -> Notification {
        Notification(name: Notification.Name("test.original.scroll"), object: source ?? reader,
                     userInfo: [ChavrusaReaderScrollKey.scrollView: view ?? scroll,
                                ChavrusaReaderScrollKey.beginsDrag: begin,
                                ChavrusaReaderScrollKey.translationY: CGFloat(begin ? 0 : -40),
                                ChavrusaReaderScrollKey.isAtTop: false])
    }
    func attempt() { host.sidebar.navigationChrome.reveal(); host.receive(event(begin: true)); host.receive(event()) }
    attempt()
    check("actual selected original reader in owned active window collapses", !host.sidebar.navigationChrome.isVisible)
    host.sidebar.navigationChrome.reveal()
    let otherReader = ReaderViewModel()
    host.receive(event(reader: otherReader, begin: true)); host.receive(event(reader: otherReader))
    check("different reader object cannot collapse this window", host.sidebar.navigationChrome.isVisible)
    host.selectedTab = .search; attempt()
    check("selected nonreader tab rejected", host.sidebar.navigationChrome.isVisible)
    host.selectedTab = .viewer; host.scenePhase = .inactive; attempt()
    check("inactive actual scene phase rejected", host.sidebar.navigationChrome.isVisible)
    host.scenePhase = .active; host.workspace!.attached = false; attempt()
    check("unattached original workspace rejected", host.sidebar.navigationChrome.isVisible)
    host.workspace!.attached = true; ChavrusaTextReaderUI.isEnabled = false; attempt()
    check("feature-off event cannot change chrome", host.sidebar.navigationChrome.isVisible)
    ChavrusaTextReaderUI.isEnabled = true
    let request = host.sidebar.overview.request(); attempt()
    check("requested overview blocks reader scroll", host.sidebar.navigationChrome.isVisible)
    _ = host.sidebar.overview.requestClose(request); attempt()
    check("dismissing overview still blocks reader scroll", host.sidebar.navigationChrome.isVisible)
    _ = host.sidebar.overview.didDismiss(request)
    reader.isPopoverPresented = true; attempt()
    check("original reader popover blocks chrome", host.sidebar.navigationChrome.isVisible)
    reader.isPopoverPresented = false; reader.readerInspectorVisible = true; attempt()
    check("original inspector blocks chrome", host.sidebar.navigationChrome.isVisible)
    reader.readerInspectorVisible = false
    let otherWindow = UIWindow(), otherScroll = UIScrollView()
    otherScroll.window = otherWindow
    host.sidebar.navigationChrome.reveal()
    host.receive(event(view: otherScroll, begin: true)); host.receive(event(view: otherScroll))
    check("different sending window is rejected before consumption", host.sidebar.navigationChrome.isVisible)
    attempt()
    check("original valid path remains usable after rejection controls", !host.sidebar.navigationChrome.isVisible)
}
"""

def legacy_type(source):
    enabled = block(source, "private static var isEnabled: Bool")
    method = block(source, "static func legacyTabsPresentation(")
    return "@MainActor struct Legacy {\n" + enabled + "\n" + method + "\n}\n"

def compile_run(name, source, swiftc, out, env):
    swift = out / (name + ".swift")
    exe = out / (name + ".exe")
    swift.write_text(source, encoding="utf-8", newline="\n")
    started = time.monotonic()
    compiled = subprocess.run([str(swiftc), "-swift-version", "6", "-parse-as-library", str(swift), "-o", str(exe)],
                              capture_output=True, text=True, encoding="utf-8", env=env, timeout=180)
    result = {"source_lf_sha256": sha(source), "compile_exit": compiled.returncode,
              "compile_stdout": compiled.stdout, "compile_stderr": compiled.stderr}
    if compiled.returncode == 0:
        run = subprocess.run([str(exe)], capture_output=True, text=True, encoding="utf-8", env=env, timeout=30)
        result.update({"run_exit": run.returncode, "run_stdout": run.stdout, "run_stderr": run.stderr})
        try: result["assertions"] = json.loads(run.stdout)
        except json.JSONDecodeError: pass
    result["seconds"] = round(time.monotonic() - started, 3)
    return result

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--swiftc", type=Path, required=True)
    parser.add_argument("--base", default=DEFAULT_BASE)
    args = parser.parse_args()
    out = ROOT / "build/overview-release-ui-20261120"
    out.mkdir(parents=True, exist_ok=True)
    sources = {p: (ROOT / p).read_text(encoding="utf-8") for p in [COMPACT, COORDINATOR, LAYOUT, STATE, CHROME]}
    base_compact = subprocess.run(["git", "show", args.base + ":" + COMPACT], cwd=ROOT, check=True,
                                 capture_output=True, text=True, encoding="utf-8").stdout
    legacy_red = PREAMBLE + legacy_type(base_compact) + LEGACY_RUN + "\n@main struct Run { @MainActor static func main() throws { verifyLegacyBinding(); try finish() } }\n"
    coordinator = sources[COORDINATOR]
    observer = block(coordinator, "func observeNavigationChromeWindow(")
    owner = block(coordinator, "func ownsNavigationChromeWindow(")
    consumer = block(sources[LAYOUT], "private func receiveReaderNavigationScroll(")
    reporter_source = (ROOT / "Source/ChavrusaText/ReaderHost/ChavrusaReaderHost.swift").read_text(encoding="utf-8")
    keys = block(reporter_source, "enum ChavrusaReaderScrollKey")
    generated_coordinator = """
@MainActor final class Coordinator {
    var overview = ReaderOverviewPresentationState()
    var navigationChrome = ReaderNavigationChromeState()
    private weak var navigationChromeWindowOwner: UIView?
    private weak var navigationChromeWindow: UIWindow?
""" + observer + "\n" + owner + "\n}\n"
    host = """
@MainActor final class ScrollHost {
    var selectedTab = Tab.viewer
    var scenePhase = ScenePhase.active
    var workspace: Workspace? = Workspace()
    let bManager = Manager()
    let sidebar = Coordinator()
    let readerChromeAnimation: Int? = nil
    func receive(_ note: Notification) { receiveReaderNavigationScroll(note) }
""" + consumer + "\n}\n"
    green = PREAMBLE + sources[STATE] + "\n" + sources[CHROME] + "\n" + keys + "\n"
    green += legacy_type(sources[COMPACT]) + generated_coordinator + host + LEGACY_RUN + LIFETIME_RUN
    green += "\n@main struct Run { @MainActor static func main() throws { verifyLegacyBinding(); verifyLifetime(); verifyChromeThresholds(); verifyWindowOwner(); verifyConsumer(); try finish() } }\n"
    env = dict(os.environ)
    env["PATH"] = str(args.swiftc.parent) + os.pathsep + env.get("PATH", "")
    results = {"base": args.base, "source_scope": "exact extracted original logic; explicit UIKit/Binding doubles; Apple SDK/Native NOT_RUN",
               "source_lf_sha256": {p: sha(v) for p,v in sources.items()},
               "legacy_red": compile_run("legacy-red", legacy_red, args.swiftc, out, env),
               "lifecycle_green": compile_run("lifecycle-green", green, args.swiftc, out, env)}
    (DOCS / "PORTABLE_VERIFICATION.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(results, ensure_ascii=False, indent=2))
    assert results["legacy_red"]["compile_exit"] == 0
    assert results["legacy_red"].get("run_exit") == 1
    assert results["legacy_red"]["assertions"]["failed"] == 2
    assert results["lifecycle_green"]["compile_exit"] == 0
    assert results["lifecycle_green"].get("run_exit") == 0
    assert results["lifecycle_green"]["assertions"]["failed"] == 0

if __name__ == "__main__": main()
