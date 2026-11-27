import datetime
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parent
base = root.parent / "inspector-generation-attempt-2"
sdk = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk"
flags = ["-parse-as-library", "-swift-version", "6", "-D", "DEBUG", "-Xfrontend", "-strict-concurrency=complete",
         "-sdk", sdk, "-target", "arm64-apple-ios17.0-macabi", "-F", sdk + "/System/iOSSupport/System/Library/Frameworks",
         "-module-cache-path", str(base / "module-cache")]
digest = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
report = {
    "startedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "scope": "Mac Catalyst whole-source component control and SwiftUI host typecheck; no application, simulator or original native UI execution",
    "steps": [], "freeBytesBefore": shutil.disk_usage(root).free,
    "newSources": {p.name: digest(p) for p in root.glob("*.swift")},
}


def save():
    (root / "RESULT.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def run(name, command, timeout=120):
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    with (root / (name + ".stdout.log")).open("wb") as out, (root / (name + ".stderr.log")).open("wb") as err:
        result = subprocess.run(command, stdout=out, stderr=err, timeout=timeout, cwd=root)
    report["steps"].append({"name": name, "command": command, "startedUTC": started,
                            "finishedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(), "exitCode": result.returncode})
    save()
    if result.returncode != 0:
        raise RuntimeError(name + " failed")


try:
    prior = base / "RESULT.json"
    assert digest(prior) == "949a8d016e0b0937887e5eeed6405655768bebb5ebfc4f9d2b95b087d43188ad"
    receipt = json.loads(prior.read_text())
    assert receipt["status"] == "COMPLETE"
    report["reusedBuildReceipt"] = {"path": str(prior), "sha256": digest(prior)}
    support = sorted((base / "Source").rglob("*.swift"))
    for path in support:
        assert receipt["sources"][str(path.relative_to(base))] == digest(path)
    for relative, sha in receipt["sources"].items():
        if relative.startswith("kit/"):
            assert digest(base / relative) == sha
    report["reusedSourceHashes"] = {str(p): digest(p) for p in support}
    report["reusedModuleHashes"] = {str(base / name): digest(base / name) for name in
                                    ("TorahInspectorCore.swiftmodule", "TorahInspectorUI.swiftmodule", "libTorahInspectorCore.dylib")}
    run("compiler-version", ["xcrun", "swiftc", "--version"])
    sources = [str(p) for p in support] + [str(root / "InspectorModeBoundaries.swift"), str(root / "MaktabahTorahInspectorAdapter.swift")]
    run("candidate-whole-host-typecheck", ["xcrun", "swiftc"] + flags +
        ["-typecheck", "-D", "INSPECTOR_HOST_TYPECHECK", "-I", str(base)] + sources +
        [str(root / "OtzariaReaderSourcesInspectorHost.swift")])
    binary = root / "candidate-controls"
    run("candidate-compile", ["xcrun", "swiftc"] + flags + ["-I", str(base), "-L", str(base), "-lTorahInspectorCore"] +
        sources + [str(root / "InspectorModeControls.swift"), "-o", str(binary)])
    run("candidate-run", [str(binary), str(root / "candidate-cases.json")], timeout=30)
    report["candidate"] = json.loads((root / "candidate-cases.json").read_text())
    assert report["candidate"]["passed"] == report["candidate"]["total"] == 8
    report["status"] = "COMPLETE"
except Exception as error:
    report["status"] = "FAILED"
    report["error"] = str(error)
finally:
    report["finishedUTC"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    report["freeBytesAfter"] = shutil.disk_usage(root).free
    save()
