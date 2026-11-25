#!/usr/bin/env python3
"""Whole-source Apple Foundation ownership48 and current local43/cold2.

The real CloudKit manager, SDK record mapping and original debouncer compile in
both executables. Explicit account/transport/wait doubles execute the ownership
controls; this gate never initializes a live account or sends a CloudKit request.
The selected43 Swift file is copied whole; original validators and deadlines remain.
The local-only route records no Cloud48 execution or acceptance.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import importlib.util
import json
import platform
import re
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL_DRIVER = "tools/hq-local-annotation-editor-acceptance.py"
SELF = "tools/hq-local-annotation-cloud-acceptance.py"
CLOUD_DECLARATIONS = "Tests/HQ/local-annotation-cloud/LocalAnnotationCloudAcceptance.swift"
CLOUD_BOUNDARY = "Tests/HQ/local-annotation-cloud/LocalAnnotationCloudBoundary.swift"
EXTRA_SOURCES = [
    "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorCloudOwnership.swift",
    "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorCloudKit.swift",
    "Source/Core/CloudKit/CloudKitCoreManager.swift",
    "Source/Core/CloudKit/CloudKitUploadDebouncer.swift",
    "Source/Core/CloudKit/CloudKitSyncable.swift",
    "Source/Core/CloudKit/AnnotationSyncHandler.swift",
    CLOUD_BOUNDARY,
]


def load_original():
    spec = importlib.util.spec_from_file_location("unchanged_local_annotation_driver", ROOT / ORIGINAL_DRIVER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


original = load_original()
# The selected whole43 executable gets the required complete cloud dependencies.
# The actual current Swift assertions and @main entry are copied without rewriting.
SOURCES = original.SOURCES[:-1] + [p for p in EXTRA_SOURCES if p not in original.SOURCES] + original.SOURCES[-1:]
CLOUD_SOURCES = SOURCES[:-1] + [CLOUD_DECLARATIONS]
CASE_COUNT = 43
CLOUD_CASE_COUNT = 48
COLD_MODES = original.COLD_MODES
verify_cold = original.verify_cold
verify_sqlite = original.verify_sqlite
verify_cases = original.verify_cases
declaration_names = original.declaration_names
run_logged = original.run_logged
sha = original.sha
write_json = original.write_json
PREFIX_END = "// The actual original SQLite driver calls this synchronous function inside the"


def cloud_declaration_names(text):
    names = re.findall(r'await run\("([a-z0-9_]+)"\)', text)
    if len(names) != CLOUD_CASE_COUNT or len(set(names)) != CLOUD_CASE_COUNT:
        raise ValueError("All48 unique owned-cloud declarations required")
    return names


def verify_cloud_cases(rows, expected):
    if not isinstance(rows, list) or len(rows) != CLOUD_CASE_COUNT or any(not isinstance(row, dict) for row in rows):
        raise ValueError("Missing or malformed cloud component results")
    names = [row.get("name") for row in rows]
    if len(set(names)) != CLOUD_CASE_COUNT or set(names) != set(expected):
        raise ValueError("Cloud results do not match exact declarations")
    if any(row.get("status") != "PASS" or row.get("error") is not None for row in rows):
        raise ValueError("Failed, skipped or unexecuted cloud case")


def fixture_prefix(root):
    data = (Path(root) / original.SOURCES[-1]).read_bytes()
    marker = PREFIX_END.encode()
    if data.count(marker) != 1:
        raise ValueError("Original fixture prefix is not uniquely bounded")
    prefix = data[:data.index(marker)]
    if b"@main" in prefix or prefix.count(b"struct LocalFixture") != 1:
        raise ValueError("Original fixture prefix shape changed")
    return prefix


def source_provenance(root):
    paths = set(SOURCES + CLOUD_SOURCES) | {SELF, ORIGINAL_DRIVER,
        "Maktabah.xcodeproj/project.pbxproj", "Source/Core/Database/CloudKitSyncManager.swift",
        "Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift"}
    core = Path(root) / "Source/Otzaria/Actions"
    paths.update(p.relative_to(root).as_posix() for p in core.rglob("*")
                 if p.is_file() and ".build" not in p.parts and p.suffix in (".swift", ".json", ".resolved"))
    return sorted(paths)


def compiled_targets(cloud_only=False, local_only=False):
    if cloud_only and local_only:
        raise ValueError("Choose one explicit execution selection")
    local = ("LocalAnnotationEditorAcceptance", SOURCES)
    cloud = ("LocalAnnotationCloudOwnershipAcceptance", CLOUD_SOURCES)
    return [local] if local_only else [cloud] if cloud_only else [local, cloud]


def verify_copies(root, owned, cloud_only=False, local_only=False):
    result = {}
    for target, inputs in compiled_targets(cloud_only, local_only):
        directory = Path(owned) / "package/Sources" / target
        names = {Path(path).name: path for path in inputs}
        if len(names) != len(inputs):
            raise ValueError("Whole-source filename collision")
        extra = {"OriginalLocalFixture.swift"} if target == "LocalAnnotationCloudOwnershipAcceptance" else set()
        if {p.name for p in directory.iterdir()} != set(names) | extra:
            raise ValueError("Compiled source membership differs")
        observed = {}
        for name, source in names.items():
            copied = directory / name
            if copied.is_symlink() or not copied.is_file() or copied.read_bytes() != (Path(root) / source).read_bytes():
                raise ValueError("Whole compiled source differs: " + source)
            observed[source] = sha(copied)
        if extra:
            prefix = directory / "OriginalLocalFixture.swift"
            if prefix.is_symlink() or prefix.read_bytes() != fixture_prefix(root):
                raise ValueError("Original fixture prefix differs")
            observed["generated:exact_original_fixture_prefix"] = sha(prefix)
        result[target] = observed
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--cloud-only", action="store_true",
                           help="Run the owned Cloud48 component without repeating local43/cold2")
    selection.add_argument("--local-only", action="store_true",
                           help="Run current local43/cold2 with the complete existing cloud source closure")
    args = parser.parse_args()
    success_status = ("PASS_APPLE_FOUNDATION_LOCAL43_COLD2" if args.local_only
                      else "PASS_APPLE_FOUNDATION_CLOUD48" if args.cloud_only
                      else "PASS_APPLE_FOUNDATION_CLOUD48_LOCAL43_COLD2")
    artifacts = args.artifacts_dir.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    if (artifacts / "RESULT.json").exists():
        raise RuntimeError("Preserve prior attempt")
    report = {"status": "NOT_RUN", "scope": ("APPLE_FOUNDATION_ORIGINAL_STORE_COMPONENT"
              if args.local_only else "APPLE_FOUNDATION_OWNED_CLOUD_COMPONENT"),
        "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "host": platform.platform(),
        "commands": [], "cases": [], "cloud_cases": [], "cold_processes": [],
        "execution_selection": ("local43_cold2" if args.local_only else
                                "cloud48" if args.cloud_only else "cloud48_local43_cold2"),
        "native_ui_executed": 0, "anytype_executed": 0, "cloudkit_transport_executed": 0,
        "app_relaunch_executed": 0, "live_exchange_enabled": False,
        "boundaries": "Whole original Store/Repository/SQLite/ledger/session/Core/debouncer/CK mapping; explicit account/transport/wait and unrelated catalog/UI/localization doubles"}
    before = None
    paths = []
    try:
        if sys.platform != "darwin":
            raise RuntimeError("Installed Apple SDK required; no compiler installation or non-Apple fallback")
        swift = shutil.which("swift")
        if not swift:
            raise RuntimeError("Installed Swift required")
        sdk = Path(subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True, timeout=30).strip())
        if not (sdk / "usr/include/sqlite3.h").is_file():
            raise RuntimeError("Original Apple SDK SQLite3 required")
        core = ROOT / "Source/Otzaria/Actions"
        if not (core / "Package.swift").is_file():
            raise RuntimeError("Whole pinned original Core package required")
        paths = source_provenance(ROOT)
        before = {path: sha(ROOT / path) for path in paths}
        report["source_before"] = before
        report["source_sha"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, timeout=30).strip()
        report["source_status"] = subprocess.check_output(["git", "status", "--short"], cwd=ROOT, text=True, timeout=30)
        report["swift"] = subprocess.check_output([swift, "--version"], text=True, timeout=30).strip()
        report["sdk"] = str(sdk)
        expected = [] if args.cloud_only else declaration_names((ROOT / SOURCES[-1]).read_text(encoding="utf-8"))
        expected_cloud = [] if args.local_only else cloud_declaration_names((ROOT / CLOUD_DECLARATIONS).read_text(encoding="utf-8"))
        owned = artifacts / ("owned-" + str(uuid.uuid4()))
        package = owned / "package"
        fixtures = owned / "fixtures"
        cloud_fixtures = owned / "cloud-fixtures"
        fixtures.mkdir(parents=True)
        cloud_fixtures.mkdir()
        report["owned_directory"] = str(owned)
        for target, sources in compiled_targets(args.cloud_only, args.local_only):
            directory = package / "Sources" / target
            directory.mkdir(parents=True)
            for source in sources:
                shutil.copyfile(ROOT / source, directory / Path(source).name)
            if target == "LocalAnnotationCloudOwnershipAcceptance":
                (directory / "OriginalLocalFixture.swift").write_bytes(fixture_prefix(ROOT))
        report["compiled_copies_before"] = verify_copies(ROOT, owned, args.cloud_only, args.local_only)
        targets = []
        for target, _ in compiled_targets(args.cloud_only, args.local_only):
            targets.append('''.executableTarget(name: NAME,
                dependencies: [.product(name: "OtzariaActionCore", package: "actions")],
                swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])],
                linkerSettings: [.linkedLibrary("sqlite3")])'''.replace("NAME", json.dumps(target)))
        manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "LocalAnnotationCloudOwnershipAcceptance",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: CORE_PATH)],
    targets: [TARGETS], swiftLanguageModes: [.v6])
'''.replace("CORE_PATH", json.dumps(core.as_posix())).replace("TARGETS", ",\n        ".join(targets))
        (package / "Package.swift").write_bytes(manifest.encode())
        command = [swift, "build", "--package-path", str(package), "--scratch-path", str(owned / "swift-build"), "-j", "1"]
        run_logged(command, ROOT, artifacts, "compile", 480, report)
        binary_path = Path(run_logged(command + ["--show-bin-path"], ROOT, artifacts, "binary-path", 30, report).strip())
        executable = binary_path / "LocalAnnotationEditorAcceptance"
        cloud_executable = binary_path / "LocalAnnotationCloudOwnershipAcceptance"
        if not args.cloud_only:
            report["executable_sha256"] = sha(executable)
        if not args.local_only:
            report["cloud_executable_sha256"] = sha(cloud_executable)
        if not args.cloud_only:
            run_logged([str(executable), "self-tests", str(fixtures)], ROOT, artifacts, "component-cases", 180, report)
            report["cases"] = json.loads((fixtures / "CASES.json").read_text())
            verify_cases(report["cases"], expected)
        if not args.local_only:
            run_logged([str(cloud_executable), str(cloud_fixtures)], ROOT, artifacts, "cloud-cases", 180, report)
            report["cloud_cases"] = json.loads((cloud_fixtures / "CASES.json").read_text())
            verify_cloud_cases(report["cloud_cases"], expected_cloud)
        if not args.cloud_only:
            for mode in COLD_MODES:
                run_logged([str(executable), mode, str(fixtures)], ROOT, artifacts, mode, 45, report)
                report["cold_processes"].append(json.loads((fixtures / (mode + ".json")).read_text()))
            first = json.loads((fixtures / "cold-expected-1.json").read_text())
            second = json.loads((fixtures / "cold-expected-2.json").read_text())
            verify_cold(report["cold_processes"], first, second)
            report["independent_sqlite_readback"] = verify_sqlite(fixtures, first, second)
            report["cold_reopen_gates"] = 2
        report["compiled_copies_after"] = verify_copies(ROOT, owned, args.cloud_only, args.local_only)
        if report["compiled_copies_before"] != report["compiled_copies_after"] or before != {path: sha(ROOT / path) for path in paths}:
            raise RuntimeError("Compiled copy or source changed during execution")
        report["status"] = success_status
    except Exception as error:
        report["error"] = repr(error)
        report["status"] = "FAILED" if report["commands"] else "NOT_RUN"
        print(repr(error))
    finally:
        # Retain partial real rows even when a process exits nonzero; no partial
        # rows or compile-only status can satisfy the strict final gate.
        if "owned_directory" in report:
            for key, subdirectory in (("cases", "fixtures"), ("cloud_cases", "cloud-fixtures")):
                path = Path(report["owned_directory"]) / subdirectory / "CASES.json"
                if path.is_file():
                    try: report[key] = json.loads(path.read_text())
                    except Exception as error: report[key + "_read_error"] = repr(error)
        if before is not None:
            report["source_after"] = {path: sha(ROOT / path) for path in paths}
            report["source_unchanged"] = before == report["source_after"]
            if not report["source_unchanged"]:
                report["status"] = "FAILED"
        for prefix, key in (("", "cases"), ("cloud_", "cloud_cases")):
            report[prefix + "passed_cases"] = sum(row.get("status") == "PASS" for row in report[key] if isinstance(row, dict))
            report[prefix + "failed_cases"] = sum(row.get("status") != "PASS" for row in report[key] if isinstance(row, dict))
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        write_json(artifacts / "RESULT.json", report)
        print(json.dumps({key: report[key] for key in ("status", "passed_cases", "failed_cases", "cloud_passed_cases", "cloud_failed_cases")}, sort_keys=True))
    return 0 if report["status"] == success_status else 1


if __name__ == "__main__":
    raise SystemExit(main())
