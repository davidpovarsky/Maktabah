#!/usr/bin/env python3
"""Install genuine data through the app's existing native installer.

miniTest10 remains the default UI fixture. --profile production provisions the
full verified corpus for a subsequent Release UI run; provisioning alone is not
acceptance. The existing search-acceptance fixture assumes miniTest10's document
count, so production provisioning does not request that fixture. No raw database
replacement, digest bypass or generated mock text is used. No token is logged.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument("--profile", choices=["miniTest10", "production"], default="miniTest10")
parser.add_argument("--release-id", type=int, help="Official frozen release for a production native install observation")
parser.add_argument("--artifact-label", choices=["11", "13", "phone", "11-search", "11-reader", "11-sidebar", "11-window", "11-index"])
arguments = parser.parse_args()
profile = arguments.profile
if arguments.release_id is not None:
    if profile != "production" or not 0 < arguments.release_id <= 9_223_372_036_854_775_807:
        parser.error("--release-id requires the production profile and a positive Int64 release ID")
artifact_suffix = "-" + arguments.artifact_label if arguments.artifact_label else ""
udid = Path("sim_udid.txt").read_text().strip()
bundle = "com.davidpovarsky.chavrusatext"
container = Path(subprocess.check_output(["xcrun", "simctl", "get_app_container", udid, bundle, "data"], text=True, timeout=45).strip())
report = container / "Documents" / ("faithful-fixture-" + str(uuid.uuid4()) + ".json")
report.parent.mkdir(parents=True, exist_ok=True)
environment = os.environ.copy()
release_key = "SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RELEASE_ID"
environment.pop(release_key, None)
if arguments.release_id is not None:
    environment[release_key] = str(arguments.release_id)
for key, value in {
    "OTZARIA_DATA_PROFILE": profile,
    "OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE": "install",
    "OTZARIA_NATIVE_BOOTSTRAP_INSTALL_SEARCH": "1" if profile == "miniTest10" else "0",
    "OTZARIA_NATIVE_BOOTSTRAP_REQUIRE_RESUME": "0",
    "OTZARIA_NATIVE_BOOTSTRAP_RESULT": str(report),
    "GH_TOKEN": os.environ.get("GH_TOKEN", ""),
}.items():
    environment["SIMCTL_CHILD_" + key] = value
subprocess.run(["xcrun", "simctl", "launch", udid, bundle, "-OtzariaDataProfile", profile], env=environment, check=True, timeout=90)
try:
    deadline = time.monotonic() + (3600 if profile == "production" else 480)
    while not report.is_file():
        if time.monotonic() >= deadline:
            raise SystemExit(f"Native {profile} installation timed out; real UI tests cannot run without genuine data")
        time.sleep(3)
    value = json.loads(report.read_text())
    destination = Path(f"build/artifacts/{profile}-native-fixture-install{artifact_suffix}.json")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(report, destination)
    minimum_books = 7000 if profile == "production" else 10
    if (not value.get("passed") or value.get("profileID") != profile
            or value.get("bookCount", 0) < minimum_books or not value.get("shaMatched")):
        raise SystemExit(f"Native {profile} report failed; see the saved report")
    print("Native UI fixture ready:", {key: value.get(key) for key in ["passed", "profileID", "profileVersion", "bookCount", "shaMatched"]})
finally:
    failure_in_flight = sys.exc_info()[0] is not None
    try:
        subprocess.run(["xcrun", "simctl", "terminate", udid, bundle], check=False, capture_output=True, timeout=60)
    except subprocess.TimeoutExpired as error:
        # Retain the native validation failure (e.g. an HTTP504 search-package
        # download), rather than replacing it with a cleanup traceback.
        diagnostic = Path(f"build/artifacts/{profile}-native-fixture-termination{artifact_suffix}.json")
        diagnostic.parent.mkdir(parents=True, exist_ok=True)
        diagnostic.write_text(json.dumps({"status": "TIMEOUT", "error": str(error),
                                           "nativeValidationFailurePreserved": failure_in_flight}, indent=2))
        if not failure_in_flight:
            raise
