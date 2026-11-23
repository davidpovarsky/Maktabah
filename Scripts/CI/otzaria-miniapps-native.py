#!/usr/bin/env python3
"""One actual Otzaria editor -> Hanlin TextStudio -> original saved-note journey."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import runpy
import shutil
import sqlite3
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/artifacts/miniapps-native"
PRODUCER_DIR = ROOT / "build/miniapps-producer"
INPUTS = ROOT / "Scripts/CI/otzaria-miniapps-native.inputs.json"
BUILD_INPUTS = ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json"
SELECTOR = "MiniAppsAnnotationAcceptanceTests/testOriginalNoteReturnsTextFromActualMiniAppsAndPersistsAfterRelaunch"
GROUPS = [{"label": "11-reader", "size": "11", "hid_comparison": False, "case_ids": [SELECTOR]}]
BUNDLE = "com.davidpovarsky.chavrusatext"
PRODUCER = "com.itorah.hanlinminiapps"
GROUP = "group.com.itorah.shared"
MANIFEST = OUT / "selection.json"


def require(value, message):
    if not value:
        raise RuntimeError(message)


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n")


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def capture(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True, timeout=120).strip()


def git(*args):
    return capture("git", *args)


def configuration():
    value = json.loads(INPUTS.read_text())
    require(type(value["producer_run_id"]) is int and value["producer_run_id"] > 0, "Producer run must be frozen")
    require(re.fullmatch(r"[a-f0-9]{40}", value["producer_source_sha"]), "Producer source must be frozen")
    require(value["producer_repository"] == "davidpovarsky/hanlin-ai", "Unexpected producer source repository")
    require(value["producer_artifact_name"] == "app-split-" + str(value["producer_run_id"]),
            "Unexpected producer artifact identity")
    return value


def source_context():
    config = configuration()
    inputs = json.loads(BUILD_INPUTS.read_text())
    source = inputs["application_source_sha"]
    require(re.fullmatch(r"[a-f0-9]{40}", source), "Application source must be frozen")
    head = git("rev-parse", "HEAD")
    require(head == os.environ["EXPECTED_CHECKOUT_SHA"], "Wrong immutable native checkout")
    subprocess.run(["git", "merge-base", "--is-ancestor", source, head], cwd=ROOT, check=True, timeout=90)
    trees = {p: git("rev-parse", "HEAD:" + p) for p in
             ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]}
    require(all(value == git("rev-parse", source + ":" + path) for path, value in trees.items()),
            "Original consumer application or test changed after source pin")
    require(all(inputs["application_trees"][p] == trees[p] for p in inputs["application_trees"]),
            "Original native build pins do not bind this source")
    require(inputs["hanlin_gitlink"] == config["producer_source_sha"], "Consumer SDK and actual producer differ")
    original = runpy.run_path(str(ROOT / "Scripts/CI/completion-focused-native.py"))
    return {"checkout_sha": head, "application_source_sha": source, "application_trees": trees,
            "producer_inputs": config,
            "original_case_catalog_sha256": digest(ROOT / "docs/hq-integration/runtime27/R27_CASES.json"),
            "execution_inputs": original["exact_working_inputs"](["Scripts/CI", ".github/workflows", "Maktabah-iOSUITests", "tools"])}


def prepare():
    require(not (OUT / "source-before.json").exists(), "Existing native evidence must not be overwritten")
    context = source_context()
    contract = json.loads((ROOT / "docs/hq-integration/runtime27/R27_CASES.json").read_text())
    if SELECTOR not in {row["case_id"] for row in contract["cases"] + contract.get("supplemental_cases", [])}:
        contract.setdefault("supplemental_cases", []).append({
            "case_id": SELECTOR, "device": "ipad11", "status": "NOT_RUN",
            "oracle": "Real original note UI, actual Hanlin TextStudio typed result and callback, same SQLite row and atomic receipt, native source process restart"})
    contract.update(source_test_commit=context["application_source_sha"],
                    app_source=context["application_source_sha"],
                    application_source_sha=context["application_source_sha"],
                    execution_case_ids=[SELECTOR], execution_groups=GROUPS, required_nonzero_cases=1,
                    native_cases_executed=0, expected_per_device={"ipad11": 1, "ipad13": 0, "iphone": 0},
                    diagnostic_only=True, hid_comparison=False,
                    scope="Actual two-app MiniApps consumer acceptance only; previously accepted unrelated suites are not replayed")
    runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["execution_groups"](contract)
    declarations = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))["validate_selections"](
        [SELECTOR], ROOT / "Maktabah-iOSUITests")
    require(declarations["status"] == "DECLARATIONS_MATCH", "The selected original XCTest is absent")
    write(OUT / "declarations.json", declarations)
    write(MANIFEST, contract)
    write(OUT / "source-before.json", context)


def restore_producer():
    config = configuration()
    repository = config["producer_repository"]
    run_id = str(config["producer_run_id"])
    run = json.loads(capture("gh", "api", f"repos/{repository}/actions/runs/{run_id}"))
    require(run["head_sha"] == config["producer_source_sha"], "Actual producer run has a different source")
    destination = PRODUCER_DIR
    destination.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + 1800
    while True:
        artifacts = json.loads(capture("gh", "api", f"repos/{repository}/actions/runs/{run_id}/artifacts?per_page=100"))
        matches = [a for a in artifacts["artifacts"] if a["name"] == config["producer_artifact_name"] and not a["expired"]]
        if matches:
            require(len(matches) == 1, "Ambiguous actual producer artifact")
            break
        run = json.loads(capture("gh", "api", f"repos/{repository}/actions/runs/{run_id}"))
        require(run["status"] != "completed" and time.monotonic() < deadline,
                "Actual producer completed without the required simulator product")
        time.sleep(15)
    subprocess.run(["gh", "run", "download", run_id, "--repo", repository,
                    "--name", config["producer_artifact_name"], "--dir", str(destination)], cwd=ROOT, check=True, timeout=300)
    manifests = list(destination.rglob("producer-manifest.json"))
    require(len(manifests) == 1, "Actual producer artifact must contain one manifest")
    manifest_path = manifests[0]
    manifest = json.loads(manifest_path.read_text())
    require(manifest["schema_version"] == 1
            and manifest["producer_sha"] == config["producer_source_sha"]
            and str(manifest["run_id"]) == run_id and manifest["bundle_id"] == PRODUCER,
            "Actual producer manifest has the wrong identity")
    require(manifest["build_status"] == "EXECUTED_PASS", "No successful actual producer app build")
    require(manifest["app_relative_path"] == "HanlinMiniApps.app"
            and manifest["archive_name"] == "HanlinMiniApps-simulator.zip", "Unexpected simulator archive layout")
    archive = manifest_path.parent / manifest["archive_name"]
    require(digest(archive) == manifest["archive_sha256"], "Producer archive bytes do not match its manifest")
    subprocess.run(["ditto", "-x", "-k", str(archive), str(destination)], check=True, timeout=180)
    app = destination / manifest["app_relative_path"]
    info = plistlib.loads((app / "Info.plist").read_bytes())
    require(info["CFBundleIdentifier"] == PRODUCER
            and info["CFBundleExecutable"] == manifest["executable_name"], "Extracted app identity differs")
    require(digest(app / info["CFBundleExecutable"]) == manifest["executable_sha256"], "Producer executable changed")
    write(OUT / "producer-admission.json", {
        "status": "EXACT_ACTUAL_SIMULATOR_PRODUCT_RESTORED", "artifact_id": matches[0]["id"],
        "artifact_name": matches[0]["name"], "producer_manifest": manifest,
        "producer_native_acceptance_status": manifest["native_acceptance_status"],
        "note": "This consumer lane never promotes or replaces the separate producer native acceptance or physical signing result."})


def binaries():
    products = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator"
    result = {}
    for bundle in [products / "Maktabah.app", products / "Maktabah-iOSUITests-Runner.app",
                   products / "Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest"]:
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        for path in [bundle / info["CFBundleExecutable"], *sorted(bundle.glob("*.dylib"))]:
            result[str(path.relative_to(ROOT))] = digest(path)
    return result


class ActualMiniAppsProducer:
    def __init__(self):
        self.udid = None
        self.group = None
        self.captured = False
        self.video = None
        self.video_log = None
        self.state = {"status": "NOT_REACHED", "fixture_producer": False, "synthetic_results_written": False}

    def validate_selection(self, baseline, release_manifest, selection):
        require(not baseline and release_manifest is None and selection == [SELECTOR], "Wrong native case selection")

    def stage(self, udid, container, label, selection):
        require(self.udid is None and label == "11-reader" and selection == [SELECTOR], "Wrong owned simulator scope")
        self.udid = udid
        producer = PRODUCER_DIR / "HanlinMiniApps.app"
        require((OUT / "producer-admission.json").is_file(), "Actual producer product was not admitted")
        subprocess.run(["xcrun", "simctl", "install", udid, str(producer)], check=True, timeout=180)
        subprocess.run(["xcrun", "simctl", "launch", udid, PRODUCER], check=True, timeout=60)
        consumer_group = capture("xcrun", "simctl", "get_app_container", udid, BUNDLE, GROUP)
        producer_group = capture("xcrun", "simctl", "get_app_container", udid, PRODUCER, GROUP)
        require(Path(consumer_group).resolve() == Path(producer_group).resolve(),
                "The two installed original apps do not resolve the same App Group")
        self.group = Path(consumer_group).resolve()
        self.state.update(status="ACTUAL_PRODUCER_INSTALLED", udid=udid, group=str(self.group),
                          consumer_bundle=BUNDLE, producer_bundle=PRODUCER, shared_group_identifier=GROUP)
        write(OUT / "actual-two-app-stage.json", self.state)
        self.video_log = (OUT / "native-video.log").open("w")
        self.video = subprocess.Popen(["xcrun", "simctl", "io", udid, "recordVideo", str(OUT / "actual-two-app-ipad.mp4")],
                                      stdout=self.video_log, stderr=subprocess.STDOUT)
        return {"TEST_RUNNER_MINIAPPS_NATIVE_SHARED_GROUP": str(self.group),
                "TEST_RUNNER_MINIAPPS_NATIVE_PRODUCER_BUNDLE": PRODUCER}

    def redact_evidence(self, line):
        return line

    def capture(self, udid, label):
        require(udid == self.udid and label == "11-reader", "Wrong producer evidence simulator")
        if self.captured:
            return
        self.captured = True
        if self.video is not None:
            self.video.terminate()
            try:
                self.video.wait(timeout=30)
            except subprocess.TimeoutExpired:
                self.video.kill()
                self.video.wait(timeout=10)
            self.video_log.close()
        report = {"status": "INCOMPLETE", "records": [], "fixture_producer": False, "synthetic_results_written": False}
        try:
            for path in sorted((self.group / "MiniAppsBridge/v1/requests").glob("*.json")):
                record = json.loads(path.read_text())
                request = record["request"]
                if request["source"]["appID"] != BUNDLE:
                    continue
                document = json.loads(request["source"]["metadata"]["otzaria.annotation.v1"])
                database = Path(document["profile"])
                require(database.is_file(), "Original request annotation database is unavailable")
                connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)
                try:
                    rows = connection.execute(
                        "SELECT r.annotation_id,r.annotation_uuid,a.ckRecordId,a.note,r.result_json "
                        "FROM miniapps_result_receipts r JOIN annotations a ON a.id=r.annotation_id "
                        "WHERE r.request_id=?", (request["id"],)).fetchall()
                finally:
                    connection.close()
                result = record.get("result") or {}
                expected = "\n".join(item["text"] for item in result.get("items", []) if item.get("text") is not None)
                verified = (record["acknowledged"] is True and result.get("status") == "success"
                            and result.get("operation") == "insert" and len(rows) == 1
                            and rows[0][0] == document["annotationID"]
                            and rows[0][1] == rows[0][2] == document["annotationUUID"]
                            and rows[0][3] == expected and expected.startswith("MiniApps original note שלום "))
                report["records"].append({"shared_record": record, "original_receipt_rows": rows,
                                           "same_original_annotation_verified": verified})
            require(len(report["records"]) == 1 and all(r["same_original_annotation_verified"] for r in report["records"]),
                    "Expected one actual producer callback with the original atomic saved receipt")
            report["status"] = "ACTUAL_SHARED_RECORD_AND_ORIGINAL_SQLITE_RECEIPT_PASS"
        except Exception as error:
            report["error"] = type(error).__name__ + ": " + str(error)
        write(OUT / "native-wire-evidence.json", report)
        result = ROOT / "build/artifacts/result-11-reader.xcresult"
        if result.is_dir():
            subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                            "--output-path", str(ROOT / "build/artifacts/visual-miniapps")], check=True, timeout=180)

    def cleanup(self, udid):
        if self.udid is not None:
            self.capture(udid, "11-reader")


def execute():
    require(source_context() == json.loads((OUT / "source-before.json").read_text()), "Source changed before native execution")
    build = json.loads((ROOT / "build/hq-stage2/result.json").read_text())
    require(build["status"] == "SIMULATOR_BUILD_FOR_REAL_UI_PASS", "Original app and UI runner did not build")
    write(OUT / "built-binaries.json", binaries())
    driver = runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))
    controller = driver["runtime27_interruption"].InterruptController().install()
    try:
        return driver["run_logged"]([sys.executable, "Scripts/CI/otzaria-miniapps-native.py", "matrix"],
                                    "miniapps-two-app-matrix.log", 7200, interrupt_controller=controller)
    finally:
        controller.restore()


def matrix():
    require(source_context() == json.loads((OUT / "source-before.json").read_text()), "Source changed before original matrix")
    require(not os.environ.get("FAITHFUL_RUNTIME27_RELEASE_MANIFEST") and not os.environ.get("FAITHFUL_DIAGNOSTIC_CASES"),
            "The MiniApps lane cannot combine unrelated native suites")
    os.environ["VALIDATING_BASELINE"] = "false"
    os.environ["FAITHFUL_RUNTIME27_MANIFEST"] = str(MANIFEST)
    return runpy.run_path(str(ROOT / "Scripts/CI/run-faithful-ipad-matrix.py"))["main"](live_provider=ActualMiniAppsProducer())


def collect():
    report = {"status": "FAILED", "scope": "ACTUAL_TWO_APP_CONSUMER_NATIVE_ONLY",
              "required_case_ids": [SELECTOR], "full_native116_acceptance": False,
              "physical_signing_status": "NOT_TESTED_BY_SIMULATOR", "synthetic_results_written": False}
    try:
        context = source_context()
        report.update(context)
        require(context == json.loads((OUT / "source-before.json").read_text()), "Qualification source changed")
        build = json.loads((ROOT / "build/hq-stage2/result.json").read_text())
        require(build["status"] == "SIMULATOR_BUILD_FOR_REAL_UI_PASS" and build["checkout_sha"] == context["checkout_sha"],
                "No matching original app and UI runner build")
        require(binaries() == json.loads((OUT / "built-binaries.json").read_text()), "Actual native code images changed")
        hq = runpy.run_path(str(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"))
        hq["verify_actual_sources"](build)
        native = build["native_context"]
        require(digest(ROOT / "Maktabah.xcodeproj/project.pbxproj") == native["generated_project_sha256"]
                and digest(ROOT / "Maktabah.xcworkspace/contents.xcworkspacedata") == native["workspace_sha256"],
                "Original generated CocoaPods project/workspace changed")
        hq["prepare_original_hanlin"](json.loads(BUILD_INPUTS.read_text()), build, verify_only=True)
        write(OUT / "original-post-ui-input-audit.json", build)
        contract = json.loads(MANIFEST.read_text())
        runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["collect_cases"](report, contract)
        result = json.loads((ROOT / "build/artifacts/faithful-ipad-matrix.json").read_text())
        devices = result.get("devices", [])
        require(len(devices) == 1 and devices[0]["label"] == "11-reader"
                and devices[0]["status"] == "EXECUTED_PASS" and devices[0]["ownedSimulatorCleanup"] == "PASS"
                and report.get("executed_ui_pass") == 1
                and not any(report.get(key, 0) for key in ["executed_ui_fail", "executed_ui_skip", "ui_not_run"]),
                "The original two-app XCTest did not execute and pass")
        wire = json.loads((OUT / "native-wire-evidence.json").read_text())
        require(wire["status"] == "ACTUAL_SHARED_RECORD_AND_ORIGINAL_SQLITE_RECEIPT_PASS", "Original saved callback receipt is incomplete")
        report["producer_admission"] = json.loads((OUT / "producer-admission.json").read_text())
        report["status"] = "ACTUAL_TWO_APP_CONSUMER_UI_EXECUTED_PASS"
        return 0
    except Exception as error:
        report["error"] = type(error).__name__ + ": " + str(error)
        return 1
    finally:
        write(OUT / "result.json", report)


def run_from_existing_native_workflow(report, run_logged, controller):
    """Use the existing native subset runner without changing workflow authority."""
    code = 1
    try:
        prepare()
        if run_logged([sys.executable, "Scripts/CI/typecheck-faithful-ui-tests.py", "--ui-compile-only"],
                      "miniapps-ui-sdk-compile.log", 600, interrupt_controller=controller):
            raise RuntimeError("New real UI test did not compile against the Apple SDK")
        if run_logged([sys.executable, "Scripts/CI/hq-stage2-focused-apple.py", "--build-for-testing",
                       "--derived-data", "build/DerivedData"],
                      "miniapps-original-app-build.log", 7200, interrupt_controller=controller):
            raise RuntimeError("Original app/test build failed; new two-app UI case NOT_RUN")
        restore_producer()
        write(OUT / "built-binaries.json", binaries())
        code = run_logged([sys.executable, "Scripts/CI/otzaria-miniapps-native.py", "matrix"],
                          "miniapps-two-app-matrix.log", 7200, interrupt_controller=controller)
    except Exception as error:
        report["miniapps_driver_error"] = type(error).__name__ + ": " + str(error)
        code = 1
    finally:
        collection_code = collect()
        outcome = json.loads((OUT / "result.json").read_text())
        report.update(outcome)
        report.setdefault("case_outcomes", [])
        report["mode"] = "ui"
    return code or collection_code


if __name__ == "__main__":
    os.chdir(ROOT)
    OUT.mkdir(parents=True, exist_ok=True)
    (ROOT / "build/artifacts/runtime27").mkdir(parents=True, exist_ok=True)
    modes = {"prepare": prepare, "restore-producer": restore_producer, "run": execute, "matrix": matrix, "collect": collect}
    if len(sys.argv) != 2 or sys.argv[1] not in modes:
        raise SystemExit("Expected prepare, restore-producer, run, matrix or collect")
    raise SystemExit(modes[sys.argv[1]]() or 0)
