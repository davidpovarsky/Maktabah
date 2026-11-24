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
ORIGINAL_SOURCE = "1969b2065469b55e38e42cbb838a469ffa6a80f7"
DEPENDENCY_SOURCE = "6ba33d848bda808181e6b3174c05bac5b3fd2d94"
SOURCE = "7d5510dd29af2b66d740de136352916868c341ed"
COMPOSITION_BASE = "83e7e6db234117e43a5b025c0cf923aecedfaa4a"
COMPOSITION_INPUTS = ROOT / "Scripts/CI/runtime27-final-source-composition.inputs.json"
COMPOSITION_SHA256 = "36d14ddf2b9c7cb594e0cc982acb1f0d8e69b808d3c5868876b9fe79d2c994b0"
HISTORICAL_CONTROL_SOURCE = "602659607a3a6a2586a7c4a8d7ce6114eec8cd86"
MAC_SOURCE_INPUTS = ROOT / "Scripts/CI/runtime27-original-editor-mac-source.inputs.json"
MAC_SOURCE_SHA256 = "f58d3421dcec46d89c7de6d2cbf58a9c2a5178990631462ac5fce2fd6f458849"
ORIGINAL_HANLIN = "e00498e33f106cc43be0476ffa2e09329c8ca300"
QUALIFIED_HANLIN = "ca3c91f2233bf5c77990643b29a874aac8704639"
ORIGINAL_CORE = "e7bf34111e603ca977becd007dd4e5bb109af857"
QUALIFIED_CORE = "07431abccbfb151ca2dab67bca6cf86fcb2bd3b8"
HOST_LOCK = "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
SELECTOR = "OriginalEditorAnnotationAcceptanceTests/testSavedBlankAnnotationUsesOriginalEditorAndReopensMixedBlocksAfterProcessRelaunch"
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


def verify_qualified_dependency_delta(paths, before_hanlin, after_hanlin, before_lock, after_lock):
    """Require the exact qualified dependency leaf without adopting another app lane."""
    require(paths == [HOST_LOCK, "Vendor/HanlinSDK"],
            "Qualified dependency leaf changed original application or test source")
    require(before_hanlin == ORIGINAL_HANLIN and after_hanlin == QUALIFIED_HANLIN,
            "Qualified dependency leaf changed the reviewed Hanlin identities")
    require(hashlib.sha256(before_lock).hexdigest()
                == "722609bb6b71362aee5e7f401246edcd037a2d1815c2fc4704bf93830d9f5530"
            and hashlib.sha256(after_lock).hexdigest()
                == "a41b340f77574fd74013ba5df160cffabab473f1941a50031d0f9025007c8c9c"
            and before_lock.count(ORIGINAL_CORE.encode()) == 1
            and after_lock == before_lock.replace(ORIGINAL_CORE.encode(), QUALIFIED_CORE.encode())
            and after_lock.replace(QUALIFIED_CORE.encode(), ORIGINAL_CORE.encode()) == before_lock,
            "Qualified Host lock is not the exact single-revision change with its original inverse")
    return {"original_application_source": ORIGINAL_SOURCE, "qualified_dependency_source": DEPENDENCY_SOURCE,
            "product_delta": paths, "hanlin_source": QUALIFIED_HANLIN,
            "swift_ai_sdk_source": QUALIFIED_CORE,
            "host_lock_sha256": hashlib.sha256(after_lock).hexdigest(),
            "original_interface_and_tests_unchanged": True, "native_stageb_qualified": False}


def qualified_dependency_source():
    paths = git("diff", "--name-only", ORIGINAL_SOURCE, DEPENDENCY_SOURCE, "--",
                "Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests").splitlines()
    before_lock, after_lock = [subprocess.check_output(
        ["git", "show", source + ":" + HOST_LOCK], cwd=ROOT, timeout=90)
        for source in [ORIGINAL_SOURCE, DEPENDENCY_SOURCE]]
    return verify_qualified_dependency_delta(
        paths, git("rev-parse", ORIGINAL_SOURCE + ":Vendor/HanlinSDK"),
        git("rev-parse", DEPENDENCY_SOURCE + ":Vendor/HanlinSDK"), before_lock, after_lock)


