#!/usr/bin/env python3
"""Cheap real-SDK check of the self-contained black-box XCTest sources."""
import json
from pathlib import Path
import subprocess

artifacts = Path("build/artifacts")
artifacts.mkdir(parents=True, exist_ok=True)
sdk = Path(subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True).strip())
platform = Path(subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-platform-path"], text=True).strip())
version = subprocess.check_output(["xcodebuild", "-version"], text=True).strip()
command = ["xcrun", "swiftc", "-typecheck", "-module-name", "Maktabah_iOSUITests", "-swift-version", "6", "-enable-testing",
           "-D", "DEBUG", "-module-alias", "Testing=_Testing_Unavailable",
           "-target", "arm64-apple-ios18.6-simulator", "-sdk", str(sdk),
           "-Isystem", str(platform / "Developer/usr/lib"),
           "-F", str(platform / "Developer/Library/Frameworks"), "-F", str(sdk / "Developer/Library/Frameworks"),
           "-module-cache-path", "build/UIAcceptanceModuleCache"]
# Exact upcoming-feature flags from the real app UI-test SwiftDriver invocation.
for feature in ["MemberImportVisibility", "InferIsolatedConformances", "NonisolatedNonsendingByDefault"]:
    command.extend(["-enable-upcoming-feature", feature])
command.extend(["Maktabah-iOSUITests/MaktabahUITestBase.swift", "Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift"])
result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
(artifacts / "ui-acceptance-typecheck.log").write_text(result.stdout, encoding="utf-8")
report = {"sourceSHA": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
          "xcode": version, "sdk": str(sdk), "target": "arm64-apple-ios18.6-simulator",
          "status": "TYPECHECK_PASS" if result.returncode == 0 else "FAIL",
          "warningCount": result.stdout.count("warning:"),
          "notRuntimeAcceptance": True}
(artifacts / "ui-acceptance-typecheck.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
print(result.stdout)
raise SystemExit(result.returncode)
