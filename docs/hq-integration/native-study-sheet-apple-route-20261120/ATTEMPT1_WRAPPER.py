#!/usr/bin/env python3
"""Bind an actual full app and twelve additive Native cases plus Foundation25.

Original runtime27.py and its matrix own full app compilation, Simulator,
XCTest, deadlines and evidence collection. This is not full116/114 acceptance.
"""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
DOCS = "docs/hq-integration/native-study-sheet-apple-route-20261120/"
BINDING_PATH = DOCS + "SOURCE_BINDING.json"
BINDING = json.loads((ROOT / BINDING_PATH).read_bytes())
BASE = BINDING["source_commit"]
TREES = BINDING["protected_trees"]
REF = "refs/heads/codex/otzaria-native-study-sheet-native-20261120"
WORKFLOW = ".github/workflows/otzaria-native-study-sheet-native.yml"
SELF = "Scripts/CI/native-study-sheet-native.py"
TESTS = "Scripts/CI/test-native-study-sheet-native.py"
ORIGINAL_MANIFEST = "docs/hq-integration/runtime27/R27_CASES.json"
INPUTS = "Scripts/CI/hq-stage2-focused-apple.inputs.json"
ADDITIONS = "Scripts/CI/hq-stage2-otzaria-test-additions.json"
RUNTIME = "Scripts/CI/runtime27.py"
CASES = ['NativeStudySheetPadTests/testSystemStudySheetThreeDetentsPhysicallyRightRTL', 'NativeStudySheetPadTests/testSystemStudySheetThreeDetentsPhysicallyRightLTR', 'NativeStudySheetPadTests/testSystemStudySheetSameIPadNarrowAndWideRetainsOwnerAndAnchor', 'NativeStudySheetPadTests/testSystemStudySheetPeekAllowsOriginalReaderScrollBehindIt', 'NativeStudySheetPadTests/testSystemStudySheetOriginalNotesSaveEditDeleteAndCancel', 'NativeStudySheetPadTests/testSystemStudySheetOriginalTOCWaitsForActualSheetDismissal', 'NativeStudySheetPadTests/testSystemStudySheetOriginalEmbeddedSefariaOwnerAndAnchor', 'NativeStudySheetPadTests/testSystemStudySheetParentCloseWhileOriginalNoteChildIsVisible', 'NativeStudySheetPadTests/testSystemStudySheetTOCWhileOriginalNoteChildIsVisible', 'NativeStudySheetPadTests/testSystemStudySheetReopenDuringActualDismissalRejectsStaleAndReplayedInput', 'NativeStudySheetPadTests/testSystemStudySheetInteractiveDismissThenSameIPadResizeDoesNotReopen', 'NativeStudySheetPhoneFallbackTests/testOriginalPhoneInspectorFallbackRetainsReader']
CONFIGURATIONS = {
    "ipad11": {"label": "11-reader", "size": "11", "cases": CASES[:-1],
               "manifest": "docs/hq-integration/runtime27/native-study-sheet-ipad11.json"},
    "iphone": {"label": "phone", "size": "phone", "cases": CASES[-1:],
               "manifest": "docs/hq-integration/runtime27/native-study-sheet-iphone.json"},
}
ALLOWED = {WORKFLOW, SELF, TESTS, INPUTS, ADDITIONS, RUNTIME,
           *[c["manifest"] for c in CONFIGURATIONS.values()]}
OUT = ROOT / "build/artifacts/native-study-sheet-native"


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, timeout=120)


def read_json(path):
    return json.loads((ROOT / path).read_bytes())


def frozen_json(path):
    return json.loads(git("show", BASE + ":" + path))


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def require_finalized(binding):
    require(binding.get("source_sealed") is True, "UNFINALIZED source; activation forbidden")
    values = [binding.get("source_commit"), binding.get("source_tree"), *binding.get("protected_trees", {}).values()]
    require(len(values) == 6 and all(isinstance(v, str) and len(v) == 40 and all(c in "0123456789abcdef" for c in v) for v in values), "Unbound actual source/tree")


def github_context():
    return {"repository": os.environ.get("GITHUB_REPOSITORY"), "run_id": os.environ.get("GITHUB_RUN_ID"),
            "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"), "head": os.environ.get("GITHUB_SHA"),
            "ref": os.environ.get("GITHUB_REF")}


