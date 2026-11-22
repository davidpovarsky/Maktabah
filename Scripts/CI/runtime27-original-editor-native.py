#!/usr/bin/env python3
"""One original saved-annotation UI journey through the original SDK and matrix."""
import ast
import hashlib
import importlib
import json
import os
from pathlib import Path
import plistlib
import re
import runpy
import stat
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "67518e8df6975c976e8f1cd9e622328dc45985fc"
SELECTOR = "OriginalEditorAnnotationAcceptanceTests/testSavedBlankAnnotationUsesOriginalEditorAndDurablyReopensTwoBlocks"
MARKER = "owned-local-only"
BUNDLE = "com.davidpovarsky.chavrusatext"
OUT = ROOT / "build/original-editor-native-evidence"
ARTIFACTS = ROOT / "build/artifacts"
SELECTION = OUT / "selection.json"
ADMISSION = ROOT / "Scripts/CI/runtime27-original-editor.inputs.json"
FULL = ROOT / "docs/hq-integration/runtime27/R27_CASES.json"
RELEASE = ROOT / "Scripts/CI/runtime27-release-manifest.json"
GROUPS = [{"label": "11-reader", "size": "11", "hid_comparison": False, "case_ids": [SELECTOR]}]


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, timeout=90).decode().strip()


def source_context():
    head = git("rev-parse", "HEAD")
    require(head == os.environ["EXPECTED_CHECKOUT_SHA"], "Wrong immutable qualification checkout")
    subprocess.run(["git", "merge-base", "--is-ancestor", SOURCE, head], cwd=ROOT, check=True, timeout=90)
    trees = {path: git("rev-parse", "HEAD:" + path) for path in
             ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]}
    require(all(value == git("rev-parse", SOURCE + ":" + path) for path, value in trees.items()),
            "Reviewed original-editor consumer application or test changed")
    inputs = json.loads((ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json").read_text())
    require(inputs["application_source_sha"] == SOURCE and all(inputs["application_trees"][path] == trees[path]
                for path in ["Source", "Vendor", "Maktabah.xcodeproj"]), "Stage2 pins do not bind the reviewed consumer")
    original = runpy.run_path(str(ROOT / "Scripts/CI/completion-focused-native.py"))
    execution_inputs = original["exact_working_inputs"](["Scripts/CI", ".github/workflows", "Maktabah-iOSUITests", "tools"])
    return {"checkout_sha": head, "application_source_sha": SOURCE, "application_trees": trees,
            "execution_inputs": execution_inputs, "sdk_admission_sha256": digest(ADMISSION),
            "native116_catalog_sha256": digest(FULL), "release114_manifest_sha256": digest(RELEASE)}


def runtime_dependency_preflight():
    """Import the selected route's declared dependencies before the app build.

    The original fixture installer has top-level native actions, so inspect its
    imports without executing that script or creating a simulator here.
    """
    require(sys.version_info >= (3, 11) and callable(getattr(hashlib, "file_digest", None)),
            "The original native route requires Python 3.11+ with hashlib.file_digest")
    ci = ROOT / "Scripts/CI"
    pending = [ci / name for name in ["runtime27.py", "run-faithful-ipad-matrix.py",
               "prepare-faithful-ipad-fixtures.py", "runtime27-fixture-oracle.py", "verify-faithful-xctest.py",
               "hq-original-editor-distribution.py", "restore-original-editor-distribution.py"]]
    checked, imported = {}, set()
    while pending:
        path = pending.pop()
        if path.name in checked:
            continue
        require(path.parent == ci and path.is_file() and not path.is_symlink(), "Missing original Python route input")
        before = digest(path)
        for node in ast.walk(ast.parse(path.read_bytes(), filename=str(path))):
            names = [value.name for value in node.names] if isinstance(node, ast.Import) else (
                [node.module] if isinstance(node, ast.ImportFrom) and node.level == 0 else [])
            for name in names:
                require(isinstance(name, str) and name, "Invalid original Python dependency")
                if name.split(".")[0] in sys.stdlib_module_names:
                    importlib.import_module(name)
                    imported.add(name)
                else:
                    require(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name), "Unqualified Python dependency: " + name)
                    local = ci / (name + ".py")
                    require(local.is_file(), "Missing required Python dependency before native build: " + name)
                    pending.append(local)
        require(digest(path) == before, "Python route input changed during dependency preflight")
        checked[path.name] = before
    write(OUT / "python-runtime-preflight.json", {"status": "SELECTED_ROUTE_IMPORT_PREFLIGHT_PASS",
          "python": sys.version, "executable": sys.executable, "source_inputs": checked,
          "actual_imported_stdlib_modules": sorted(imported), "third_party_python_modules_required": [],
          "native_process_or_fixture_executed": False})


def prepare():
    require(not (OUT / "source-before.json").exists() and not (ARTIFACTS / "faithful-ipad-matrix.json").exists(),
            "Refusing stale native qualification evidence")
    context = source_context()
    runtime_dependency_preflight()
    sdk_input = json.loads(ADMISSION.read_text())
    require(re.fullmatch(r"[a-f0-9]{40}", sdk_input.get("source_sha", ""))
            and re.fullmatch(r"[a-f0-9]{64}", sdk_input.get("archive_sha256", ""))
            and type(sdk_input.get("artifact_id")) is int and sdk_input["artifact_id"] > 0,
            "Original editable SDK artifact pins are not finalized")
    contract = json.loads(FULL.read_text())
    existing = {row["case_id"] for row in contract["cases"] + contract.get("supplemental_cases", [])}
    require(SELECTOR not in existing, "Dedicated original-editor case unexpectedly entered a standard catalog")
    contract.setdefault("supplemental_cases", []).append({
        "case_id": SELECTOR, "device": "ipad11", "status": "NOT_RUN",
        "oracle": "Original saved blank annotation, two native UITextView blocks, real export/CAS/import and rendered reopen"})
    contract.update(source_test_commit=SOURCE, app_source=SOURCE, application_source_sha=SOURCE,
                    execution_case_ids=[SELECTOR], execution_groups=GROUPS, required_nonzero_cases=1,
                    native_cases_executed=0, expected_per_device={"ipad11": 1, "ipad13": 0, "iphone": 0},
                    diagnostic_only=True, hid_comparison=False,
                    scope="Separate original-editor Stage B UI acceptance; full Native116/Release114 unchanged")
    runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["execution_groups"](contract)
    declarations = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))["validate_selections"](
        [SELECTOR], ROOT / "Maktabah-iOSUITests")
    require(declarations["status"] == "DECLARATIONS_MATCH", "Dedicated original XCTest declaration is missing")
    write(OUT / "declarations.json", declarations)
    write(SELECTION, contract)
    write(OUT / "source-before.json", context)


