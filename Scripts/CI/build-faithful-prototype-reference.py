#!/usr/bin/env python3
"""Build the owner's byte-identical demo as a separate, Simulator-only oracle.

Nothing here belongs to Maktabah's target. The generated project replaces only
Playgrounds' AppleProductTypes packaging; the app source remains untouched and
the original CommandPalette dependency uses the owner's immutable source pin.
"""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path.cwd()
source = root / "tools/faithful-ui-reference/MyApp.swift"
source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
if source_hash != "cd07ea2e5eef10a2601e4eaa7ab6cab77213867743170fd1bc1a9311cda3d51d":
    raise SystemExit("The owner's original prototype source has changed; it cannot be used as an exact oracle")
output = root / "build/SafariPrototypeReference"
project = output / "SafariPrototypeReference.xcodeproj"
project.mkdir(parents=True, exist_ok=True)
pin = "9ed36f80b81783433d3e5cc5e75987f71d71bd53"
original_package = output / "OriginalCommandPalette"
if not original_package.exists():
    subprocess.run(["git", "clone", "--no-checkout", "https://github.com/halilozel1903/CommandPalette.git", str(original_package)], check=True)
    subprocess.run(["git", "-C", str(original_package), "checkout", "--detach", pin], check=True)
if subprocess.check_output(["git", "-C", str(original_package), "rev-parse", "HEAD"], text=True).strip() != pin:
    raise SystemExit("The isolated prototype dependency does not match its immutable original pin")

# Stable identifiers, one application target, no signing or production changes.
objects = {
    "001": 'isa = PBXProject; attributes = { LastUpgradeCheck = 2700; }; buildConfigurationList = REF010; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = REF002; productRefGroup = REF003; projectDirPath = ""; projectRoot = ""; targets = (REF004); packageReferences = (REF020);',
    "002": 'isa = PBXGroup; children = (REF005, REF003); sourceTree = "<group>";',
    "003": 'isa = PBXGroup; children = (REF006); name = Products; sourceTree = "<group>";',
    "004": 'isa = PBXNativeTarget; buildConfigurationList = REF011; buildPhases = (REF007, REF008, REF009); buildRules = (); dependencies = (); name = SafariPrototypeReference; productName = SafariPrototypeReference; productReference = REF006; productType = "com.apple.product-type.application"; packageProductDependencies = (REF021);',
    "005": f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {json.dumps(str(source))}; sourceTree = "<absolute>";',
    "006": 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SafariPrototypeReference.app; sourceTree = BUILT_PRODUCTS_DIR;',
    "007": 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (REF022); runOnlyForDeploymentPostprocessing = 0;',
    "008": 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (REF023); runOnlyForDeploymentPostprocessing = 0;',
    "009": 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;',
    "010": 'isa = XCConfigurationList; buildConfigurations = (REF012); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;',
    "011": 'isa = XCConfigurationList; buildConfigurations = (REF013); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;',
    "012": 'isa = XCBuildConfiguration; name = Debug; buildSettings = { SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 6.0; };',
    "013": 'isa = XCBuildConfiguration; name = Debug; buildSettings = { PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = com.example.safaritoolbarsearch; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"; TARGETED_DEVICE_FAMILY = "1,2"; SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor; CODE_SIGNING_ALLOWED = NO; };',
    "020": f'isa = XCLocalSwiftPackageReference; relativePath = {json.dumps(str(original_package))};',
    "021": 'isa = XCSwiftPackageProductDependency; package = REF020; productName = CommandPalette;',
    "022": 'isa = PBXBuildFile; fileRef = REF005;',
    "023": 'isa = PBXBuildFile; productRef = REF021;',
}
def identifier(number):
    return "FA1700000000000000000" + number

pbx = "// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n"
for number, body in objects.items():
    for reference in objects:
        body = body.replace("REF" + reference, identifier(reference))
    pbx += f"{identifier(number)} = {{ {body} }};\n"
pbx += f"}}; rootObject = {identifier('001')}; }}\n"
(project / "project.pbxproj").write_text(pbx)
subprocess.run(["plutil", "-lint", str(project / "project.pbxproj")], check=True)
subprocess.run(["xcodebuild", "build", "-project", str(project), "-scheme", "SafariPrototypeReference",
                "-configuration", "Debug", "-sdk", "iphonesimulator", "-destination", "generic/platform=iOS Simulator",
                "-derivedDataPath", str(output / "DerivedData"), "CODE_SIGNING_ALLOWED=NO", "ARCHS=arm64"], check=True)
app = output / "DerivedData/Build/Products/Debug-iphonesimulator/SafariPrototypeReference.app"
subprocess.run(["codesign", "--force", "--deep", "--sign", "-", str(app)], check=True)
manifest = {"sourceSHA256": source_hash, "commandPaletteRevision": pin,
            "source": "Owner SafariToolbarSearch.swiftpm/MyApp.swift; byte-identical", "configuration": "Debug",
            "packagingDifference": "Simulator-only Xcode application target instead of AppleProductTypes",
            "productionTargetMembership": False}
destination = root / "build/artifacts/prototype-reference-manifest.json"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(manifest, indent=2))
