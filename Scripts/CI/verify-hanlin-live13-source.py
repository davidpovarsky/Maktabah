#!/usr/bin/env python3
"""Read-only admission for one original live case on the reviewed cold-search repair."""
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "9bee6104e2938767b4e4e1047c56da8991d621fb"
APPLICATION = "869f6a5a5eedbc94484467fe1c92f2802f497cda"
SDK = "e00498e33f106cc43be0476ffa2e09329c8ca300"
DRIVER = "Scripts/CI/runtime27-hanlin-live.py"
INPUTS = "Scripts/CI/hq-stage2-focused-apple.inputs.json"
WORKFLOW = ".github/workflows/otzaria-hanlin-live-native.yml"
GUARD = "Scripts/CI/verify-hanlin-live13-source.py"
OLD_GUARD = "Scripts/CI/verify-hanlin-live12-source.py"
SESSION = "Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift"
PACKET = "docs/hq-integration/hanlin-live13-20261123/"
COLD = "docs/hq-integration/hanlin-cold-search-20261123/"
ADMISSION = PACKET + "LIVE13_SOURCE_ADMISSION.json"
EXECUTION_INPUTS = PACKET + "LIVE13_EXECUTION_INPUTS.json"
SNAPSHOT_ROOTS = [
    "Scripts/CI", "Scripts/verify-otzaria-mini-parity.py", ".github/workflows",
    "tools", "Maktabah-iOSUITests", "docs/hq-integration/runtime27/R27_CASES.json"
]
APPLICATION_TREES = ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]
COLD_DOCUMENTS = {COLD + name for name in (
    "COLD_SEARCH_PEER_REVIEW.json", "CORE_CONTROLS_RESULT.json",
    "CORE_CONTROLS_swift-test.stderr", "CORE_CONTROLS_swift-test.stdout",
    "IMPLEMENTATION_SCOPE.md", "PRODUCT_DIFF.patch", "README.md",
    "SOURCE_CORRESPONDENCE.json", "SWIFT_SYNTAX_PARSE.json")}
NEW_DOCUMENTS = {PACKET + name for name in (
    "README.md", "LIVE13_SOURCE_ADMISSION.json", "LIVE13_EXECUTION_INPUTS.json",
    "WORKFLOW_ONLY.patch", "LIVE12_INTAKE.json", "live13-controller.py",
    "test-live13-controller-identity.py", "CONTROLLER_SOURCE_REVIEW.json",
    "CONTROLLER_IDENTITY.stdout.log", "CONTROLLER_IDENTITY.stderr.log")}


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


def clean_file(path):
    raw = (ROOT / path).read_bytes()
    require(raw == blob("HEAD", path), "Dirty source input: " + path)
    return raw


