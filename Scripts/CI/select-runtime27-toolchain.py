#!/usr/bin/env python3
"""Select an existing Xcode/27.x runtime pair for the entire real UI matrix.

No toolchain is installed, no global xcode-select state is changed, and no
runtime is replaced. AppIntentsTesting links private OS services, so a newer
installed runtime cannot be assumed compatible with an older SDK's test kit.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys

def version_pair(value):
    parts = tuple(int(part) for part in value.split("."))
    return (parts + (0, 0))[:2]

def supports_matrix(runtime):
    types = runtime.get("supportedDeviceTypes", [])
    return (any("iPad Pro" in item["name"] and "11-inch" in item["name"] for item in types)
            and any("iPad Pro" in item["name"] and "13-inch" in item["name"] for item in types)
            and any(re.search(r"iPhone-[0-9]+(?:-|$)", item["identifier"]) for item in types))

def matching_runtimes(sdk_version, runtimes):
    if version_pair(sdk_version)[0] != 27:
        return []
    return [item for item in runtimes
            if item.get("isAvailable")
            and item["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
            and version_pair(item["version"]) == version_pair(sdk_version)
            and supports_matrix(item)]

def inspect_installed(developer):
    environment = dict(os.environ, DEVELOPER_DIR=str(developer))
    def command(args):
        return subprocess.check_output(args, env=environment, text=True,
                                       stderr=subprocess.STDOUT, timeout=60).strip()
    xcode = command(["xcodebuild", "-version"])
    match = re.search(r"^Xcode (\d+(?:\.\d+)*)", xcode)
    if not match or version_pair(match[1])[0] != 27:
        return {"developer_dir": str(developer), "xcode": xcode, "status": "NOT_XCODE27"}
    sdk = command(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"])
    platform = Path(command(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-platform-path"]))
    framework = platform / "Developer/Library/Frameworks/AppIntentsTesting.framework/AppIntentsTesting"
    runtimes = json.loads(command(["xcrun", "simctl", "list", "runtimes", "available", "-j"]))["runtimes"]
    matches = matching_runtimes(sdk, runtimes)
    return {
        "developer_dir": str(developer), "xcode": xcode, "xcode_version": match[1],
        "sdk_version": sdk, "app_intents_testing_exists": framework.is_file(),
        "app_intents_testing": str(framework),
        "runtime_inventory": [{key: item.get(key) for key in
                              ("identifier", "version", "buildversion", "isAvailable")}
                             | {"supports_full_device_matrix": supports_matrix(item)}
                             for item in runtimes if ".iOS-" in item["identifier"]],
        "matching_runtime_ids": [item["identifier"] for item in matches],
        "status": "MATCHED_MATRIX_PAIR" if matches and framework.is_file() else "NO_MATCHED_MATRIX_PAIR",
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--github-env", action="store_true")
    parser.add_argument("--report", type=Path,
                        default=Path("build/artifacts/runtime27/toolchain-selection.json"))
    args = parser.parse_args()
    if sys.platform != "darwin":
        raise SystemExit("Real installed macOS/Xcode required")
    active = Path(os.environ.get("DEVELOPER_DIR") or
                  subprocess.check_output(["xcode-select", "-p"], text=True).strip())
    developers = {active, *[app / "Contents/Developer" for app in Path("/Applications").glob("Xcode*.app")]}
    report = {"observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "status": "NO_MATCHED_MATRIX_PAIR", "active_developer_dir": str(active),
              "candidates": [], "selected": None, "native_ui_executed": 0,
              "global_xcode_select_changed": False, "toolchains_installed": False}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    def save():
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for developer in sorted(developers, key=str):
        if not (developer / "usr/bin/xcodebuild").is_file():
            continue
        try:
            report["candidates"].append(inspect_installed(developer))
        except (subprocess.SubprocessError, OSError, ValueError) as error:
            report["candidates"].append({"developer_dir": str(developer),
                                         "status": "INSPECTION_FAILED", "error": str(error)})
        save()
    candidates = [item for item in report["candidates"] if item["status"] == "MATCHED_MATRIX_PAIR"]
    candidates.sort(key=lambda item: (version_pair(item["sdk_version"]),
                                     version_pair(item["xcode_version"]),
                                     "beta" not in item["developer_dir"].lower(),
                                     item["developer_dir"]), reverse=True)
    if not candidates:
        save()
        print(json.dumps(report, indent=2))
        raise SystemExit("No installed Xcode27 SDK/runtime pair supports the complete iPad/iPhone matrix")
    selected = candidates[0]
    selected = {key: selected[key] for key in
                ("developer_dir", "xcode", "xcode_version", "sdk_version", "app_intents_testing")}
    selected["runtime_identifier"] = candidates[0]["matching_runtime_ids"][0]
    report.update(status="MATCHED_MATRIX_PAIR_SELECTED", selected=selected)
    save()
    if args.github_env:
        path = os.environ.get("GITHUB_ENV")
        if not path:
            raise SystemExit("GITHUB_ENV is required for scoped job configuration")
        values = {"DEVELOPER_DIR": selected["developer_dir"],
                  "FAITHFUL_RUNTIME27_IDENTIFIER": selected["runtime_identifier"]}
        if any("\n" in value or "\r" in value for value in values.values()):
            raise SystemExit("Unexpected newline in inspected toolchain identifier")
        with open(path, "a", encoding="utf-8") as output:
            for key, value in values.items():
                output.write(key + "=" + value + "\n")
    print(json.dumps({"status": report["status"], "selected": selected,
                      "native_ui_executed": 0}, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
