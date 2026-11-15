"""Swift 6 action/key regression: exact production declarations, explicit SDK stand-ins.

Windows cannot typecheck SwiftUI. Only its EnvironmentKey/EnvironmentValues and
split-visibility interfaces are stand-ins here. Production key, value accessor,
coordinator and the actual iPad action body compile unmodified (import replaced).
No project build/workflow/SDK acceptance is claimed.
"""
from pathlib import Path
import hashlib
import subprocess
import tempfile
import os
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/features/search/selftest-20261115/swift6-action"
OUT.mkdir(parents=True, exist_ok=True)
path = ROOT / "Source/ChavrusaText/Search/UI/GlobalSearchPresentationCoordinator.swift"
production = path.read_text(encoding="utf-8")
baseline = subprocess.check_output(["git", "show", "da186f45:" + path.relative_to(ROOT).as_posix()], cwd=ROOT).decode("utf-8")
ipad = (ROOT / "Source/UI/iOS/Views/iPadLayout.swift").read_text(encoding="utf-8")
marker = ".environment(\\.globalSearchBookChooser) {\n"
action = ipad.split(marker, 1)[1].split("\n        }", 1)[0]
boundary = """
import Foundation
import Observation
// Minimal explicit SDK stand-ins; not a substitute for Apple's module.
protocol EnvironmentKey { associatedtype Value; static var defaultValue: Value { get } }
struct EnvironmentValues {
    private var storage: [ObjectIdentifier: Any] = [:]
    subscript<K: EnvironmentKey>(_ key: K.Type) -> K.Value {
        get { (storage[ObjectIdentifier(key)] as? K.Value) ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}
enum NavigationSplitViewVisibility { case all, detailOnly }
enum FixtureSizeClass { case compact, regular }
@MainActor final class FixtureSession { var showsBookFilterSheet = false }
@MainActor final class FixtureManager { let unifiedSearchSession = FixtureSession() }
@MainActor struct FixtureNativeHost {
    let horizontalSizeClass: FixtureSizeClass?
    let bManager: FixtureManager
    let searchPresentation: GlobalSearchPresentationCoordinator
    var nativeBookAction: @MainActor @Sendable () -> Void {
        {
""" + action + """
        }
    }
}
"""
tests = """
@main @MainActor struct ActionKeyFixtureRunner {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }
    static func main() async {
        var environment = EnvironmentValues()
        check(environment.globalSearchBookChooser == nil, "default key is absent; compact fallback remains possible")
        let manager = FixtureManager()
        let coordinator = GlobalSearchPresentationCoordinator()
        coordinator.columnVisibility = .detailOnly
        let regular = FixtureNativeHost(horizontalSizeClass: .regular, bManager: manager, searchPresentation: coordinator)
        environment.globalSearchBookChooser = regular.nativeBookAction
        let sendableRegularAction = environment.globalSearchBookChooser
        await Task.detached { await sendableRegularAction?() }.value
        check(coordinator.columnVisibility == .all, "transferred regular action hops to MainActor and reveals Search sidebar")
        check(!manager.unifiedSearchSession.showsBookFilterSheet, "regular action does not request compact chooser")
        coordinator.columnVisibility = .detailOnly
        let compact = FixtureNativeHost(horizontalSizeClass: .compact, bManager: manager, searchPresentation: coordinator)
        environment.globalSearchBookChooser = compact.nativeBookAction
        let sendableCompactAction = environment.globalSearchBookChooser
        await Task.detached { await sendableCompactAction?() }.value
        check(manager.unifiedSearchSession.showsBookFilterSheet, "transferred compact action opens existing native chooser")
        check(coordinator.columnVisibility == .detailOnly, "compact action preserves split visibility")
        environment.globalSearchBookChooser = nil
        check(environment.globalSearchBookChooser == nil, "action can be removed without new state")
        print("PASS: \\(checks) Swift6 action/key assertions; exact production declarations/iPad action, explicit SwiftUI stand-ins; native NOT_RUN")
    }
}
"""

with tempfile.TemporaryDirectory(prefix="global-search-action-swift6-") as tmp:
    tmp = Path(tmp)
    def compile_source(source, name):
        # Keep all production declarations and annotations exact; replace import only.
        file = tmp / (name + ".swift")
        file.write_text(boundary + source.replace("import SwiftUI", "") + tests, encoding="utf-8")
        binary = tmp / (name + (".exe" if os.name == "nt" else ""))
        result = subprocess.run(["swiftc", "-swift-version", "6", "-strict-concurrency=complete", "-warnings-as-errors",
                                 "-parse-as-library", str(file), "-o", str(binary)], capture_output=True, text=True)
        (OUT / (name + ".log")).write_text(result.stdout + result.stderr, encoding="utf-8")
        return result, binary, file
    red, _, _ = compile_source(baseline, "baseline-red")
    assert red.returncode != 0 and "defaultValue" in red.stderr and "not concurrency-safe" in red.stderr, red.stderr
    print("RED confirmed: original exact key/value rejected by Swift6 concurrency checking")
    green, binary, generated = compile_source(production, "candidate-green")
    if green.returncode:
        print(green.stderr)
        raise SystemExit(green.returncode)
    result = subprocess.run([str(binary)], capture_output=True, text=True, check=True)
    (OUT / "candidate-run.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    print(result.stdout, end="")
    # A Sendable action remains MainActor-isolated: a missing actor hop is rejected.
    negative = generated.read_text(encoding="utf-8").replace("await sendableRegularAction?()", "sendableRegularAction?()")
    file = tmp / "missing-actor-hop.swift"
    file.write_text(negative, encoding="utf-8")
    rejected = subprocess.run(["swiftc", "-swift-version", "6", "-strict-concurrency=complete", "-warnings-as-errors",
                               "-parse-as-library", "-typecheck", str(file)], capture_output=True, text=True)
    (OUT / "missing-actor-hop-rejected.log").write_text(rejected.stdout + rejected.stderr, encoding="utf-8")
    assert rejected.returncode != 0 and ("not marked with 'await'" in rejected.stderr or "actor-isolated" in rejected.stderr), rejected.stderr
    print("PASS: missing MainActor hop rejected; no unsafe Sendable/nonisolated escape")
    print("production-action-source-sha256=" + hashlib.sha256(path.read_bytes()).hexdigest())
    (OUT / "RESULT.json").write_text(json.dumps({
        "authority": "Windows Swift6.3.3 language/concurrency compiler; explicit SwiftUI SDK stand-ins",
        "flags": ["-swift-version", "6", "-strict-concurrency=complete", "-warnings-as-errors"],
        "productionSourceSHA256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "iPadActionBodySHA256": hashlib.sha256(action.encode()).hexdigest(),
        "baseline": "da186f456056fc5b9409de28fc7c989a2911cd1b",
        "baselineExpectedRedExit": red.returncode,
        "candidateCompileExit": green.returncode,
        "candidateRunExit": result.returncode,
        "actionAssertions": 6,
        "missingActorHopExpectedRejectionExit": rejected.returncode,
        "appleSDKTypecheck": "NOT_RUN for corrected candidate; prior frozen candidate failed actual Swift6 SDK compilation"
    }, indent=2) + "\n", encoding="utf-8")
