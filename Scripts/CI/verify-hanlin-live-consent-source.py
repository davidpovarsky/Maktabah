#!/usr/bin/env python3
"""Read-only source admission for the original Live consent observation follow-up."""
import difflib
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "aa7741b16d00fbee8dea8ff67a25cf1cc7c0a9e3"
ORIGINAL_APPLICATION = "869f6a5a5eedbc94484467fe1c92f2802f497cda"
APPLICATION = "7841f4af33142f72936ca97428733b3059f806b0"
SDK = "e00498e33f106cc43be0476ffa2e09329c8ca300"
BRANCH = "codex/otzaria-hanlin-live-consent-20261123"
TEST = "Maktabah-iOSUITests/HanlinConsumerAcceptanceTests.swift"
DRIVER = "Scripts/CI/runtime27-hanlin-live.py"
INPUTS = "Scripts/CI/hq-stage2-focused-apple.inputs.json"
WORKFLOW = ".github/workflows/otzaria-hanlin-live-native.yml"
GUARD = "Scripts/CI/verify-hanlin-live-consent-source.py"
OLD_GUARD = "Scripts/CI/verify-hanlin-live13-source.py"
HELPERS = "Scripts/CI/verify-hanlin-live12-source.py"
SESSION = "Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift"
PACKET = "docs/hq-integration/hanlin-live-consent-20261123/"
ADMISSION = PACKET + "LIVE_CONSENT_SOURCE_ADMISSION.json"
EXECUTION_INPUTS = PACKET + "LIVE_CONSENT_EXECUTION_INPUTS.json"
SOURCE_INDEX = PACKET + "SOURCE_DOCUMENT_INDEX.json"
APPLICATION_TREES = ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]
SNAPSHOT_ROOTS = [
    "Scripts/CI", "Scripts/verify-otzaria-mini-parity.py", ".github/workflows",
    "tools", "Maktabah-iOSUITests", "docs/hq-integration/runtime27/R27_CASES.json"
]
CI_DOCUMENTS = {PACKET + name for name in (
    "CI_PREPARATION.md", "CI_INVERSES.json", "CI_INPUT_CHANGE_MAP.json",
    "WORKFLOW_ONLY.patch", "LIVE_CONSENT_SOURCE_ADMISSION.json",
    "LIVE_CONSENT_EXECUTION_INPUTS.json")}
BEFORE_SHA256 = "9f4c35fee98102373e5961759569077833d8eb83ad427255d7f11ef2e55d5143"
AFTER_SHA256 = "c8810b3f3c9ca42e71286f75dc255825b1a107f6baaf35ca45c93e7ff126b593"
PROPOSAL_SHA256 = "f635f446622b12bf89ae2529cf9ab2fe5ab626b12acfb1e21ffa9c457fa34eea"


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
    target = ROOT / path
    require(target.is_file() and not target.is_symlink(), "Invalid source file: " + path)
    raw = target.read_bytes()
    require(raw == blob("HEAD", path), "Dirty source input: " + path)
    return raw


