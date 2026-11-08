#!/usr/bin/env python3
"""Cheap real-SDK compile of self-contained tests, including SIL isolation checks."""
import json
import hashlib
from pathlib import Path
import subprocess

artifacts = Path("build/artifacts")
artifacts.mkdir(parents=True, exist_ok=True)
sdk = Path(subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True).strip())
platform = Path(subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-platform-path"], text=True).strip())
version = subprocess.check_output(["xcodebuild", "-version"], text=True).strip()
# Targeted read-only SDK evidence: current documentation introduces a VoiceOver
# automation service, but its actual platform/Simulator availability must come
# from this installed toolchain rather than an older Simulator guide.
voiceover = []
for frameworks in [platform / "Developer/Library/Frameworks", sdk / "Developer/Library/Frameworks"]:
    headers = frameworks / "XCUIAutomation.framework/Headers"
    if headers.is_dir():
        for header in sorted(headers.glob("*.h")):
            source = header.read_text()
            if "VoiceOver" in source or "XCUI_SIMULATOR_UNAVAILABLE" in source:
                voiceover.append(f"// {header}\n{source}")
(artifacts / "xcuiautomation-voiceover-sdk.txt").write_text("\n".join(voiceover) or "XCUIAutomation headers not found in the checked SDK paths\n")
command = ["xcrun", "swiftc", "-c", "-whole-module-optimization", "-o", "build/UIAcceptanceCheck.o",
           "-module-name", "Maktabah_iOSUITests", "-swift-version", "6", "-enable-testing",
           "-D", "DEBUG", "-module-alias", "Testing=_Testing_Unavailable",
           "-target", "arm64-apple-ios18.6-simulator", "-sdk", str(sdk),
           "-Isystem", str(platform / "Developer/usr/lib"),
           "-F", str(platform / "Developer/Library/Frameworks"), "-F", str(sdk / "Developer/Library/Frameworks"),
           "-module-cache-path", "build/UIAcceptanceModuleCache"]
# Exact upcoming-feature flags from the real app UI-test SwiftDriver invocation.
for feature in ["MemberImportVisibility", "InferIsolatedConformances", "NonisolatedNonsendingByDefault"]:
    command.extend(["-enable-upcoming-feature", feature])
ui_sources = ["Maktabah-iOSUITests/MaktabahUITestBase.swift", "Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift",
              "Maktabah-iOSUITests/Build8401SevenDefectsAcceptanceTests.swift",
              "Maktabah-iOSUITests/PullNavigationAcceptanceTests.swift",
              "Maktabah-iOSUITests/SefariaEmbeddedAcceptanceTests.swift"]
compiler_options = command.copy()
command.extend(ui_sources)
result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
(artifacts / "ui-acceptance-typecheck.log").write_text(result.stdout, encoding="utf-8")
report = {"sourceSHA": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
          "xcode": version, "sdk": str(sdk), "target": "arm64-apple-ios18.6-simulator",
          "status": "SDK_COMPILE_PASS" if result.returncode == 0 else "FAIL",
          "includesCodeGeneration": True,
          "warningCount": result.stdout.count("warning:"),
          "notRuntimeAcceptance": True}
(artifacts / "ui-acceptance-typecheck.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
print(result.stdout)
toolbar_sources = [Path("Source/ChavrusaText/ToolbarSearch/ReaderToolbarActionAdapter.swift"),
                   Path("Source/ChavrusaText/ToolbarSearch/SafariToolbarSourcePort.swift"),
                   Path("Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift"),
                   Path("Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift")]
toolbar_code = 0
if all(path.is_file() for path in toolbar_sources):
    # Compile the real self-contained app components, not substitute stubs.
    # They do not exist in the immutable original baseline checkout.
    toolbar_command = compiler_options.copy()
    toolbar_command[toolbar_command.index("-module-name") + 1] = "FaithfulToolbarSDK"
    toolbar_command[toolbar_command.index("-o") + 1] = "build/ToolbarSourceCheck.o"
    toolbar_command.extend(map(str, toolbar_sources))
    toolbar_result = subprocess.run(toolbar_command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    toolbar_code = toolbar_result.returncode
    (artifacts / "toolbar-sdk-compile.log").write_text(toolbar_result.stdout)
    toolbar_report = {"sourceSHA": report["sourceSHA"], "xcode": version, "sdk": str(sdk),
                      "status": "SDK_COMPILE_PASS" if toolbar_code == 0 else "FAIL",
                      "includesCodeGeneration": True, "notRuntimeAcceptance": True,
                      "sourceHashes": {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in toolbar_sources}}
    (artifacts / "toolbar-sdk-compile.json").write_text(json.dumps(toolbar_report, indent=2))
    print(json.dumps(toolbar_report, indent=2))
    print(toolbar_result.stdout)
raise SystemExit(result.returncode or toolbar_code)