def built_binaries():
    products = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator"
    identities = {}
    for bundle in [products / "Maktabah.app", products / "Maktabah-iOSUITests-Runner.app",
                   products / "Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest"]:
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        for path in [bundle / info["CFBundleExecutable"], *sorted(bundle.glob("*.dylib"))]:
            require(path.is_file() and not path.is_symlink(), "Actual native code image is missing or aliased")
            identities[path.relative_to(ROOT).as_posix()] = {"bytes": path.stat().st_size, "sha256": digest(path)}
    return identities


def execute():
    require(source_context() == json.loads((OUT / "source-before.json").read_text()), "Qualification inputs changed before execution")
    build = json.loads((ROOT / "build/hq-stage2/result.json").read_text())
    require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
            and build.get("checkout_sha") == os.environ["EXPECTED_CHECKOUT_SHA"]
            and build.get("original_editor_distribution", {}).get("admission_sha256") == digest(ADMISSION),
            "No current-source actual app build with admitted original SDK")
    write(OUT / "built-binaries-before.json", built_binaries())
    driver = runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))
    controller = driver["runtime27_interruption"].InterruptController().install()
    try:
        return driver["run_logged"]([sys.executable, "Scripts/CI/runtime27-original-editor-native.py", "matrix"],
                                    "original-editor-native-matrix.log", 4_200, interrupt_controller=controller)
    finally:
        controller.restore()


