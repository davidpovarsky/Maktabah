#!/usr/bin/env python3
"""Run the existing disposable update fixtures on Apple; never discover app data."""
import json
import platform
from pathlib import Path
import shutil
import subprocess
import sys

repo = Path(__file__).resolve().parent.parent
fixtures = repo / "Tests/HQ/updates"
build = fixtures / ".build"
build.mkdir(parents=True, exist_ok=True)
report_path = build / "hq-updates-apple-report.json"
log_path = build / "hq-updates-apple.log"
report = {"status": "NOT_RUN", "appRuntime": "NOT_RUN", "physicalDevice": "NOT_RUN",
          "nativeUpdateRecovery": "NOT_RUN", "target": "arm64-apple-ios26.0-simulator"}

with log_path.open("w", encoding="utf-8") as log:
    def run(args):
        log.write("COMMAND " + json.dumps([str(arg) for arg in args]) + "\n")
        log.flush()
        result = subprocess.run(args, cwd=repo, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        log.write(result.stdout)
        log.flush()
        print(result.stdout, end="", flush=True)
        result.check_returncode()
        return result.stdout.strip()

    try:
        if platform.system() != "Darwin":
            raise RuntimeError("Apple checks require a real Mac/Xcode; Windows is portable evidence only")
        report["sourceSHA"] = run(["git", "rev-parse", "HEAD"])
        report["xcode"] = run(["xcodebuild", "-version"])
        report["swift"] = run(["xcrun", "swiftc", "--version"])
        report["host"] = run(["sw_vers"])
        report["sdk"] = run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"])
        report["sdkVersion"] = run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"])
        # Inventory only: no boot, install, launch, or physical-device mutation.
        report["availableSimulators"] = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "-j"]))
        report["runtimeDevice"] = "NOT_RUN: SDK typecheck and macOS fixture executables only"
        for command in ["idb", "maestro"]:
            report[command] = run([command, "--version"]) if shutil.which(command) else "NOT_INSTALLED"

        run([sys.executable, "-B", "tools/hq-updates-extract-fixtures.py", str(build / "ProductionCatalog.swift")])
        service = repo / "Source/ChavrusaText/BookUpdates/MaktabahBookUpdateSafety.swift"
        core = [service, build / "ProductionCatalog.swift", fixtures / "main.swift"]
        adapter = [service, build / "ProductionCatalog.swift", build / "ProductionBackendID.swift",
                   build / "ProductionEntryPoints.swift", fixtures / "ProductionShims.swift", fixtures / "AdapterMain.swift"]

        run(["xcrun", "swiftc", "-typecheck", "-parse-as-library", "-swift-version", "6",
             "-target", report["target"], "-sdk", report["sdk"], *adapter])
        report["appleSDKTypecheck"] = "EXECUTED_PASS_WITH_COMPILER_DOUBLES"

        for name, sources, flags in [("core", core, ["-D", "HQ_UPDATES_FIXTURE"]),
                                      ("adapter", adapter, ["-parse-as-library"])]:
            executable = build / ("hq-updates-" + name)
            run(["xcrun", "swiftc", "-swift-version", "6", *flags, *sources, "-o", executable])
            result = run([executable, build])
            if "EXECUTED_PASS" not in result:
                raise RuntimeError("Fixture executable did not report actual executed checks")
            report[name] = [line for line in result.splitlines() if line.startswith("EXECUTED_PASS")][-1]
        report["status"] = "EXECUTED_PASS"
    except Exception as error:
        report["status"] = "FAILED"
        report["error"] = str(error)
        raise
    finally:
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, ensure_ascii=False, indent=2))
