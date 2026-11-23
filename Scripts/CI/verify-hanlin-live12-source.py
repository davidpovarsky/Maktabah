#!/usr/bin/env python3
"""Read-only Live12 source admission. No credential, provider, build or test run."""
import ast
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "fdb78a44778c318b277506f0b09ba91c3b678e91"
APPLICATION = "d4b1825bd5645f4949e4b57e48a73022c3b7cba1"
LIVE10 = "9533a8017adadecf770b19811e72b495f32e90f7"
NO_SEND = "6591bba49d2b5a28d02b763c4360406843fce4cf"
SDK = "e00498e33f106cc43be0476ffa2e09329c8ca300"
SESSION = "Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift"
DRIVER = "Scripts/CI/runtime27-hanlin-live.py"
INPUTS = "Scripts/CI/hq-stage2-focused-apple.inputs.json"
WORKFLOW = ".github/workflows/otzaria-hanlin-live-native.yml"
GUARD = "Scripts/CI/verify-hanlin-live12-source.py"
PACKET = "docs/hq-integration/hanlin-live12-20261123/"
DIAGNOSTIC_PACKET = "docs/hq-integration/hanlin-live11-diagnosis-20261123/"
ADMISSION = PACKET + "LIVE12_SOURCE_ADMISSION.json"
EXECUTION_INPUTS = PACKET + "LIVE12_EXECUTION_INPUTS.json"
DIAGNOSTIC_FILES = {
    DIAGNOSTIC_PACKET + name for name in (
        "CONTROL.stderr.log", "CONTROL.stdout.log", "CONTROL_RESULT.json",
        "DIAGNOSTIC_ONLY.patch", "DIAGNOSTIC_SOURCE_DELTA.json", "README.md",
        "SOURCE_PROVENANCE.json", "SWIFT_SYNTAX_PARSE.json", "diagnostic_controls.py")
}
NEW_DOCUMENTS = {
    PACKET + name for name in (
        "README.md", "LIVE12_SOURCE_ADMISSION.json", "LIVE12_EXECUTION_INPUTS.json",
        "WORKFLOW_ONLY.patch", "REVIEWED_DIAGNOSTIC_REUSE.json")
}
SNAPSHOT_ROOTS = [
    "Scripts/CI", "Scripts/verify-otzaria-mini-parity.py", ".github/workflows",
    "tools", "Maktabah-iOSUITests", "docs/hq-integration/runtime27/R27_CASES.json"
]
APPLICATION_TREES = ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]
TABLE_NAMES = {"CONNECTION_DIAGNOSTIC_STAGES", "CONNECTION_DIAGNOSTIC_REASONS", "CONNECTION_DIAGNOSTIC_FLAGS"}


def require(value, message):
    if not value:
        raise ValueError(message)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, timeout=60)


def blob(revision, path):
    return git("show", revision + ":" + path)


def tree(revision, path):
    return git("rev-parse", revision + ":" + path).decode().strip()


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def blob_hash(raw):
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def changed(before, after):
    return set(git("diff", "--name-only", before, after).decode().splitlines())


def declarations(source, names):
    values = {}
    for node in ast.parse(source).body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            if node.targets[0].id in names:
                values[node.targets[0].id] = node.value
    require(set(values) == set(names), "Missing or ambiguous source constants")
    return values


def constants(source):
    return {name: ast.literal_eval(value) for name, value in declarations(
        source, {"MODEL", "REVIEWED_SOURCE", "SELECTOR", "ENDPOINT"}).items()}


def diagnostic_tables(source):
    return {name: ast.dump(value, include_attributes=False)
            for name, value in declarations(source, TABLE_NAMES).items()}


def functional_driver(source):
    parsed = ast.parse(source)
    parsed.body = [node for node in parsed.body if not (
        isinstance(node, ast.Assign) and len(node.targets) == 1
        and isinstance(node.targets[0], ast.Name)
        and node.targets[0].id in TABLE_NAMES | {"REVIEWED_SOURCE"})]
    return ast.dump(parsed, include_attributes=False)


