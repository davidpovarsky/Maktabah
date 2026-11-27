#!/usr/bin/env python3
"""Execute source-bound installer recovery controls on an Apple host.

The prepared INPUTS.json records exact product bytes and the immutable baseline.
No downloads, app UI or production-corpus acceptance is claimed by this runner.
"""
import argparse, datetime, hashlib, json, os, pathlib, platform, subprocess, sys

def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepared-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()
    root = args.prepared_dir.resolve()
    if sys.platform != "darwin":
        raise RuntimeError("Apple SDK/compiler and real filesystem required")
    contract = json.loads((root / "INPUTS.json").read_text())
    expected = contract["inputs"]
    actual = {path: digest(root / path) for path in expected}
    if actual != expected:
        raise RuntimeError("Prepared source bytes differ from their receipt")
    result = {"scope": "real-filesystem-SQLite-component", "base_sha": contract["base_sha"],
              "inputs": actual, "runner": digest(pathlib.Path(__file__)),
              "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "host": platform.platform(), "ui_acceptance": False, "cases": {}, "commands": []}
    for command in [["xcodebuild", "-version"], ["xcrun", "swiftc", "--version"], ["df", "-k", "/System/Volumes/Data"]]:
        r = subprocess.run(command, text=True, capture_output=True, timeout=30)
        result["commands"].append({"command": command, "exit": r.returncode, "stdout": r.stdout, "stderr": r.stderr})
        r.check_returncode()
    boundary = root / "ComponentBoundary.swift"
    boundary.write_text("""import Foundation

enum AppConfig { static let appSupportDir: URL? = nil }
@MainActor final class OtzariaMaktabahBridge {
    static let shared = OtzariaMaktabahBridge()
    var isEnabled: Bool { false }
    func installDatabase(from url: URL) throws { fatalError("Application bridge outside component scope") }
    func activateManagedDatabase(at url: URL) throws { fatalError("Application bridge outside component scope") }
    func restoreDatabaseIfPossible() throws -> Bool { fatalError("Application bridge outside component scope") }
    func resetConnection() { fatalError("Application bridge outside component scope") }
}
@MainActor final class OtzariaTantivySearchRepository {
    static let shared = OtzariaTantivySearchRepository()
    func closeAllEngines() { fatalError("Search engine outside component scope") }
}
""")
    result["boundaries"] = {"app_and_search": digest(boundary),
                            "unused_zstd": digest(root / "Tests/HQ/sqlite/UnusedZstdBoundary.swift")}
    for variant in ["baseline", "candidate"]:
        sources = []
        for name in contract["source_files"]:
            prefix = "Baseline/" if variant == "baseline" and name in contract["changed_files"] else ""
            sources.append(str(root / (prefix + name)))
        binary = root / ("LibraryRecovery-" + variant)
        command = ["xcrun", "swiftc", "-swift-version", "5", "-parse-as-library",
                   "-module-cache-path", str(root / "modules"), "-L", "/opt/homebrew/lib", "-lzstd",
                   *sources, str(boundary), "-o", str(binary)]
        with (root / ("compile-" + variant + ".log")).open("w") as log:
            run = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        result["commands"].append({"command": command, "exit": run.returncode})
        if run.returncode:
            result["status"] = "COMPILE_FAILED"
            (root / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
            print((root / ("compile-" + variant + ".log")).read_text())
            return 1
        run = subprocess.run([str(binary)], cwd=root, env={**os.environ, "OTZARIA_DATA_PROFILE": "production"},
                             text=True, capture_output=True, timeout=60)
        (root / ("run-" + variant + ".log")).write_text(run.stdout + run.stderr)
        rows = [json.loads(line) for line in run.stdout.splitlines() if line.startswith("{")]
        result["cases"][variant] = {"exit": run.returncode, "binary": digest(binary), "rows": rows}
        print(variant, run.returncode, run.stdout, run.stderr)
    result["inputs_after"] = {path: digest(root / path) for path in expected}
    candidate = result["cases"]["candidate"]
    baseline = result["cases"]["baseline"]
    summaries = [x for x in candidate["rows"] if "passed" in x]
    require_pass = (candidate["exit"] == 0 and len(summaries) == 1 and summaries[0]["passed"] == 10
                    and summaries[0]["failed"] == 0 and summaries[0]["skipped"] == 0
                    and baseline["exit"] != 0 and result["inputs_after"] == actual)
    result["status"] = "COMPONENT_PASS" if require_pass else "FAILED"
    result["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    (root / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    return 0 if require_pass else 1

if __name__ == "__main__":
    raise SystemExit(main())
