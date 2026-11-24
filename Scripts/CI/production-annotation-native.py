#!/usr/bin/env python3
"""Ordinary saved-note UI acceptance using the original matrix and real SQLite."""
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import plistlib
import runpy
import sqlite3
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/production-annotation-native-evidence"
ARTIFACTS = ROOT / "build/artifacts"
SELECTION = OUT / "selection.json"
SELECTOR = "ProductionAnnotationEditorAcceptanceTests/testOrdinaryEditorSavesSameAnnotationDiscardsDraftAndRecoversAfterTermination"
GROUPS = [{"label": "11-reader", "size": "11", "hid_comparison": False, "case_ids": [SELECTOR]}]
BUNDLE = "com.davidpovarsky.chavrusatext"
PREFIX = "NORMAL_ANNOTATION_STORAGE "
STAGES = ["saved-plain-row", "native-body-saved-same-uuid", "discard-preserved-canonical-bytes",
          "cold-open-preserved-same-rich-body"]
FIELDS = {"stage", "annotation_id", "annotation_uuid", "revision", "payload_sha256", "native_body_bytes",
          "native_body_sha256", "source_sha256", "mutation_id", "sqlite_open_mode", "qualification_mode"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n")


def source_context():
    # This only reuses the existing exact source/SDK admission checks. It does
    # not invoke the qualification factory, callback, account or test selector.
    context = runpy.run_path(str(ROOT / "Scripts/CI/runtime27-original-editor-native.py"))[
        "source_context"](require_current_build=True)
    for key in os.environ:
        require(not (key.endswith("OTZARIA_ORIGINAL_EDITOR_QUALIFICATION")
                     or key.endswith("OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME")),
                "The ordinary UI route cannot inherit a qualification mode")
    return context


def qualified_build_context():
    path = ROOT / "build/hq-stage2/result.json"
    raw = path.read_bytes()
    build = json.loads(raw)
    require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
            and build.get("checkout_sha") == os.environ["EXPECTED_CHECKOUT_SHA"],
            "An actual same-checkout app and UI runner build is required")
    routes = build.get("original_editor_routes")
    require(isinstance(routes, dict), "The ordinary editor requires qualified SDK routes")
    app = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app"
    result = runpy.run_path(str(ROOT / "Scripts/CI/original_editor_sdk_routes.py"))["verify"](
        ROOT, routes["path"], "Debug", "iphonesimulator", app, route_sha256=routes["sha256"], after_ui=True)
    images = runpy.run_path(str(ROOT / "Scripts/CI/mac-prepared-inputs.py"))["code_images"](ROOT)
    sha = hashlib.sha256(raw).hexdigest()
    require(digest(path) == sha, "Original build receipt changed during admission")
    return {"build_receipt_sha256": sha, "qualified_sdk_route": result, "complete_native_images": images}


def prepare():
    require(not (OUT / "source-before.json").exists()
            and not (ARTIFACTS / "faithful-ipad-matrix.json").exists(),
            "Retain the prior attempt before preparing a new ordinary UI journey")
    context = source_context()
    contract = json.loads((ROOT / "docs/hq-integration/runtime27/R27_CASES.json").read_text())
    existing = {row["case_id"] for row in contract["cases"] + contract.get("supplemental_cases", [])}
    require(SELECTOR not in existing, "The dedicated ordinary case must not change Native116/Release114")
    contract.setdefault("supplemental_cases", []).append({
        "case_id": SELECTOR, "device": "ipad11", "status": "NOT_RUN",
        "oracle": "Ordinary UI, original native blocks, same saved UUID/revision and opaque SQLite body, discard and actual cold process recovery"})
    source = context["application_source_sha"]
    contract.update(source_test_commit=source, app_source=source, application_source_sha=source,
                    execution_case_ids=[SELECTOR], execution_groups=GROUPS, required_nonzero_cases=1,
                    native_cases_executed=0, expected_per_device={"ipad11": 1, "ipad13": 0, "iphone": 0},
                    diagnostic_only=True, hid_comparison=False,
                    scope="Separate ordinary local annotation editor acceptance; no qualification mode, cross-app sync or physical-device credit")
    runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["execution_groups"](contract)
    declarations = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))["validate_selections"](
        [SELECTOR], ROOT / "Maktabah-iOSUITests")
    require(declarations["status"] == "DECLARATIONS_MATCH", "Ordinary XCTest declaration is missing")
    write(OUT / "declarations.json", declarations)
    write(SELECTION, contract)
    write(OUT / "source-before.json", context)
    write(OUT / "qualified-build-before.json", qualified_build_context())