def read_regular(path, maximum, owner):
    path, owner = Path(path), Path(owner).resolve()
    require(path.is_absolute() and path.resolve().is_relative_to(owner), "Evidence escaped the owned container")
    for parent in [path, *path.parents]:
        require(not parent.is_symlink(), "Aliased qualification evidence")
        if parent == owner:
            break
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as stream:
        before = os.fstat(stream.fileno())
        require(stat.S_ISREG(before.st_mode) and 0 <= before.st_size <= maximum,
                "Missing or oversized named qualification evidence")
        raw = stream.read(maximum + 1)
        after = os.fstat(stream.fileno())
    require((before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns)
            == (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns)
            and len(raw) == before.st_size, "Qualification evidence changed while being retained")
    return raw


def retain_file(source, destination, maximum, owner):
    raw = read_regular(source, maximum, owner)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        require(destination.read_bytes() == raw, "Refusing to replace already retained qualification evidence")
    else:
        with destination.open("xb") as stream:
            stream.write(raw)
    return {"path": destination.relative_to(OUT).as_posix(), "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest()}


class OriginalEditorEvidence:
    """Reuse the reviewed matrix callback seam; never alter simulator lifecycle."""
    def __init__(self):
        self.udid = None
        self.capture_attempted = False
        self.state = {"scope": "NAMED_ORIGINAL_EDITOR_EVIDENCE_ONLY", "staged_private_inputs": False,
                      "account_repository_collected": False, "files": [], "status": "NOT_REACHED"}

    def persist(self):
        write(OUT / "native-evidence-collection.json", self.state)

    def validate_selection(self, baseline, release_manifest, selection):
        require(not baseline and release_manifest is None and selection == [SELECTOR],
                "Original-editor callback cannot activate outside its dedicated case")

    def stage(self, udid, container, label, selection):
        require(self.udid is None and label == "11-reader" and selection == [SELECTOR],
                "Unexpected original-editor simulator scope")
        uuid.UUID(udid)
        actual = Path(container).resolve()
        require(actual.is_dir() and udid in actual.parts, "Original matrix did not supply its owned app container")
        self.udid = udid
        self.state.update(udid=udid, label=label, status="ORIGINAL_FIXTURE_READY")
        self.persist()
        return {"TEST_RUNNER_OTZARIA_ORIGINAL_EDITOR_QUALIFICATION": MARKER}

    def redact_evidence(self, line):
        # No provider credential or account material is injected into argv,
        # environment or XCTest typing by this route.
        return line

    def capture(self, udid, label):
        require(udid == self.udid and label == "11-reader", "Wrong owned simulator evidence request")
        if self.capture_attempted:
            return
        self.capture_attempted = True
        try:
            container = Path(subprocess.check_output(
                ["xcrun", "simctl", "get_app_container", udid, BUNDLE, "data"],
                text=True, timeout=45).strip()).resolve()
            require(container.is_dir() and udid in container.parts, "Wrong actual qualification container")
            presentations = container / "Documents/original-editor-qualification"
            retained = []
            if presentations.exists():
                require(not presentations.is_symlink(), "Aliased original-editor receipt directory")
                directories = list(presentations.iterdir())
                require(len(directories) <= 1, "More than one native original-editor presentation")
                for directory in directories:
                    uuid.UUID(directory.name)
                    require(directory.is_dir() and not directory.is_symlink(), "Invalid actual presentation directory")
                    allowed = {"editing.json", "saved.json", "reopened.json", "failed.json", "committed-without-current-view.json"}
                    for source in sorted(directory.iterdir()):
                        require(source.name in allowed, "Unexpected native qualification report")
                        retained.append(retain_file(source, OUT / "native/qualification" / directory.name / source.name,
                                                    32_768, container))
            temporary = container / "tmp"
            require(temporary.is_dir() and not temporary.is_symlink(), "Invalid original app temporary directory")
            captures = [path for path in temporary.iterdir() if path.name.startswith("anytype-original-snapshot-")]
            require(len(captures) <= 4, "Unbounded original snapshot evidence")
            protobuf = {"native-export-report.pb", "before-oldAnytypeID.pb", "before-uniqueKey.pb",
                        "import-rpc-accepted-not-complete.pb", "finish-collection-query.pb",
                        "imported-root-query.pb", "original-restored-object-show.pb"}
            for directory in sorted(captures):
                uuid.UUID(directory.name.removeprefix("anytype-original-snapshot-"))
                require(directory.is_dir() and not directory.is_symlink(), "Invalid original snapshot directory")
                for source in sorted(directory.iterdir()):
                    name = source.name
                    if name in protobuf or re.fullmatch(r"import-event-0[0-7]\.pb", name):
                        maximum = 1_048_576 if name == "original-restored-object-show.pb" else 262_144
                    elif name == "native-root-map.json":
                        maximum = 32_768
                    elif name.endswith(".zip"):
                        maximum = 65_536
                    else:
                        raise RuntimeError("Unexpected original native snapshot output")
                    retained.append(retain_file(source, OUT / "native/snapshots" / directory.name / name, maximum, container))
            require(sum(row["bytes"] for row in retained) <= 8 * 1024 * 1024, "Unbounded named native evidence total")
            self.state.update(files=retained, status="NAMED_EVIDENCE_RETAINED", account_repository_collected=False)
        except BaseException as error:
            self.state.update(status="COLLECTION_FAILED", error=type(error).__name__ + ": " + str(error))
            raise
        finally:
            self.persist()

    def cleanup(self, udid):
        # The original matrix still stops/deletes only its own simulator. This
        # callback retains bounded failure evidence before that existing step.
        if self.udid is not None:
            require(udid == self.udid, "Wrong original-editor cleanup scope")
            self.capture(udid, "11-reader")
        self.persist()


def matrix():
    require(source_context() == json.loads((OUT / "source-before.json").read_text()), "Source changed before original matrix")
    require(not os.environ.get("FAITHFUL_RUNTIME27_RELEASE_MANIFEST") and not os.environ.get("FAITHFUL_DIAGNOSTIC_CASES"),
            "Dedicated original-editor run cannot mix selectors or Release inputs")
    os.environ["VALIDATING_BASELINE"] = "false"
    os.environ["FAITHFUL_RUNTIME27_MANIFEST"] = str(SELECTION)
    callback = OriginalEditorEvidence()
    try:
        return runpy.run_path(str(ROOT / "Scripts/CI/run-faithful-ipad-matrix.py"))["main"](live_provider=callback)
    finally:
        callback.persist()


def verify_native_receipts():
    collection = json.loads((OUT / "native-evidence-collection.json").read_text())
    require(collection["status"] == "NAMED_EVIDENCE_RETAINED" and collection["account_repository_collected"] is False,
            "Named native evidence was not retained")
    presentations = list((OUT / "native/qualification").iterdir())
    require(len(presentations) == 1, "Missing unique original native presentation")
    reports = {stage: json.loads((presentations[0] / (stage + ".json")).read_text())
               for stage in ["editing", "saved", "reopened"]}
    opened, saved, reopened = (reports[key] for key in ["editing", "saved", "reopened"])
    for report in reports.values():
        require(report["qualification"] == MARKER and report["bundle_id"] == BUNDLE
                and report["annotation_uuid"] == opened["annotation_uuid"]
                and report["annotation_id"] == opened["annotation_id"]
                and report["preview_derived_from_native_body"] is False, "Actual annotation receipt identity differs")
    require(opened["initial_revision"] == 0 and opened["initial_note_blank"] is True
            and opened["initial_rich_body_absent"] is True
            and saved["commit_revision"] == 1 and saved["commit_replayed"] is False
            and saved["commit_delivery"] in {"committed", "completedWithoutOwnership"}
            and reopened["reopened_revision"] == saved["commit_revision"]
            and reopened["reopened_annotation_uuid"] == opened["annotation_uuid"]
            and reopened["reopened_annotation_id"] == opened["annotation_id"]
            and reopened["reopened_payload_digest"] == saved["payload_digest"]
            and reopened["durable_body_verified_by_original_reopen"] is True,
            "Actual original saved-row/reopen receipt is incomplete")
    snapshots = OUT / "native/snapshots"
    maps = list(snapshots.glob("*/native-root-map.json"))
    require(len(maps) == 1, "Missing original import completion/root-map evidence")
    mapped = json.loads(maps[0].read_text())
    require(mapped["archiveSHA256"] == saved["native_archive_sha256"]
            and mapped["sourceObjectID"] == opened["original_object_id"]
            and mapped["sourceSpaceID"] == opened["original_space_id"]
            and mapped["mappedObjectID"] == reopened["reopened_object_id"]
            and mapped["targetSpaceID"] == reopened["reopened_space_id"]
            and digest(maps[0].parent / "original-native-import.zip") == saved["native_archive_sha256"],
            "Original import evidence is not bound to the actual durable capture")
    exports = list(snapshots.glob("*/native-export-report.pb"))
    require(len(exports) == 1 and exports[0].stat().st_size > 0, "Missing original export report")
    archives = list(exports[0].parent.glob("*.zip"))
    require(len(archives) == 1 and digest(archives[0]) == saved["native_archive_sha256"],
            "Original export archive does not match the durable body receipt")
    return {"annotation_uuid": opened["annotation_uuid"], "annotation_id": opened["annotation_id"],
            "revision": saved["commit_revision"], "native_archive_sha256": saved["native_archive_sha256"],
            "payload_digest": saved["payload_digest"], "preview_derived_from_native_body": False}


def retain_visual_evidence(devices):
    result = ARTIFACTS / "result-11-reader.xcresult"
    if not result.is_dir():
        return []
    require(len(devices) == 1 and devices[0].get("label") == "11-reader", "Unowned XCTest attachment source")
    raw = ROOT / "build/original-editor-native-raw-attachments"
    require(not raw.exists(), "Refusing to replace original native attachments")
    subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                    "--output-path", str(raw)], check=True, timeout=180)
    manifest = json.loads(read_regular(raw / "manifest.json", 2 * 1024 * 1024, ROOT))
    require(isinstance(manifest, list), "Unknown actual XCTest attachment manifest")
    retained = []
    for entry in manifest:
        if entry.get("testIdentifier", "").removesuffix("()") != SELECTOR:
            continue
        for attachment in entry.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName", "")
            if not name.removeprefix("DIAGNOSTIC-").startswith("original-editor-"):
                continue
            filename = attachment.get("exportedFileName", "")
            suffix = Path(filename).suffix.lower()
            require(re.fullmatch(r"[A-Za-z0-9_.-]+", filename) and Path(filename).name == filename
                    and suffix in {".png", ".txt", ".json"}
                    and attachment.get("deviceId") == devices[0].get("udid"), "Unowned named XCTest attachment")
            maximum = 20 * 1024 * 1024 if suffix == ".png" else 2 * 1024 * 1024
            retained.append({**retain_file(raw / filename, OUT / "visual" / filename, maximum, ROOT),
                             "original_attachment": attachment, "testIdentifier": entry["testIdentifier"]})
    require(len(retained) <= 40 and sum(row["bytes"] for row in retained) <= 80 * 1024 * 1024,
            "Unbounded named original-editor attachments")
    write(OUT / "visual/manifest.json", retained)
    return retained


