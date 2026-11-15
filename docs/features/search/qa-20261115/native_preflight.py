#!/usr/bin/env python3
"""Read-only, task-scoped facts. Never builds/tests or changes destinations."""
import argparse
import datetime
import json
import platform
import re
import shutil
import subprocess
from pathlib import Path


def command(args, cwd=None):
    executable = shutil.which(args[0])
    if not executable:
        return {"command": args, "available": False}
    try:
        result = subprocess.run([executable, *args[1:]], cwd=cwd, capture_output=True,
                                text=True, timeout=45, check=False)
        return {"command": args, "available": True, "exitCode": result.returncode,
                "stdout": result.stdout, "stderr": result.stderr}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"command": args, "available": True, "error": str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--candidate", required=True, help="Exact integrated 40-character SHA")
    parser.add_argument("--udid", help="Manager-assigned simulator, never auto-selected")
    parser.add_argument("--project", type=Path,
                        help="Existing project; read effective target settings only")
    args = parser.parse_args()
    report = {"schemaVersion": 1, "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "system": platform.system(), "candidate": args.candidate, "udid": args.udid,
              "status": "BLOCKED", "nativeTestsRun": 0, "physicalTestsRun": 0,
              "scope": "read-only facts; no build, test, boot, erase, install, CI or settings mutation",
              "blockers": [], "checks": {}}
    blockers, checks = report["blockers"], report["checks"]
    if not re.fullmatch(r"[0-9a-f]{40}", args.candidate):
        blockers.append("candidate must be an exact lowercase 40-character commit SHA")
    checks["head"] = command(["git", "rev-parse", "HEAD"], args.repo)
    if checks["head"].get("stdout", "").strip() != args.candidate:
        blockers.append("working checkout does not match the supplied immutable candidate")
    checks["status"] = command(["git", "status", "--porcelain=v1"], args.repo)
    if checks["status"].get("stdout", "").strip():
        blockers.append("checkout is dirty; record/install an immutable manager-integrated candidate")
    if platform.system() != "Darwin":
        blockers.append("Apple SDK/native simulator authority unavailable on this operating system")
    else:
        for key, argv in {
            "xcode": ["xcodebuild", "-version"],
            "developerDirectory": ["xcode-select", "-p"],
            "swift": ["xcrun", "swift", "--version"],
            "iphoneSDK": ["xcrun", "--sdk", "iphoneos", "--show-sdk-version"],
            "simulatorSDK": ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"],
            "runtimes": ["xcrun", "simctl", "list", "runtimes", "--json"],
            "devices": ["xcrun", "simctl", "list", "devices", "--json"],
            "deviceTypes": ["xcrun", "simctl", "list", "devicetypes", "--json"],
        }.items():
            checks[key] = command(argv)
            if checks[key].get("exitCode") != 0:
                blockers.append(f"required {key} probe failed")
        checks["idbVersion"] = command(["idb", "--version"])
        checks["maestroVersion"] = command(["maestro", "--version"])
        # Neither optional CLI presence nor its version proves working HID.
        if not args.udid:
            blockers.append("explicit manager-assigned simulator UDID is required")
        else:
            try:
                payload = json.loads(checks["devices"].get("stdout", ""))
                destinations = [(runtime, device) for runtime, devices in payload["devices"].items()
                                for device in devices if device.get("udid") == args.udid]
                if len(destinations) != 1 or not destinations[0][1].get("isAvailable"):
                    blockers.append("assigned UDID not uniquely present and available")
                else:
                    report["observedDestination"] = {"runtime": destinations[0][0],
                                                     "device": destinations[0][1]}
            except (ValueError, KeyError, TypeError):
                blockers.append("unable to decode actual destination inventory")
        if not args.project:
            blockers.append("existing project path required for effective per-target deployment settings")
        elif args.udid:
            checks["effectiveSettings"] = command([
                "xcodebuild", "-project", str(args.project.resolve()), "-alltargets",
                "-configuration", "Debug", "-sdk", "iphonesimulator",
                "-showBuildSettings", "-json"], args.repo)
            try:
                settings = json.loads(checks["effectiveSettings"].get("stdout", ""))
                relevant = [item for item in settings if item.get("buildSettings", {}).get("PRODUCT_TYPE")
                            in {"com.apple.product-type.application", "com.apple.product-type.bundle.ui-testing"}]
                report["effectiveTargets"] = [{"target": item["target"],
                    "productType": item["buildSettings"].get("PRODUCT_TYPE"),
                    "deploymentTarget": item["buildSettings"].get("IPHONEOS_DEPLOYMENT_TARGET")}
                    for item in relevant]
                types = {item["productType"] for item in report["effectiveTargets"]}
                if not {"com.apple.product-type.application", "com.apple.product-type.bundle.ui-testing"} <= types:
                    blockers.append("both actual app and UI-test target settings required")
                for target in report["effectiveTargets"]:
                    version = tuple(int(part) for part in (target["deploymentTarget"] or "0").split("."))
                    if version < (26, 2):
                        blockers.append(f"effective target {target['target']} is below required 26.2")
            except (ValueError, KeyError, TypeError):
                blockers.append("effective per-target build settings could not be decoded")
    if not blockers:
        report["status"] = "PREFLIGHT_FACTS_COLLECTED_NATIVE_NOT_RUN"
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 2 if blockers else 0


if __name__ == "__main__":
    raise SystemExit(main())