def owned_container(udid):
    require(str(uuid.UUID(udid)).upper() == udid, "Invalid original owned Simulator identity")
    raw = subprocess.check_output(["xcrun", "simctl", "get_app_container", udid, BUNDLE, "data"],
                                  text=True, timeout=45).strip()
    path = Path(raw)
    expected = Path.home() / "Library/Developer/CoreSimulator/Devices" / udid / "data/Containers/Data/Application"
    require(path.is_absolute() and path.is_dir() and path.resolve(strict=True) == path
            and path.parent == expected.resolve(strict=True), "The data container is not owned by this Simulator")
    return path


def original_debug_database(container):
    preferences = container / "Library/Preferences" / (BUNDLE + ".plist")
    require(not preferences.is_symlink(), "Aliased original app preferences")
    values = plistlib.loads(preferences.read_bytes()) if preferences.exists() else {}
    # AppConfig.folder(for:) uses this default only without a stored bookmark.
    # A selected external/iCloud folder must never be silently replaced here.
    require("annotations_FolderPath" not in values, "The original annotation folder has a bookmark")
    require(values.get("use_icloud_for_annotations", False) is False,
            "The owned fresh case must use the original local annotation folder")
    path = container / "Library/Application Support/Maktabah-Debug/Annotations.sqlite"
    require(path.resolve() == path, "Aliased original annotation database path")
    return path


