#!/usr/bin/env python3
"""R27 tool probe and integration into the existing native UI execution path."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/artifacts/runtime27"


def capture(command, name):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=120)
    (OUT / name).write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f"Tool preflight failed: {command}; see {name}")
    return result.stdout


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    report = {"status": "FAIL", "executed_ui_pass": 0, "executed_ui_fail": 0,
              "mode": os.environ.get("RUNTIME27_MODE"), "idb": "NOT_USED_XCUITEST_DRIVER",
              "maestro": "NOT_USED_NO_SELECTED_FLOW", "distribution": False}
    try:
        if sys.platform != "darwin":
            raise RuntimeError("R27 execution requires real macOS/Xcode")
        report["checkout_sha"] = capture(["git", "rev-parse", "HEAD"], "checkout.txt").strip()
        if report["checkout_sha"] != os.environ.get("EXPECTED_CHECKOUT_SHA"):
            raise RuntimeError("Unexpected checkout")
        report["xcode"] = capture(["xcodebuild", "-version"], "xcode.txt")
        report["swift"] = capture(["xcrun", "swiftc", "--version"], "swift.txt")
        report["python"] = sys.version
        report["sdk"] = capture(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], "sdk.txt").strip()
        if not report["sdk"].startswith("27."):
            raise RuntimeError("Installed simulator SDK is not27.x")
        for kind in ("summary", "tests", "test-details", "activities"):
            capture(["xcrun", "xcresulttool", "get", "test-results", kind, "--help"], f"xcresult-{kind}-help.txt")
            if kind in ("summary", "tests"):
                schema = capture(["xcrun", "xcresulttool", "get", "test-results", kind, "--schema"], f"xcresult-{kind}-schema.json")
                json.loads(schema)
        runtimes = json.loads(capture(["xcrun", "simctl", "list", "runtimes", "-j"], "runtimes.json"))
        capture(["xcrun", "simctl", "list", "devicetypes", "-j"], "device-types.json")
        available = [v for v in runtimes["runtimes"] if v.get("isAvailable") and v.get("version", "").split(".")[0] == "27"]
        if not available:
            raise RuntimeError("No installed available OS27 simulator runtime")
        report["available_runtime27"] = available
        report["reviewed_skills"] = []
        for repository, revision, subpath in [
            ("conorluddy/ios-simulator-skill", "86fb9ba90a438bd2ee7ab640165bd77da396d941", "ios-simulator-skill/skills/ios-simulator-skill"),
            ("foreztgump/maestro-mobile-testing-skill", "d2d9d9387ebba3724d972bee75af15da28622aeb", "skills/maestro-mobile-testing"),
        ]:
            url = f"https://raw.githubusercontent.com/{repository}/{revision}/{subpath}/SKILL.md"
            data = urllib.request.urlopen(url, timeout=60).read()
            name = repository.split("/")[-1] + "-SKILL.md"
            (OUT / name).write_bytes(data)
            report["reviewed_skills"].append({"repository": repository, "revision": revision, "path": subpath,
                                              "sha256": hashlib.sha256(data).hexdigest(), "runtime_tools_installed": []})
        if report["mode"] == "probe":
            report["status"] = "ENVIRONMENT_PROBE_PASS_UI_NOT_RUN"
            return 0
        raise RuntimeError("Real UI mode requires the immutable reviewed Q case manifest; not yet selected")
    except Exception as error:
        report["error"] = str(error)
        print(str(error), file=sys.stderr)
        return 1
    finally:
        (OUT / "result.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({key: report.get(key) for key in ("status", "checkout_sha", "sdk", "error")}, indent=2))


if __name__ == "__main__":
    raise SystemExit(main())