def verify():
    head = git("rev-parse", "HEAD").decode().strip()
    require(os.environ.get("EXPECTED_CHECKOUT_SHA", head) == head, "Wrong immutable checkout")
    require(os.environ.get("GITHUB_REPOSITORY", "davidpovarsky/Maktabah") == "davidpovarsky/Maktabah",
            "Wrong repository")
    require(os.environ.get("GITHUB_REF", "refs/heads/codex/otzaria-hanlin-live13-20261123") ==
            "refs/heads/codex/otzaria-hanlin-live13-20261123", "Wrong owned live branch")
    raw = clean_file(ADMISSION)
    contract = json.loads(raw)
    require(contract["schema_version"] == 1 and contract["repository"] == "davidpovarsky/Maktabah"
            and contract["branch"] == "codex/otzaria-hanlin-live13-20261123",
            "Wrong source admission")
    require(contract["baseline_live12_source"] == BASELINE
            and contract["application_source_sha"] == APPLICATION
            and contract["hanlin_gitlink"] == SDK, "Wrong immutable source lineage")
    for revision in (BASELINE, APPLICATION):
        require(git("rev-parse", revision + "^{commit}").decode().strip() == revision,
                "Source revision is not exact")
    require(git("rev-parse", APPLICATION + "^").decode().strip() == BASELINE,
            "Repair is not based on the actual failed source")
    for path in APPLICATION_TREES:
        require(tree("HEAD", path) == tree(APPLICATION, path) == contract["application_trees"][path],
                "Application/test tree differs: " + path)
    for path in APPLICATION_TREES[1:]:
        require(tree("HEAD", path) == tree(BASELINE, path), "Original vendor/project/UI tests changed")
    require(tree("HEAD", "Vendor/HanlinSDK") == SDK, "Pinned original SDK changed")
    git("diff", "--exit-code", "HEAD", "--", *APPLICATION_TREES)
    require(clean_file(SESSION) == blob(BASELINE, SESSION), "Original chat session/prompt changed")

    peer_raw = clean_file(COLD + "COLD_SEARCH_PEER_REVIEW.json")
    require(sha(peer_raw) == "efbc1a32e2f7dcd1b31977cd991c1e317d3167d3692165bcd09be397da41daec",
            "Reviewed source receipt changed")
    peer = json.loads(peer_raw)
    require(peer["status"] == "SOURCE_SCOPE_ACCEPTED" and peer["base"] == BASELINE
            and peer["findings_requiring_source_change"] == [], "Source peer review differs")
    source_paths = {row["path"] for row in peer["reviewed_rows"]}
    require(len(source_paths) == 6, "Expected five existing product files and one new Core test")
    require(changed(BASELINE, APPLICATION) == source_paths | COLD_DOCUMENTS,
            "Repair contains an unreviewed source/document path")
    require(set(git("diff", "--name-only", BASELINE, APPLICATION, "--", "Source").decode().splitlines())
            == source_paths, "Source change scope differs")
    for row in peer["reviewed_rows"]:
        content = clean_file(row["path"])
        require(content == blob(APPLICATION, row["path"])
                and len(content) == row["bytes"] and sha(content) == row["after_sha256"],
                "Reviewed source bytes differ: " + row["path"])
        if "base_sha256" in row:
            require(sha(blob(BASELINE, row["path"])) == row["base_sha256"], "Wrong original source")
        else:
            require(row.get("base") == "ABSENT"
                    and git("ls-tree", BASELINE, "--", row["path"]) == b"", "New test existed in baseline")
    for path in COLD_DOCUMENTS:
        require(clean_file(path) == blob(APPLICATION, path), "Frozen repair evidence changed")
    controls_raw = clean_file(COLD + "CORE_CONTROLS_RESULT.json")
    require(sha(controls_raw) == "f000fb744a88fadeecd6be89e40ab5864be4b396f2a57c1cb76867df3c46daad",
            "Actual Core result changed")
    controls = json.loads(controls_raw)
    require(controls["returncode"] == 0 and controls["timed_out"] is False,
            "Actual Core execution did not pass")
    for name in ("stdout", "stderr"):
        evidence = clean_file(COLD + "CORE_CONTROLS_swift-test." + name)
        require(len(evidence) == controls["swift-test." + name]["bytes"]
                and sha(evidence) == controls["swift-test." + name]["sha256"], "Core log changed")
    require(b"Executed 17 tests, with 0 failures (0 unexpected)" in
            clean_file(COLD + "CORE_CONTROLS_swift-test.stdout"), "Missing actual focused Core summary")

    # Reuse only pure source-parsing helpers from the exact retained old guard.
    # The old guard's verify() is not called and its source constants are not replaced.
    old_guard = clean_file(OLD_GUARD)
    require(old_guard == blob(BASELINE, OLD_GUARD)
            and sha(old_guard) == "660490e0250747fd8d6b87b0d73a76a8a439eddb897cf84d33f07a7fac2aa0b9",
            "Original source helper changed")
    helper = runpy.run_path(str(ROOT / OLD_GUARD))
    original_driver = blob(BASELINE, DRIVER)
    current_driver = clean_file(DRIVER)
    old_binding = ('REVIEWED_SOURCE = "' + helper["constants"](original_driver)["REVIEWED_SOURCE"] + '"').encode()
    new_binding = ('REVIEWED_SOURCE = "' + APPLICATION + '"').encode()
    require(original_driver.count(old_binding) == 1
            and current_driver == original_driver.replace(old_binding, new_binding, 1),
            "Original runtime driver changed beyond the exact source binding")
    require(helper["functional_driver"](current_driver) == helper["functional_driver"](original_driver)
            and helper["diagnostic_tables"](current_driver) == helper["diagnostic_tables"](original_driver),
            "Original runtime semantics or finite diagnostics changed")
    require(helper["constants"](current_driver) == {
        "MODEL": "gemini-3.5-flash-lite", "REVIEWED_SOURCE": APPLICATION,
        "SELECTOR": "HanlinLiveProviderAcceptanceTests/testOriginalLiveProviderUsesCanonicalCoreAndRevokesReadConsent",
        "ENDPOINT": "https://generativelanguage.googleapis.com/v1beta/openai/"
    }, "Model/selector/endpoint/source differs")
    require(helper["snapshot_roots"](current_driver) == SNAPSHOT_ROOTS, "Source closure scope changed")
    require(sha(current_driver) == contract["driver_sha256"], "Driver digest differs")

    expected_inputs = json.loads(blob(BASELINE, INPUTS))
    expected_inputs["application_source_sha"] = APPLICATION
    expected_inputs["application_trees"] = {path: tree(APPLICATION, path)
                                           for path in expected_inputs["application_trees"]}
    input_raw = clean_file(INPUTS)
    require(json.loads(input_raw) == expected_inputs and sha(input_raw) == contract["inputs_sha256"],
            "Build inputs changed beyond actual application source/trees")
    old_step = (b"      - name: Verify the immutable Live12 diagnostic source boundary\n"
                b"        run: python3 Scripts/CI/verify-hanlin-live12-source.py\n")
    new_step = (b"      - name: Verify the immutable Live13 cold-search repair source boundary\n"
                b"        run: python3 Scripts/CI/verify-hanlin-live13-source.py\n")
    original_workflow = blob(BASELINE, WORKFLOW)
    workflow = clean_file(WORKFLOW)
    require(original_workflow.count(old_step) == 1
            and workflow == original_workflow.replace(old_step, new_step, 1),
            "Workflow changed beyond the source admission step")
    require(b"on:\n  workflow_dispatch:\n" in workflow and b"\n  push:" not in workflow
            and b"\n  pull_request:" not in workflow and b"\n  schedule:" not in workflow,
            "Live workflow must remain manual only")
    require(sha(workflow) == contract["workflow_sha256"]
            and sha(clean_file(GUARD)) == contract["source_guard_sha256"], "Gate digest differs")
    require(changed(APPLICATION, "HEAD") == {DRIVER, INPUTS, GUARD, WORKFLOW} | NEW_DOCUMENTS,
            "Unexpected source/preflight path")

    inventory_raw = clean_file(EXECUTION_INPUTS)
    require(sha(inventory_raw) == contract["execution_inputs_sha256"], "Execution inventory digest differs")
    inventory = json.loads(inventory_raw)
    require(inventory["roots"] == SNAPSHOT_ROOTS and inventory["application_source_sha"] == APPLICATION,
            "Execution inventory source/scope differs")
    actual = {}
    for row in git("ls-tree", "-r", "-z", "HEAD", "--", *SNAPSHOT_ROOTS).split(b"\0"):
        if not row:
            continue
        meta, name = row.split(b"\t", 1)
        mode, kind, expected_blob = meta.decode().split()
        require(kind == "blob", "Unexpected execution input kind")
        path = name.decode()
        target = ROOT / path
        content = os.readlink(target).encode() if mode == "120000" and target.is_symlink() else target.read_bytes()
        require(blob_hash(content) == expected_blob, "Dirty actual execution input: " + path)
        actual[path] = {"mode": mode, "blob": expected_blob, "bytes": len(content), "sha256": sha(content)}
    require(actual == inventory["files"]
            and all(path in actual for path in (GUARD, OLD_GUARD, DRIVER, INPUTS, WORKFLOW)),
            "Actual source closure differs")

    prior_raw = clean_file(PACKET + "LIVE12_INTAKE.json")
    require(sha(prior_raw) == "54761f6b160f9b79a46ad4cf61e89473e21b51293efd8391ebcece8fface3d89",
            "Actual failed Live12 intake changed")
    prior = json.loads(prior_raw)
    require(prior["run_id"] == 45114449674 and prior["source"] == BASELINE
            and prior["native_cases"]["PASS"] == 0 and prior["native_cases"]["FAIL"] == 1,
            "Prior native failure was relabeled")
    cleanup = prior["temporary_secret_cleanup"]
    require(cleanup["delete_http_status"] == 204 and cleanup["after_http_status"] == 404
            and cleanup["checkout_sha"] == BASELINE, "Prior cleanup is unproven")
    review = json.loads(clean_file(PACKET + "CONTROLLER_SOURCE_REVIEW.json"))
    require(review["exact_inverse_source_proof"] is True
            and review["controller_sha256"] == sha(clean_file(PACKET + "live13-controller.py"))
            and review["result"]["status"] == "PASS" and review["result"]["executed"] == 3,
            "Changed controller identity review is unproven")
    require(contract["live13_native_result"] == "NOT_RUN"
            and contract["historical_no_send_reused_as_current_acceptance"] is False
            and contract["provider_called_by_preparation"] is False
            and contract["credential_accessed_by_preparation"] is False,
            "Source admission cannot claim native/provider/credential execution")
    return {
        "status": "SOURCE_ADMISSION_PASS", "checkout_sha": head,
        "application_source_sha": APPLICATION, "source_admission_sha256": sha(raw),
        "source_admission_git_blob": tree("HEAD", ADMISSION),
        "workflow_sha256": sha(workflow), "workflow_git_blob": tree("HEAD", WORKFLOW),
        "execution_input_count": len(actual), "execution_inputs_sha256": sha(inventory_raw),
        "reviewed_product_files": 5, "new_Core_tests": 17, "Core_tests_reexecuted": False,
        "independent_source_review": "ACCEPTED", "old_source_guard_reexecuted": False,
        "previous_live12_native_result": "FAIL", "prior_secret_cleanup": "DELETE204_GET404_VERIFIED",
        "historical_no_send_reused_as_current_acceptance": False,
        "live13_native_result": "NOT_RUN_BY_THIS_CHECK", "manual_workflow_only": True,
        "completion_succeeded_alone_is_host_receipt": False,
        "provider_called": False, "credential_accessed": False,
        "changed_gate_paths": sorted(changed(APPLICATION, "HEAD")),
    }


if __name__ == "__main__":
    print(json.dumps(verify(), sort_keys=True, indent=2))