def validate_context(context, expected):
    require(context.get("repository") == "davidpovarsky/Maktabah" and context.get("head") == expected
            and context.get("ref") == REF, "Wrong actual workflow context")
    require(isinstance(context.get("run_id"), str) and context["run_id"].isdigit()
            and context.get("run_attempt") == "1", "Missing exact first-attempt run binding")


def validate_identity(head, expected, ref, parents, trees, changed):
    require(len(expected) == 40 and all(c in "0123456789abcdef" for c in expected), "Missing exact expected checkout")
    require(head == expected and ref == REF, "Wrong immutable checkout/ref")
    require(parents == [BASE], "This route requires exactly one reviewed child of M")
    require(trees == TREES, "Application, dependency, project or XCTest tree changed")
    require(set(changed) >= ALLOWED, "Missing required focused source/pins")
    require(all(path in ALLOWED or path.startswith(DOCS) for path in changed), "Unreviewed changed path")


def validate_manifest(current, original, configuration):
    require(configuration in CONFIGURATIONS, "Unknown configuration")
    config = CONFIGURATIONS[configuration]
    selected = config["cases"]
    old_rows = original["cases"] + original["supplemental_cases"]
    rows = current["cases"] + current["supplemental_cases"]
    require(len(old_rows) == 116 and rows[:116] == old_rows, "Original116 rows/oracles changed")
    require(len(rows) == 128 and len({r["case_id"] for r in rows}) == 128, "Expected116+12 unique additive declarations")
    require([r["case_id"] for r in rows[116:]] == CASES, "Wrong new declared methods")
    require([r["device"] for r in rows[116:]] == ["ipad11"] * 11 + ["iphone"]
            and all(r["status"] == "NOT_RUN" for r in rows[116:]), "Wrong diagnostic device or unexecuted credit")
    require(current["execution_case_ids"] == selected, "Wrong configuration selection/order")
    require(current["execution_groups"] == [{"label": config["label"], "size": config["size"], "case_ids": selected}], "Wrong original matrix partition")
    expected_per_device = {"ipad11": 11 if configuration == "ipad11" else 0,
                           "ipad13": 0, "iphone": 1 if configuration == "iphone" else 0}
    require(current["expected_per_device"] == expected_per_device, "Wrong per-device counts")
    require(current["required_nonzero_cases"] == len(selected) and current["native_cases_executed"] == 0, "Wrong execution count")
    require(current["diagnostic_only"] is True and current["hid_comparison"] is False, "Wrong diagnostic mode")
    require(all(current[key] == BASE for key in ("source_test_commit", "app_source", "application_source_sha")), "Source/test pins do not bind M")
    history = current["native_study_sheet_diagnostic_20261120"]
    require(history["configuration"] == configuration and history["source_snapshot"] == BASE, "Wrong diagnostic provenance")
    require(history["original_execution_case_ids"] == original["execution_case_ids"]
            and history["additional_declared_rows"] == rows[116:], "Original full scope not retained")
    require(history["full_native116_acceptance"] is False and history["full_release114_acceptance"] is False
            and history["new_native_executions"] == 0, "Unexecuted or full-phase credit")
    allowed = {"source_test_commit", "app_source", "application_source_sha", "scope", "native_cases_executed",
               "required_nonzero_cases", "expected_per_device", "diagnostic_only", "hid_comparison", "execution_case_ids",
               "execution_groups", "selected_scope_reason", "diagnostic_purpose", "supplemental_cases", "native_study_sheet_diagnostic_20261120"}
    require({k: v for k, v in current.items() if k not in allowed} ==
            {k: v for k, v in original.items() if k not in allowed}, "Unrelated manifest contract changed")


