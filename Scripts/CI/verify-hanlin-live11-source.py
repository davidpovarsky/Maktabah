#!/usr/bin/env python3
"""Read-only Live11 source admission. No provider, credential, build, or test execution."""
import ast
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
ADMISSION = "docs/hq-integration/hanlin-live11-20261123/LIVE11_SOURCE_ADMISSION.json"

def require(value, message):
    if not value:
        raise ValueError(message)

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, timeout=60)

def blob(revision, path):
    return git("show", revision + ":" + path)

def tree(revision, path):
    return git("rev-parse", revision + ":" + path).decode().strip()

def literals(source, names=None):
    if names is None:
        names = {"MODEL", "REVIEWED_SOURCE", "SELECTOR", "ENDPOINT"}
    result = {}
    for node in ast.parse(source).body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            if node.targets[0].id in names:
                result[node.targets[0].id] = ast.literal_eval(node.value)
    return result

def normalize_driver(source):
    allowed = {"REVIEWED_SOURCE", "CONNECTION_DIAGNOSTIC_STAGES", "CONNECTION_DIAGNOSTIC_REASONS", "CONNECTION_DIAGNOSTIC_FLAGS"}
    parsed = ast.parse(source)
    parsed.body = [node for node in parsed.body if not (
        isinstance(node, ast.Assign) and len(node.targets) == 1
        and isinstance(node.targets[0], ast.Name) and node.targets[0].id in allowed)]
    return ast.dump(parsed, include_attributes=False)

def verify():
    raw = (ROOT / ADMISSION).read_bytes()
    require(raw == blob("HEAD", ADMISSION), "Dirty source admission")
    contract = json.loads(raw)
    baseline = contract["baseline_live10_source"]
    accepted = contract["historical_no_send"]["source"]
    app = contract["application_source_sha"]
    diagnostic = contract["diagnostic_commit"]
    session = contract["session_path"]
    driver = contract["driver_path"]
    inputs_path = contract["inputs_path"]
    workflow = contract["workflow_path"]
    paths = ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]
    for path in paths:
        require(tree(accepted, path) == tree(baseline, path), "Original no-send/Live10 lineage mismatch: " + path)
        require(tree("HEAD", path) == tree(app, path), "Current application/test tree differs from the pinned candidate: " + path)
        require(tree("HEAD", path) == contract["application_trees"][path], "Recorded tree mismatch: " + path)
    require(tree(app, "Source") != tree(accepted, "Source"), "Do not falsely claim unchanged full Source tree")
    require(git("diff", "--name-only", baseline, app, "--", "Source").decode().splitlines() == [session],
            "Application delta extends beyond the reviewed diagnostic")
    for path in paths[1:]:
        require(tree(app, path) == tree(baseline, path), "Untouched original product tree changed: " + path)
    require(blob(app, session) == blob(diagnostic, session), "Session differs from the reviewed diagnostic")
    require(blob(baseline, session) == blob(contract["diagnostic_parent"], session), "Diagnostic preimage differs")
    for path in [session, driver, inputs_path, workflow, "Scripts/CI/verify-hanlin-live11-source.py"]:
        require((ROOT / path).read_bytes() == blob("HEAD", path), "Dirty reviewed input: " + path)
    require(hashlib.sha256((ROOT / session).read_bytes()).hexdigest() == contract["session_sha256"], "Session hash differs")
    require(hashlib.sha256((ROOT / inputs_path).read_bytes()).hexdigest() == contract["inputs_sha256"], "Build input hash differs")
    current_driver = (ROOT / driver).read_bytes()
    require(hashlib.sha256(current_driver).hexdigest() == contract["driver_sha256"], "Driver hash differs")
    diagnostic_names = {"CONNECTION_DIAGNOSTIC_STAGES", "CONNECTION_DIAGNOSTIC_REASONS", "CONNECTION_DIAGNOSTIC_FLAGS"}
    require(literals(current_driver, diagnostic_names) == literals(blob(diagnostic, driver), diagnostic_names), "Diagnostic enum tables differ from review")
    require(normalize_driver(current_driver) == normalize_driver(blob(baseline, driver)), "Original live driver behavior changed")
    require(literals(current_driver) == {
        "MODEL": contract["model"], "REVIEWED_SOURCE": app,
        "SELECTOR": contract["selector"], "ENDPOINT": contract["endpoint"]
    }, "Live source/model/selector binding differs")
    old_inputs = json.loads(blob(baseline, inputs_path))
    expected_inputs = dict(old_inputs)
    expected_inputs["application_source_sha"] = app
    expected_inputs["application_trees"] = {path: contract["application_trees"][path]
                                           for path in old_inputs["application_trees"]}
    require(json.loads((ROOT / inputs_path).read_bytes()) == expected_inputs, "Unrelated build input changed")
    prior_workflow = blob(baseline, workflow).decode()
    expected_workflow = prior_workflow.replace(
        "  push:\n    branches: [codex/otzaria-hanlin-live-20261121]\n", "", 1)
    expected_workflow = expected_workflow.replace(
        "      - name: Require the reviewed existing credential configuration\n",
        "      - name: Verify the immutable Live11 diagnostic source boundary\n"
        "        run: python3 Scripts/CI/verify-hanlin-live11-source.py\n"
        "      - name: Require the reviewed existing credential configuration\n", 1)
    current_workflow = (ROOT / workflow).read_bytes()
    require(current_workflow == expected_workflow.encode(), "Workflow differs from the exact manual-only continuation")
    require(hashlib.sha256(current_workflow).hexdigest() == contract["workflow_sha256"], "Workflow hash differs")
    changed = set(git("diff", "--name-only", baseline, "HEAD").decode().splitlines())
    functional = {path for path in changed if not path.startswith("docs/hq-integration/hanlin-live11-20261123/")}
    require(functional == {session, driver, inputs_path, workflow, "Scripts/CI/verify-hanlin-live11-source.py"},
            "Unexpected functional change")
    return {
        "status": "SOURCE_ADMISSION_PASS",
        "checkout_sha": git("rev-parse", "HEAD").decode().strip(),
        "application_source_sha": app,
        "source_admission_sha256": hashlib.sha256(raw).hexdigest(),
        "historical_no_send_run": contract["historical_no_send"]["run_id"],
        "historical_product_trees_match_live10": True,
        "current_source_tree_matches_historical": False,
        "current_delta": "Reviewed diagnostic-only session changes; original assertions, authority and provider behavior retained",
        "native_no_send_reexecuted": False,
        "native_live11_result": "NOT_RUN_BY_THIS_CHECK",
        "provider_called": False,
        "credential_accessed": False,
    }

if __name__ == "__main__":
    print(json.dumps(verify(), sort_keys=True, indent=2))
