#!/usr/bin/env python3
"""Cheap real-SDK compile of self-contained tests, including SIL isolation checks."""
import json
import hashlib
from pathlib import Path
import subprocess
import sys

membership_code = 0
if Path("Source/ChavrusaText/ReaderHost/ReaderOverviewPresentation.swift").is_file():
    # Keep the membership gate failing, while still obtaining independent SDK
    # compiler diagnostics for packages awaiting manager-owned app registration.
    membership_code = subprocess.run([sys.executable, "Scripts/CI/verify-otzaria-xcode-project.py"]).returncode

artifacts = Path("build/artifacts")
artifacts.mkdir(parents=True, exist_ok=True)
sdk = Path(subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True).strip())
platform = Path(subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-platform-path"], text=True).strip())
version = subprocess.check_output(["xcodebuild", "-version"], text=True).strip()
swift_version = subprocess.check_output(["xcrun", "swift", "--version"], text=True).strip()
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
if Path("Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift").is_file():
    ui_sources.append("Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift")
for name in ["GlobalSearchNativeAcceptanceTests.swift", "R27NativeInteractionAcceptanceTests.swift", "Sidebar11201AcceptanceTests.swift"]:
    path = "Maktabah-iOSUITests/" + name
    if Path(path).is_file():
        ui_sources.append(path)
compiler_options = command.copy()
command.extend(ui_sources)
result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
(artifacts / "ui-acceptance-typecheck.log").write_text(result.stdout, encoding="utf-8")
report = {"sourceSHA": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
          "xcode": version, "swift": swift_version, "sdk": str(sdk), "target": "arm64-apple-ios18.6-simulator",
          "status": "SDK_COMPILE_PASS" if result.returncode == 0 else "FAIL",
          "includesCodeGeneration": True,
          "warningCount": result.stdout.count("warning:"),
          "notRuntimeAcceptance": True}
(artifacts / "ui-acceptance-typecheck.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
print(result.stdout)

# Compile the actual self-contained native sidebar containers before a full
# app build. They need only SwiftUI/UIKit: no app/model stand-ins or harness.
sidebar_code = 0
sidebar_path = Path("Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift")
if sidebar_path.is_file() and "private struct ReaderSidebarPages<" in sidebar_path.read_text():
    sidebar = sidebar_path.read_text()
    component = sidebar.split("#if canImport(SwiftUI)", 1)[0] + "\nimport SwiftUI\nimport UIKit\n"
    component += sidebar[sidebar.index("private struct ReaderSidebarPages<"):sidebar.rindex("#endif")]
    component_path = Path("build/Phase1SidebarAdapter.swift")
    component_path.write_text(component)
    sidebar_command = compiler_options.copy()
    sidebar_command[sidebar_command.index("-module-name") + 1] = "Phase1SidebarSDK"
    sidebar_command[sidebar_command.index("-o") + 1] = "build/Phase1SidebarSDK.o"
    sidebar_command.append(str(component_path))
    sidebar_result = subprocess.run(sidebar_command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    sidebar_code = sidebar_result.returncode
    report["sidebarAdapterSDK"] = {"sourceSHA": report["sourceSHA"],
        "status": "SDK_COMPILE_PASS" if sidebar_code == 0 else "BUILD_FAILED",
        "scope": "Actual ReaderSidebarPages and ReaderSidebarSplitConfiguration; no app/model stubs; no native UI methods",
        "sourceSHA256": hashlib.sha256(sidebar_path.read_bytes()).hexdigest(), "command": sidebar_command}
    with (artifacts / "ui-acceptance-typecheck.log").open("a", encoding="utf-8") as output:
        output.write("\n=== Exact native sidebar adapter SDK compilation ===\n" + sidebar_result.stdout)
    print(json.dumps(report["sidebarAdapterSDK"], indent=2))
    print(sidebar_result.stdout)
toolbar_sources = [Path("Source/ChavrusaText/ToolbarSearch/ReaderToolbarActionAdapter.swift"),
                   Path("Source/ChavrusaText/ToolbarSearch/SafariToolbarSourcePort.swift"),
                   Path("Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift"),
                   Path("Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift"),
                   Path("Source/ChavrusaText/ReaderHost/ReaderOverviewPresentation.swift"),
                   Path("MaktabahTests/ReaderOverviewPresentationTests.swift")]
# Include the real self-contained UIKit source port when checking a focused
# correction such as the original UIFontDescriptor factories. No app/model
# substitutes are used, and immutable baseline sources remain untouched.
tabs_port = Path("Source/ChavrusaText/StudyWorkspace/UI/DuckDuckGoTabsPort")
toolbar_sources.extend(tabs_port / name for name in [
    "TabsBarLayout.swift", "TabsBarView.swift", "TabsBarCell.swift", "TabsBarViewController.swift",
    "TabFlareBackgroundController.swift", "TabFlaredBackgroundView.swift", "ReaderBookTabsModel.swift",
    "ReaderTabFadeOutLabel.swift", "TabSwitcherPagePort.swift",
])
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
# UI03/04 downstream package: compile the real sources and their actual Core /
# UIRouting dependencies for the installed iOS SDK. Windows excludes UIKit and
# AppIntents, so portable tests alone cannot validate these declarations.
# This extends the existing manual SDK check; it changes no workflow triggers,
# app target membership, deployment target, signing or runtime acceptance.
native_host_code = 0
native_host = Path("Source/ChavrusaText/UIRoutingHost")
if (native_host / "Package.swift").is_file():
    native_host_command = ["xcrun", "swift", "build", "--package-path", str(native_host),
                           "--build-system", "native",
                           "--triple", "arm64-apple-ios26.0-simulator", "--sdk", str(sdk),
                           "-j", "2", "-v", "-Xswiftc", "-strict-concurrency=complete",
                           "-Xswiftc", "-target", "-Xswiftc", "arm64-apple-ios26.0-simulator"]
    native_host_result = subprocess.run(native_host_command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    native_host_code = native_host_result.returncode
    (artifacts / "native-routing-host-sdk.log").write_text(native_host_result.stdout, encoding="utf-8")
    native_host_sources = [native_host / "Package.swift", *sorted((native_host / "Sources").rglob("*.swift"))]
    native_host_report = {"sourceSHA": report["sourceSHA"], "xcode": version, "swift": swift_version, "sdk": str(sdk),
                          "target": "arm64-apple-ios26.0-simulator", "command": native_host_command,
                          "status": "SDK_COMPILE_PASS" if native_host_code == 0 else "BUILD_FAILED",
                          "notRuntimeAcceptance": True, "nativeUITestsExecuted": 0,
                          "sourceHashes": {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in native_host_sources}}
    (artifacts / "native-routing-host-sdk.json").write_text(json.dumps(native_host_report, indent=2), encoding="utf-8")
    # Retain the new evidence in the existing workflow's already-uploaded files.
    report["nativeRoutingHost"] = native_host_report
    (artifacts / "ui-acceptance-typecheck.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    with (artifacts / "ui-acceptance-typecheck.log").open("a", encoding="utf-8") as output:
        output.write("\n=== Native routing host SDK compilation ===\n" + native_host_result.stdout)
    print(json.dumps(native_host_report, indent=2))
    print(native_host_result.stdout)
report["appMembershipStatus"] = "PASS" if membership_code == 0 else "FAIL"
report["toolbarSDKStatus"] = "SDK_COMPILE_PASS" if toolbar_code == 0 else "BUILD_FAILED"
report["aggregateSDKStatus"] = "PASS" if not (result.returncode or sidebar_code or toolbar_code or native_host_code or membership_code) else "FAIL"
(artifacts / "ui-acceptance-typecheck.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
raise SystemExit(result.returncode or sidebar_code or toolbar_code or native_host_code or membership_code)