def validate_pins(inputs, old_inputs, additions, old_additions, runtime, old_runtime):
    edits = read_json(DOCS + "RUNTIME_EXACT_EDIT.json")
    inverse = runtime.decode()
    for edit in reversed(edits["replacements"]):
        require(inverse.count(edit["after"]) == 1, "Ambiguous runtime path inverse")
        inverse = inverse.replace(edit["after"], edit["before"], 1)
    require(inverse.count(BINDING["r27_test_sha256"]) == 1, "Missing actual test hash guard")
    inverse = inverse.replace(BINDING["r27_test_sha256"], BINDING["original_r27_pin"], 1)
    require(inverse.encode() == old_runtime, "Original runtime changed beyond explicit path and reviewed source hash")
    require(old_additions.count(BINDING["old_project_pin"].encode()) == 1 and
            additions == old_additions.replace(BINDING["old_project_pin"].encode(), BINDING["project_blob"].encode()), "Exact78 additions/build exclusions changed beyond project proof pin")
    allowed = {"application_source_sha", "application_trees", "otzaria_test_additions_sha256"}
    require({k: v for k, v in inputs.items() if k not in allowed} ==
            {k: v for k, v in old_inputs.items() if k not in allowed}, "Engine/resource/SDK/package inputs changed")
    require(inputs["application_source_sha"] == BASE and inputs["application_trees"] ==
            {k: TREES[k] for k in ("Source", "Vendor", "Maktabah.xcodeproj")}, "Wrong app source/trees")
    require(inputs["otzaria_test_additions_sha256"] == sha(additions), "Unbound exact additions manifest")
    require(inputs["hanlin_gitlink"] == "e00498e33f106cc43be0476ffa2e09329c8ca300", "Original Hanlin changed")


def exact_working_inputs(paths):
    records = {}
    for row in git("ls-tree", "-r", "-z", "HEAD", "--", *paths).split(b"\0"):
        if not row:
            continue
        meta, name = row.split(b"\t", 1)
        mode, kind, object_id = meta.decode().split()
        if kind != "blob":
            continue
        path = name.decode()
        p = ROOT / path
        data = os.readlink(p).encode() if mode == "120000" and p.is_symlink() else p.read_bytes()
        require(blob(data) == object_id, "Dirty tracked execution input: " + path)
        records[path] = {"blob": object_id, "bytes": len(data), "sha256": sha(data)}
    require(records, "Empty execution source closure")
    return records


