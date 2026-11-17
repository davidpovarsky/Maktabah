#!/usr/bin/env python3
"""Real black-box acceptance on disposable 11/13-inch iPadOS 27 simulators."""
import json
import hashlib
import os
import re
import runpy
import shutil
from pathlib import Path
import subprocess
import sys
import time
import uuid
import signal
from datetime import datetime, timezone

_SCRIPTS_CI_DIR = str(Path(__file__).resolve().parent)
if _SCRIPTS_CI_DIR not in sys.path:
    sys.path.insert(0, _SCRIPTS_CI_DIR)

import runtime27_interruption


def main():
    root = Path.cwd()
    artifacts = root / "build/artifacts"
    artifacts.mkdir(parents=True, exist_ok=True)
    app = root / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app"
    prototype = root / "build/SafariPrototypeReference/DerivedData/Build/Products/Debug-iphonesimulator/SafariPrototypeReference.app"
    if not app.is_dir():
        raise SystemExit("The actual built app is missing")

    controller = runtime27_interruption.InterruptController().install()
    report = None
    try:
        def sim_json(*args):
            return json.loads(subprocess.check_output(["xcrun", "simctl", *args, "-j"], text=True, timeout=60))

        runtimes = [runtime for runtime in sim_json("list", "runtimes", "available")["runtimes"]
                    if runtime.get("isAvailable") and runtime["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS")
                    and runtime["version"].split(".")[0] == "27"]
        if not runtimes:
            raise SystemExit("Required iPadOS 27 runtime is unavailable; older Simulator results cannot satisfy this gate")
        # Prefer the installed SDK's matching runtime before a newer installed runtime.
        # The 27.x gate and exact supported-device checks below remain mandatory.
        # Record this choice rather than silently selecting a newer runtime variant.
        sdk_version = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"],
                                              text=True, timeout=60).strip()
        sdk_major_minor = tuple(map(int, sdk_version.split(".")[:2]))
        runtimes.sort(key=lambda value: (
            tuple(map(int, value["version"].split(".")[:2])) == sdk_major_minor,
            tuple(map(int, value["version"].split(".")))
        ), reverse=True)
        device_types = sim_json("list", "devicetypes")["devicetypes"]
        baseline = os.environ.get("VALIDATING_BASELINE") == "true"
        diagnostic_cases = [item.strip() for item in os.environ.get("FAITHFUL_DIAGNOSTIC_CASES", "").split(",") if item.strip()]
        runtime27_contract = None
        runtime27_groups = None
        if os.environ.get("FAITHFUL_RUNTIME27_MANIFEST"):
            runtime27_contract = json.loads(Path(os.environ["FAITHFUL_RUNTIME27_MANIFEST"]).read_text())
            runtime27_groups = runpy.run_path("Scripts/CI/runtime27.py")["execution_groups"](runtime27_contract)
            diagnostic_cases = [value for group in runtime27_groups for value in group["case_ids"]]
        if diagnostic_cases:
            verify_selection = runpy.run_path("Scripts/CI/verify-faithful-xctest.py")["verify"]
            declarations = verify_selection("", diagnostic_cases)["suites"]
            if (len(set(diagnostic_cases)) != len(diagnostic_cases)
                    or any(not re.fullmatch(r"\w+/test\w+", item) for item in diagnostic_cases)
                    or any(len(value["expected"]) != 1 for value in declarations)):
                raise SystemExit("Every diagnostic selection must name one declared, unique Suite/testMethod")
        app_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
        report = {"appSHA": app_sha, "testSHA": os.environ.get("GITHUB_SHA"), "baseline": baseline,
                  "configuration": "Debug", "dataProfile": "miniTest10", "devices": [],
                  "fullMatrixAcceptance": not bool(diagnostic_cases), "diagnosticCases": diagnostic_cases,
                  "simulatorSDKVersion": sdk_version,
                  "runtimePreference": "matching-installed-SDK-then-newest-available-27.x"}

        def write_matrix_report():
            if report is not None:
                (artifacts / "faithful-ipad-matrix.json").write_text(json.dumps(report, indent=2))

        def create_compatible_ipad(size):
            candidates = [value for value in device_types if
                          (bool(re.search(r"iPhone-[0-9]+(?:-|$)", value["identifier"])) if size == "phone" else "iPad Pro" in value["name"] and f"{size}-inch" in value["name"])]
            # Use a numbered conventional iPhone for the existing compact-phone gate.
            # The SDK-matched runtime exposed only iPhone Duo in run42510775166;
            # its different native size classes/toolbars do not test this gate's
            # conventional portrait-phone contract. Record the exact selected device.
            # Some installed device profiles (e.g. RAM variants) are incompatible with
            # an otherwise available runtime. Let CoreSimulator verify each exact pair.
            def preference(value):
                generation = re.search(r"(?:-M|iPhone-)([0-9]+)", value["identifier"])
                return ("16GB" in value["identifier"], -int(generation[1]) if generation else 0, value["identifier"])
            candidates.sort(key=preference)
            failures = []
            for runtime in runtimes:
                supported = {value["identifier"] for value in runtime.get("supportedDeviceTypes", [])}
                for device_type in candidates:
                    if device_type["identifier"] not in supported:
                        continue
                    result = subprocess.run(["xcrun", "simctl", "create", f"Faithful {size}-inch {uuid.uuid4().hex[:8]}",
                                             device_type["identifier"], runtime["identifier"]], text=True, capture_output=True, timeout=90)
                    if result.returncode == 0:
                        return result.stdout.strip(), device_type, runtime, failures
                    failures.append({"deviceType": device_type["identifier"], "runtime": runtime["identifier"], "error": result.stderr.strip()})
            raise SystemExit(f"No compatible {size}-inch iPad Pro / iPadOS 27 pair: {json.dumps(failures)}")

        phone_case_prefix = ("FaithfulReaderIPhoneTests/", "R27NativePhoneTests/")
        diagnostic_sizes = (["11"] if any(not case.startswith(phone_case_prefix) for case in diagnostic_cases) else [])
        diagnostic_sizes += ["phone"] if any(case.startswith(phone_case_prefix) for case in diagnostic_cases) else []
        scenarios = runtime27_groups or [{"size": size, "label": size} for size in (diagnostic_sizes if diagnostic_cases else ["11", "13", "phone"])]
        for index, scenario in enumerate(scenarios):
            if controller.interrupted:
                break
            size, label = scenario["size"], scenario["label"]
            try:
                udid, device_type, runtime, failures = create_compatible_ipad(size)
            except KeyboardInterrupt as error:
                controller.mark_interrupted(error)
                report["status"] = "INTERRUPTED_UI_UNVERIFIED"
                report["interrupted"] = True
                report["interruptedPhase"] = "BEFORE_SIMULATOR_CREATED"
                report["error"] = f"{type(error).__name__}: {error}"
                write_matrix_report()
                break
            device = {"size": size, "label": label, "type": device_type, "runtime": runtime, "udid": udid, "status": "NOT_RUN", "incompatiblePairs": failures}
            report["devices"].append(device)
            recording = None
            recording_log = None
            palette_log_stream = None
            hid_comparison = None
            native_url_delivery = None
            active_xcodebuild = None

            def phase(name, **details):
                device["phase"] = name
                device["phaseStartedAt"] = datetime.now(timezone.utc).isoformat()
                device["phaseDetails"] = details
                write_matrix_report()
                print(f"Faithful {label}-inch: {name} {json.dumps(details)}", flush=True)

            def install_owned_app(path, bundle, timeout):
                """Recover only a timed-out Simulator installation, never an XCTest."""
                assert device["udid"] == udid
                attempts = device.setdefault("installationAttempts", [])
                for attempt in range(2):
                    record = {"bundle": bundle, "attempt": attempt + 1, "status": "STARTED"}
                    attempts.append(record)
                    try:
                        phase("INSTALLING", bundle=bundle, attempt=attempt + 1, timeoutSeconds=timeout)
                        subprocess.run(["xcrun", "simctl", "install", udid, str(path)], check=True, timeout=timeout)
                        phase("VERIFYING_APP_CONTAINER", bundle=bundle, attempt=attempt + 1)
                        installed = subprocess.check_output(["xcrun", "simctl", "get_app_container", udid, bundle, "app"],
                                                            text=True, timeout=45).strip()
                        if not installed or not Path(installed).is_dir():
                            raise RuntimeError(f"Native installer did not expose the actual {bundle} application container")
                        record.update(status="INSTALLED", appContainer=installed)
                        phase("INSTALLED", bundle=bundle, attempt=attempt + 1)
                        return
                    except subprocess.TimeoutExpired as error:
                        record["timedOutPhase"] = device.get("phase")
                        record.update(status="INSTALL_TIMEOUT", error=str(error))
                        phase("INSTALL_TIMEOUT", bundle=bundle, attempt=attempt + 1)
                        if attempt:
                            raise
                        # Preserve the first timeout and exact native service evidence.
                        phase("COLLECTING_INSTALL_DIAGNOSTICS", bundle=bundle)
                        try:
                            subprocess.run([sys.executable, "Scripts/CI/collect-faithful-simulator-failure.py", udid, label],
                                           check=False, timeout=150)
                        except subprocess.TimeoutExpired:
                            # Run 42014227785 showed diagnostics itself timing out and
                            # aborting the single authorized install recovery. Retain
                            # partial evidence and the timeout; actual reinstall, launch
                            # and every native XCTest remain required for acceptance.
                            record["diagnostics"] = "TIMEOUT"
                            phase("INSTALL_DIAGNOSTICS_TIMEOUT", bundle=bundle)
                        for diagnostic in artifacts.glob(f"simulator-failure-{label}*"):
                            diagnostic.rename(diagnostic.with_name(diagnostic.name.replace(
                                f"simulator-failure-{label}", f"simulator-install-recovery-{label}-{bundle}", 1)))
                        phase("RESTARTING_OWNED_SIMULATOR", bundle=bundle)
                        subprocess.run([sys.executable, "Scripts/CI/shutdown-faithful-simulator.py", udid], check=True, timeout=240)
                        subprocess.run(["xcrun", "simctl", "boot", udid], check=True, timeout=90)
                        subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, timeout=900)

            def mark_device_interrupted(error):
                controller.mark_interrupted(error)
                if device.get("status") != "INTERRUPTED":
                    device["interruptedPhase"] = device.get("phase")
                device["status"] = "INTERRUPTED"
                device["error"] = f"{type(error).__name__}: {error}"
                if isinstance(device.get("largeText"), dict) and device["largeText"].get("status") != "EXECUTED_PASS":
                    device["largeText"]["status"] = "INTERRUPTED"
                report["status"] = "INTERRUPTED_UI_UNVERIFIED"
                report["interrupted"] = True

            def run_interrupted_cleanup():
                controller.cleanup_active = True
                try:
                    device["status"] = "INTERRUPTED"
                    if isinstance(device.get("largeText"), dict) and device["largeText"].get("status") != "EXECUTED_PASS":
                        device["largeText"]["status"] = "INTERRUPTED"
                    device.setdefault("ownedSimulatorCleanup", "PENDING")
                    report["status"] = "INTERRUPTED_UI_UNVERIFIED"
                    report["interrupted"] = True
                    try:
                        write_matrix_report()
                    except OSError:
                        pass

                    cleanup_errors = {}
                    if active_xcodebuild is not None:
                        runtime27_interruption.run_isolated_cleanup_step(
                            "xcodebuild",
                            lambda: runtime27_interruption.stop_owned_subprocess(active_xcodebuild, prefer_sigint=True),
                            cleanup_errors,
                        )
                    if native_url_delivery is not None:
                        runtime27_interruption.run_isolated_cleanup_step(
                            "native_url_delivery", native_url_delivery.stop, cleanup_errors
                        )
                    if hid_comparison is not None:
                        runtime27_interruption.run_isolated_cleanup_step(
                            "hid_comparison", hid_comparison.stop, cleanup_errors
                        )
                    if palette_log_stream is not None:
                        stream_report = runtime27_interruption.run_isolated_cleanup_step(
                            "palette_log_stream", palette_log_stream.stop, cleanup_errors
                        )
                        if stream_report is not None:
                            device["paletteInputStream"] = stream_report
                    if recording is not None:
                        runtime27_interruption.run_isolated_cleanup_step(
                            "recording",
                            lambda: runtime27_interruption.stop_owned_subprocess(recording, prefer_sigint=True),
                            cleanup_errors,
                        )
                    if recording_log is not None:
                        runtime27_interruption.run_isolated_cleanup_step("recording_log", recording_log.close, cleanup_errors)
                    if runtime27_contract and label == "11-window":
                        device["paletteInputDiagnosticExitCode"] = "SKIPPED_ON_INTERRUPTION"
                    if cleanup_errors:
                        device["cleanupErrors"] = cleanup_errors
                    try:
                        write_matrix_report()
                    except OSError:
                        pass

                    try:
                        subprocess.run(
                            [sys.executable, "Scripts/CI/shutdown-faithful-simulator.py", udid],
                            check=True,
                            timeout=runtime27_interruption.INTERRUPTED_SIM_SHUTDOWN_TIMEOUT,
                        )
                        # Delete only the disposable simulator created above, never a user's/default device.
                        subprocess.run(
                            ["xcrun", "simctl", "delete", udid],
                            check=True,
                            capture_output=True,
                            timeout=runtime27_interruption.INTERRUPTED_SIM_DELETE_TIMEOUT,
                        )
                        device["ownedSimulatorCleanup"] = "PASS"
                    except (subprocess.SubprocessError, OSError, KeyboardInterrupt) as cleanup_error:
                        device["ownedSimulatorCleanup"] = "FAIL"
                        device["ownedSimulatorCleanupError"] = type(cleanup_error).__name__
                    finally:
                        try:
                            write_matrix_report()
                        except OSError:
                            pass
                finally:
                    controller.cleanup_active = False

            try:
                phase("BOOTING", udid=udid)
                subprocess.run(["xcrun", "simctl", "boot", udid], check=True, timeout=90)
                subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, timeout=900)
                # Verify the small independent oracle first, before the large app's
                # installation/indexing. Both iPad sizes previously timed out installing
                # this oracle after Maktabah, for baseline and candidate alike.
                if size != "phone" and (not diagnostic_cases or any(case.startswith("SafariPrototypeReferenceTests/") for case in diagnostic_cases)):
                    install_owned_app(prototype, "com.example.safaritoolbarsearch", 180)
                    phase("VERIFYING_ORACLE_LAUNCH")
                    subprocess.run(["xcrun", "simctl", "launch", udid, "com.example.safaritoolbarsearch"], check=True, timeout=90)
                    subprocess.run(["xcrun", "simctl", "terminate", udid, "com.example.safaritoolbarsearch"], check=True, timeout=60)
                install_owned_app(app, "com.davidpovarsky.chavrusatext", 600)
                (root / "sim_udid.txt").write_text(udid)
                phase("PROVISIONING_NATIVE_FIXTURES")
                for fixture_attempt in range(2):
                    try:
                        subprocess.run([sys.executable, "Scripts/CI/prepare-faithful-ipad-fixtures.py", "--artifact-label", label],
                                       check=True, timeout=720)
                        break
                    except subprocess.CalledProcessError:
                        fixture_report = artifacts / f"miniTest10-native-fixture-install-{label}.json"
                        failure = json.loads(fixture_report.read_text()) if fixture_report.is_file() else {}
                        termination_report = artifacts / f"miniTest10-native-fixture-termination-{label}.json"
                        termination = json.loads(termination_report.read_text()) if termination_report.is_file() else {}
                        recover_cleanup = runpy.run_path("Scripts/CI/runtime27-fixture-recovery.py")["verified_fixture_cleanup_timeout"]
                        if recover_cleanup(failure, termination, fixture_attempt):
                            # Run43750733453 installed the genuine hashed fixture, then
                            # simctl terminate timed out. Preserve that failure and
                            # prove the exact owned simulator is idle before reboot.
                            # No failed installer/test is retried or counted as passed.
                            shutil.copyfile(fixture_report, artifacts / f"miniTest10-native-fixture-install-{label}-before-reboot.json")
                            shutil.copyfile(termination_report, artifacts / f"miniTest10-native-fixture-termination-{label}-before-reboot.json")
                            phase("RECOVERING_VERIFIED_FIXTURE_CLEANUP_TIMEOUT", udid=udid)
                            assert device["udid"] == udid
                            subprocess.run([sys.executable, "Scripts/CI/shutdown-faithful-simulator.py", udid], check=True, timeout=240)
                            subprocess.run(["xcrun", "simctl", "boot", udid], check=True, timeout=90)
                            subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, timeout=900)
                            device["fixtureCleanupRecovery"] = "OWNED_SHUTDOWN_VERIFIED_AND_REBOOTED; ALL_UI_STILL_REQUIRED"
                            break
                        errors = failure.get("errors") or []
                        transient_download = (failure.get("phase") == "install" and bool(errors)
                            and all(re.search(r"\bHTTP (502|503|504)\b", str(error)) for error in errors))
                        if fixture_attempt != 0 or failure.get("passed") is not False or not transient_download:
                            raise
                        # Preserve the real failed report. Relaunch the same native
                        # installer once; every data/profile/hash check remains intact.
                        shutil.copyfile(fixture_report, artifacts / f"miniTest10-native-fixture-install-{label}-attempt-1.json")
                        phase("RETRYING_TRANSIENT_FIXTURE_DOWNLOAD", attempt=2)
                        time.sleep(5)
                selection = ["SafariPrototypeReferenceTests", "FaithfulReaderVisualBaselineTests"]
                if size == "phone":
                    selection = ["FaithfulReaderIPhoneTests"]
                elif not baseline:
                    selection.append("FaithfulReaderUIAcceptanceTests")
                    if index == 0:
                        selection.extend(["SefariaEmbeddedAcceptanceTests", "Build8401SevenDefectsAcceptanceTests", "PullNavigationAcceptanceTests"])
                if diagnostic_cases:
                    selection = [case for case in diagnostic_cases
                                 if case.startswith(phone_case_prefix) == (size == "phone")]
                if runtime27_groups:
                    selection = scenario["case_ids"]
                result = artifacts / f"result-{label}.xcresult"
                command = ["xcodebuild", "test-without-building", "-workspace", "Maktabah.xcworkspace", "-scheme", "Maktabah-iOS",
                           "-parallel-testing-enabled", "NO",
                           "-destination", f"platform=iOS Simulator,id={udid}", "-derivedDataPath", "build/DerivedData",
                           "-resultBundlePath", str(result)]
                command.extend(f"-only-testing:Maktabah-iOSUITests/{suite}" for suite in selection)
                environment = os.environ.copy()
                container = subprocess.check_output(["xcrun", "simctl", "get_app_container", udid, "com.davidpovarsky.chavrusatext", "data"], text=True, timeout=45).strip()
                environment["TEST_RUNNER_FAITHFUL_VIEWPORT_DIRECTORY"] = str(Path(container) / "Documents")
                if any(case.startswith("NativeRoutingAcceptanceTests/") for case in selection):
                    native_url_delivery = runpy.run_path("Scripts/CI/runtime27-url-delivery.py")["NativeURLDelivery"](
                        udid, container, label, artifacts / "runtime27")
                    environment.update(native_url_delivery.start())
                if runtime27_contract and runtime27_contract.get("hid_comparison") and scenario.get("hid_comparison", True):
                    tools = json.loads((artifacts / "runtime27/hid-tools.json").read_text())
                    hid_comparison = runpy.run_path("Scripts/CI/runtime27-hid.py")["HIDComparison"](
                        udid, container, label, tools, artifacts / "runtime27")
                    environment.update(hid_comparison.start())
                if runtime27_contract:
                    environment.update(runpy.run_path("Scripts/CI/runtime27-fixture-oracle.py")["derive_oracle"](
                        udid, label, include_sidebar=any(case.startswith("Sidebar11201AcceptanceTests/") for case in selection)))
                    recording_log = (artifacts / f"runtime27/recording-{label}.log").open("w")
                    recording = subprocess.Popen(["xcrun", "simctl", "io", udid, "recordVideo", str(artifacts / f"runtime27/native-{label}.mp4")],
                                                 stdout=recording_log, stderr=subprocess.STDOUT)
                if runtime27_contract and label == "11-window":
                    palette_log_stream = runpy.run_path("Scripts/CI/collect-runtime27-palette-log.py")["PaletteLogStream"](udid, label).start()
                phase("RUNNING_NATIVE_XCTEST", suites=selection)
                with (artifacts / f"test-simulator-{label}.log").open("w") as log:
                    process = subprocess.Popen(command, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
                    active_xcodebuild = process
                    for line in process.stdout:
                        if hid_comparison is not None:
                            line = hid_comparison.redact_evidence(line)
                        if native_url_delivery is not None:
                            line = native_url_delivery.redact_evidence(line)
                        log.write(line)
                        log.flush()
                        print(line, end="", flush=True)
                    code = process.wait()
                    active_xcodebuild = None
                device["xcodebuildExitCode"] = code
                log_text = (artifacts / f"test-simulator-{label}.log").read_text()
                missing_suites = [suite for suite in sorted({item.split("/")[0] for item in selection}) if not re.search(
                    r"Test Suite '(?:[^']*\.)?" + re.escape(suite) + r"' passed", log_text)]
                device["requiredSuites"] = selection
                device["missingOrFailedSuites"] = missing_suites
                if code == 0 and missing_suites:
                    code = 1
                verification = subprocess.run([sys.executable, "Scripts/CI/verify-faithful-xctest.py",
                                               "--log", str(artifacts / f"test-simulator-{label}.log"),
                                               "--out", str(artifacts / f"test-case-execution-{label}.json"), *selection])
                if verification.returncode:
                    code = code or 1
                # Consume actual xcresult, not merely Xcode's textual summaries. Exact
                # named methods are required for the reviewed R27 subset; default full
                # suite selections expand through the existing declaration verifier.
                declared = runpy.run_path("Scripts/CI/verify-faithful-xctest.py")["verify"]("", selection)
                required = [row["suite"] + "/" + method for row in declared["suites"] for method in row["expected"]]
                strict = [sys.executable, "tools/verify_xcresult_zero_skips.py", "--xcresult", str(result),
                          "--log", str(artifacts / f"test-simulator-{label}.log"), "--scope", "focused-ui",
                          "--expected-device", udid, "--expected-os-major", "27",
                          "--min-tests", str(len(required)), "--out", str(artifacts / f"runtime27/verified-{label}.json")]
                for identity in required:
                    strict.extend(["--required-case", identity])
                if subprocess.run(strict).returncode:
                    code = code or 1
                counts = [int(value) for value in re.findall(r"Executed\s+([1-9][0-9]*)\s+tests?", log_text)]
                device["executedXCTestCount"] = max(counts, default=0)
                minimum_count = len(selection) if diagnostic_cases else (1 if baseline or size == "phone" else 6)
                if code == 0 and device["executedXCTestCount"] < minimum_count:
                    raise SystemExit("Expected black-box XCTest cases were not actually executed")
                device["status"] = "EXECUTED_PASS" if code == 0 else "FAIL"
                if any(case == "NativeRoutingAcceptanceTests" or case.startswith("NativeRoutingAcceptanceTests/") for case in selection):
                    native_dir = artifacts / f"native-routing-logs-{label}"
                    native_dir.mkdir(parents=True, exist_ok=True)
                    native_log_report = {"udid": udid, "label": label, "bundleID": "com.davidpovarsky.chavrusatext",
                                         "collectedAt": datetime.now(timezone.utc).isoformat(), "status": "MISSING"}
                    try:
                        actual_container = Path(subprocess.check_output(
                            ["xcrun", "simctl", "get_app_container", udid, "com.davidpovarsky.chavrusatext", "data"],
                            text=True, timeout=45).strip())
                        actual_log = actual_container / "Documents/OtzariaLogs/otzaria-reader.log"
                        native_log_report["actualContainer"] = str(actual_container)
                        if actual_log.is_file():
                            retained_log = native_dir / "otzaria-reader.log"
                            shutil.copyfile(actual_log, retained_log)
                            native_log_report.update(status="RETAINED", bytes=retained_log.stat().st_size,
                                                     sha256=hashlib.sha256(retained_log.read_bytes()).hexdigest(),
                                                     artifact=str(retained_log.relative_to(artifacts)))
                    except Exception as error:
                        native_log_report.update(status="COLLECTION_ERROR", error=str(error))
                    (native_dir / "collection.json").write_text(json.dumps(native_log_report, indent=2) + "\n")
                    device["nativeRoutingLog"] = native_log_report
                viewport_reports = artifacts / f"viewport-reports-{label}"
                viewport_reports.mkdir(parents=True, exist_ok=True)
                # XCTest can relocate the installed data container. Collect only the
                # explicitly UUID-named read-only viewport reports from native app data.
                for candidate in Path(container).parent.iterdir():
                    for source in (candidate / "Documents").glob("faithful-*.viewport.json"):
                        shutil.copyfile(source, viewport_reports / source.name)
                # Attachments are exported even after a failing test for honest diagnosis.
                if result.is_dir():
                    subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                                    "--output-path", str(artifacts / f"visual-{label}")], check=True)
                if size == "13" and not runtime27_contract:
                    help_result = subprocess.run(["xcrun", "simctl", "help", "ui"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=True)
                    (artifacts / "simctl-ui-help.txt").write_text(help_result.stdout)
                    requested_size = "accessibility-extra-extra-extra-large"
                    if "content_size" not in help_result.stdout or requested_size not in help_result.stdout:
                        raise SystemExit("Installed simctl cannot verify the required accessibility text-size configuration")
                    device["largeText"] = {"status": "NOT_RUN", "requested": requested_size}
                    try:
                        subprocess.run(["xcrun", "simctl", "ui", udid, "content_size", requested_size], check=True)
                        actual_size = subprocess.check_output(["xcrun", "simctl", "ui", udid, "content_size"], text=True).strip()
                        device["largeText"]["actual"] = actual_size
                        if requested_size not in actual_size:
                            raise SystemExit("The requested system text-size setting was not actually applied")
                        large_result = artifacts / "result-13-large-text.xcresult"
                        large_command = [value for value in command if not value.startswith("-only-testing:")]
                        large_command[large_command.index("-resultBundlePath") + 1] = str(large_result)
                        large_command.append("-only-testing:Maktabah-iOSUITests/FaithfulReaderLargeTextTests")
                        environment["TEST_RUNNER_FAITHFUL_BASELINE"] = str(baseline).lower()
                        log_path = artifacts / "test-simulator-13-large-text.log"
                        phase("RUNNING_LARGEST_TEXT_XCTEST", ordinarySuitesStatus=device["status"])
                        with log_path.open("w") as log:
                            large_proc = subprocess.run(large_command, env=environment, stdout=log, stderr=subprocess.STDOUT, text=True)
                        counts = [int(value) for value in re.findall(r"Executed\s+([1-9][0-9]*)\s+tests?", log_path.read_text())]
                        device["largeText"]["executedXCTestCount"] = max(counts, default=0)
                        verification = subprocess.run([sys.executable, "Scripts/CI/verify-faithful-xctest.py",
                                                       "--log", str(log_path), "--out", str(artifacts / "test-case-execution-13-large-text.json"),
                                                       "FaithfulReaderLargeTextTests"])
                        if large_result.is_dir():
                            subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(large_result),
                                            "--output-path", str(artifacts / "visual-13-large-text")], check=True)
                        if large_proc.returncode or not counts or verification.returncode:
                            device["largeText"]["status"] = "FAIL"
                            raise SystemExit("Largest-text real UI acceptance failed or did not execute")
                        device["largeText"]["status"] = "EXECUTED_PASS"
                    finally:
                        if controller.interrupted:
                            if device["largeText"].get("status") != "EXECUTED_PASS":
                                device["largeText"]["status"] = "INTERRUPTED"
                        else:
                            subprocess.run(["xcrun", "simctl", "ui", udid, "content_size", "large"], check=True)
                if code:
                    raise SystemExit(f"Native UI acceptance failed: {missing_suites}; acceptance status {code}; actual xcodebuild status {device['xcodebuildExitCode']}")
            except KeyboardInterrupt as error:
                mark_device_interrupted(error)
                phase("INTERRUPTED", error=device["error"])
            except (Exception, SystemExit) as error:
                device["status"] = "FAIL"
                device["error"] = f"{type(error).__name__}: {error}"
                device["failedPhase"] = device.get("phase")
                phase("FAILED", error=device["error"])
                try:
                    subprocess.run([sys.executable, "Scripts/CI/collect-faithful-simulator-failure.py", udid, label], check=False, timeout=150)
                except subprocess.TimeoutExpired:
                    device["diagnostics"] = "TIMEOUT"
                # Retain a hard failure, but still execute the other required native
                # configurations so one device does not hide the iPhone/13-inch result.
            finally:
                if controller.interrupted:
                    run_interrupted_cleanup()
                else:
                    try:
                        if native_url_delivery is not None:
                            native_url_delivery.stop()
                        if hid_comparison is not None:
                            hid_comparison.stop()
                        if palette_log_stream is not None:
                            device["paletteInputStream"] = palette_log_stream.stop()
                        if recording is not None:
                            recording.send_signal(signal.SIGINT)
                            try:
                                recording.wait(timeout=30)
                            except subprocess.TimeoutExpired:
                                recording.terminate()
                                recording.wait(timeout=15)
                            recording_log.close()
                        if runtime27_contract and label == "11-window":
                            try:
                                diagnostic = subprocess.run([sys.executable, "Scripts/CI/collect-runtime27-palette-log.py", udid, label],
                                                            check=False, timeout=60)
                                device["paletteInputDiagnosticExitCode"] = diagnostic.returncode
                            except subprocess.TimeoutExpired:
                                device["paletteInputDiagnosticExitCode"] = "TIMEOUT; no handler-delivery inference"
                        write_matrix_report()
                        try:
                            subprocess.run([sys.executable, "Scripts/CI/shutdown-faithful-simulator.py", udid], check=True, timeout=300)
                            # Delete only the disposable simulator created above, never a user's/default device.
                            subprocess.run(["xcrun", "simctl", "delete", udid], check=True, capture_output=True, timeout=120)
                            device["ownedSimulatorCleanup"] = "PASS"
                        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
                            device["ownedSimulatorCleanup"] = "FAIL"
                            device["ownedSimulatorCleanupError"] = type(error).__name__
                            # Retain the failure and simulator, and attempt the remaining
                            # independent configurations. Cleanup must not hide phone cases.
                        write_matrix_report()
                    except KeyboardInterrupt as error:
                        mark_device_interrupted(error)
                        run_interrupted_cleanup()
            if controller.interrupted:
                break

        if controller.interrupted:
            report["status"] = "INTERRUPTED_UI_UNVERIFIED"
            report["interrupted"] = True
            write_matrix_report()
            return 130

        failed = [device["label"] for device in report["devices"]
                  if device["status"] != "EXECUTED_PASS" or device.get("ownedSimulatorCleanup") != "PASS"]
        if failed:
            raise SystemExit(f"Native acceptance failed for {failed}; see per-device logs and the complete matrix. Release is prohibited.")
        if diagnostic_cases:
            print("Selected 11-inch diagnostics completed. Full matrix, largest text, iPhone and Release acceptance remain NOT_RUN.")
        else:
            print("Required iPad sizes, largest text configuration and iPhone completed; production/Release and physical-device gates are separate.")
        return 0
    except KeyboardInterrupt as error:
        controller.mark_interrupted(error)
        if report is not None:
            report["status"] = "INTERRUPTED_UI_UNVERIFIED"
            report["interrupted"] = True
            report["error"] = f"{type(error).__name__}: {error}"
            (artifacts / "faithful-ipad-matrix.json").write_text(json.dumps(report, indent=2))
        else:
            (artifacts / "faithful-ipad-matrix.json").write_text(json.dumps({
                "status": "INTERRUPTED_UI_UNVERIFIED",
                "interrupted": True,
                "interruptedPhase": "PRE_REPORT_SETUP",
                "devices": [],
                "error": f"{type(error).__name__}: {error}",
            }, indent=2))
        return 130
    finally:
        controller.restore()


if __name__ == "__main__":
    raise SystemExit(main())
