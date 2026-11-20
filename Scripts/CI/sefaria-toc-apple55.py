#!/usr/bin/env python3
"""Run the complete original Sefaria transport fixture on Apple Foundation.

This is host Foundation execution, not an iPad SDK, app, Native UI, network,
or physical-offline acceptance result. The same full 55 cases run in the
lightweight workflow selector and before the original Native/normal builds.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PRODUCTION = [
    "Source/LibraryBackend/LibraryBackendModels.swift",
    "Source/LibraryBackend/LibraryPresentationPolicy+Display.swift",
    "Source/Sefaria/Domain/SefariaModels.swift",
    "Source/Sefaria/Domain/SefariaNavigationParser.swift",
    "Source/Sefaria/Network/SefariaDTOs.swift",
    "Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift",
    "Source/ChavrusaText/Localization/TalmudHebrewAddressFormatter.swift",
    "Source/Sefaria/Network/SefariaHTTPClient.swift",
]
APPENDIX = "Tests/HQ/sefaria-mobile-navigation/TOCTransportAcceptanceAppendix.swift"
DRIVER = "tools/hq-sefaria-toc-transport.py"
LANGUAGE_DRIVER = "tools/hq-sefaria-navigation-language.py"
WRAPPER = "Scripts/CI/sefaria-toc-apple55.py"
INTERRUPTION_HELPER = "Scripts/CI/runtime27_interruption.py"
MODE_COUNTS = {"failure-retry": 26, "cancel-held": 26, "lifetime": 3}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def source_inputs(root, expected_sha):
    require(bool(re.fullmatch(r"[0-9a-f]{40}", expected_sha)), "Exact immutable checkout SHA is required")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root).decode().strip()
    require(head == expected_sha, "Actual checkout does not match the requested SHA")
    records = {}
    for relative in [*PRODUCTION, APPENDIX, DRIVER, LANGUAGE_DRIVER, WRAPPER, INTERRUPTION_HELPER]:
        raw = (root / relative).read_bytes()
        original = subprocess.check_output(["git", "show", head + ":" + relative], cwd=root)
        require(raw == original, "Changed source input: " + relative)
        records[relative] = {"bytes": len(raw), "sha256": sha(raw), "gitBlobExact": True}
    return records


def verify_driver_result(directory, sources):
    result = json.loads((directory / "RESULT.json").read_text(encoding="utf-8"))
    require(result.get("status") == "PASS", "The complete original driver did not pass")
    require(result.get("modeSelection") == "transport-and-lifetime"
            and result.get("httpSnapshot") is None, "A partial mode or source override is not acceptance")
    require(result.get("inputHashesUnchanged") is True, "Source changed during execution")
    require(type(result.get("executed")) is int and result["executed"] == 55
            and type(result.get("passed")) is int and result["passed"] == 55,
            "Exactly 55 executed and passed cases are required")
    require(result.get("compile", {}).get("returncode") == 0, "Actual Swift compilation failed")
    modes = result.get("modes", {})
    expected = json.loads((directory / "CASES_EXPECTED.json").read_text(encoding="utf-8"))
    require(list(modes) == list(MODE_COUNTS) and list(expected) == list(MODE_COUNTS),
            "The three complete original fixture modes are required")
    for mode, count in MODE_COUNTS.items():
        names = expected[mode]
        require(isinstance(names, list) and len(names) == count and len(set(names)) == count
                and all(isinstance(name, str) and name for name in names),
                "Missing or duplicated expected inventory: " + mode)
        rows = json.loads((directory / mode / "CASES.json").read_text(encoding="utf-8"))
        require(isinstance(rows, list) and len(rows) == count
                and [row.get("name") for row in rows] == names
                and all(row.get("passed") is True for row in rows),
                "Failed, missing, or duplicated actual case: " + mode)
        item = modes[mode]
        require(item.get("returncode") == 0 and item.get("failed") == []
                and type(item.get("executed")) is int and item["executed"] == count
                and type(item.get("passed")) is int and item["passed"] == count,
                "Mode summary does not match actual leaves: " + mode)
    records = json.loads((directory / "INPUTS.json").read_text(encoding="utf-8"))
    require([row.get("path") for row in records] == [*PRODUCTION, APPENDIX],
            "Require the complete eight production files and original test appendix")
    appendix = (directory / "inputs" / PRODUCTION[-1]).read_bytes()
    original_http_length = sources[PRODUCTION[-1]]["bytes"]
    # The complete copied HTTP file ends with this explicitly test-only appendix.
    expected_appendix = records[-1]
    require(expected_appendix["bytes"] == sources[APPENDIX]["bytes"]
            and expected_appendix["sha256"] == sources[APPENDIX]["sha256"],
            "Test appendix differs from the immutable checkout")
    require(appendix[original_http_length:original_http_length + 1] == b"\n"
            and sha(appendix[original_http_length + 1:]) == sources[APPENDIX]["sha256"],
            "HTTP fixture must append exactly the complete test-only source")
    for row in records[:-1]:
        relative = row["path"]
        expected_source = sources[relative]
        require(row.get("bytes") == expected_source["bytes"]
                and row.get("sha256") == expected_source["sha256"]
                and row.get("originalWholePrefixExact") is True,
                "Input identity mismatch: " + relative)
        raw = (directory / "inputs" / relative).read_bytes()
        require(sha(raw) == row.get("snapshotSHA256")
                and sha(raw[:expected_source["bytes"]]) == expected_source["sha256"],
                "Compiled whole-file prefix mismatch: " + relative)
        if relative != PRODUCTION[-1]:
            require(len(raw) == expected_source["bytes"], "Unexpected production-source appendix")
    return result


def preserve_raw(source, destination):
    """Retain exact bounded fixture inputs/logs/proofs; no compiler cache or executable."""
    records = []
    if source.is_dir():
        for path in sorted(source.rglob("*")):
            require(not path.is_symlink(), "Unexpected symlink in owned fixture evidence")
            if not path.is_file() or path.name == "toc-transport-foundation.exe":
                continue
            relative = path.relative_to(source)
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
            raw = target.read_bytes()
            require(raw == path.read_bytes(), "Raw evidence copy changed")
            records.append({"path": relative.as_posix(), "bytes": len(raw), "sha256": sha(raw)})
    return records


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-sha", default=os.environ.get("EXPECTED_CHECKOUT_SHA", ""))
    parser.add_argument("--artifacts-dir", type=Path, default=ROOT / "build/artifacts/sefaria-toc-apple55")
    parser.add_argument("--work-dir", type=Path, default=ROOT / "build/sefaria-toc-apple55")
    args = parser.parse_args(argv)
    output, work = args.artifacts_dir.resolve(), args.work_dir.resolve()
    require(not output.exists() and not work.exists(), "Use fresh evidence and work directories")
    output.mkdir(parents=True)
    work.mkdir(parents=True)
    run_directory = work / "driver"
    report = {"schemaVersion": 1, "startedAt": utc(), "status": "ERROR",
              "expectedSHA": args.expected_sha, "native": "NOT_RUN", "iPadSDK": "NOT_RUN",
              "realNetwork": "NOT_RUN", "embeddedHermes": "NOT_RUN", "physicalOffline": "NOT_RUN",
              "scope": "Actual macOS Apple Foundation, complete eight production sources plus test-only appendix",
              "host": {"platform": sys.platform, "machine": platform.machine(), "release": platform.release()},
              "toolchainCommands": [], "executed": 0, "passed": 0}
    sources = {}
    try:
        require(sys.platform == "darwin", "Apple Foundation gate requires actual macOS")
        sources = source_inputs(ROOT, args.expected_sha)
        write_json(output / "SOURCE_INPUTS.json", sources)

        def capture(command, label):
            stdout, stderr = output / (label + ".stdout.log"), output / (label + ".stderr.log")
            row = {"command": command, "timeoutSeconds": 30, "stdout": stdout.name, "stderr": stderr.name}
            report["toolchainCommands"].append(row)
            with stdout.open("wb") as out, stderr.open("wb") as err:
                result = subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, timeout=30)
            row["returncode"] = result.returncode
            require(result.returncode == 0, "Apple toolchain query failed: " + label)
            return stdout.read_text(encoding="utf-8").strip()

        xcode = capture(["xcodebuild", "-version"], "xcode")
        require(re.search(r"(?m)^Xcode 27(?:[.\s]|$)", xcode) is not None,
                "The original acceptance requires installed Xcode 27")
        compiler = Path(capture(["xcrun", "--find", "swiftc"], "swiftc-path")).resolve()
        require(compiler.is_file(), "Selected real Apple Swift compiler is absent")
        capture([str(compiler), "--version"], "swift-version")
        target = json.loads(capture([str(compiler), "-print-target-info"], "swift-target-info"))
        require("apple-macosx" in target.get("target", {}).get("triple", ""),
                "The selected Swift target must be the real macOS host")
        report["swiftTargetInfo"] = target
        sdk = Path(capture(["xcrun", "--sdk", "macosx", "--show-sdk-path"], "macos-sdk-path")).resolve()
        require(sdk.is_dir(), "Selected original macOS SDK is absent")
        capture(["xcrun", "--sdk", "macosx", "--show-sdk-version"], "macos-sdk-version")
        for platform_name in ["iphoneos", "iphonesimulator"]:
            version = capture(["xcrun", "--sdk", platform_name, "--show-sdk-version"], platform_name + "-sdk")
            require(version.split(".")[0] == "27", "The selected SDK pair must remain version 27")
        capture(["sw_vers"], "macos-version")
        report["developerDirectory"] = os.environ.get("DEVELOPER_DIR")
        report["compiler"] = str(compiler)
        report["macOSSDK"] = str(sdk)
        environment = os.environ.copy()
        environment["PATH"] = str(compiler.parent) + os.pathsep + environment.get("PATH", "")
        environment["SDKROOT"] = str(sdk)
        require(Path(shutil.which("swiftc", path=environment["PATH"])).resolve() == compiler,
                "The complete driver must use the observed selected Apple compiler")
        cache = work / "module-cache"
        cache.mkdir()
        command = [sys.executable, str(ROOT / DRIVER), "--output", str(run_directory),
                   "--module-cache", str(cache)]
        report["driverCommand"] = command
        report["driverTimeoutSeconds"] = 300
        write_json(output / "GATE_COMMANDS.json", report)
        # Only this subprocess group is owned. Cancellation never leaves a compiler
        # running after the gate exits, and cannot target another runner's process.
        import runtime27_interruption
        with (output / "driver.stdout.log").open("wb") as out, (output / "driver.stderr.log").open("wb") as err:
            process = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=out, stderr=err,
                                       start_new_session=True)
            try:
                code = process.wait(timeout=300)
            except BaseException:
                report["ownedProcessCleanup"] = runtime27_interruption.stop_owned_process_group(process)
                raise
        report["driverReturncode"] = code
        if (run_directory / "RESULT.json").is_file():
            partial = json.loads((run_directory / "RESULT.json").read_text(encoding="utf-8"))
            report["driverResult"] = partial
            report["executed"] = partial.get("executed", 0)
            report["passed"] = partial.get("passed", 0)
        require(code == 0, "The complete original Apple transport driver failed")
        result = verify_driver_result(run_directory, sources)
        actual_compile = json.loads((run_directory / "COMMANDS.json").read_text(encoding="utf-8"))["compile"]
        require(Path(actual_compile[0]).resolve() == compiler, "Compiled with a different Swift executable")
        require("-strict-concurrency=complete" in actual_compile and "-swift-version" in actual_compile
                and actual_compile[actual_compile.index("-swift-version") + 1] == "6",
                "The original strict Swift 6 fixture settings must be preserved")
        report["inputHashesUnchanged"] = all(sha((ROOT / path).read_bytes()) == record["sha256"]
                                            for path, record in sources.items())
        require(report["inputHashesUnchanged"], "Immutable sources changed during Apple execution")
        report["driverResult"] = result
        report["executed"] = 55
        report["passed"] = 55
        report["status"] = "APPLE_FOUNDATION_55_PASS"
    except BaseException as error:
        report["status"] = "INTERRUPTED" if isinstance(error, KeyboardInterrupt) else "ERROR"
        report["error"] = {"type": type(error).__name__, "message": str(error)}
    finally:
        try:
            records = preserve_raw(run_directory, output / "raw")
            write_json(output / "RAW_INDEX.json", records)
        except Exception as error:
            report["status"] = "ERROR"
            report["preservationError"] = {"type": type(error).__name__, "message": str(error)}
        if sources:
            report["inputHashesUnchanged"] = all((ROOT / path).is_file()
                and sha((ROOT / path).read_bytes()) == record["sha256"] for path, record in sources.items())
            if not report["inputHashesUnchanged"]:
                report["status"] = "ERROR"
        report["finishedAt"] = utc()
        write_json(output / "RESULT.json", report)
        print(json.dumps(report, indent=2))
    return 0 if report["status"] == "APPLE_FOUNDATION_55_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
