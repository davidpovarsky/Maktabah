#!/usr/bin/env python3
"""Full native corpus -> same-container Release upgrade -> genuine UI tests.

Run after the Debug/visual gates, using this exact checkout. No app database is
copied or fabricated. Only a simulator created by this script is removed.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

root = Path.cwd()
artifacts = root / "build/artifacts"
artifacts.mkdir(parents=True, exist_ok=True)
report = {"appSHA": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
          "configuration": "Release", "dataProfile": "production", "status": "NOT_RUN"}
def run(command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)
def sim_json(*args):
    return json.loads(subprocess.check_output(["xcrun", "simctl", *args, "-j"], text=True))

# Build an actual Release binary/test runner. Reuse verified dependencies and
# production Metro resources from the already-built Debug validation checkout.
run(["xcodebuild", "build-for-testing", "-workspace", "Maktabah.xcworkspace", "-scheme", "Maktabah-iOS",
     "-configuration", "Release", "-sdk", "iphonesimulator", "-destination", "generic/platform=iOS Simulator",
     "-derivedDataPath", "build/ReleaseDerivedData", "-clonedSourcePackagesDirPath", "build/SourcePackages",
     "-disableAutomaticPackageResolution", "-jobs", "8", "CODE_SIGN_IDENTITY=-", "CODE_SIGNING_REQUIRED=YES",
     "CODE_SIGNING_ALLOWED=YES", "COMPILER_INDEX_STORE_ENABLE=NO", "ONLY_ACTIVE_ARCH=YES", "ARCHS=arm64",
     "ENABLE_USER_SCRIPT_SANDBOXING=NO", "RCT_NO_LAUNCH_PACKAGER=1", "SKIP_BUNDLING=1", "FAIL_ON_MISSING_BUNDLE=1",
     "OTZARIA_DEFAULT_DATA_PROFILE=production"])
products = root / "build/ReleaseDerivedData/Build/Products/Release-iphonesimulator"
release_app = products / "Maktabah.app"
run(["bash", "Scripts/copy-sefaria-bundle-resources.sh", str(release_app)])
run(["codesign", "--force", "--deep", "--sign", "-", str(release_app)])
run(["codesign", "--force", "--deep", "--sign", "-", str(products / "Maktabah-iOSUITests-Runner.app")])

runtimes = [value for value in sim_json("list", "runtimes", "available")["runtimes"]
            if value.get("isAvailable") and value["version"].split(".")[0] == "27"
            and ".iOS-" in value["identifier"]]
runtimes.sort(key=lambda value: tuple(map(int, value["version"].split("."))), reverse=True)
types = [value for value in sim_json("list", "devicetypes")["devicetypes"] if "iPad Pro" in value["name"] and "13-inch" in value["name"]]
types.sort(key=lambda value: ("16GB" in value["identifier"], value["identifier"]))
udid = None
for runtime in runtimes:
    supported = {value["identifier"] for value in runtime.get("supportedDeviceTypes", [])}
    for device_type in types:
        if device_type["identifier"] not in supported:
            continue
        result = subprocess.run(["xcrun", "simctl", "create", "Faithful Release " + uuid.uuid4().hex[:8],
                                 device_type["identifier"], runtime["identifier"]], capture_output=True, text=True)
        if result.returncode == 0:
            udid = result.stdout.strip()
            report.update(runtime=runtime, deviceType=device_type, udid=udid)
            break
    if udid:
        break
if not udid:
    raise SystemExit("No compatible 13-inch iPadOS 27 Simulator; Release acceptance did not execute")
try:
    run(["xcrun", "simctl", "boot", udid], timeout=90)
    run(["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=900)
    debug_app = root / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app"
    run(["xcrun", "simctl", "install", udid, str(debug_app)], timeout=600)
    (root / "sim_udid.txt").write_text(udid)
    # The existing native installer validates digest/schema/quick_check and
    # installs into the ordinary managed app container. Its DEBUG entry point
    # is used only to provision data, then the Release app replaces the binary.
    run([sys.executable, "Scripts/CI/prepare-faithful-ipad-fixtures.py", "--profile", "production"], timeout=3900)
    install = json.loads((artifacts / "production-native-fixture-install.json").read_text())
    report["nativeInstallation"] = {key: install.get(key) for key in ["passed", "profileID", "shaMatched", "bookCount", "lineCount", "extractedBytes", "searchArtifactsRequested"]}
    if install.get("extractedBytes", 0) < 1_500_000_000:
        raise SystemExit("The full production corpus was not provisioned")
    run(["xcrun", "simctl", "install", udid, str(release_app)], timeout=600)
    result_path = artifacts / "production-release.xcresult"
    command = ["xcodebuild", "test-without-building", "-workspace", "Maktabah.xcworkspace", "-scheme", "Maktabah-iOS",
               "-configuration", "Release", "-derivedDataPath", "build/ReleaseDerivedData", "-destination", f"platform=iOS Simulator,id={udid}",
               "-resultBundlePath", str(result_path), "-only-testing:Maktabah-iOSUITests/FaithfulProductionReleaseTests"]
    with (artifacts / "production-release-tests.log").open("w") as log:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        for line in process.stdout:
            log.write(line)
            print(line, end="", flush=True)
        code = process.wait()
    text = (artifacts / "production-release-tests.log").read_text()
    report["executedXCTestCount"] = max([int(value) for value in re.findall(r"Executed\s+([1-9][0-9]*)\s+tests?", text)], default=0)
    if result_path.is_dir():
        run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result_path), "--output-path", str(artifacts / "visual-production-release")])
    if code or report["executedXCTestCount"] == 0:
        raise SystemExit("The actual full-corpus Release UI acceptance failed or did not execute")
    report["status"] = "EXECUTED_PASS"
finally:
    (artifacts / "production-release-acceptance.json").write_text(json.dumps(report, indent=2))
    subprocess.run(["xcrun", "simctl", "shutdown", udid], check=False, capture_output=True)
    subprocess.run(["xcrun", "simctl", "delete", udid], check=False, capture_output=True)