def source_check(phase, expected, configuration):
    require_finalized(BINDING)
    context = github_context()
    validate_context(context, expected)
    require(configuration in CONFIGURATIONS, "Unknown configuration")
    config = CONFIGURATIONS[configuration]
    require(os.environ.get("RUNTIME27_CASE_MANIFEST") == config["manifest"], "Unbound runtime manifest argument")
    head = git("rev-parse", "HEAD").decode().strip()
    parents = git("show", "-s", "--format=%P", "HEAD").decode().split()
    trees = {path: git("rev-parse", "HEAD:" + path).decode().strip() for path in TREES}
    changed = git("diff", "--name-only", BASE, "HEAD").decode().splitlines()
    validate_identity(head, expected, context["ref"], parents, trees, changed)
    require((ROOT / ORIGINAL_MANIFEST).read_bytes() == git("show", BASE + ":" + ORIGINAL_MANIFEST), "Original Native116 catalog was edited")
    for name, value in CONFIGURATIONS.items():
        validate_manifest(read_json(value["manifest"]), frozen_json(ORIGINAL_MANIFEST), name)
    validate_pins(read_json(INPUTS), frozen_json(INPUTS), (ROOT / ADDITIONS).read_bytes(), git("show", BASE + ":" + ADDITIONS),
                  (ROOT / RUNTIME).read_bytes(), git("show", BASE + ":" + RUNTIME))
    require(sha((ROOT / "Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift").read_bytes()) == BINDING["r27_test_sha256"], "Pinned R27 source differs")
    require(sha((ROOT / "Maktabah-iOSUITests/NativeStudySheetAcceptanceTests.swift").read_bytes()) == BINDING["native_test_sha256"], "Pinned new Native tests differ")
    require(sha((ROOT / "Source/Features/Reader/iOS/NativeStudySheetPresenter.swift").read_bytes()) == BINDING["presenter_sha256"], "Pinned presenter differs")
    require("19d1b35397af4f10ae70cfb3f444c9de87383b53" in (ROOT / "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text(), "Original Kit pin changed")
    require(git("rev-parse", "HEAD:Maktabah.xcodeproj/project.pbxproj").decode().strip() == BINDING["project_blob"], "Pinned original project differs")
    records = exact_working_inputs(["Scripts/CI", ".github/workflows", "Maktabah-iOSUITests", "tools",
                                   "Tests/HQ/native-study-sheet", "docs/hq-integration/native-study-sheet-20261120", ORIGINAL_MANIFEST, DOCS,
                                   *[value["manifest"] for value in CONFIGURATIONS.values()]])
    if phase == "before":
        product = exact_working_inputs(list(TREES))
    else:
        build = read_json("build/hq-stage2/result.json")
        hq = runpy.run_path(str(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"))
        hq["verify_actual_sources"](build)
        native = build.get("native_context", {})
        require(sha((ROOT / "Maktabah.xcodeproj/project.pbxproj").read_bytes()) == native.get("generated_project_sha256"), "Generated original Pod integration project changed")
        require(sha((ROOT / "Maktabah.xcworkspace/contents.xcworkspacedata").read_bytes()) == native.get("workspace_sha256"), "Original workspace changed")
        hq["prepare_original_hanlin"](read_json(INPUTS), build, verify_only=True)
        product = {"original_helper_actual_source_count": build["actual_source_inputs_verified"],
                   "package_checkouts": build["actual_package_checkouts"], "generated_configuration": build.get("generated_configuration", [])}
        write(OUT / "original-post-ui-input-audit.json", build)
        before = read_json("build/artifacts/native-study-sheet-native/SOURCE_BEFORE.json")
        require(records == before["execution_inputs"], "CI/test/selection bytes changed across execution")
    return {"status": "SOURCE_BOUND_ONLY", "head": head, "application_and_tests": BASE, "context": context,
            "configuration": configuration, "manifest": config["manifest"], "phase": phase, "trees": trees,
            "changed_paths": changed, "execution_inputs": records, "product_inputs": product,
            "native_pass_credit": 0, "full_native116_acceptance": False, "full_release114_acceptance": False}


def raw_leaves(tree):
    case_id = runpy.run_path(str(ROOT / "tools/verify_xcresult_zero_skips.py"))["case_id"]
    leaves = []
    def visit(node, suite=None):
        if node.get("nodeType") == "Test Suite":
            suite = node["name"].split(".")[-1]
        if node.get("nodeType") == "Test Case":
            leaves.append((case_id(node.get("nodeIdentifier") or f"{suite}/{node['name']}"), node.get("result")))
        for child in node.get("children", []):
            visit(child, suite)
    for node in tree.get("testNodes", []):
        visit(node)
    return leaves


def validate_outcomes(ui, build, summary, leaves, expected, configuration):
    require(configuration in CONFIGURATIONS, "Unknown actual configuration")
    config = CONFIGURATIONS[configuration]
    selected = config["cases"]
    count = len(selected)
    require(ui.get("checkout_sha") == build.get("checkout_sha") == expected, "Outcome checkout mismatch")
    require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS", "No complete actual full-app/test build")
    require(build.get("application_source_sha") == BASE and build.get("application_trees") ==
            {k: TREES[k] for k in ("Source", "Vendor", "Maktabah.xcodeproj")}, "Build source mismatch")
    require(ui.get("status") == "SELECTED_UI_EXECUTED_PASS" and ui.get("mode") == "ui", "Selected execution did not pass")
    require(ui.get("full_release_acceptance") is False and ui.get("distribution") is False, "Invalid full/distribution credit")
    require(ui.get("test_source_commit") == BASE and ui.get("test_tree") == TREES["Maktabah-iOSUITests"], "Actual test source mismatch")
    require(ui.get("requested_ui_case_count") == ui.get("executed_ui_pass") == count, "Incomplete configuration execution")
    require(all(ui.get(key) == 0 for key in ("executed_ui_fail", "executed_ui_skip", "ui_not_run")), "Failed/skipped/unverified original case")
    expected_rows = Counter((case, configuration, config["label"], "Passed") for case in selected)
    actual_rows = Counter((row.get("case_id"), row.get("device"), row.get("configuration_label"), row.get("actual")) for row in ui.get("case_outcomes", []))
    require(actual_rows == expected_rows, "Wrong actual case/device/configuration or duplicate outcome")
    require(summary.get("passedTests") == count and all(summary.get(key) == 0 for key in ("failedTests", "skippedTests", "expectedFailures")), "Raw summary is not the exact ordinary passes")
    require(Counter(leaves) == Counter((case, "Passed") for case in selected), "Raw case leaves differ or duplicate")
    manifest = ROOT / config["manifest"]
    require(ui.get("case_manifest_sha256") == sha(manifest.read_bytes()), "Execution used a different selected scope")
    require(ui.get("helper_inputs_sha256", {}).get(RUNTIME) == sha((ROOT / RUNTIME).read_bytes()), "Execution used a different original runtime")


def qualify(expected, configuration, artifact_root=None):
    config = CONFIGURATIONS[configuration]
    build_root = ROOT / "build" if artifact_root is None else artifact_root
    def load(path):
        return json.loads((build_root / path).read_bytes())
    ui = load("artifacts/runtime27/result.json")
    build = load("hq-stage2/result.json")
    summary = load(f"artifacts/runtime27/verified-{config['label']}.summary.json")
    leaves = raw_leaves(load(f"artifacts/runtime27/verified-{config['label']}.tests.json"))
    validate_outcomes(ui, build, summary, leaves, expected, configuration)
    return {"status": "SELECTED_ADDITIVE_NATIVE_CASES_PASS", "head": expected, "application_and_tests": BASE,
            "configuration": configuration, "context": github_context(), "case_outcomes": ui["case_outcomes"],
            "selected_count": len(config["cases"]), "original_native_catalog_preserved": 116,
            "full_native116_acceptance": False, "full_release114_acceptance": False}


def validate_foundation(raw, result, expected, context):
    require(result.get("status") == "FOUNDATION25_PASS" and result.get("head") == expected
            and result.get("application_and_tests") == BASE and result.get("context") == context,
            "Missing exact actual Foundation result")
    require(result.get("driver_exit") == 0 and type(result.get("driver_exit")) is int,
            "Missing ordinary successful actual Foundation driver exit")
    require(result.get("before") == result.get("after") and result.get("before"), "Foundation source changed")
    require(result.get("before_product") == result.get("after_product") and result.get("before_product"),
            "Foundation product source changed or observation missing")
    require(raw.get("qualified") is True and raw.get("before") == raw.get("after") and raw.get("before"),
            "Raw Foundation source/outcome incomplete")
    expected_inputs = {}
    for path, entry in BINDING["foundation_inputs"].items():
        data = (ROOT / path).read_bytes()
        require(blob(data) == entry["git_blob"] and sha(data) == entry["sha256"],
                "Foundation source does not equal reviewed Git input: " + path)
        observed = result["before"].get(path, result["before_product"].get(path))
        require(observed == {"blob": entry["git_blob"], "bytes": entry["bytes"], "sha256": entry["sha256"]},
                "Foundation producer did not bind actual source: " + path)
        if path == "tools/hq-native-study-sheet-lifecycle.py":
            continue
        key = "before_workspace" if path.endswith("/interactive-dismissal-before.swift") else path
        expected_inputs[key] = entry["sha256"]
    require(raw["before"] == expected_inputs, "Raw Foundation inputs differ from exact reviewed source")
    driver = runpy.run_path(str(ROOT / "tools/hq-native-study-sheet-lifecycle.py"))
    stages = raw.get("stages", [])
    require([stage.get("phase") for stage in stages] == ["baseline", "candidate", "lifecycle"],
            "Missing original baseline/candidate/lifecycle stages")
    for stage, fixture, failed in zip(stages,
            ["NativeStudySheetOwnerAcceptance.swift", "NativeStudySheetOwnerAcceptance.swift", "NativeStudySheetLifecycleAcceptance.swift"],
            [driver["EXPECTED_RED"], set(), set()]):
        declared = driver["case_ids"]((ROOT / driver["FIXTURES"] / fixture).read_text())
        require(stage.get("declared") == declared and stage.get("expected_failures") == sorted(failed), "Wrong exact Swift case oracle")
        require(type(stage.get("compile", {}).get("returncode")) is int and stage["compile"]["returncode"] == 0
                and stage.get("compile", {}).get("timeout") is False,
                "Swift compile/setup failure is zero controls")
        require(type(stage.get("runtime", {}).get("returncode")) is int
                and stage.get("runtime", {}).get("timeout") is False, "Invalid ordinary runtime completion")
        require(stage.get("qualified") is True and stage.get("executed") == len(declared)
                and driver["qualify"](stage.get("checks"), declared, stage.get("runtime", {}), failed),
                "Unqualified or partial actual Swift controls")
    require(sum(stage["executed"] for stage in stages[1:]) == 25, "Missing candidate Foundation25")
    return 25


def foundation(expected):
    import signal
    report = {"status": "FAIL", "head": expected, "application_and_tests": BASE,
              "context": github_context(), "Foundation_controls_passed": 0, "native_pass_credit": 0}
    try:
        require_finalized(BINDING)
        require(sys.platform == "darwin", "Foundation execution requires actual Apple toolchain")
        # Same original cold source check before Pod integration: no fake build
        # result and no Native outcome is created by these two observations.
        before = source_check("before", expected, "ipad11")
        report.update(before=before["execution_inputs"], before_product=before["product_inputs"])
        output = ROOT / "build/native-study-sheet-foundation"
        require(not output.exists(), "Refuse reused Foundation output")
        command = [sys.executable, "tools/hq-native-study-sheet-lifecycle.py", "--root", str(ROOT),
                   "--output", str(output), "--before-workspace",
                   "docs/hq-integration/native-study-sheet-20261120/interactive-dismissal-before.swift"]
        OUT.mkdir(parents=True, exist_ok=True)
        with (OUT / "foundation-driver.log").open("wb") as log:
            process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = process.wait(timeout=660)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=10)
                raise RuntimeError("Owned Foundation process group exceeded finite 660s; no Swift credit")
        report["driver_exit"] = code
        after = source_check("before", expected, "ipad11")
        report.update(before=before["execution_inputs"], after=after["execution_inputs"],
                      before_product=before["product_inputs"], after_product=after["product_inputs"])
        require(report["before_product"] == report["after_product"], "Product source changed across Foundation execution")
        require(code == 0, "Actual Foundation driver did not qualify; raw failures retained")
        raw = json.loads((output / "RESULT.json").read_bytes())
        report["status"] = "FOUNDATION25_PASS"
        report["Foundation_controls_passed"] = validate_foundation(raw, report, expected, github_context())
        return 0
    except Exception as error:
        report["status"] = "FAIL"
        report["qualification_error"] = str(error)
        return 1
    finally:
        write(OUT / "FOUNDATION.json", report)


def require_downloaded_foundation(evidence_root, expected, context):
    directory = evidence_root / "native-study-sheet-foundation-evidence"
    result = json.loads((directory / "artifacts/native-study-sheet-native/FOUNDATION.json").read_bytes())
    raw = json.loads((directory / "native-study-sheet-foundation/RESULT.json").read_bytes())
    return validate_foundation(raw, result, expected, context)


def validate_aggregate(records, expected, context, matrix_result):
    validate_context(context, expected)
    require(matrix_result == "success", "At least one actual matrix job failed or did not complete")
    require(set(records) == set(CONFIGURATIONS), "Missing or extra configuration evidence")
    actual = []
    for configuration, config in CONFIGURATIONS.items():
        record = records[configuration]
        result, before, after = record["result"], record["before"], record["after"]
        require(result.get("status") == "SELECTED_ADDITIVE_NATIVE_CASES_PASS" and result.get("selected_count") == len(config["cases"]), "Partial configuration result")
        for item in (result, before, after):
            require(item.get("head") == expected and item.get("application_and_tests") == BASE
                    and item.get("context") == context and item.get("configuration") == configuration, "Cross-run/attempt/head/configuration evidence")
            require(item.get("full_native116_acceptance") is False and item.get("full_release114_acceptance") is False, "Invalid full acceptance credit")
        require(before.get("phase") == "before" and after.get("phase") == "after"
                and before.get("status") == after.get("status") == "SOURCE_BOUND_ONLY", "Missing complete source observations")
        require(before.get("trees") == after.get("trees") == TREES
                and before.get("execution_inputs") == after.get("execution_inputs") and before.get("execution_inputs"), "Configuration source changed")
        require(before.get("manifest") == after.get("manifest") == config["manifest"], "Wrong frozen per-device manifest")
        rows = result.get("case_outcomes", [])
        require(Counter((r.get("case_id"), r.get("device"), r.get("configuration_label"), r.get("actual")) for r in rows)
                == Counter((case, configuration, config["label"], "Passed") for case in config["cases"]), "Aggregate duplicated or misplaced actual case")
        actual.extend(rows)
    require(len(actual) == 12, "Expected exactly eleven iPad plus one phone actual executions")
    return actual


def aggregate(expected, evidence_root):
    require_finalized(BINDING)
    context = github_context()
    validate_context(context, expected)
    require(git("rev-parse", "HEAD").decode().strip() == expected, "Aggregate checked out wrong source")
    records = {}
    errors = []
    observed_runtime_reports = {}
    for configuration in CONFIGURATIONS:
        directory = evidence_root / ("native-study-sheet-native-evidence-" + configuration)
        prefix = directory / "artifacts/native-study-sheet-native"
        try:
            raw = json.loads((directory / "artifacts/runtime27/result.json").read_bytes())
            observed_runtime_reports[configuration] = {
                "qualification": "UNQUALIFIED_RAW_OBSERVATION",
                "observed": {key: raw.get(key) for key in (
                    "status", "checkout_sha", "test_source_commit", "test_tree", "requested_ui_case_count",
                    "executed_ui_pass", "executed_ui_fail", "executed_ui_skip", "ui_not_run", "case_outcomes")},
            }
            records[configuration] = {name: json.loads((prefix / filename).read_bytes()) for name, filename in
                                      (("result", "RESULT_AFTER.json"), ("before", "SOURCE_BEFORE.json"), ("after", "SOURCE_AFTER.json"))}
            # Replay actual raw xcresult leaves/summary and build identity from each
            # separately downloaded current-run artifact, not just its PASS label.
            qualify(expected, configuration, directory)
        except Exception as error:
            errors.append({"configuration": configuration, "error": str(error)})
    report = {"status": "FAIL", "head": expected, "application_and_tests": BASE, "context": context,
              "records": records, "errors": errors, "observed_runtime_reports": observed_runtime_reports,
              "requested_case_executions": 12,
              "full_native116_acceptance": False, "full_release114_acceptance": False}
    try:
        require(not errors, "Incomplete or invalid configuration evidence")
        require(os.environ.get("FOUNDATION_JOB_RESULT") == "success", "Actual Foundation job did not complete successfully")
        foundation_passed = require_downloaded_foundation(evidence_root, expected, context)
        outcomes = validate_aggregate(records, expected, context, os.environ.get("MATRIX_JOB_RESULT"))
        report.update(status="TWELVE_ADDITIVE_NATIVE_AND_FOUNDATION25_PASS", case_outcomes=outcomes,
                      executed_pass=12, executed_fail=0, executed_skip=0, not_run=0, Foundation_controls_passed=foundation_passed,
                      scope="Twelve new methods: ipad11=11 and iphone=1, plus actual Foundation25; not final116/114 acceptance.")
        return 0
    except Exception as error:
        report["qualification_error"] = str(error)
        return 1
    finally:
        write(OUT / "AGGREGATE.json", report)
        print(json.dumps({key: report.get(key) for key in ("status", "head", "requested_case_executions", "qualification_error")}, indent=2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=("before", "after", "aggregate", "foundation"))
    parser.add_argument("--configuration", choices=CONFIGURATIONS)
    parser.add_argument("--evidence-root", type=Path)
    args = parser.parse_args()
    expected = os.environ.get("EXPECTED_CHECKOUT_SHA", "")
    if args.phase == "foundation":
        require(args.configuration is None and args.evidence_root is None, "Foundation takes no Native result arguments")
        return foundation(expected)
    if args.phase == "aggregate":
        require(args.evidence_root is not None and args.configuration is None, "Aggregate requires only evidence root")
        return aggregate(expected, args.evidence_root)
    require(args.configuration in CONFIGURATIONS, "Missing exact configuration")
    report = {"status": "FAIL", "phase": args.phase, "head": expected, "application_and_tests": BASE,
              "configuration": args.configuration, "context": github_context(),
              "selected_count": len(CONFIGURATIONS[args.configuration]["cases"]),
              "full_native116_acceptance": False, "full_release114_acceptance": False}
    try:
        source = source_check(args.phase, expected, args.configuration)
        write(OUT / ("SOURCE_" + args.phase.upper() + ".json"), source)
        if args.phase == "after":
            report.update(qualify(expected, args.configuration))
        else:
            report.update(status="SOURCE_PREFLIGHT_PASS", native_pass_credit=0)
        return 0
    except Exception as error:
        report["error"] = str(error)
        print(type(error).__name__ + ": " + str(error), file=sys.stderr)
        return 1
    finally:
        write(OUT / ("RESULT_" + args.phase.upper() + ".json"), report)
        print(json.dumps({key: report.get(key) for key in ("status", "phase", "head", "configuration", "selected_count", "error")}, indent=2))


if __name__ == "__main__":
    raise SystemExit(main())
