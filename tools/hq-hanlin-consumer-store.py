#!/usr/bin/env python3
"""Execute the complete app-owned conversation store with original SDK value contracts.
This is an actual filesystem/CAS proof, not app, provider, native UI or physical protection acceptance.
"""
from pathlib import Path
import argparse, datetime, hashlib, json, os, re, shutil, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--artifacts-dir", type=Path, required=True)
parser.add_argument("--sdk-sha", required=True)
args = parser.parse_args()
if not re.fullmatch(r"[a-f0-9]{40}", args.sdk_sha):
    raise SystemExit("Exact SDK source SHA required")
sdk = ROOT / "Vendor/HanlinSDK"
out = args.artifacts_dir.resolve()
out.mkdir(parents=True, exist_ok=True)
if any(out.iterdir()):
    raise SystemExit("Retain prior evidence; use an empty artifacts directory")
package = out / "package"
package.mkdir()
inputs = {}
def original(name, target):
    raw = subprocess.check_output(["git", "-C", str(sdk), "show", args.sdk_sha + ":" + name])
    target = package / target
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(raw)
    inputs[name] = {"source_commit": args.sdk_sha, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
for module, prefix in [
    ("HanlinPlatformContracts", "Packages/HanlinPlatform/Sources/HanlinPlatformContracts"),
    ("HanlinHostContracts", "Packages/HanlinAgentSDK/Sources/HanlinHostContracts"),
    ("HanlinPresentationKit", "Packages/HanlinPresentationSDK/Sources/HanlinPresentationKit"),
]:
    paths = subprocess.check_output(["git", "-C", str(sdk), "ls-tree", "-r", "--name-only",
        args.sdk_sha, "--", prefix], text=True).splitlines()
    assert paths, prefix
    for name in paths:
        original(name, "Sources/" + module + "/" + name[len(prefix) + 1:])
# The complete unchanged original message DTO is the only ChatCore type used by
# this pure persistence owner. No provider/engine API is synthesized or executed.
# Actual SDK product linkage is separately checked by the original iOS app build.
original("Packages/HanlinPlatform/Sources/HanlinChatCore/HanlinChatMessage.swift",
         "Sources/HanlinChatCore/HanlinChatMessage.swift")
for source, target in [
    ("Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinConversationStore.swift",
     "Sources/OtzariaHanlinConsumerStore/OtzariaHanlinConversationStore.swift"),
    ("Tests/HQ/hanlin-consumer/OtzariaHanlinConversationStoreTests.swift",
     "Tests/OtzariaHanlinConversationStoreTests/OtzariaHanlinConversationStoreTests.swift"),
]:
    raw = (ROOT / source).read_bytes()
    destination = package / target
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(raw)
    inputs[source] = {"sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
manifest = """// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "OtzariaHanlinStoreProof",
    platforms: [.macOS(.v26), .iOS("27.0")], targets: [
        .target(name: "HanlinPlatformContracts", resources: [.process("Resources")]),
        .target(name: "HanlinHostContracts", dependencies: ["HanlinPlatformContracts"]),
        .target(name: "HanlinPresentationKit"),
        .target(name: "HanlinChatCore"),
        .target(name: "OtzariaHanlinConsumerStore", dependencies:
            ["HanlinHostContracts", "HanlinPresentationKit", "HanlinChatCore"]),
        .testTarget(name: "OtzariaHanlinConversationStoreTests", dependencies:
            ["OtzariaHanlinConsumerStore", "HanlinHostContracts", "HanlinPresentationKit", "HanlinChatCore"])
    ], swiftLanguageModes: [.v6])
"""
(package / "Package.swift").write_text(manifest, encoding="utf-8", newline="\n")
(out / "inputs.json").write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8", newline="\n")
command = [shutil.which("swift"), "test", "--scratch-path", str(ROOT / "build/hcs"),
           "-j", "1", "-Xswiftc", "-strict-concurrency=complete"]
with (out / "swift-test.log").open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, cwd=package, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=300)
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
        else:
            process.kill()
        process.wait()
        code = 124
log = (out / "swift-test.log").read_text(encoding="utf-8", errors="replace")
fixture = ROOT / "Tests/HQ/hanlin-consumer/OtzariaHanlinConversationStoreTests.swift"
expected = sorted(set(re.findall(r"func (test[A-Za-z0-9_]+)\(", fixture.read_text(encoding="utf-8"))))
passed = sorted(set(re.findall(r"Test Case '.*OtzariaHanlinConversationStoreTests[ .](test[A-Za-z0-9_]+)[\\]'].*passed", log)))
if not passed:
    passed = sorted(set(re.findall(r"Test Case 'OtzariaHanlinConversationStoreTests\.(test[A-Za-z0-9_]+)' passed", log)))
if len(expected) != 11 or passed != expected:
    code = code or 1
report = {
    "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "status": "PASS_ACTUAL_SCOPED_FILESYSTEM_STORE" if code == 0 else "FAIL",
    "exit_code": code, "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    "working_source_hashes": inputs, "sdk_sha": args.sdk_sha, "command": command,
    "passed": passed, "expected": expected, "warnings": log.count("warning:"),
    "swift_log_sha256": hashlib.sha256((out / "swift-test.log").read_bytes()).hexdigest(),
    "native_ui_executed": 0, "physical_protection_verified": False, "provider_executed": False,
    "boundary": "Complete app store with actual Foundation files, independent host/SDK CAS, scoped lease rejection and platform filesystem write failure. Complete original SDK contract/presentation modules and unchanged message DTO; no engine/provider, UIKit scene, native navigation or physical protection proof."
}
(out / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps({k: v for k, v in report.items() if k != "working_source_hashes"}))
if code:
    print(log[-16000:])
raise SystemExit(code)
