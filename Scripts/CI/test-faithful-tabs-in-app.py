#!/usr/bin/env python3
"""Run original UIKit tests inside UIApplication, as in their original app target.

SwiftPM's hostless xctest cannot dispatch UIButton actions. This generated,
Simulator-only application supplies a real host; all test sources are unchanged.
"""
import json
from pathlib import Path
import subprocess

root = Path.cwd()
directory = root / "build/SourcePortTestHost"
project = directory / "FaithfulTabsTests.xcodeproj"
project.mkdir(parents=True, exist_ok=True)
(directory / "App.swift").write_text("import SwiftUI\n@main struct TestHost: App { var body: some Scene { WindowGroup { Color.clear } } }\n")
objects = {}
def uid(name):
    import hashlib
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def add(name, body):
    objects[name] = body
    return uid(name)
def refs(*names): return "(" + ",".join(uid(name) for name in names) + ")"
def quoted(value): return json.dumps(str(value))
def configurations(name, settings):
    add(name + "Config", 'isa = XCBuildConfiguration; name = Debug; buildSettings = {' + settings + '};')
    add(name + "Configs", 'isa = XCConfigurationList; buildConfigurations = ' + refs(name + "Config") + '; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;')
configurations("Project", 'SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 6.0; ENABLE_TESTABILITY = YES; CODE_SIGN_IDENTITY = "-";')
configurations("Host", 'PRODUCT_NAME = FaithfulTabsTestHost; PRODUCT_BUNDLE_IDENTIFIER = com.example.faithfultabs.host; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES; TARGETED_DEVICE_FAMILY = "1,2";')
configurations("Tests", 'PRODUCT_NAME = FaithfulTabsTests; PRODUCT_BUNDLE_IDENTIFIER = com.example.faithfultabs.tests; GENERATE_INFOPLIST_FILE = YES; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/FaithfulTabsTestHost.app/FaithfulTabsTestHost"; BUNDLE_LOADER = "$(TEST_HOST)";')
add("AppSource", 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App.swift; sourceTree = "<group>";')
add("AppBuild", 'isa = PBXBuildFile; fileRef = ' + uid("AppSource") + ';')
add("AppProduct", 'isa = PBXFileReference; explicitFileType = wrapper.application; path = FaithfulTabsTestHost.app; sourceTree = BUILT_PRODUCTS_DIR;')
add("TestProduct", 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = FaithfulTabsTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
test_names = []
port = root / "Source/ChavrusaText/StudyWorkspace/UI/DuckDuckGoTabsPort"
test_sources = sorted((port / "Tests").glob("*.swift")) + [
    root / "Source/ChavrusaText/ReaderHost/ReaderNavigationChromeState.swift",
    root / "MaktabahTests/ReaderNavigationChromeStateTests.swift",
    root / "Source/ChavrusaText/ReaderHost/ReaderOverviewPresentation.swift",
    root / "MaktabahTests/ReaderOverviewPresentationTests.swift",
]
for path in test_sources:
    name = path.stem
    test_names.append(name)
    add(name, 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ' + quoted(path) + '; sourceTree = "<absolute>";')
    add(name + "Build", 'isa = PBXBuildFile; fileRef = ' + uid(name) + ';')
add("Package", 'isa = XCLocalSwiftPackageReference; relativePath = ' + quoted(port) + ';')
add("Library", 'isa = XCSwiftPackageProductDependency; package = ' + uid("Package") + '; productName = DuckDuckGoBookTabs;')
add("LibraryBuild", 'isa = PBXBuildFile; productRef = ' + uid("Library") + ';')
for name, kind, files in [("AppSources", "Sources", ["AppBuild"]), ("TestSources", "Sources", [name + "Build" for name in test_names]),
                           ("AppFrameworks", "Frameworks", []), ("TestFrameworks", "Frameworks", ["LibraryBuild"])]:
    add(name, f'isa = PBX{kind}BuildPhase; buildActionMask = 2147483647; files = {refs(*files)}; runOnlyForDeploymentPostprocessing = 0;')
add("HostDependency", 'isa = PBXTargetDependency; target = ' + uid("Host") + ';')
for name, product, product_type, phases, dependencies, packages in [
    ("Host", "AppProduct", "application", ["AppSources", "AppFrameworks"], [], []),
    ("Tests", "TestProduct", "bundle.unit-test", ["TestSources", "TestFrameworks"], ["HostDependency"], ["Library"])]:
    add(name, f'isa = PBXNativeTarget; name = {name}; buildConfigurationList = {uid(name + "Configs")}; buildPhases = {refs(*phases)}; buildRules = (); dependencies = {refs(*dependencies)}; packageProductDependencies = {refs(*packages)}; productReference = {uid(product)}; productType = "com.apple.product-type.{product_type}";')
add("Group", 'isa = PBXGroup; children = ' + refs("AppSource", *test_names, "AppProduct", "TestProduct") + '; sourceTree = "<group>";')
add("Project", f'isa = PBXProject; buildConfigurationList = {uid("ProjectConfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base); mainGroup = {uid("Group")}; projectDirPath = ""; projectRoot = ""; targets = {refs("Host", "Tests")}; packageReferences = {refs("Package")};')
pbx = '// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'
pbx += "\n".join(f'{uid(name)} = {{ {body} }};' for name, body in objects.items())
pbx += f'\n}}; rootObject = {uid("Project")}; }}\n'
(project / "project.pbxproj").write_text(pbx)
schemes = project / "xcshareddata/xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
def reference(name, product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(name)}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:FaithfulTabsTests.xcodeproj"/>'
scheme = '<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction><BuildActionEntries>'
for name, product in [("Host", "FaithfulTabsTestHost.app"), ("Tests", "FaithfulTabsTests.xctest")]:
    scheme += '<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">' + reference(name, product) + '</BuildActionEntry>'
scheme += '</BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">'
scheme += reference("Tests", "FaithfulTabsTests.xctest") + '</TestableReference></Testables><MacroExpansion>' + reference("Host", "FaithfulTabsTestHost.app") + '</MacroExpansion></TestAction></Scheme>'
(schemes / "FaithfulTabsTests.xcscheme").write_text(scheme)
subprocess.run(["plutil", "-lint", str(project / "project.pbxproj")], check=True)
udid = (root / "sim_udid.txt").read_text().strip()
subprocess.run(["xcodebuild", "test", "-project", str(project), "-scheme", "FaithfulTabsTests", "-destination", f"platform=iOS Simulator,id={udid}",
                "-resultBundlePath", str(root / "build/artifacts/duck-tabs.xcresult"), "ONLY_ACTIVE_ARCH=YES", "ARCHS=arm64"], check=True)
