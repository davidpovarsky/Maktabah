#!/usr/bin/env python3
"""Reproduce the current SDK navigation transition boundary using its WHOLE original dispatcher."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--artifacts-dir", type=Path, required=True)
parser.add_argument("--sdk-sha", default="080d1a2b264ead9e3f9df690f2dd0d3e81ebd07e")
args = parser.parse_args()
sdk = ROOT / "Vendor/HanlinSDK"
output = args.artifacts_dir.resolve()
output.mkdir(parents=True, exist_ok=True)
if any(output.iterdir()):
    raise SystemExit("Retain prior evidence; use an empty artifacts directory")
package = output / "package"
package.mkdir()
inputs = {}
def original(name, target):
    raw = subprocess.check_output(["git", "-C", str(sdk), "show", args.sdk_sha + ":" + name])
    destination = package / target
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(raw)
    inputs[name] = {"source_commit": args.sdk_sha, "sha256": hashlib.sha256(raw).hexdigest(),
                    "bytes": len(raw), "build_path": target}
for module, prefix in [
    ("HanlinPlatformContracts", "Packages/HanlinPlatform/Sources/HanlinPlatformContracts"),
    ("HanlinHostContracts", "Packages/HanlinAgentSDK/Sources/HanlinHostContracts"),
]:
    paths = subprocess.check_output(["git", "-C", str(sdk), "ls-tree", "-r", "--name-only",
                                     args.sdk_sha, "--", prefix], text=True).splitlines()
    assert paths, prefix
    for path in paths:
        original(path, "Sources/" + module + "/" + path[len(prefix)+1:])
original("Packages/HanlinAgentSDK/Sources/HanlinAgentCore/HanlinHostDispatcher.swift",
         "Sources/HanlinAgentCore/HanlinHostDispatcher.swift")
fixture = ROOT / "Tests/HQ/hanlin-host/SDKNavigationTransitionTests.swift"
destination = package / "Tests/SDKNavigationTransitionTests/SDKNavigationTransitionTests.swift"
destination.parent.mkdir(parents=True)
destination.write_bytes(fixture.read_bytes())
manifest = """// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "HanlinNavigationTransitionProof",
    platforms: [.iOS("27.0"), .macOS(.v26)],
    targets: [
    .target(name: "HanlinPlatformContracts", resources: [.process("Resources")]),
    .target(name: "HanlinHostContracts", dependencies: ["HanlinPlatformContracts"]),
    .target(name: "HanlinAgentCore", dependencies: ["HanlinPlatformContracts", "HanlinHostContracts"]),
    .testTarget(name: "SDKNavigationTransitionTests", dependencies: ["HanlinAgentCore", "HanlinHostContracts", "HanlinPlatformContracts"])
], swiftLanguageModes: [.v6])
"""
(package / "Package.swift").write_bytes(manifest.encode())
(output / "inputs.json").write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
command = [shutil.which("swift"), "test", "--scratch-path", str(ROOT / "build/hn"),
           "-j", "1", "-Xswiftc", "-strict-concurrency=complete"]
with (output / "swift-test.log").open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, cwd=package, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=240)
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
        else:
            process.kill()
        process.wait()
        code = 124
log_text = (output / "swift-test.log").read_text(encoding="utf-8", errors="replace")
expected = sorted(set(re.findall(r"func (test[A-Za-z0-9_]+)\(", fixture.read_text(encoding="utf-8"))))
passed = sorted(set(re.findall(r"Test Case '.*SDKNavigationTransitionTests[ .](test[A-Za-z0-9_]+)[\]'].*passed", log_text)))
if not passed:
    passed = sorted(set(re.findall(r"Test Case 'SDKNavigationTransitionTests\.(test[A-Za-z0-9_]+)' passed", log_text)))
if len(expected) != 8 or passed != expected:
    code = code or 1
report = {
    "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "status": "REPRODUCED_CURRENT_CONTRACT_LIMITATION" if code == 0 else "FAIL",
    "exit_code": code, "sdk_sha": args.sdk_sha,
    "inputs": len(inputs), "fixture_sha256": hashlib.sha256(fixture.read_bytes()).hexdigest(),
    "command": command, "passed": passed, "expected": expected,
    "warnings": log_text.count("warning:"), "native_passes": 0,
    "production_navigation_acceptance": "NOT_RUN",
    "boundary": "Whole unchanged SDK HostDispatcher + complete original Platform/Host contract modules. Explicit host/navigation effect double; no AgentSession, provider, UIKit, Otzaria runtime or actual UI acknowledgement.",
    "finding": "Current context changes caused by navigation cannot be acknowledged through HostDispatcher.open: returning the old context becomes stale after the host effect, while returning a new context fails result validation. Existing safety guards remain unchanged.",
}
(output / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
if code:
    print(log_text[-18000:])
raise SystemExit(code)