class OrdinaryEvidence:
    def __init__(self):
        self.udid = None
        self.database = None
        self.captured = False
        self.state = {"status": "NOT_REACHED", "qualification_mode": False, "body_injected": False,
                      "sqlite_writes": 0, "account_repository_collected": False, "observations": []}

    def persist(self):
        write(OUT / "ordinary-storage-observations.json", self.state)

    def validate_selection(self, baseline, release_manifest, selection):
        require(not baseline and release_manifest is None and selection == [SELECTOR],
                "The callback belongs only to the dedicated ordinary case")

    def stage(self, udid, container, label, selection):
        require(self.udid is None and label == "11-reader" and selection == [SELECTOR],
                "Unexpected original matrix scope")
        actual = owned_container(udid)
        require(actual == Path(container).resolve(strict=True), "The original matrix container differs")
        self.udid, self.database = udid, original_debug_database(actual)
        self.state.update(status="ORIGINAL_LOCAL_FOLDER_OBSERVED", udid=udid,
                          database_path=str(self.database), annotation_bookmark_absent=True,
                          use_icloud_for_annotations=False)
        self.persist()
        # Only XCTest receives the read-only observation path. The application
        # does not receive a path override, qualification flag or native body.
        return {"TEST_RUNNER_OTZARIA_ANNOTATION_ACCEPTANCE_DATABASE": str(self.database)}

    def redact_evidence(self, line):
        if PREFIX in line:
            require(line.count(PREFIX) == 1, "Ambiguous ordinary storage observation")
            payload = line.split(PREFIX, 1)[1].strip()
            require(len(payload.encode()) <= 8192, "Oversized ordinary storage observation")
            value = json.loads(payload)
            require(type(value) is dict and set(value) == FIELDS
                    and value.get("stage") in STAGES
                    and value.get("qualification_mode") is False
                    and value.get("sqlite_open_mode") == "read-only", "Unexpected ordinary observation schema")
            require(len(self.state["observations"]) < len(STAGES), "Unexpected duplicate storage observation")
            self.state["observations"].append(value)
            self.persist()
        return line

    def capture(self, udid, label):
        require(udid == self.udid and label == "11-reader", "Wrong owned ordinary evidence request")
        if self.captured:
            return
        self.captured = True
        try:
            database = original_debug_database(owned_container(udid))
            require(database.is_file(), "Original annotation database is absent")
            self.state.update(observed_database_path=str(database),
                              container_relocated=database != self.database)
            observations = self.state["observations"]
            if [row["stage"] for row in observations] != STAGES:
                self.state["status"] = "INCOMPLETE_TEST_OBSERVATIONS"
                return
            before, saved, discarded, cold = observations
            require(type(before["annotation_id"]) is int and before["annotation_id"] > 0
                    and all(row["annotation_id"] == before["annotation_id"]
                            and row["annotation_uuid"] == before["annotation_uuid"] for row in observations),
                    "The normal journey changed its original row or UUID")
            require(saved["revision"] == before["revision"] + 1 and before["native_body_bytes"] == 0
                    and saved["native_body_bytes"] > 16, "The normal journey did not commit a full native body")
            require(all({key: value for key, value in row.items() if key != "stage"}
                        == {key: value for key, value in saved.items() if key != "stage"}
                        for row in (discarded, cold)), "Discard or cold reopen changed canonical storage")
            with closing(sqlite3.connect(database.as_uri() + "?mode=ro", uri=True, timeout=5)) as connection:
                require(connection.execute("PRAGMA quick_check").fetchall() == [("ok",)],
                        "Original annotation database failed its actual SQLite check")
                rows = connection.execute("""
                    SELECT a.id, a.ckRecordId, h.revision, v.payload_digest, v.payload_base64, v.mutation_id, v.source_digest
                    FROM annotations a JOIN otzaria_annotation_exchange_heads h
                      ON h.namespace = 'otzaria.local.annotation' AND lower(h.annotation_uuid) = lower(a.ckRecordId)
                    JOIN otzaria_annotation_exchange_versions v
                      ON v.namespace = h.namespace AND v.annotation_uuid = h.annotation_uuid AND v.revision = h.revision
                    WHERE a.id = ?
                    """, (saved["annotation_id"],)).fetchall()
            require(len(rows) == 1, "Exactly one real saved canonical version is required")
            identity, record_id, revision, sha, encoded, mutation, source = rows[0]
            import base64
            raw = base64.b64decode(encoded, validate=True)
            require(hashlib.sha256(raw).hexdigest() == sha == saved["payload_sha256"],
                    "Current canonical envelope differs from the actual saved observation")
            envelope = json.loads(raw)
            rich = envelope["richBody"]
            body = base64.b64decode(rich["bytesBase64"], validate=True)
            require(rich["format"] == "anytype.native-protobuf-archive" and rich["formatVersion"] == 1
                    and len(body) == saved["native_body_bytes"]
                    and hashlib.sha256(body).hexdigest() == saved["native_body_sha256"]
                    and str(uuid.UUID(record_id)).upper() == saved["annotation_uuid"]
                    and revision == saved["revision"] and mutation == saved["mutation_id"]
                    and source == saved["source_sha256"], "Original read-only SQLite body verification differs")
            self.state.update(status="ACTUAL_CANONICAL_SQLITE_OBSERVED", quick_check="ok",
                              final_annotation_id=identity, final_payload_sha256=sha,
                              final_native_body_sha256=hashlib.sha256(body).hexdigest(),
                              original_sdk_account_material_read=False)
        except BaseException as error:
            self.state.update(status="COLLECTION_FAILED", error=type(error).__name__ + ": " + str(error))
            raise
        finally:
            self.persist()

    def cleanup(self, udid):
        if self.udid is not None:
            self.capture(udid, "11-reader")
        self.persist()