def collect():
    report = {"status": "FAILED", "scope": "SEPARATE_ORIGINAL_EDITOR_STAGE_B", "required_case_ids": [SELECTOR],
              "full_native116_acceptance": False, "full_release114_acceptance": False,
              "device_or_production_qualification": False, "preview_qualification": "NOT_DERIVED"}
    matrix_path = ARTIFACTS / "faithful-ipad-matrix.json"
    try:
        matrix_report = json.loads(matrix_path.read_text()) if matrix_path.exists() else {}
    except (ValueError, OSError) as error:
        matrix_report = {"report_error": type(error).__name__ + ": " + str(error)}
    devices = matrix_report.get("devices", [])
    report["original_matrix"] = matrix_report
    report["primary_native_failures"] = [{"label": row.get("label"), "failedPhase": row.get("failedPhase"),
                                          "error": row.get("error")} for row in devices if row.get("status") != "EXECUTED_PASS"]
    exit_code = 1
    try:
        context = source_context()
        require(context == json.loads((OUT / "source-before.json").read_text()), "Source or original catalogs changed during UI")
        report.update(context)
        build = json.loads((ROOT / "build/hq-stage2/result.json").read_text())
        require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS" and build["checkout_sha"] == context["checkout_sha"],
                "No matching original SDK/app/runner build")
        require(built_binaries() == json.loads((OUT / "built-binaries-before.json").read_text()),
                "Actual app or UI runner image changed during UI")
        hq = runpy.run_path(str(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"))
        hq["verify_actual_sources"](build)
        require(digest(ROOT / "Maktabah.xcodeproj/project.pbxproj") == build["native_context"]["generated_project_sha256"]
                and digest(ROOT / "Maktabah.xcworkspace/contents.xcworkspacedata") == build["native_context"]["workspace_sha256"],
                "Original generated project/workspace changed")
        hq["prepare_original_hanlin"](json.loads((ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json").read_text()),
                                      build, verify_only=True)
        write(OUT / "original-post-ui-input-audit.json", build)
        sdk = runpy.run_path(str(ROOT / "Scripts/CI/hq-original-editor-distribution.py"))
        sdk["verify_built_app"](ROOT, build["original_editor_distribution"],
            ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app",
            ROOT / "build/hq-stage2/original-editor", after_ui=True)
        runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["collect_cases"](report, json.loads(SELECTION.read_text()))
        strict = json.loads((ARTIFACTS / "runtime27/verified-11-reader.json").read_text())
        require(len(devices) == 1 and devices[0].get("label") == "11-reader"
                and devices[0].get("status") == "EXECUTED_PASS" and devices[0].get("ownedSimulatorCleanup") == "PASS"
                and not devices[0].get("livePrivateInputCleanup") and not devices[0].get("cleanupErrors")
                and strict.get("status") == "EXECUTED_PASS" and strict.get("required_ui_cases") == [SELECTOR]
                and strict.get("executed_total") == 1 and strict.get("failed") == 0 and strict.get("skipped") == 0
                and report.get("executed_ui_pass") == 1
                and not any(report.get(key, 0) for key in ["executed_ui_fail", "executed_ui_skip", "ui_not_run"]),
                "The exact original native case did not execute and pass with complete cleanup")
        report["durable_native_receipt"] = verify_native_receipts()
        report["status"] = "ORIGINAL_EDITOR_STAGE_B_UI_EXECUTED_PASS"
        exit_code = 0
    except Exception as error:
        report["error"] = type(error).__name__ + ": " + str(error)
    finally:
        # Only bounded named reports/logs cross the artifact boundary; neither
        # the simulator's SDK repository nor broad app data is uploaded.
        names = ["faithful-ipad-matrix.json", "test-simulator-11-reader.log", "test-case-execution-11-reader.json",
                 "miniTest10-native-fixture-install-11-reader.json", "miniTest10-native-fixture-install-11-reader-attempt-1.json",
                 "miniTest10-native-fixture-install-11-reader-before-reboot.json", "miniTest10-native-fixture-termination-11-reader.json",
                 "miniTest10-native-fixture-termination-11-reader-before-reboot.json"]
        names += ["runtime27/" + name for name in ["verified-11-reader.json", "verified-11-reader.summary.json",
                  "verified-11-reader.tests.json", "fixture-oracle-11-reader.json", "original-editor-native-matrix.log"]]
        try:
            retained = []
            for name in names:
                source = ARTIFACTS / name
                if source.is_file():
                    retained.append(retain_file(source, OUT / "original-matrix" / name, 32 * 1024 * 1024, ROOT))
            write(OUT / "retained-original-matrix-files.json", retained)
            visuals = retain_visual_evidence(devices)
            if exit_code == 0:
                for name in ["original-editor-two-typed-blocks", "original-editor-imported-two-rendered-blocks"]:
                    require(any(row["path"].endswith(".png") and row["original_attachment"]["suggestedHumanReadableName"]
                                .startswith("DIAGNOSTIC-" + name) for row in visuals),
                            "Missing original actual native editor screenshot: " + name)
        except Exception as error:
            report.update(status="FAILED", evidence_retention_error=type(error).__name__ + ": " + str(error))
            exit_code = 1
        write(OUT / "result.json", report)
    return exit_code


if __name__ == "__main__":
    os.chdir(ROOT)
    OUT.mkdir(parents=True, exist_ok=True)
    (ARTIFACTS / "runtime27").mkdir(parents=True, exist_ok=True)
    command = sys.argv[1] if len(sys.argv) == 2 else None
    if command not in {"prepare", "run", "matrix", "collect"}:
        raise SystemExit("Expected prepare, run, matrix or collect")
    raise SystemExit({"prepare": prepare, "run": execute, "matrix": matrix, "collect": collect}[command]())