def snapshot_roots(source):
    function = next(node for node in ast.parse(source).body
                    if isinstance(node, ast.FunctionDef) and node.name == "source_context")
    assignments = [node for node in function.body if isinstance(node, ast.Assign)
                   and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name)
                   and node.targets[0].id == "paths"]
    require(len(assignments) == 1, "Original source snapshot root declaration changed")
    return ast.literal_eval(assignments[0].value)


def original_workflow_delta():
    before = blob(APPLICATION, WORKFLOW)
    old = (b"      - name: Verify the immutable Live11 diagnostic source boundary\n"
           b"        run: python3 Scripts/CI/verify-hanlin-live11-source.py\n")
    new = (b"      - name: Verify the immutable Live12 diagnostic source boundary\n"
           b"        run: python3 Scripts/CI/verify-hanlin-live12-source.py\n")
    require(before.count(old) == 1, "Original Live11 source-admission step differs")
    return before.replace(old, new, 1)


def clean_file(path):
    actual = (ROOT / path).read_bytes()
    require(actual == blob("HEAD", path), "Dirty source input: " + path)
    return actual


def verify():
    head = git("rev-parse", "HEAD").decode().strip()
    expected = os.environ.get("EXPECTED_CHECKOUT_SHA")
    require(expected is None or expected == head, "Wrong immutable workflow checkout")
    raw = clean_file(ADMISSION)
    contract = json.loads(raw)
    require(contract["schema_version"] == 1 and contract["repository"] == "davidpovarsky/Maktabah"
            and contract["branch"] == "codex/otzaria-hanlin-live12-20261123",
            "Wrong owned repository/branch contract")
    require(contract["baseline_live11_source"] == BASELINE
            and contract["application_source_sha"] == APPLICATION
            and contract["diagnostic_commit"] == APPLICATION
            and contract["hanlin_gitlink"] == SDK, "Wrong immutable source lineage")
    for revision in (BASELINE, APPLICATION, LIVE10, NO_SEND):
        require(git("rev-parse", revision + "^{commit}").decode().strip() == revision, "Source revision is not exact")
    for path in APPLICATION_TREES:
        require(tree(NO_SEND, path) == tree(LIVE10, path), "Accepted historical no-send lineage differs: " + path)
        require(tree("HEAD", path) == tree(APPLICATION, path) == contract["application_trees"][path],
                "Candidate application/test tree differs: " + path)
    for path in APPLICATION_TREES[1:]:
        require(tree("HEAD", path) == tree(BASELINE, path) == tree(NO_SEND, path),
                "Original vendor/project/UI-test tree changed: " + path)
    require(tree("HEAD", "Vendor/HanlinSDK") == SDK, "Original Hanlin gitlink changed")
    require(tree("HEAD", "Source") != tree(NO_SEND, "Source"),
            "Do not equate diagnostic application source with historical no-send")
    require(git("diff", "--name-only", BASELINE, APPLICATION, "--", "Source").decode().splitlines() == [SESSION],
            "Reviewed application delta is not the one diagnostic session")
    require(git("diff", "--name-only", NO_SEND, APPLICATION, "--", "Source").decode().splitlines() == [SESSION],
            "Historical application delta includes unreviewed functional files")
    git("diff", "--exit-code", "HEAD", "--", *APPLICATION_TREES)
    require(clean_file(SESSION) == blob(APPLICATION, SESSION), "Reviewed d4 diagnostic application bytes changed")
    require(sha(clean_file(SESSION)) == contract["session_sha256"], "Session source digest differs")
    require(changed(BASELINE, APPLICATION) == {SESSION, DRIVER} | DIAGNOSTIC_FILES,
            "Reviewed diagnostic commit contains unexpected files")
    for path in DIAGNOSTIC_FILES:
        require(clean_file(path) == blob(APPLICATION, path), "Inherited diagnostic evidence changed: " + path)

    # The reviewed five controls are preserved as historical source/schema evidence.
    # They are not rerun here and are not provider/native acceptance.
    reused = json.loads(clean_file(DIAGNOSTIC_PACKET + "CONTROL_RESULT.json"))
    require(reused["status"] == "PASS_SOURCE_AND_SCHEMA_CONTROLS"
            and reused["controls_run"] == 5 and reused["failures"] == 0 and reused["errors"] == 0
            and reused["native_or_host_runtime_qualified"] is False and reused["provider_called"] is False,
            "Reviewed diagnostic controls are not the accepted source-only result")
    inverse = json.loads(clean_file(DIAGNOSTIC_PACKET + "DIAGNOSTIC_SOURCE_DELTA.json"))
    require(inverse["base"] == BASELINE and {row["path"] for row in inverse["files"]} == {SESSION, DRIVER},
            "Diagnostic inverse boundary differs")
    for row in inverse["files"]:
        restored = blob(APPLICATION, row["path"]).decode()
        for replacement in reversed(row["replacements"]):
            require(restored.count(replacement["after"]) == 1, "Diagnostic inverse is ambiguous")
            restored = restored.replace(replacement["after"], replacement["before"], 1)
        require(restored.encode() == blob(BASELINE, row["path"]), "Diagnostic inverse does not restore Live11 source")

    current_driver = clean_file(DRIVER)
    original_driver = blob(APPLICATION, DRIVER)
    original_constant = ('REVIEWED_SOURCE = "' + constants(original_driver)["REVIEWED_SOURCE"] + '"').encode()
    candidate_constant = ('REVIEWED_SOURCE = "' + APPLICATION + '"').encode()
    require(original_driver.count(original_constant) == 1, "Reviewed source assignment is ambiguous")
    require(current_driver == original_driver.replace(original_constant, candidate_constant, 1),
            "Driver delta is not the exact application-source rebind")
    require(sha(current_driver) == contract["driver_sha256"], "Driver digest differs")
    require(diagnostic_tables(current_driver) == diagnostic_tables(original_driver),
            "Reviewed finite diagnostic enum sets changed")
    require(functional_driver(current_driver) == functional_driver(blob(BASELINE, DRIVER))
            == functional_driver(blob(LIVE10, DRIVER)), "Original functional driver changed")
    require(constants(current_driver) == {
        "MODEL": "gemini-3.5-flash-lite", "REVIEWED_SOURCE": APPLICATION,
        "SELECTOR": "HanlinLiveProviderAcceptanceTests/testOriginalLiveProviderUsesCanonicalCoreAndRevokesReadConsent",
        "ENDPOINT": "https://generativelanguage.googleapis.com/v1beta/openai/"
    }, "Original model/selector/endpoint or application binding changed")
    require(snapshot_roots(current_driver) == SNAPSHOT_ROOTS, "Original actual source snapshot closure changed")

    old_inputs = json.loads(blob(APPLICATION, INPUTS))
    expected_inputs = dict(old_inputs)
    expected_inputs["application_source_sha"] = APPLICATION
    expected_inputs["application_trees"] = {path: tree(APPLICATION, path) for path in old_inputs["application_trees"]}
    input_raw = clean_file(INPUTS)
    require(json.loads(input_raw) == expected_inputs, "Build inputs changed beyond the application-source/tree rebind")
    require(sha(input_raw) == contract["inputs_sha256"], "Build-input digest differs")
    workflow = clean_file(WORKFLOW)
    require(workflow == original_workflow_delta(), "Workflow is not the exact Live11-to-Live12 source-admission step")
    require(b"on:\n  workflow_dispatch:\n" in workflow and b"\n  push:" not in workflow,
            "Live12 must remain manual-only")
    require(sha(workflow) == contract["workflow_sha256"], "Workflow digest differs")
    require(sha(clean_file(GUARD)) == contract["source_guard_sha256"], "Source guard digest differs")

    delta = changed(APPLICATION, "HEAD")
    require(delta == {DRIVER, INPUTS, GUARD, WORKFLOW} | NEW_DOCUMENTS,
            "Unexpected Live12 source/preflight path")
    all_delta = changed(BASELINE, "HEAD")
    require(all_delta == {SESSION, DRIVER, INPUTS, GUARD, WORKFLOW} | DIAGNOSTIC_FILES | NEW_DOCUMENTS,
            "Unexpected full delta from actual failed Live11")

    # Verify the exact inputs that the original runtime source_context() will
    # independently hash again around the real app/test execution.
    inventory_raw = clean_file(EXECUTION_INPUTS)
    require(sha(inventory_raw) == contract["execution_inputs_sha256"], "Execution-input inventory digest differs")
    inventory = json.loads(inventory_raw)
    require(inventory["roots"] == SNAPSHOT_ROOTS and inventory["application_source_sha"] == APPLICATION,
            "Execution-input inventory has a different source scope")
    declared = inventory["files"]
    require(type(declared) is dict, "Malformed execution-input inventory")
    actual = {}
    rows = git("ls-tree", "-r", "-z", "HEAD", "--", *SNAPSHOT_ROOTS)
    for row in rows.split(b"\0"):
        if not row:
            continue
        meta, name = row.split(b"\t", 1)
        mode, kind, expected_blob = meta.decode().split()
        require(kind == "blob", "Unexpected execution closure object kind")
        path = name.decode()
        target = ROOT / path
        content = os.readlink(target).encode() if mode == "120000" and target.is_symlink() else target.read_bytes()
        require(blob_hash(content) == expected_blob, "Dirty actual execution input: " + path)
        actual[path] = {"mode": mode, "blob": expected_blob, "bytes": len(content), "sha256": sha(content)}
    require(actual == declared and all(path in actual for path in (GUARD, DRIVER, INPUTS, WORKFLOW)),
            "Actual execution source snapshot inputs differ")
    historical = contract["historical_no_send"]
    require(historical["run_id"] == 45041601629 and historical["source"] == NO_SEND
            and historical["reexecuted"] is False and historical["current_full_source_tree_equal"] is False,
            "Historical no-send evidence boundary changed")
    require(contract["previous_live11"]["run_id"] == 45103578190
            and contract["previous_live11"]["source"] == BASELINE
            and contract["previous_live11"]["native_result"] == "FAIL",
            "Actual failed Live11 outcome was changed")
    require(contract["live12_native_result"] == "NOT_RUN"
            and contract["provider_called_by_preparation"] is False
            and contract["credential_accessed_by_preparation"] is False,
            "Preparation cannot claim live acceptance")
    return {
        "status": "SOURCE_ADMISSION_PASS", "checkout_sha": head,
        "application_source_sha": APPLICATION, "source_admission_sha256": sha(raw),
        "source_admission_git_blob": tree("HEAD", ADMISSION),
        "workflow_sha256": sha(workflow), "workflow_git_blob": tree("HEAD", WORKFLOW),
        "execution_input_count": len(actual), "execution_inputs_sha256": sha(inventory_raw),
        "full_changed_paths": sorted(all_delta), "functional_changed_paths": sorted({SESSION, DRIVER, INPUTS, GUARD, WORKFLOW}),
        "inherited_diagnostic_documents_verified": len(DIAGNOSTIC_FILES),
        "reviewed_diagnostic_controls_reused": 5, "reviewed_diagnostic_controls_reexecuted": False,
        "historical_no_send_run": 45041601629, "historical_no_send_reexecuted": False,
        "current_source_tree_matches_historical_no_send": False,
        "previous_live11_native_result": "FAIL", "live12_native_result": "NOT_RUN_BY_THIS_CHECK",
        "completion_succeeded_alone_is_host_receipt": False,
        "manual_workflow_only": True, "provider_called": False, "credential_accessed": False,
    }


if __name__ == "__main__":
    print(json.dumps(verify(), sort_keys=True, indent=2))