def verify_composed_build_inputs(inputs, composition):
    resolution = composition["shared_build_input_resolution"]
    keys = resolution["resolved_fields"]
    require(keys == ["application_source_sha", "application_trees", "hanlin_gitlink"]
            and {key: inputs[key] for key in keys} == resolution["composed_values"],
            "Build inputs do not bind the exact composed application and qualified Hanlin")
    common = {key: value for key, value in inputs.items() if key not in keys}
    identity = hashlib.sha256(json.dumps(
        common, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    require(identity == resolution["all_remaining_fields_canonical_sha256"],
            "Artifact or engine/resource build inputs changed outside the source-only binding")
    return identity


def composed_product_source(*, historical_control_source=None):
    """Verify each composed product object against its accepted source ancestor."""
    require(digest(COMPOSITION_INPUTS) == COMPOSITION_SHA256,
            "Reviewed final source composition manifest changed")
    config = json.loads(COMPOSITION_INPUTS.read_text())
    require(config["schema"] == "otzaria.final-composed-product-source/1"
            and config["base_application_source"] == COMPOSITION_BASE
            and config["application_source_sha"] == SOURCE
            and config["application_tree"] == git("rev-parse", SOURCE + "^{tree}"),
            "Final composition source identity differs")
    roots = ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]
    require(config["application_trees"] == {
        path: git("rev-parse", SOURCE + ":" + path) for path in roots},
        "Final composition product trees differ")
    paths = git("diff", "--name-only", COMPOSITION_BASE, SOURCE, "--", *roots).splitlines()
    rows = config["product_delta"]
    require(len(rows) == 18 and paths == [row["path"] for row in rows],
            "Final composition has an undeclared product delta")

    def source_object(revision, path):
        listing = git("ls-tree", revision, "--", path)
        if not listing:
            return None
        meta, actual_path = listing.split("\t")
        require(actual_path == path, "Final source object path differs")
        mode, kind, identity = meta.split()
        value = {"mode": mode, "kind": kind, "object": identity}
        if kind == "blob":
            raw = subprocess.check_output(["git", "show", revision + ":" + path],
                                          cwd=ROOT, timeout=90)
            value.update(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
        return value

    for revision in set(config["accepted_sources"].values()):
        subprocess.run(["git", "merge-base", "--is-ancestor", revision, SOURCE],
                       cwd=ROOT, check=True, timeout=90)
    for row in rows:
        path = row["path"]
        require(row["accepted_source"] == config["accepted_sources"][row["accepted_lane"]]
                and source_object(COMPOSITION_BASE, path) == row["before"]
                and source_object(SOURCE, path) == row["after"]
                and source_object(row["accepted_source"], path) == row["after"]
                and row["accepted_source_object"] == row["after"]["object"],
                "Composed product does not equal its accepted source: " + path)
    if historical_control_source is None:
        subprocess.run(["git", "diff", "--quiet", SOURCE, "--", *roots],
                       cwd=ROOT, check=True, timeout=90)
        read_input = lambda path: (ROOT / path).read_bytes()
    else:
        require(historical_control_source == HISTORICAL_CONTROL_SOURCE,
                "Historical composition receipt source is not the reviewed immutable control")
        read_input = lambda path: subprocess.check_output(
            ["git", "show", historical_control_source + ":" + path], cwd=ROOT, timeout=90)
    build_inputs = json.loads(read_input(config["shared_build_input_resolution"]["path"]))
    common_inputs_sha256 = verify_composed_build_inputs(build_inputs, config)
    legacy = config["preserved_legacy_sdk_inputs"]
    require(legacy["qualification_for_composed_expanded_sdk"] == "UNQUALIFIED"
            and hashlib.sha256(read_input(legacy["path"])).hexdigest() == legacy["sha256"],
            "Preserved SDK inputs changed without a new reviewed composition binding")
    return {"manifest_sha256": COMPOSITION_SHA256,
            "base_application_source": COMPOSITION_BASE,
            "application_source_sha": SOURCE, "product_paths": paths,
            "accepted_source_objects_verified": len(rows),
            "artifact_engine_resource_inputs_sha256": common_inputs_sha256,
            "expanded_sdk_artifact_qualified": False,
            "native_stageb_qualified": False}


def require_composed_sdk_input(config):
    require(type(config.get("schema")) is int and config["schema"] == 3,
            "Composed full SDK requires actual schema3 producer admission; preserved legacy pins are UNQUALIFIED")


def source_context(*, projection_output=None, require_current_build=False):
    require(re.fullmatch(r"[a-f0-9]{40}", SOURCE), "Reviewed process-resume application source is not frozen")
    head = git("rev-parse", "HEAD")
    require(head == os.environ["EXPECTED_CHECKOUT_SHA"], "Wrong immutable qualification checkout")
    subprocess.run(["git", "merge-base", "--is-ancestor", SOURCE, head], cwd=ROOT, check=True, timeout=90)
    dependency_adoption = qualified_dependency_source()
    sdk_input = json.loads(ADMISSION.read_bytes())
    local = sdk_input.get("producer_kind") == "local-mac"
    mac_source, projection = None, None
    if local:
        runpy.run_path(str(ROOT / "Scripts/CI/original_editor_local_admission.py"))["validate_configuration"](sdk_input)
        composition = composed_product_source(historical_control_source=HISTORICAL_CONTROL_SOURCE)
        mac_source = runpy.run_path(str(ROOT / "Scripts/CI/original_editor_mac_source.py"))["verify"](
            ROOT, MAC_SOURCE_INPUTS, MAC_SOURCE_SHA256)
        product_source, hanlin = mac_source["application_source_sha"], mac_source["hanlin_source"]
        projection = runpy.run_path(str(ROOT / "Scripts/CI/original_editor_mac_projection.py"))["verify"](
            ROOT, mac_source, ADMISSION, require_current_build=require_current_build)
        if projection_output:
            write(OUT / projection_output, projection)
    else:
        composition = composed_product_source()
        product_source, hanlin = SOURCE, QUALIFIED_HANLIN
    trees = {path: git("rev-parse", "HEAD:" + path) for path in
             ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]}
    require(all(value == git("rev-parse", product_source + ":" + path) for path, value in trees.items()),
            "Reviewed original-editor consumer application or test changed")
    inputs = json.loads((ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json").read_text())
    require(inputs["application_source_sha"] == product_source and inputs["hanlin_gitlink"] == hanlin
            and all(inputs["application_trees"][path] == trees[path]
                for path in ["Source", "Vendor", "Maktabah.xcodeproj"]), "Stage2 pins do not bind the reviewed consumer")
    original = runpy.run_path(str(ROOT / "Scripts/CI/completion-focused-native.py"))
    execution_inputs = original["exact_working_inputs"](["Scripts/CI", ".github/workflows", "Maktabah-iOSUITests", "tools"])
    return {"checkout_sha": head, "application_source_sha": product_source, "application_trees": trees,
            "qualified_dependency_adoption": dependency_adoption, "source_composition": composition,
            "mac_source_composition": mac_source,
            "generated_projection_contract": projection["binding"] if projection else None,
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
    sdk_input = json.loads(ADMISSION.read_bytes())
    if sdk_input.get("schema") == 2:
        pending.append(ci / "original_editor_continuation_admission.py")
        pending.append(ci / "original_editor_clang_imports.py")
        pending.append(ci / "original_editor_host_clang_context.py")
        if sdk_input.get("continuation_kind") == "original-signed-consumer-runtime/1":
            pending.append(ci / "original_editor_signed_consumer_admission.py")
    if sdk_input.get("schema") == 3:
        pending.append(ci / "original_editor_shared_runtime.py")
    if sdk_input.get("producer_kind") == "local-mac":
        pending.append(ci / "original_editor_local_admission.py")
        pending.append(ci / "original_editor_mac_source.py")
        pending.append(ci / "original_editor_mac_projection.py")
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
    context = source_context(projection_output="projection-before.json")
    runtime_dependency_preflight()
    sdk_input = json.loads(ADMISSION.read_text())
    require_composed_sdk_input(sdk_input)
    local = sdk_input.get("producer_kind") == "local-mac"
    if local:
        runpy.run_path(str(ROOT / "Scripts/CI/original_editor_local_admission.py"))["validate_configuration"](sdk_input)
    require(re.fullmatch(r"[a-f0-9]{40}", sdk_input.get("source_sha", ""))
            and re.fullmatch(r"[a-f0-9]{64}", sdk_input.get("archive_sha256", ""))
            and (local or (type(sdk_input.get("artifact_id")) is int and sdk_input["artifact_id"] > 0)),
            "Original editable SDK artifact pins are not finalized")
    contract = json.loads(FULL.read_text())
    existing = {row["case_id"] for row in contract["cases"] + contract.get("supplemental_cases", [])}
    require(SELECTOR not in existing, "Dedicated original-editor case unexpectedly entered a standard catalog")
    contract.setdefault("supplemental_cases", []).append({
        "case_id": SELECTOR, "device": "ipad11", "status": "NOT_RUN",
        "oracle": "Original saved blank annotation, mixed Hebrew/English native blocks, real export/CAS/import, exact owned account/object process relaunch and rendered reopen"})
    product_source = context["application_source_sha"]
    contract.update(source_test_commit=product_source, app_source=product_source, application_source_sha=product_source,
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
    require(source_context(projection_output="projection-build.json", require_current_build=True)
            == json.loads((OUT / "source-before.json").read_text()), "Qualification inputs changed before execution")
    build = json.loads((ROOT / "build/hq-stage2/result.json").read_text())
    require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
            and build.get("checkout_sha") == os.environ["EXPECTED_CHECKOUT_SHA"]
            and build.get("original_editor_distribution", {}).get("admission_sha256") == digest(ADMISSION),
            "No current-source actual app build with admitted original SDK")
    sdk_input = json.loads(ADMISSION.read_bytes())
    if sdk_input.get("producer_kind") == "local-mac":
        admitted = build["original_editor_distribution"]
        require(admitted.get("producer_kind") == "local-mac" and admitted.get("schema") == 3
                and admitted.get("run_id") == sdk_input["run_id"]
                and admitted.get("source_sha") == sdk_input["source_sha"]
                and admitted.get("local_execution_sha256") == sdk_input["local_execution_sha256"],
                "Actual StageB build lost its local SDK producer binding")
        runpy.run_path(str(ROOT / "Scripts/CI/hq-original-editor-distribution.py"))["require_unchanged"](ROOT, admitted)
    if sdk_input.get("schema") == 2:
        admitted = build["original_editor_distribution"]
        require(admitted.get("schema") == 2
                and admitted.get("framework_producer") == sdk_input["framework_producer"]
                and admitted.get("runtime_qualification_producer") == sdk_input["runtime_qualification_producer"]
                and admitted.get("qualification_sha256") == sdk_input["qualification_sha256"],
                "Actual StageB build lost the separate producer bindings")
        runpy.run_path(str(ROOT / "Scripts/CI/hq-original-editor-distribution.py"))["require_unchanged"](ROOT, admitted)
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
                require(len(directories) <= 2, "More than two native original-editor process presentations")
                for directory in directories:
                    uuid.UUID(directory.name)
                    require(directory.is_dir() and not directory.is_symlink(), "Invalid actual presentation directory")
                    allowed = {"editing.json", "saved.json", "reopened.json", "process-resume-prepared.json",
                               "process-resumed.json", "closed.json", "credential-cleanup.json",
                               "failed.json", "committed-without-current-view.json"}
                    for source in sorted(directory.iterdir()):
                        require(source.name in allowed, "Unexpected native qualification report")
                        retained.append(retain_file(source, OUT / "native/qualification" / directory.name / source.name,
                                                    32_768, container))
            checkpoint_root = container / "Library/Application Support/Anytype"
            if checkpoint_root.exists():
                require(checkpoint_root.is_dir() and not checkpoint_root.is_symlink(),
                        "Aliased original qualification repository parent")
                for name in ["OriginalEditorQualificationClaim.json", "OriginalEditorQualificationResume.json",
                             "OriginalEditorQualificationResumeAttempt.json"]:
                    source = checkpoint_root / name
                    if source.exists():
                        retained.append(retain_file(source, OUT / "native/process-checkpoint" / name, 32_768, container))
            temporary = container / "tmp"
            require(temporary.is_dir() and not temporary.is_symlink(), "Invalid original app temporary directory")
            captures = [path for path in temporary.iterdir() if path.name.startswith("anytype-original-snapshot-")]
            require(len(captures) <= 4, "Unbounded original snapshot evidence")
            protobuf = {"native-export-report.pb", "before-oldAnytypeID.pb", "before-uniqueKey.pb",
                        "import-rpc-accepted-not-complete.pb", "finish-collection-query.pb",
                        "imported-root-query.pb", "original-restored-object-show.pb",
                        "original-empty-page-create.pb", "original-empty-page-show.pb",
                        "original-process-resume-object-show.pb"}
            for directory in sorted(captures):
                uuid.UUID(directory.name.removeprefix("anytype-original-snapshot-"))
                require(directory.is_dir() and not directory.is_symlink(), "Invalid original snapshot directory")
                for source in sorted(directory.iterdir()):
                    name = source.name
                    if name in protobuf or re.fullmatch(r"import-event-0[0-7]\.pb", name):
                        maximum = 1_048_576 if name in {"original-restored-object-show.pb", "original-empty-page-show.pb",
                                                     "original-process-resume-object-show.pb"} else 262_144
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
    require(source_context(require_current_build=True) == json.loads((OUT / "source-before.json").read_text()),
            "Source changed before original matrix")
    require(not os.environ.get("FAITHFUL_RUNTIME27_RELEASE_MANIFEST") and not os.environ.get("FAITHFUL_DIAGNOSTIC_CASES"),
            "Dedicated original-editor run cannot mix selectors or Release inputs")
    os.environ["VALIDATING_BASELINE"] = "false"
    os.environ["FAITHFUL_RUNTIME27_MANIFEST"] = str(SELECTION)
    callback = OriginalEditorEvidence()
    try:
        return runpy.run_path(str(ROOT / "Scripts/CI/run-faithful-ipad-matrix.py"))["main"](live_provider=callback)
    finally:
        callback.persist()


def strict_native_json(path, maximum=32_768):
    raw = read_regular(path, maximum, OUT)
    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, "Duplicate original qualification JSON key")
            result[key] = value
        return result
    result = json.loads(raw, object_pairs_hook=pairs,
                        parse_constant=lambda value: (_ for _ in ()).throw(ValueError("Nonfinite native JSON")))
    require(type(result) is dict, "Native qualification report is not an object")
    return result


def native_integer(value, name, minimum=0, maximum=2**63 - 1):
    require(type(value) is int and minimum <= value <= maximum, "Invalid original integer: " + name)
    return value


def native_uuid(value, name):
    require(type(value) is str and str(uuid.UUID(value)).upper() == value, "Invalid canonical UUID: " + name)
    return value


def native_digest(value, name):
    require(type(value) is str and re.fullmatch(r"[a-f0-9]{64}", value), "Invalid original digest: " + name)
    return value


def native_identity(value, name):
    require(type(value) is str and re.fullmatch(r"[A-Za-z0-9_.-]{1,512}", value)
            and value not in {".", ".."}, "Invalid original identity: " + name)
    return value


def verify_native_receipts():
    collection = strict_native_json(OUT / "native-evidence-collection.json", 262_144)
    require(collection["status"] == "NAMED_EVIDENCE_RETAINED"
            and collection["account_repository_collected"] is False,
            "Named native evidence was not retained")
    presentations = list((OUT / "native/qualification").iterdir())
    require(len(presentations) == 2, "Exactly two original process presentations are required")
    for directory in presentations:
        native_uuid(directory.name, "presentation directory")
        require(directory.is_dir() and not directory.is_symlink(), "Aliased native presentation")
    first = [path for path in presentations if (path / "editing.json").is_file()]
    second = [path for path in presentations if (path / "process-resumed.json").is_file()]
    require(len(first) == len(second) == 1 and first[0] != second[0], "Unqualified process presentation lineage")
    require({path.name for path in first[0].iterdir()}
            == {"editing.json", "saved.json", "reopened.json", "process-resume-prepared.json"},
            "First process did not end with its one prepared checkpoint")
    require({path.name for path in second[0].iterdir()}
            == {"process-resumed.json", "credential-cleanup.json", "closed.json"},
            "Second process did not retain its resumed object and explicit cleanup")
    reports = {stage: strict_native_json(first[0] / (stage + ".json"))
               for stage in ["editing", "saved", "reopened", "process-resume-prepared"]}
    reports.update({stage: strict_native_json(second[0] / (stage + ".json"))
                    for stage in ["process-resumed", "closed"]})
    opened, saved, reopened, prepared, resumed, closed = (
        reports[key] for key in ["editing", "saved", "reopened", "process-resume-prepared", "process-resumed", "closed"]
    )
    annotation_uuid = native_uuid(opened["annotation_uuid"], "annotation")
    annotation_id = native_integer(opened["annotation_id"], "annotation ID", 1)
    profile = native_uuid(opened["profile_id"], "profile")
    first_pid = native_integer(opened["process_id"], "first process PID", 1, 2**31 - 1)
    second_pid = native_integer(resumed["process_id"], "second process PID", 1, 2**31 - 1)
    require(first_pid != second_pid, "The original editor never changed process")
    for stage, report in reports.items():
        require(type(report["schema"]) is int and report["schema"] == 2
                and report["stage"] == stage and report["qualification"] == MARKER
                and report["bundle_id"] == BUNDLE
                and report["annotation_uuid"] == annotation_uuid
                and native_integer(report["annotation_id"], "report annotation ID", 1) == annotation_id
                and report["profile_id"] == profile
                and report["preview_derived_from_native_body"] is False,
                "Actual process annotation report identity differs")
        expected_pid = second_pid if stage in {"process-resumed", "closed"} else first_pid
        expected_mode = "resume-owned-once" if expected_pid == second_pid else "prepare-owned-once"
        require(native_integer(report["process_id"], "report PID", 1, 2**31 - 1) == expected_pid
                and report["process_mode"] == expected_mode, "Wrong owned process marker or PID")
    require(native_integer(opened["initial_revision"], "initial revision") == 0
            and opened["initial_note_blank"] is True and opened["initial_rich_body_absent"] is True
            and native_integer(saved["commit_revision"], "commit revision", 1) == 1
            and saved["commit_replayed"] is False
            and saved["commit_delivery"] in {"committed", "completedWithoutOwnership"}
            and native_integer(reopened["reopened_revision"], "reopened revision", 1) == saved["commit_revision"]
            and reopened["reopened_annotation_uuid"] == annotation_uuid
            and native_integer(reopened["reopened_annotation_id"], "reopened annotation ID", 1) == annotation_id
            and reopened["reopened_payload_digest"] == saved["payload_digest"]
            and reopened["durable_body_verified_by_original_reopen"] is True,
            "Actual original saved-row/reopen receipt is incomplete")
    require(resumed["initial_rich_body_absent"] is False and resumed["initial_note_blank"] is True
            and native_integer(resumed["initial_revision"], "resumed revision", 1) == saved["commit_revision"],
            "Second process did not read the existing rich annotation")
    equal_fields = ["process_runtime_nonce", "process_account_id", "process_space_id", "process_object_id",
                    "process_workspace_namespace", "process_saved_body_sha256", "process_saved_archive_sha256",
                    "process_annotation_uuid", "process_profile_id", "process_payload_digest",
                    "process_source_witness_sha256", "process_annotation_id", "process_revision", "process_prepared_pid"]
    for name in equal_fields:
        require(prepared[name] == resumed[name] == closed[name]
                and type(prepared[name]) is type(resumed[name]) is type(closed[name]),
                "Process checkpoint mismatch: " + name)
    for name in ["process_runtime_nonce", "process_workspace_namespace", "process_annotation_uuid", "process_profile_id"]:
        native_uuid(prepared[name], name)
    for name in ["process_account_id", "process_space_id", "process_object_id"]:
        native_identity(prepared[name], name)
    for name in ["process_saved_body_sha256", "process_saved_archive_sha256",
                 "process_payload_digest", "process_source_witness_sha256"]:
        native_digest(prepared[name], name)
    require(prepared["process_credential_consumed"] is False
            and resumed["process_credential_consumed"] is True
            and closed["process_credential_consumed"] is True
            and native_integer(prepared["process_prepared_pid"], "prepared PID", 1, 2**31 - 1) == first_pid
            and native_integer(prepared["process_current_pid"], "preparation current PID", 1, 2**31 - 1) == first_pid
            and native_integer(resumed["process_current_pid"], "resume current PID", 1, 2**31 - 1) == second_pid
            and native_integer(closed["process_current_pid"], "closing PID", 1, 2**31 - 1) == second_pid
            and prepared["process_annotation_uuid"] == annotation_uuid
            and native_integer(prepared["process_annotation_id"], "checkpoint annotation ID", 1) == annotation_id
            and prepared["process_profile_id"] == profile
            and native_integer(prepared["process_revision"], "checkpoint revision", 1) == saved["commit_revision"]
            and prepared["process_payload_digest"] == saved["payload_digest"]
            and prepared["process_saved_archive_sha256"] == saved["native_archive_sha256"]
            and prepared["process_source_witness_sha256"] == reopened["reopened_source_witness_sha256"]
            and prepared["process_space_id"] == reopened["reopened_space_id"] == resumed["original_space_id"]
            and prepared["process_object_id"] == reopened["reopened_object_id"] == resumed["original_object_id"],
            "The original checkpoint was not consumed for these exact saved identities")
    cleanup = strict_native_json(second[0] / "credential-cleanup.json", 8_192)
    require(set(cleanup) == {"schema", "qualification", "presentation_id", "process_id", "process_mode", "scope", "status"}
            and type(cleanup["schema"]) is int and cleanup["schema"] == 1
            and cleanup["qualification"] == MARKER
            and cleanup["presentation_id"] == second[0].name
            and cleanup["process_mode"] == "resume-owned-once"
            and native_integer(cleanup["process_id"], "credential cleanup PID", 1, 2**31 - 1) == second_pid
            and cleanup["scope"] == "only the original factory-owned qualification query"
            and cleanup["status"] == "OWNED_QUERY_ABSENCE_VERIFIED"
            and closed["credential_cleanup_status"] == cleanup["status"],
            "The exact original qualification credential has no owned absence receipt")
    checkpoint_dir = OUT / "native/process-checkpoint"
    require({path.name for path in checkpoint_dir.iterdir()}
            == {"OriginalEditorQualificationClaim.json", "OriginalEditorQualificationResume.json",
                "OriginalEditorQualificationResumeAttempt.json"}, "Missing exact owned checkpoint files")
    claim = strict_native_json(checkpoint_dir / "OriginalEditorQualificationClaim.json", 4_096)
    checkpoint = strict_native_json(checkpoint_dir / "OriginalEditorQualificationResume.json")
    attempt = strict_native_json(checkpoint_dir / "OriginalEditorQualificationResumeAttempt.json", 4_096)
    nonce = prepared["process_runtime_nonce"]
    require(set(claim) == {"runtimeNonce", "scope"} and claim["runtimeNonce"] == nonce
            and claim["scope"] == "fresh local-only original editor acceptance; no account reset or repository reuse",
            "Wrong original first-process repository claim")
    require(set(checkpoint) == {"schema", "runtimeNonce", "bundleID", "accountID", "spaceID", "objectID",
                               "spaceCreationResponseSHA256", "preparedProcessID", "parentIdentity",
                               "repositoryIdentity", "accountRepositoryIdentity", "request"}
            and checkpoint["schema"] == "original-editor-owned-process-resume/1"
            and checkpoint["runtimeNonce"] == nonce and checkpoint["bundleID"] == BUNDLE
            and checkpoint["accountID"] == prepared["process_account_id"]
            and checkpoint["spaceID"] == prepared["process_space_id"]
            and checkpoint["objectID"] == prepared["process_object_id"]
            and native_integer(checkpoint["preparedProcessID"], "checkpoint PID", 1, 2**31 - 1) == first_pid,
            "Actual owned native checkpoint differs from the presentation")
    native_digest(checkpoint["spaceCreationResponseSHA256"], "original Space creation response")
    for name in ["parentIdentity", "repositoryIdentity", "accountRepositoryIdentity"]:
        identity = checkpoint[name]
        require(type(identity) is dict and set(identity) == {"device", "inode"},
                "Invalid original directory identity fields")
        native_integer(identity["device"], "directory device", -(2**63), 2**63 - 1)
        native_integer(identity["inode"], "directory inode", 0, 2**64 - 1)
    request = checkpoint["request"]
    mapping = {"workspaceNamespace": "process_workspace_namespace", "hostProfileID": "process_profile_id",
               "annotationUUID": "process_annotation_uuid", "legacyAnnotationID": "process_annotation_id",
               "revision": "process_revision", "sourceWitnessSHA256": "process_source_witness_sha256",
               "payloadDigest": "process_payload_digest", "nativeArchiveSHA256": "process_saved_archive_sha256",
               "nativeBodySHA256": "process_saved_body_sha256"}
    require(type(request) is dict and set(request) == set(mapping), "Unqualified resume request fields")
    for key, field in mapping.items():
        require(request[key] == prepared[field] and type(request[key]) is type(prepared[field]),
                "Original checkpoint request differs: " + key)
    require(set(attempt) == {"schema", "runtimeNonce", "preparedProcessID", "resumingProcessID"}
            and attempt["schema"] == "original-editor-owned-process-resume-attempt/1"
            and attempt["runtimeNonce"] == nonce
            and native_integer(attempt["preparedProcessID"], "attempt prepared PID", 1, 2**31 - 1) == first_pid
            and native_integer(attempt["resumingProcessID"], "attempt resumed PID", 1, 2**31 - 1) == second_pid,
            "The exclusive native resume attempt belongs to another process")
    snapshots = OUT / "native/snapshots"
    maps = list(snapshots.glob("*/native-root-map.json"))
    require(len(maps) == 1, "Missing original import completion/root-map evidence")
    mapped = strict_native_json(maps[0])
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
    for name in ["original-empty-page-create.pb", "original-empty-page-show.pb", "original-process-resume-object-show.pb"]:
        matches = list(snapshots.glob("*/" + name))
        require(len(matches) == 1 and 0 < matches[0].stat().st_size <= 1_048_576,
                "Missing exact original native response: " + name)
    return {"annotation_uuid": annotation_uuid, "annotation_id": annotation_id,
            "revision": saved["commit_revision"], "native_archive_sha256": saved["native_archive_sha256"],
            "payload_digest": saved["payload_digest"], "preview_derived_from_native_body": False,
            "process_ids": [first_pid, second_pid], "process_runtime_nonce": nonce,
            "process_workspace_namespace": prepared["process_workspace_namespace"],
            "original_account_id": prepared["process_account_id"], "original_space_id": prepared["process_space_id"],
            "original_object_id": prepared["process_object_id"],
            "saved_local_body_sha256": prepared["process_saved_body_sha256"],
            "credential_cleanup_status": cleanup["status"],
            "native_snapshot_digest": None, "body_acknowledgement_granted": False,
            "scope": "actual process restart, exact saved local context, same original account/Space/object and rendered blocks"}


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
        context = source_context(projection_output="projection-after.json", require_current_build=True)
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
                for name in ["original-editor-two-typed-blocks", "original-editor-imported-two-rendered-blocks",
                             "original-editor-process-resume-prepared",
                             "original-editor-process-relaunched-two-rendered-blocks"]:
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
