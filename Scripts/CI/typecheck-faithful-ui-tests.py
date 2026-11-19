#!/usr/bin/env python3
"""Cheap real-SDK compile of self-contained tests, including SIL isolation checks."""
import json
import hashlib
import runpy
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
           "-target", "arm64-apple-ios27.0-simulator", "-sdk", str(sdk),
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
          "xcode": version, "swift": swift_version, "sdk": str(sdk), "target": "arm64-apple-ios27.0-simulator",
          "status": "SDK_COMPILE_PASS" if result.returncode == 0 else "FAIL",
          "includesCodeGeneration": True,
          "warningCount": result.stdout.count("warning:"),
          "sourceHashes": {path: hashlib.sha256(Path(path).read_bytes()).hexdigest() for path in ui_sources},
          "notRuntimeAcceptance": True, "nativeUITestsExecuted": 0}
# Validate the exact selected declarations with this actual Apple Swift
# frontend too. Syntax/declaration evidence never grants a Native execution.
contract = json.loads(Path("docs/hq-integration/runtime27/R27_CASES.json").read_text())
groups = runpy.run_path("Scripts/CI/runtime27.py")["execution_groups"](contract)
selected = [case for group in groups for case in group["case_ids"]]
declaration_report = runpy.run_path("Scripts/CI/verify-faithful-xctest.py")["validate_selections"](selected)
declaration_tests = subprocess.run([sys.executable, "Scripts/CI/test-verify-faithful-xctest.py"],
                                   capture_output=True, text=True, timeout=120)
declaration_code = int(declaration_report["status"] != "DECLARATIONS_MATCH" or declaration_tests.returncode != 0)
report["nativeDeclarationPreflight"] = {"selectedCount": len(selected), "declarations": declaration_report,
    "compilerRegressionExitCode": declaration_tests.returncode, "nativeUITestsExecuted": 0}
with (artifacts / "ui-acceptance-typecheck.log").open("a", encoding="utf-8") as output:
    output.write("\nCompiler declaration regression checks (not Native):\n"
                 + declaration_tests.stdout + declaration_tests.stderr)