def verify():
    head = git("rev-parse", "HEAD").decode().strip()
    require(os.environ.get("EXPECTED_CHECKOUT_SHA", head) == head, "Wrong immutable checkout")
    require(os.environ.get("GITHUB_REPOSITORY", "davidpovarsky/Maktabah") == "davidpovarsky/Maktabah",
            "Wrong repository")
    require(os.environ.get("GITHUB_REF", "refs/heads/" + BRANCH) == "refs/heads/" + BRANCH,
            "Wrong owned manual Live branch")
    raw = clean_file(ADMISSION)
    contract = json.loads(raw)
    require(contract["schema_version"] == 1 and contract["repository"] == "davidpovarsky/Maktabah"
            and contract["branch"] == BRANCH, "Wrong source admission")
    require(contract["baseline_live13_source"] == BASELINE
            and contract["original_application_source_sha"] == ORIGINAL_APPLICATION
            and contract["application_source_sha"] == APPLICATION
            and contract["hanlin_gitlink"] == SDK, "Wrong immutable source lineage")
    for revision in (BASELINE, ORIGINAL_APPLICATION, APPLICATION):
        require(git("rev-parse", revision + "^{commit}").decode().strip() == revision,
                "Source revision is not exact")
    require(git("rev-parse", APPLICATION + "^").decode().strip() == BASELINE
            and git("rev-parse", "HEAD^").decode().strip() == APPLICATION,
            "Test repair and CI child must retain their reviewed immediate parents")
    for path in APPLICATION_TREES:
        require(tree("HEAD", path) == tree(APPLICATION, path) == contract["application_trees"][path],
                "Application/test tree differs: " + path)
    for path in APPLICATION_TREES[:3]:
        require(tree("HEAD", path) == tree(BASELINE, path) == tree(ORIGINAL_APPLICATION, path),
                "Original application/vendor/project changed: " + path)
    require(tree("HEAD", "Vendor/HanlinSDK") == SDK, "Pinned original SDK changed")
    git("diff", "--exit-code", "HEAD", "--", *APPLICATION_TREES)
    require(clean_file(SESSION) == blob(BASELINE, SESSION), "Original chat session/prompt changed")

    # The exact source-only evidence index closes the prior native failure and
    # reviewed patch. It is immutable across the new CI child.
    index_raw = clean_file(SOURCE_INDEX)
    require(index_raw == blob(APPLICATION, SOURCE_INDEX)
            and sha(index_raw) == "f44206875be0674b78c342d1c8e47832562f71502587b4b8b2f0155ce5e8ba03",
            "Reviewed source/evidence index changed")
    index = json.loads(index_raw)
    require(index["base_source"] == BASELINE and index["source_after_sha256"] == AFTER_SHA256,
            "Wrong source index lineage")
    source_documents = {SOURCE_INDEX}
    for row in index["files"]:
        relative = PurePosixPath(row["path"])
        require(not relative.is_absolute() and ".." not in relative.parts
                and str(relative) == row["path"], "Invalid owned evidence path")
        path = PACKET + str(relative)
        require(path not in source_documents, "Duplicate source evidence")
        source_documents.add(path)
        content = clean_file(path)
        require(content == blob(APPLICATION, path) and len(content) == row["bytes"]
                and sha(content) == row["sha256"], "Source evidence differs: " + path)
    require(len(source_documents) == 44
            and changed(BASELINE, APPLICATION) == {TEST} | source_documents,
            "Test repair contains an unreviewed path")
    require(changed(APPLICATION, "HEAD") == {DRIVER, INPUTS, GUARD, WORKFLOW} | CI_DOCUMENTS,
            "Unexpected CI/preparation change")
    for path in CI_DOCUMENTS:
        clean_file(path)

    before = blob(BASELINE, TEST)
    after = clean_file(TEST)
    require(sha(before) == BEFORE_SHA256 and sha(after) == AFTER_SHA256
            and after == blob(APPLICATION, TEST), "Reviewed test bytes differ")
    require(clean_file(PACKET + "reviewed-proposal/before.swift") == before
            and clean_file(PACKET + "reviewed-proposal/after.swift") == after,
            "Retained test preimage/afterimage differs")
    proposal = clean_file(PACKET + "reviewed-proposal/PROPOSAL.diff")
    reconstructed = "".join(difflib.unified_diff(
        before.decode().splitlines(True), after.decode().splitlines(True),
        fromfile="a/" + TEST, tofile="b/" + TEST)).encode()
    require(sha(proposal) == PROPOSAL_SHA256 and reconstructed == proposal,
            "Exact reviewed proposal differs")
    before_lines, after_lines = before.splitlines(True), after.splitlines(True)
    edits = [row for row in difflib.SequenceMatcher(
        None, before_lines, after_lines, autojunk=False).get_opcodes() if row[0] != "equal"]
    require(len(edits) == 1 and edits[0][0] == "insert", "Expected one additive observation hunk")
    _, _, _, start, end = edits[0]
    require(end - start == 53 and b"".join(after_lines[:start] + after_lines[end:]) == before,
            "Whole-file test inverse differs")
    inserted = b"".join(after_lines[start:end])
    wait = (b"        let enabled = XCTWaiter.wait(for: [XCTNSPredicateExpectation(\n"
            b'            predicate: NSPredicate(format: "value == %@", "1"), object: consent\n'
            b"        )], timeout: 10)\n")
    assertion = b'        XCTAssertEqual(enabled, .completed, "One actual consent switch tap must turn access ON")\n'
    require(before.count(wait) == inserted.count(wait) == 1
            and before.count(assertion) == inserted.count(assertion) == 1,
            "Original semantic wait/assertion not copied verbatim")
    require(before.count(b"        press(nativeConsent)\n") == after.count(b"        press(nativeConsent)\n"),
            "An extra consent tap was added")

    # Do not invoke or amend the previous admission. Its whole-UI-tree contract
    # continues to describe the older source, and all its evidence remains exact.
    require(clean_file(OLD_GUARD) == blob(BASELINE, OLD_GUARD)
            and sha(clean_file(OLD_GUARD)) == "b7eabeaa88041e9cdfe84825708d3fc051d2a38ec032643964069a48cb4cd9fd",
            "Original Live13 guard changed")
    helper_raw = clean_file(HELPERS)
    require(helper_raw == blob(BASELINE, HELPERS)
            and sha(helper_raw) == "660490e0250747fd8d6b87b0d73a76a8a439eddb897cf84d33f07a7fac2aa0b9",
            "Original pure source helpers changed")
    helper = runpy.run_path(str(ROOT / HELPERS))
    original_driver = blob(BASELINE, DRIVER)
    driver = clean_file(DRIVER)
    old_binding = ('REVIEWED_SOURCE = "' + ORIGINAL_APPLICATION + '"').encode()
    new_binding = ('REVIEWED_SOURCE = "' + APPLICATION + '"').encode()
    require(original_driver.count(old_binding) == 1
            and driver == original_driver.replace(old_binding, new_binding, 1),
            "Runtime changed beyond its one reviewed-source literal")
    require(helper["functional_driver"](driver) == helper["functional_driver"](original_driver)
            and helper["diagnostic_tables"](driver) == helper["diagnostic_tables"](original_driver),
            "Original execution or diagnostic behavior changed")
    constants = {
        "MODEL": "gemini-3.5-flash-lite", "REVIEWED_SOURCE": APPLICATION,
        "SELECTOR": "HanlinLiveProviderAcceptanceTests/testOriginalLiveProviderUsesCanonicalCoreAndRevokesReadConsent",
        "ENDPOINT": "https://generativelanguage.googleapis.com/v1beta/openai/"
    }
    require(helper["constants"](driver) == constants
            and helper["snapshot_roots"](driver) == SNAPSHOT_ROOTS, "Runtime source contract differs")
    require(sha(driver) == contract["driver_sha256"], "Driver digest differs")
    expected_inputs = json.loads(blob(BASELINE, INPUTS))
    expected_inputs["application_source_sha"] = APPLICATION
    expected_inputs["application_trees"] = {path: tree(APPLICATION, path)
                                           for path in expected_inputs["application_trees"]}
    input_raw = clean_file(INPUTS)
    require(json.loads(input_raw) == expected_inputs and sha(input_raw) == contract["inputs_sha256"],
            "Build inputs changed beyond actual application source/trees")
    old_step = (b"      - name: Verify the immutable Live13 cold-search repair source boundary\n"
                b"        run: python3 Scripts/CI/verify-hanlin-live13-source.py\n")
    new_step = (b"      - name: Verify the immutable Live consent observation source boundary\n"
                b"        run: python3 Scripts/CI/verify-hanlin-live-consent-source.py\n")
    original_workflow = blob(BASELINE, WORKFLOW)
    workflow = clean_file(WORKFLOW)
    require(original_workflow.count(old_step) == 1
            and workflow == original_workflow.replace(old_step, new_step, 1),
            "Workflow changed beyond its single source admission step")
    require(b"on:\n  workflow_dispatch:\n" in workflow and b"\n  push:" not in workflow
            and b"\n  pull_request:" not in workflow and b"\n  schedule:" not in workflow,
            "Live workflow must remain manual only")
    require(sha(workflow) == contract["workflow_sha256"]
            and sha(clean_file(GUARD)) == contract["source_guard_sha256"], "Gate digest differs")

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
        require(kind == "blob" and mode in {"100644", "100755", "120000"}, "Unexpected input kind/mode")
        path = name.decode()
        target = ROOT / path
        if mode == "120000":
            require(target.is_symlink(), "Expected actual source symlink: " + path)
            content = os.readlink(target).encode()
        else:
            require(target.is_file() and not target.is_symlink(), "Invalid source input: " + path)
            content = target.read_bytes()
        require(blob_hash(content) == expected_blob, "Dirty actual execution input: " + path)
        actual[path] = {"mode": mode, "blob": expected_blob, "bytes": len(content), "sha256": sha(content)}
    require(actual == inventory["files"] and len(actual) == 285
            and all(path in actual for path in (TEST, GUARD, OLD_GUARD, HELPERS, DRIVER, INPUTS, WORKFLOW)),
            "Actual execution source closure differs")

    prior = json.loads(clean_file(PACKET + "runtime-45145388957/INTAKE.json"))
    require(prior["run"]["id"] == 45145388957 and prior["run"]["attempt"] == 1
            and prior["run"]["head_sha"] == BASELINE
            and {key: prior["outcome"][key] for key in ("selected", "executed", "passed", "failed", "skipped", "not_run")}
            == {"selected": 1, "executed": 1, "passed": 0, "failed": 1, "skipped": 0, "not_run": 0},
            "Original executed consent failure was relabeled")
    cleanup = json.loads(clean_file(PACKET + "runtime-45145388957/CLEANUP_BINDING.json"))
    receipt = cleanup["receipts"][0]["receipt"]
    require(cleanup["run_id"] == receipt["run_id"] == 45145388957
            and receipt["checkout_sha"] == BASELINE
            and receipt["delete_http_status"] == 204 and receipt["after_http_status"] == 404
            and cleanup["receipts"][1]["receipt"]["http_status"] == 404,
            "Prior controller cleanup is unproven")
    require(contract["native_result"] == "NOT_RUN"
            and contract["historical_passes_reused_as_current_acceptance"] is False
            and contract["provider_called_by_preparation"] is False
            and contract["credential_accessed_by_preparation"] is False,
            "Source admission cannot claim native/provider/credential execution")
    return {
        "status": "SOURCE_ADMISSION_PASS", "checkout_sha": head,
        "baseline_live13_source": BASELINE, "original_application_source_sha": ORIGINAL_APPLICATION,
        "application_source_sha": APPLICATION, "source_admission_sha256": sha(raw),
        "source_admission_git_blob": tree("HEAD", ADMISSION),
        "workflow_sha256": sha(workflow), "workflow_git_blob": tree("HEAD", WORKFLOW),
        "execution_input_count": len(actual), "execution_inputs_sha256": sha(inventory_raw),
        "original_product_trees_unchanged": True, "whole_file_test_inverse_exact": True,
        "added_test_lines": 53, "single_original_tap": True, "original_wait_seconds": 10,
        "original_case_timeout_seconds": 600, "old_source_guards_reexecuted": False,
        "old_portable_or_native_controls_reexecuted": False,
        "prior_actual_native_outcome": {"PASS": 0, "FAIL": 1, "SKIP": 0, "NOT_RUN": 0},
        "prior_secret_cleanup": "DELETE204_GET404_VERIFIED", "native_result": "NOT_RUN_BY_THIS_CHECK",
        "manual_workflow_only": True, "completion_succeeded_alone_is_host_receipt": False,
        "provider_called": False, "credential_accessed": False,
        "changed_gate_paths": sorted(changed(APPLICATION, "HEAD")),
    }


if __name__ == "__main__":
    print(json.dumps(verify(), sort_keys=True, indent=2))
