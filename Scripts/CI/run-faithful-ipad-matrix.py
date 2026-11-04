#!/usr/bin/env python3
"""Real black-box acceptance on disposable 11/13-inch iPadOS 27 simulators."""
import json
import os
import re
import shutil
from pathlib import Path
import subprocess
import sys
import uuid

root = Path.cwd()
artifacts = root / "build/artifacts"
artifacts.mkdir(parents=True, exist_ok=True)
app = root / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app"
prototype = root / "build/SafariPrototypeReference/DerivedData/Build/Products/Debug-iphonesimulator/SafariPrototypeReference.app"
if not app.is_dir():
    raise SystemExit("The actual built app is missing")

def sim_json(*args):
    return json.loads(subprocess.check_output(["xcrun", "simctl", *args, "-j"], text=True))

runtimes = [runtime for runtime in sim_json("list", "runtimes", "available")["runtimes"]
            if runtime.get("isAvailable") and runtime["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS")
            and runtime["version"].split(".")[0] == "27"]
if not runtimes:
    raise SystemExit("Required iPadOS 27 runtime is unavailable; older Simulator results cannot satisfy this gate")
runtimes.sort(key=lambda value: tuple(map(int, value["version"].split("."))), reverse=True)
device_types = sim_json("list", "devicetypes")["devicetypes"]
baseline = os.environ.get("VALIDATING_BASELINE") == "true"
app_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
report = {"appSHA": app_sha, "testSHA": os.environ.get("GITHUB_SHA"), "baseline": baseline,
          "configuration": "Debug", "dataProfile": "miniTest10", "devices": []}

def create_compatible_ipad(size):
    candidates = [value for value in device_types if
                  ("iPhone" in value["name"] if size == "phone" else "iPad Pro" in value["name"] and f"{size}-inch" in value["name"])]
    # Some installed device profiles (e.g. RAM variants) are incompatible with
    # an otherwise available runtime. Let CoreSimulator verify each exact pair.
    candidates.sort(key=lambda value: ("16GB" in value["identifier"], value["identifier"]))
    failures = []
    for runtime in runtimes:
        for device_type in candidates:
            result = subprocess.run(["xcrun", "simctl", "create", f"Faithful {size}-inch {uuid.uuid4().hex[:8]}",
                                     device_type["identifier"], runtime["identifier"]], text=True, capture_output=True)
            if result.returncode == 0:
                return result.stdout.strip(), device_type, runtime, failures
            failures.append({"deviceType": device_type["identifier"], "runtime": runtime["identifier"], "error": result.stderr.strip()})
    raise SystemExit(f"No compatible {size}-inch iPad Pro / iPadOS 27 pair: {json.dumps(failures)}")

for index, size in enumerate(["11", "13", "phone"]):
    udid, device_type, runtime, failures = create_compatible_ipad(size)
    device = {"size": size, "type": device_type, "runtime": runtime, "udid": udid, "status": "NOT_RUN", "incompatiblePairs": failures}
    report["devices"].append(device)
    try:
        subprocess.run(["xcrun", "simctl", "boot", udid], check=True, timeout=90)
        subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, timeout=900)
        subprocess.run(["xcrun", "simctl", "install", udid, str(app)], check=True, timeout=180)
        subprocess.run(["xcrun", "simctl", "install", udid, str(prototype)], check=True, timeout=180)
        (root / "sim_udid.txt").write_text(udid)
        subprocess.run([sys.executable, "Scripts/CI/prepare-faithful-ipad-fixtures.py"], check=True)
        fixture_report = artifacts / "miniTest10-native-fixture-install.json"
        fixture_report.rename(artifacts / f"miniTest10-native-fixture-install-{size}.json")
        selection = ["SafariPrototypeReferenceTests", "FaithfulReaderVisualBaselineTests"]
        if size == "phone":
            selection = ["FaithfulReaderIPhoneTests"]
        elif not baseline:
            selection.append("FaithfulReaderUIAcceptanceTests")
            if index == 0:
                selection.extend(["SefariaEmbeddedAcceptanceTests", "Build8401SevenDefectsAcceptanceTests", "PullNavigationAcceptanceTests"])
        result = artifacts / f"result-{size}.xcresult"
        command = ["xcodebuild", "test-without-building", "-workspace", "Maktabah.xcworkspace", "-scheme", "Maktabah-iOS",
                   "-destination", f"platform=iOS Simulator,id={udid}", "-derivedDataPath", "build/DerivedData",
                   "-resultBundlePath", str(result)]
        command.extend(f"-only-testing:Maktabah-iOSUITests/{suite}" for suite in selection)
        environment = os.environ.copy()
        container = subprocess.check_output(["xcrun", "simctl", "get_app_container", udid, "com.davidpovarsky.chavrusatext", "data"], text=True).strip()
        environment["TEST_RUNNER_FAITHFUL_VIEWPORT_DIRECTORY"] = str(Path(container) / "Documents")
        with (artifacts / f"test-simulator-{size}.log").open("w") as log:
            process = subprocess.Popen(command, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
            for line in process.stdout:
                log.write(line)
                print(line, end="", flush=True)
            code = process.wait()
        log_text = (artifacts / f"test-simulator-{size}.log").read_text()
        counts = [int(value) for value in re.findall(r"Executed\s+([1-9][0-9]*)\s+tests?", log_text)]
        device["executedXCTestCount"] = max(counts, default=0)
        if code == 0 and device["executedXCTestCount"] < (1 if baseline or size == "phone" else 6):
            raise SystemExit("Expected black-box XCTest cases were not actually executed")
        device["status"] = "EXECUTED_PASS" if code == 0 else "FAIL"
        viewport_reports = artifacts / f"viewport-reports-{size}"
        viewport_reports.mkdir(parents=True, exist_ok=True)
        for source in (Path(container) / "Documents").glob("faithful-*.viewport.json"):
            shutil.copyfile(source, viewport_reports / source.name)
        # Attachments are exported even after a failing test for honest diagnosis.
        if result.is_dir():
            subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                            "--output-path", str(artifacts / f"visual-{size}")], check=True)
        if code:
            raise SystemExit(code)
    finally:
        (artifacts / "faithful-ipad-matrix.json").write_text(json.dumps(report, indent=2))
        subprocess.run(["xcrun", "simctl", "shutdown", udid], check=False, capture_output=True)
        # Delete only the disposable simulator created above, never a user's/default device.
        subprocess.run(["xcrun", "simctl", "delete", udid], check=False, capture_output=True)

print("Both required iPad sizes completed; production/Release and physical-device gates are separate.")