(artifacts / "ui-acceptance-typecheck.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
print(result.stdout)

# Compile the actual new sidebar search/title adapters as an independent
# SwiftUI module. It uses no app/model stubs and runs no native UI methods.
native_search_code = 0
native_search_path = Path("Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift")
native_search_marker = "// BEGIN SELF-CONTAINED SIDEBAR SEARCH ADAPTERS"
if native_search_path.is_file() and native_search_marker in native_search_path.read_text():
    native_search_source = "import SwiftUI\n" + native_search_path.read_text().split(native_search_marker, 1)[1].split("// END SELF-CONTAINED SIDEBAR SEARCH ADAPTERS", 1)[0]
    native_search_component = Path("build/ReaderSidebarNativeSearchSDK.swift")
    native_search_component.write_text(native_search_source, encoding="utf-8")
    native_search_command = compiler_options.copy()
    native_search_command[native_search_command.index("-module-name") + 1] = "ReaderSidebarNativeSearchSDK"
    native_search_command[native_search_command.index("-o") + 1] = "build/ReaderSidebarNativeSearchSDK.o"
    native_search_command[native_search_command.index("-target") + 1] = "arm64-apple-ios27.0-simulator"
    native_search_command.append(str(native_search_component))
    native_search_result = subprocess.run(native_search_command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    native_search_code = native_search_result.returncode
    (artifacts / "sidebar-native-search-sdk.log").write_text(native_search_result.stdout, encoding="utf-8")
    report["sidebarNativeSearch"] = {"sourceSHA": report["sourceSHA"], "command": native_search_command,
        "sourceSHA256": hashlib.sha256(native_search_path.read_bytes()).hexdigest(),
        "componentSHA256": hashlib.sha256(native_search_source.encode()).hexdigest(),
        "status": "SDK_COMPILE_PASS" if native_search_code == 0 else "BUILD_FAILED",
        "notRuntimeAcceptance": True, "nativeUITestsExecuted": 0}
    print(json.dumps(report["sidebarNativeSearch"], indent=2))
    print(native_search_result.stdout)

# Compile the actual self-contained native sidebar containers before a full
# app build. They need only SwiftUI/UIKit: no app/model stand-ins or harness.
sidebar_code = 0
sidebar_path = Path("Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift")
if sidebar_path.is_file() and "private struct ReaderSidebarSplitConfiguration:" in sidebar_path.read_text():
    sidebar = sidebar_path.read_text()
    component = sidebar.split("#if canImport(SwiftUI)", 1)[0] + "\nimport SwiftUI\nimport UIKit\n"
    component += sidebar[sidebar.index("private struct ReaderSidebarSplitConfiguration:"):sidebar.rindex("#endif")]
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
        "scope": "Actual ReaderSidebarSplitConfiguration; no app/model stubs; no native UI methods",
        "sourceSHA256": hashlib.sha256(sidebar_path.read_bytes()).hexdigest(), "command": sidebar_command}
    with (artifacts / "ui-acceptance-typecheck.log").open("a", encoding="utf-8") as output:
        output.write("\n=== Exact native sidebar adapter SDK compilation ===\n" + sidebar_result.stdout)
    print(json.dumps(report["sidebarAdapterSDK"], indent=2))
    print(sidebar_result.stdout)
toolbar_sources = [Path("Source/ChavrusaText/ToolbarSearch/ReaderToolbarActionAdapter.swift"),
                   Path("Source/ChavrusaText/ToolbarSearch/SafariToolbarSourcePort.swift"),
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
# These two full files now contain real application composition/lifecycle
# dependencies. They cannot be honestly compiled as standalone UIKit sources.
# Their self-contained search/split portions are compiled above, without
# substitutes; full-file compilation remains mandatory in the existing actual
# app/build-for-testing gate. Keep exact hashes and that boundary in evidence.
app_composed_sidebar_sources = [
    Path("Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift"),
    Path("Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift"),
]
report["appComposedSidebar"] = {
    "scope": "Full source belongs to actual app compilation, not this standalone SDK module",
    "status": "REQUIRES_FULL_APP_BUILD",
    "standaloneCoverage": ["exact native search/title adapters", "exact native split configuration"],
    "appMembershipGate": "verify-otzaria-xcode-project.py",
    "sourceHashes": {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                     for path in app_composed_sidebar_sources if path.is_file()},
}
# The original search field now participates in the real native scene lifetime.
# Compile its exact self-contained UIKit control here; the representable and
# coordinator require the actual app composition and must pass the full
# build/build-for-testing gate. No substitute Scene/Environment owner is used.
native_field_path = Path("Source/ChavrusaText/Search/UI/NativeGlobalSearchField.swift")
native_field = native_field_path.read_text(encoding="utf-8")
native_field_marker = "private final class GlobalSearchTextField: UISearchTextField {"
if native_field.count(native_field_marker) != 1:
    raise RuntimeError("Expected one actual native UIKit search control")
native_field_component = Path("build/NativeGlobalSearchUIKitControl.swift")
native_field_bytes = ("import UIKit\n" + native_field[native_field.index(native_field_marker):]).encode()
native_field_component.write_bytes(native_field_bytes)
toolbar_sources.append(native_field_component)
report["appComposedGlobalSearchField"] = {
    "scope": "Actual representable/coordinator require the original native Scene and Environment owner",
    "status": "REQUIRES_FULL_APP_BUILD",
    "standaloneCoverage": "Exact original GlobalSearchTextField UIKit control, with no source substitutions",
    "appMembershipGate": "verify-otzaria-xcode-project.py",
    "sourceHashes": {str(native_field_path): hashlib.sha256(native_field_path.read_bytes()).hexdigest()},
    "componentSHA256": hashlib.sha256(native_field_bytes).hexdigest(),
    "nativeUITestsExecuted": 0,
}
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
# Exact self-contained passive reader TextKit witness, with no app/model stubs.
reader_visibility_code = 0
reader_visibility_path = Path("Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneProjection.swift")
reader_visibility_marker = "// BEGIN SELF-CONTAINED NATIVE READER TEXT VISIBILITY"
if reader_visibility_path.is_file() and reader_visibility_marker in reader_visibility_path.read_text():
    reader_visibility_source = "import UIKit\n" + reader_visibility_path.read_text().split(reader_visibility_marker, 1)[1].split("// END SELF-CONTAINED NATIVE READER TEXT VISIBILITY", 1)[0]
    reader_visibility_component = Path("build/NativeReaderTextVisibilitySDK.swift")
    reader_visibility_component.write_text(reader_visibility_source, encoding="utf-8")
    reader_visibility_command = compiler_options.copy()
    reader_visibility_command[reader_visibility_command.index("-module-name") + 1] = "NativeReaderTextVisibilitySDK"
    reader_visibility_command[reader_visibility_command.index("-o") + 1] = "build/NativeReaderTextVisibilitySDK.o"
    reader_visibility_command.append(str(reader_visibility_component))
    reader_visibility_result = subprocess.run(reader_visibility_command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    reader_visibility_code = reader_visibility_result.returncode
    report["nativeReaderTextVisibilitySDK"] = {
        "sourceSHA": report["sourceSHA"], "status": "SDK_COMPILE_PASS" if reader_visibility_code == 0 else "BUILD_FAILED",
        "sourceSHA256": hashlib.sha256(reader_visibility_path.read_bytes()).hexdigest(),
        "componentSHA256": hashlib.sha256(reader_visibility_source.encode()).hexdigest(),
        "notRuntimeAcceptance": True, "nativeUITestsExecuted": 0,
        "command": reader_visibility_command
    }
    with (artifacts / "ui-acceptance-typecheck.log").open("a", encoding="utf-8") as output:
        output.write("\n=== Actual native reader TextKit witness SDK compilation ===\n" + reader_visibility_result.stdout)
    print(json.dumps(report["nativeReaderTextVisibilitySDK"], indent=2))
    print(reader_visibility_result.stdout)

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
                           "--triple", "arm64-apple-ios27.0-simulator", "--sdk", str(sdk),
                           "-j", "2", "-v", "-Xswiftc", "-strict-concurrency=complete",
                           "-Xswiftc", "-target", "-Xswiftc", "arm64-apple-ios27.0-simulator"]
    native_host_result = subprocess.run(native_host_command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    native_host_code = native_host_result.returncode
    (artifacts / "native-routing-host-sdk.log").write_text(native_host_result.stdout, encoding="utf-8")
    native_host_sources = [native_host / "Package.swift", *sorted((native_host / "Sources").rglob("*.swift"))]
    native_host_report = {"sourceSHA": report["sourceSHA"], "xcode": version, "swift": swift_version, "sdk": str(sdk),
                          "target": "arm64-apple-ios27.0-simulator", "command": native_host_command,
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
# Execute the complete original SQLite wrapper with the installed macOS SQLite.
# The unrelated Zstd compile boundary fails if called; no SQLite replacement,
# source DB mutation, or Native acceptance claim is involved.
sqlite_directory = artifacts / "sqlite-source"
sqlite_command = [sys.executable, "tools/hq-sqlite-acceptance.py",
                  "--artifacts-dir", str(sqlite_directory)]
sqlite_result = subprocess.run(sqlite_command, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
sqlite_code = sqlite_result.returncode
(artifacts / "ui-acceptance-typecheck.sqlite-driver.log").write_text(sqlite_result.stdout, encoding="utf-8")
for name in ["RESULT.json", "compile.log", "tests.log", "swift-test.log", "inputs.json"]:
    source = sqlite_directory / name
    if source.is_file():
        (artifacts / ("ui-acceptance-typecheck.sqlite-" + name)).write_bytes(source.read_bytes())
sqlite_report = sqlite_directory / "RESULT.json"
report["actualSQLite"] = json.loads(sqlite_report.read_text()) if sqlite_report.is_file() else {
    "status": "FAILED_WITHOUT_REPORT", "exitCode": sqlite_code, "native_ui_executed": 0}
print(json.dumps({"actualSQLiteStatus": report["actualSQLite"]["status"],
                  "exitCode": sqlite_code}, indent=2))
# Execute the complete Hebrew matcher with the installed macOS Foundation, and
# the exact app Inspector owner with explicit app-model boundary doubles. Neither
# driver contributes a Native UI pass; the unchanged SDK dispatcher proof also
# records its explicit context-transition limitation. Actual app compilation remains required.
source_regression_code = 0
for label, driver in [
    ("hebrew-ranges", "tools/hq-hebrew-match-ranges.py"),
    ("inspector-owner", "tools/hq-native-inspector-ownership.py"),
    ("hanlin-navigation-contract", "tools/hq-hanlin-navigation-transition.py"),
]:
    directory = artifacts / label
    checked = subprocess.run([sys.executable, driver, "--artifacts-dir", str(directory)],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
    source_regression_code = source_regression_code or checked.returncode
    (artifacts / ("ui-acceptance-typecheck." + label + "-driver.log")).write_text(checked.stdout, encoding="utf-8")
    for name in ["RESULT.json", "compile.log", "tests.log", "swift-test.log", "inputs.json"]:
        source = directory / name
        if source.is_file():
            (artifacts / ("ui-acceptance-typecheck." + label + "-" + name)).write_bytes(source.read_bytes())
    receipt = directory / "RESULT.json"
    report[label] = json.loads(receipt.read_text(encoding="utf-8")) if receipt.is_file() else {
        "status": "FAILED_WITHOUT_REPORT", "exitCode": checked.returncode, "native_passes": 0}
    print(json.dumps({"sourceRegression": label, "exitCode": checked.returncode, "native_passes": 0}))
report["appMembershipStatus"] = "PASS" if membership_code == 0 else "FAIL"
report["toolbarSDKStatus"] = "SDK_COMPILE_PASS" if toolbar_code == 0 else "BUILD_FAILED"
report["aggregateSDKStatus"] = "PASS" if not (result.returncode or sidebar_code or toolbar_code or native_host_code or membership_code or native_search_code or reader_visibility_code or declaration_code or sqlite_code or source_regression_code) else "FAIL"
(artifacts / "ui-acceptance-typecheck.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
raise SystemExit(result.returncode or sidebar_code or toolbar_code or native_host_code or membership_code or native_search_code or reader_visibility_code or declaration_code or sqlite_code or source_regression_code)
