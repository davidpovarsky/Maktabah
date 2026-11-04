#!/usr/bin/env python3
"""Install genuine miniTest10 data through the app's existing native installer.

This is UI-fixture preparation, not production corpus acceptance. It does not
replace databases, bypass digests, or generate mock text. No token is logged.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

udid = Path("sim_udid.txt").read_text().strip()
bundle = "com.davidpovarsky.chavrusatext"
container = Path(subprocess.check_output(["xcrun", "simctl", "get_app_container", udid, bundle, "data"], text=True).strip())
report = container / "Documents" / ("faithful-fixture-" + str(uuid.uuid4()) + ".json")
report.parent.mkdir(parents=True, exist_ok=True)
environment = os.environ.copy()
for key, value in {
    "OTZARIA_DATA_PROFILE": "miniTest10",
    "OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE": "install",
    "OTZARIA_NATIVE_BOOTSTRAP_INSTALL_SEARCH": "1",
    "OTZARIA_NATIVE_BOOTSTRAP_REQUIRE_RESUME": "0",
    "OTZARIA_NATIVE_BOOTSTRAP_RESULT": str(report),
    "GH_TOKEN": os.environ.get("GH_TOKEN", ""),
}.items():
    environment["SIMCTL_CHILD_" + key] = value
subprocess.run(["xcrun", "simctl", "launch", udid, bundle, "-OtzariaDataProfile", "miniTest10"], env=environment, check=True, timeout=90)
try:
    deadline = time.monotonic() + 480
    while not report.is_file():
        if time.monotonic() >= deadline:
            raise SystemExit("Native miniTest10 fixture installation timed out; real UI tests cannot run without genuine data")
        time.sleep(3)
    value = json.loads(report.read_text())
    destination = Path("build/artifacts/miniTest10-native-fixture-install.json")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(report, destination)
    if not value.get("passed") or value.get("profileID") != "miniTest10" or value.get("bookCount", 0) < 10:
        raise SystemExit("Native miniTest10 fixture report failed; see the saved report")
    print("Native UI fixture ready:", {key: value.get(key) for key in ["passed", "profileID", "profileVersion", "bookCount", "shaMatched"]})
finally:
    subprocess.run(["xcrun", "simctl", "terminate", udid, bundle], check=False, capture_output=True, timeout=60)
