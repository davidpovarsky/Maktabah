#!/usr/bin/env python3
"""Compile the exact global-tab enum and scene initializer with narrow platform doubles.

This exercises restoration/canonicalization/availability/manager ownership only.
SwiftUI State, UIKit layout, real UserDefaults persistence and Native acceptance
remain the responsibility of the unchanged original Apple UI tests.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


def block(source, marker):
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 1
    pos = opening + 1
    while depth:
        if source[pos] == "{":
            depth += 1
        elif source[pos] == "}":
            depth -= 1
        pos += 1
    return source[start:pos]


SUPPORT = r"""
enum AppMode { case viewer, search, narrator, annotations, history }
struct BackendCapabilities: OptionSet, Sendable {
    let rawValue: Int
    static let search = Self(rawValue: 1)
    static let authors = Self(rawValue: 2)
}
extension String { var localized: String { self } }
@propertyWrapper struct State<Value> {
    var wrappedValue: Value
    init(initialValue: Value) { wrappedValue = initialValue }
}
@MainActor final class UserDefaults {
    static let standard = UserDefaults()
    var storedTab: Int?
    var reads = 0
    func integer(forKey key: String) -> Int {
        precondition(key == "lastSelectedTab")
        reads += 1
        return storedTab ?? 0
    }
}
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeCapabilities: BackendCapabilities = [.search, .authors]
}
@MainActor final class iOSNavigationManager {
    static var creations = 0
    var currentMode: AppMode = .viewer
    var modeChanges = 0
    init() { Self.creations += 1 }
    func switchToMode(_ mode: AppMode) { currentMode = mode; modeChanges += 1 }
}
"""

RUNNER = r"""
@main struct RestorationControls {
    @MainActor static func main() {
        let all: BackendCapabilities = [.search, .authors]
        let cases: [(String, Int?, BackendCapabilities, iOSTab)] = [
            ("missing preference", nil, all, .viewer),
            ("viewer", 0, all, .viewer),
            ("legacy text search", 1, all, .search),
            ("legacy Zayit search", 2, all, .search),
            ("global search", 3, all, .search),
            ("authors", 4, all, .author),
            ("annotations", 5, all, .annotations),
            ("history", 6, all, .history),
            ("negative corrupt preference", -1, all, .viewer),
            ("unknown corrupt preference", 99, all, .viewer),
            ("unsupported legacy text search", 1, [.authors], .viewer),
            ("unsupported legacy Zayit search", 2, [.authors], .viewer),
            ("unsupported global search", 3, [.authors], .viewer),
            ("unsupported authors", 4, [.search], .viewer),
            ("viewer with no optional capabilities", 0, [], .viewer),
            ("annotations with no optional capabilities", 5, [], .annotations),
            ("history with no optional capabilities", 6, [], .history)
        ]
        for (name, raw, capabilities, expected) in cases {
            UserDefaults.standard.storedTab = raw
            UserDefaults.standard.reads = 0
            BackendCoordinator.shared.activeCapabilities = capabilities
            let count = iOSNavigationManager.creations
            let scene = iOSMainView()
            precondition(scene.observedTab == expected, name)
            precondition(scene.observedManager.currentMode == expected.appMode, name)
            precondition(scene.observedManager.modeChanges == 1, name)
            precondition(iOSNavigationManager.creations == count + 1, name)
            precondition(UserDefaults.standard.reads == 1, name)
            precondition(UserDefaults.standard.storedTab == raw, name)
            print("PASS \(name)")
        }
        BackendCoordinator.shared.activeCapabilities = all
        UserDefaults.standard.storedTab = 3
        let first = iOSMainView()
        UserDefaults.standard.storedTab = 6
        let second = iOSMainView()
        precondition(first.observedTab == .search && first.observedManager.currentMode == .search)
        precondition(second.observedTab == .history && second.observedManager.currentMode == .history)
        precondition(first.observedManager !== second.observedManager)
        second.observedManager.switchToMode(.annotations)
        precondition(first.observedManager.currentMode == .search)
        print("PASS separate scene owners retain their own initialized destination")
        print("PASS 18 restoration controls; Native UI acceptance is NOT_RUN by this harness")
    }
}
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--swiftc", default=shutil.which("swiftc"))
    args = parser.parse_args()
    if not args.swiftc:
        raise RuntimeError("swiftc is required")
    repo = args.repo.resolve()
    output = (args.output or repo / "build/initial-global-navigation").resolve()
    output.mkdir(parents=True, exist_ok=True)
    path = repo / "Source/UI/iOS/Views/iOSMainView.swift"
    raw = path.read_bytes()
    source = raw.decode("utf-8").replace("\r\n", "\n")
    enum = block(source, "enum iOSTab:")
    view_start = source.index("struct iOSMainView:")
    initializer = block(source[view_start:], "    init() {")
    fields = [
        "    @State private var navigationManager: iOSNavigationManager",
        "    @State private var selectedTab: iOSTab",
    ]
    for field in fields:
        if source.count(field + "\n") != 1:
            raise RuntimeError("Exact initialized scene property missing: " + field)
    harness = SUPPORT + "\n" + enum + "\n@MainActor struct iOSMainView {\n"
    harness += "\n".join(fields) + "\n" + initializer
    harness += "\nvar observedTab: iOSTab { selectedTab }\n"
    harness += "var observedManager: iOSNavigationManager { navigationManager }\n}\n" + RUNNER
    harness_file = output / "restoration-controls.swift"
    harness_file.write_bytes(harness.encode("utf-8"))
    executable = output / ("restoration-controls.exe" if sys.platform == "win32" else "restoration-controls")
    commands = [
        [args.swiftc, "-frontend", "-parse", str(path)],
        [args.swiftc, "-swift-version", "6", "-parse-as-library", str(harness_file), "-o", str(executable)],
        [str(executable)],
    ]
    records = []
    for index, command in enumerate(commands):
        result = subprocess.run(command, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
        (output / f"command-{index}.stdout.log").write_bytes(result.stdout)
        (output / f"command-{index}.stderr.log").write_bytes(result.stderr)
        records.append({"command": command, "exit_code": result.returncode})
        if result.returncode != 0:
            print(result.stdout.decode("utf-8", errors="replace"))
            print(result.stderr.decode("utf-8", errors="replace"))
            raise RuntimeError(f"Control command {index} failed with exit {result.returncode}")
    assert path.read_bytes() == raw, "Source changed during controls"
    proof = {
        "status": "PASS", "controls": 18, "full_file_swift_syntax": "PASS",
        "native_ui_acceptance": "NOT_RUN",
        "source_path": path.relative_to(repo).as_posix(),
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "source_git_bytes_sha256": hashlib.sha256(source.encode("utf-8")).hexdigest(),
        "harness_sha256": hashlib.sha256(harness_file.read_bytes()).hexdigest(),
        "limitations": ["UIKit/SwiftUI State are platform doubles", "UserDefaults uses an isolated in-memory double", "No native layout or persistence acceptance claimed"],
        "commands": records,
    }
    (output / "receipt.json").write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(proof, indent=2))
    print((output / "command-2.stdout.log").read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
