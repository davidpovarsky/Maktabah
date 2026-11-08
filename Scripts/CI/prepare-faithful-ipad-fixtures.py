#!/usr/bin/env python3
"""Install genuine data through the app's existing native installer.

miniTest10 remains the default UI fixture. --profile production provisions the
full verified corpus for a subsequent Release UI run; provisioning alone is not
acceptance. The existing search-acceptance fixture assumes miniTest10's document
count, so production provisioning does not request that fixture. No raw database
replacement, digest bypass or generated mock text is used. No token is logged.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
from datetime import datetime, timezone
import shutil
import subprocess
import sys
import time
import uuid
from resolve_simulator_container import app_data_container, mini_lexical_root

parser = argparse.ArgumentParser()
parser.add_argument("--profile", choices=["miniTest10", "production"], default="miniTest10")
parser.add_argument("--artifact-label", choices=["11", "13", "phone"])
arguments = parser.parse_args()
profile = arguments.profile
artifact_suffix = "-" + arguments.artifact_label if arguments.artifact_label else ""
udid = Path("sim_udid.txt").read_text().strip()
bundle = "com.davidpovarsky.chavrusatext"
container = app_data_container(udid, bundle,
    Path(f"build/artifacts/{profile}-native-fixture-container{artifact_suffix}.json"))
# Download and authenticate the actual resource first. Its destination comes
# from a successful native database install, never a guessed signing fallback.
if profile == "miniTest10":
    lexical = Path("build/native-fixtures/lexical.db")
    expected_lexical_sha = "b42e36626802629fed178068e8cf11f0f034d6f24ae3b72ac9999b9311bf299f"
    lexical.parent.mkdir(parents=True, exist_ok=True)
    if not lexical.is_file():
        subprocess.run(["gh", "release", "download", "v0.3.0", "--repo", "Otzaria/SeforimMagicIndexer",
                        "--pattern", "lexical.db", "--output", str(lexical)], check=True, timeout=300)
    if lexical.stat().st_size != 57122816 or hashlib.sha256(lexical.read_bytes()).hexdigest() != expected_lexical_sha:
        raise SystemExit("Pinned original lexical.db checksum/size mismatch")


def install_native(search_required, label=""):
    report = container / "Documents" / ("faithful-fixture-" + str(uuid.uuid4()) + ".json")
    report.parent.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    for key, value in {
        "OTZARIA_DATA_PROFILE": profile,
        "OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE": "install",
        "OTZARIA_NATIVE_BOOTSTRAP_INSTALL_SEARCH": "1" if search_required else "0",
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
        destination = Path(f"build/artifacts/{profile}-native-fixture-install{label}{artifact_suffix}.json")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(report, destination)
        minimum_books = 7000 if profile == "production" else 10
        if (not value.get("passed") or value.get("profileID") != profile
                or value.get("bookCount", 0) < minimum_books or not value.get("shaMatched")
                or value.get("searchArtifactsRequested") is not search_required):
            raise SystemExit(f"Native {profile} report failed; see the saved report")
        print("Native installer report verified:", {key: value.get(key) for key in ["passed", "profileID", "profileVersion", "bookCount", "shaMatched"]})
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
    return value

if profile == "miniTest10":
    first_install = install_native(False, "-database")
    resources = mini_lexical_root(first_install["finalPath"], container)
    resources.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(lexical, resources / "lexical.db")
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    (resources / "lexical.db.release.json").write_text(json.dumps({
        "tagName": "v0.3.0", "assetID": 458055169,
        "assetURL": "https://github.com/Otzaria/SeforimMagicIndexer/releases/download/v0.3.0/lexical.db",
        "size": 57122816, "sha256": expected_lexical_sha, "installedAt": now, "checkedAt": now,
    }))
    print("Seeded original checksum-verified lexical resource at the native installer-selected storage path")

    final_install = install_native(True)
    if final_install.get("finalPath") != first_install["finalPath"]:
        raise SystemExit("Native storage changed between database and search installation")
else:
    install_native(False)
