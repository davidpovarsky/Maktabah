#!/usr/bin/env python3
"""Run required source/edition interactions before the independent visual matrix."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys


def main():
    artifacts = Path("build/artifacts")
    artifacts.mkdir(parents=True, exist_ok=True)
    receipt = artifacts / "backend-functional-simulator-isolation.json"
    output = artifacts / "backend-functional-acceptance.json"
    log_path = artifacts / "backend-functional-tests.log"
    result = artifacts / "backend-functional.xcresult"
    suites = ["SefariaEmbeddedAcceptanceTests", "OtzariaSchema7AcceptanceTests"]
    report = {"status": "NOT_RUN", "configuration": "Debug", "dataProfile": "miniTest10",
              "appSHA": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
              "requiredSuites": suites, "fullVisualMatrixAcceptance": False,
              "physicalDeviceAcceptance": False}
    isolation = [sys.executable, "Scripts/CI/isolated-ipad-simulator.py", "--receipt", str(receipt)]

    def run(command, timeout):
        return subprocess.run(command, check=True, timeout=timeout)

    try:
        app = Path("build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app")
        if not app.is_dir():
            raise RuntimeError("The actual built application is missing")
        run([*isolation, "--major", os.environ.get("VALIDATION_IOS_MAJOR", "27")], 180)
        udid = json.loads(receipt.read_text())["udid"]
        report["simulator"] = json.loads(receipt.read_text())
        run(["xcrun", "simctl", "boot", udid], 90)
        run(["xcrun", "simctl", "bootstatus", udid, "-b"], 900)
        run(["xcrun", "simctl", "install", udid, str(app)], 600)
        run([sys.executable, "Scripts/CI/prepare-faithful-ipad-fixtures.py"], 1800)
        command = ["xcodebuild", "test-without-building", "-workspace", "Maktabah.xcworkspace",
                   "-scheme", "Maktabah-iOS", "-parallel-testing-enabled", "NO",
                   "-destination", f"platform=iOS Simulator,id={udid}",
                   "-derivedDataPath", "build/DerivedData", "-disableAutomaticPackageResolution",
                   "-resultBundlePath", str(result)]
        command.extend(f"-only-testing:Maktabah-iOSUITests/{suite}" for suite in suites)
        with log_path.open("w", encoding="utf-8") as log:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, bufsize=1)
            for line in process.stdout:
                log.write(line)
                print(line, end="", flush=True)
            code = process.wait()
        verification = runpy.run_path("Scripts/CI/verify-faithful-xctest.py")["verify"](
            log_path.read_text(encoding="utf-8"), suites)
        (artifacts / "backend-functional-case-execution.json").write_text(json.dumps(verification, indent=2))
        report.update(xcodebuildExit=code, caseExecution=verification)
        if result.is_dir():
            run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                 "--output-path", str(artifacts / "visual-backend-functional")], 180)
        if code or verification["status"] != "EXECUTED_PASS":
            raise RuntimeError("Required native source/edition interactions did not all pass")
        report["status"] = "EXECUTED_PASS"
    except Exception as error:
        report.update(status="EXECUTED_FAIL", error=str(error))
        if receipt.is_file():
            try:
                subprocess.run(["xcrun", "simctl", "io", json.loads(receipt.read_text())["udid"],
                                "screenshot", str(artifacts / "simulator-failure-backend-functional.png")],
                               check=False, timeout=45)
            except Exception as diagnostic_error:
                report["diagnosticError"] = str(diagnostic_error)
        raise
    finally:
        output.write_text(json.dumps(report, indent=2), encoding="utf-8")
        run([*isolation, "--cleanup"], 180)


if __name__ == "__main__":
    main()