def matrix():
    require(source_context() == json.loads((OUT / "source-before.json").read_text()), "Source changed before UI")
    require(not os.environ.get("FAITHFUL_RUNTIME27_RELEASE_MANIFEST")
            and not os.environ.get("FAITHFUL_DIAGNOSTIC_CASES"), "Do not mix ordinary and standard selections")
    os.environ["VALIDATING_BASELINE"] = "false"
    os.environ["FAITHFUL_RUNTIME27_MANIFEST"] = str(SELECTION)
    callback = OrdinaryEvidence()
    try:
        return runpy.run_path(str(ROOT / "Scripts/CI/run-faithful-ipad-matrix.py"))["main"](live_provider=callback)
    finally:
        callback.persist()


def execute():
    require(source_context() == json.loads((OUT / "source-before.json").read_text()), "Source changed before run")
    require(qualified_build_context() == json.loads((OUT / "qualified-build-before.json").read_text()),
            "Qualified native inputs changed before ordinary UI")
    driver = runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))
    controller = driver["runtime27_interruption"].InterruptController().install()
    try:
        return driver["run_logged"]([sys.executable, "Scripts/CI/production-annotation-native.py", "matrix"],
                                    "production-annotation-native-matrix.log", 4200, interrupt_controller=controller)
    finally:
        controller.restore()


def collect():
    report = {"status": "FAILED", "scope": "ORDINARY_LOCAL_ANNOTATION_EDITOR",
              "required_case_ids": [SELECTOR], "qualification_mode": False,
              "cross_app_sync_accepted": False, "physical_ipad_accepted": False,
              "full_native116_accepted": False, "full_release114_accepted": False}
    try:
        context = source_context()
        require(context == json.loads((OUT / "source-before.json").read_text()), "Source changed during UI")
        qualified = qualified_build_context()
        require(qualified == json.loads((OUT / "qualified-build-before.json").read_text()),
                "Qualified SDK, native images or original build receipt changed during UI")
        write(OUT / "qualified-build-after.json", qualified)
        storage = json.loads((OUT / "ordinary-storage-observations.json").read_text())
        require(storage["status"] == "ACTUAL_CANONICAL_SQLITE_OBSERVED", "Canonical SQLite observations incomplete")
        report.update(context, qualified_sdk_route=qualified["qualified_sdk_route"],
                      complete_native_image_count=len(qualified["complete_native_images"]),
                      ordinary_storage_receipt_sha256=digest(OUT / "ordinary-storage-observations.json"))
        runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["collect_cases"](
            report, json.loads(SELECTION.read_text()))
        devices = json.loads((ARTIFACTS / "faithful-ipad-matrix.json").read_text()).get("devices", [])
        require(len(devices) == 1 and devices[0].get("label") == "11-reader"
                and devices[0].get("status") == "EXECUTED_PASS"
                and devices[0].get("ownedSimulatorCleanup") == "PASS"
                and report.get("executed_ui_pass") == 1
                and all(report.get(key, 0) == 0 for key in ["executed_ui_fail", "executed_ui_skip", "ui_not_run"]),
                "The ordinary native case must actually execute and pass without skips")
        report["status"] = "ORDINARY_LOCAL_EDITOR_UI_AND_CANONICAL_STORAGE_PASS"
        return 0
    except Exception as error:
        report["error"] = type(error).__name__ + ": " + str(error)
        return 1
    finally:
        write(OUT / "result.json", report)


if __name__ == "__main__":
    os.chdir(ROOT)
    OUT.mkdir(parents=True, exist_ok=True)
    (ARTIFACTS / "runtime27").mkdir(parents=True, exist_ok=True)
    operations = {"prepare": prepare, "run": execute, "matrix": matrix, "collect": collect}
    require(len(sys.argv) == 2 and sys.argv[1] in operations, "Expected prepare, run, matrix or collect")
    raise SystemExit(operations[sys.argv[1]]() or 0)
