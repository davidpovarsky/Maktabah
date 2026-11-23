#!/usr/bin/env python3
"""Admit one exact SDK continuation repair without changing the original Live case."""
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "96c5b1b60c15a9a0cf1c4356f9822c64d9864c86"
OLD_APPLICATION = "7841f4af33142f72936ca97428733b3059f806b0"
SDK_APPLICATION = "fb5abff01b1ae7958ab6c6733ff715ff615ae7b8"
HOST_LOCK_APPLICATION = "41f4242e83a17773e39a4b17ba2450f1e9b2ddfb"
PREVIOUS_APPLICATION = "07845de8c335a975027fd375f287a85754da51ab"
APPLICATION = "73cbc16722ea33f3600ba19f1ca35dbd1a4d9812"
HOST_LOCK = "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
OLD_SDK = "e00498e33f106cc43be0476ffa2e09329c8ca300"
SDK = "f8cf6ca543c5ceed05a60141644664c93e4565b4"
CORE = "3f38f1302764635c9991d0d00fd7b12471a5373c"
BRANCH = "codex/otzaria-hanlin-thought-signature-live-20261123"
DRIVER = "Scripts/CI/runtime27-hanlin-live.py"
INPUTS = "Scripts/CI/hq-stage2-focused-apple.inputs.json"
WORKFLOW = ".github/workflows/otzaria-hanlin-live-native.yml"
GUARD = "Scripts/CI/verify-hanlin-stream-continuation-source.py"
HELPERS = "Scripts/CI/verify-hanlin-live12-source.py"
TEST = "Maktabah-iOSUITests/HanlinConsumerAcceptanceTests.swift"
PACKET = "docs/hq-integration/hanlin-stream-continuation-20261123/"
ADMISSION = PACKET + "LIVE_STREAM_SOURCE_ADMISSION.json"
INVENTORY = PACKET + "LIVE_STREAM_EXECUTION_INPUTS.json"
TREES = ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]
SNAPSHOT_ROOTS = [
    "Scripts/CI", "Scripts/verify-otzaria-mini-parity.py", ".github/workflows",
    "tools", "Maktabah-iOSUITests", "docs/hq-integration/runtime27/R27_CASES.json",
]
DOCUMENTS = {PACKET + name for name in (
    "LIVE_STREAM_SOURCE_ADMISSION.json", "LIVE_STREAM_EXECUTION_INPUTS.json",
    "CI_PREPARATION.md", "DEPENDENCY_ADOPTION.json", "HOST_LOCK_ADOPTION.json", "CORE_APPLE_VALIDATION.json",
    "previous-live/DIAGNOSIS.json", "previous-live/CLEANUP_BINDING.json",
)}


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


def changed(before, after):
    return set(git("diff", "--name-only", before, after).decode().splitlines())


def clean(path):
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
    require(os.environ.get("GITHUB_EVENT_NAME", "workflow_dispatch") == "workflow_dispatch",
            "Live requires one owned manual dispatch")
    require(os.environ.get("GITHUB_RUN_ATTEMPT", "1") == "1", "Live retry needs new admission")
    contract_raw = clean(ADMISSION)
    contract = json.loads(contract_raw)
    require(contract["schema_version"] == 1 and contract["repository"] == "davidpovarsky/Maktabah"
            and contract["branch"] == BRANCH
            and contract["baseline_live_consent_source"] == BASELINE
            and contract["application_source_sha"] == APPLICATION
            and contract["hanlin_gitlink"] == SDK
            and contract["swift_ai_sdk_source_sha"] == CORE, "Wrong source lineage")
    require(git("rev-parse", APPLICATION + "^").decode().strip() == PREVIOUS_APPLICATION
            and git("rev-parse", PREVIOUS_APPLICATION + "^").decode().strip() == HOST_LOCK_APPLICATION
            and git("rev-parse", HOST_LOCK_APPLICATION + "^").decode().strip() == SDK_APPLICATION
            and git("rev-parse", SDK_APPLICATION + "^").decode().strip() == BASELINE
            and git("rev-parse", "HEAD^").decode().strip() == APPLICATION,
            "Application and CI must retain their exact immediate parents")
    require(changed(BASELINE, APPLICATION) == {"Vendor/HanlinSDK", HOST_LOCK}
            and changed(BASELINE, SDK_APPLICATION) == {"Vendor/HanlinSDK"}
            and changed(SDK_APPLICATION, HOST_LOCK_APPLICATION) == {HOST_LOCK}
            and changed(HOST_LOCK_APPLICATION, PREVIOUS_APPLICATION) == {"Vendor/HanlinSDK", HOST_LOCK}
            and changed(PREVIOUS_APPLICATION, APPLICATION) == {"Vendor/HanlinSDK", HOST_LOCK},
            "Application repair changed beyond the exact SDK and Host lock adoption")
    original_lock = blob(BASELINE, HOST_LOCK)
    old_core = b"e7bf34111e603ca977becd007dd4e5bb109af857"
    require(original_lock.count(old_core) == 1
            and clean(HOST_LOCK) == original_lock.replace(old_core, CORE.encode(), 1),
            "Host resolved package changed beyond the exact shared core revision")
    require(tree(BASELINE, "Vendor/HanlinSDK") == OLD_SDK
            and tree(APPLICATION, "Vendor/HanlinSDK") == tree("HEAD", "Vendor/HanlinSDK") == SDK,
            "Wrong SDK dependency")
    for path in TREES:
        require(tree("HEAD", path) == tree(APPLICATION, path) == contract["application_trees"][path],
                "Application/test tree differs: " + path)
        if path not in {"Vendor", "Maktabah.xcodeproj"}:
            require(tree("HEAD", path) == tree(BASELINE, path),
                    "Original application, project or UI assertions changed: " + path)
    git("diff", "--exit-code", "HEAD", "--", *TREES)
    require(changed(APPLICATION, "HEAD") == {DRIVER, INPUTS, WORKFLOW, GUARD} | DOCUMENTS,
            "Unexpected CI/preparation path")
    for path in DOCUMENTS:
        clean(path)

    original_driver = blob(BASELINE, DRIVER)
    driver = clean(DRIVER)
    before = ('REVIEWED_SOURCE = "' + OLD_APPLICATION + '"').encode()
    after = ('REVIEWED_SOURCE = "' + APPLICATION + '"').encode()
    require(original_driver.count(before) == 1
            and driver == original_driver.replace(before, after, 1),
            "Runtime changed beyond the exact application source literal")
    require(clean(HELPERS) == blob(BASELINE, HELPERS), "Original source helpers changed")
    helper = runpy.run_path(str(ROOT / HELPERS))
    require(helper["functional_driver"](driver) == helper["functional_driver"](original_driver)
            and helper["diagnostic_tables"](driver) == helper["diagnostic_tables"](original_driver),
            "Original execution, scanner or diagnostic behavior changed")
    require(helper["constants"](driver) == {
        "MODEL": "gemini-3.5-flash-lite", "REVIEWED_SOURCE": APPLICATION,
        "SELECTOR": "HanlinLiveProviderAcceptanceTests/testOriginalLiveProviderUsesCanonicalCoreAndRevokesReadConsent",
        "ENDPOINT": "https://generativelanguage.googleapis.com/v1beta/openai/",
    } and helper["snapshot_roots"](driver) == SNAPSHOT_ROOTS,
        "Provider, model, selector or execution scope changed")
    require(clean(TEST) == blob(BASELINE, TEST), "Original native case or 180-second wait changed")

    expected_inputs = json.loads(blob(BASELINE, INPUTS))
    expected_inputs["application_source_sha"] = APPLICATION
    expected_inputs["application_trees"] = {
        path: tree(APPLICATION, path) for path in expected_inputs["application_trees"]
    }
    expected_inputs["hanlin_gitlink"] = SDK
    require(json.loads(clean(INPUTS)) == expected_inputs,
            "Native dependency inputs changed beyond the reviewed SDK adoption")

    original_workflow = blob(BASELINE, WORKFLOW)
    before = (b"      - name: Verify the immutable Live consent observation source boundary\n"
              b"        run: python3 Scripts/CI/verify-hanlin-live-consent-source.py\n")
    after = (b"      - name: Verify the immutable shared SDK continuation source boundary\n"
             b"        run: python3 Scripts/CI/verify-hanlin-stream-continuation-source.py\n")
    workflow = clean(WORKFLOW)
    require(original_workflow.count(before) == 1
            and workflow == original_workflow.replace(before, after, 1),
            "Workflow changed beyond the source admission step")
    require(b"on:\n  workflow_dispatch:\n" in workflow
            and all(event not in workflow for event in (b"\n  push:", b"\n  schedule:", b"\n  pull_request:")),
            "Live workflow must remain manual only")
    for path, field in [(DRIVER, "driver_sha256"), (INPUTS, "inputs_sha256"),
                        (WORKFLOW, "workflow_sha256"), (GUARD, "source_guard_sha256"),
                        (INVENTORY, "execution_inputs_sha256")]:
        require(sha(clean(path)) == contract[field], "Admitted source digest differs: " + path)

    inventory = json.loads(clean(INVENTORY))
    require(inventory["roots"] == SNAPSHOT_ROOTS
            and inventory["application_source_sha"] == APPLICATION, "Wrong execution inventory")
    actual = {}
    for row in git("ls-tree", "-r", "-z", "HEAD", "--", *SNAPSHOT_ROOTS).split(b"\0"):
        if not row:
            continue
        meta, name = row.split(b"\t", 1)
        mode, kind, expected_blob = meta.decode().split()
        require(kind == "blob" and mode in {"100644", "100755", "120000"}, "Invalid source kind")
        path = name.decode()
        target = ROOT / path
        if mode == "120000":
            require(target.is_symlink(), "Missing source symlink: " + path)
            content = os.readlink(target).encode()
        else:
            content = clean(path)
        actual_blob = hashlib.sha1(b"blob " + str(len(content)).encode() + b"\0" + content).hexdigest()
        require(actual_blob == expected_blob, "Dirty execution input: " + path)
        actual[path] = {"mode": mode, "blob": expected_blob, "bytes": len(content), "sha256": sha(content)}
    require(actual == inventory["files"] and len(actual) == 286
            and contract["execution_input_count"] == len(actual), "Execution closure changed")

    require(set(contract["evidence_sha256"]) == DOCUMENTS - {ADMISSION, INVENTORY},
            "Exact complete preparation evidence set required")
    for path, digest in contract["evidence_sha256"].items():
        require(path in DOCUMENTS and sha(clean(path)) == digest, "Evidence digest differs: " + path)
    dependency = json.loads(clean(PACKET + "DEPENDENCY_ADOPTION.json"))
    require(dependency["base"] == OLD_SDK and dependency["candidate"] == SDK
            and dependency["swift_ai_sdk_source"] == CORE and len(dependency["paths"]) == 9,
            "Wrong reviewed dependency adoption")
    host_lock = json.loads(clean(PACKET + "HOST_LOCK_ADOPTION.json"))
    require(host_lock["application_source_sha"] == APPLICATION
            and host_lock["parent"] == PREVIOUS_APPLICATION
            and host_lock["hanlin_source"] == SDK and host_lock["swift_ai_sdk_source"] == CORE
            and host_lock["after_sha256"] == sha(clean(HOST_LOCK))
            and host_lock["only_revision_literal_changed"] is True,
            "Host lock qualification differs")
    core = json.loads(clean(PACKET + "CORE_APPLE_VALIDATION.json"))
    require(core["status"] == "APPLE_THOUGHT_SIGNATURE_CONTINUATION_QUALIFIED"
            and core["implementation_source_sha"] == CORE and core["ci_source_sha"] == CORE
            and core["focused"] == {'run_id': 45281860828, 'run_attempt': 1, 'artifact_id': 14869369511, 'artifact_bytes': 2728267, 'artifact_sha256': '5862195ce9de4fafac90cfe85dcbff3e4fd72c81c9286b7f8b37ce1597b8b2ae', 'source': '3f38f1302764635c9991d0d00fd7b12471a5373c', 'conclusion': 'success', 'actual_pass': 1, 'fail': 0, 'skip': 0, 'not_run': 0, 'xml_sha256': '79c5377aef943cc1b19e0ad9cf59d3ad682f286240aaead0c55edc2048308b26', 'test_binary_sha256': '31ac0de618cf34dedd61a0c1d0d443d6ede4dcf5d3070969a62275b981c68f09'}
            and core["previous_full_suite"] == {'source': 'd4286d1afa661af930f7addd6f63fff0effe4414', 'run_id': 45275019854, 'run_attempt': 1, 'conclusion': 'failure', 'artifact_id': 14867946517, 'artifact_sha256': '2551d96f45597c6263af456321eec7a53a13f0093d142f9e74a4b4c9f715b5f4', 'xml_sha256': '89e344224390072e09dfa5eb89282a816eac570e364c21cd4da9b4a1428ce6ad', 'actual_methods': 4194, 'pass': 4193, 'fail': 1, 'expectation_failures': 2, 'skip': 0, 'not_run': 0, 'test_binary_hash_retained': False}
            and core["qualified_methods"] == 4194 and core["retained_passing_methods"] == 4193
            and core["actual_focused_methods"] == 1 and core["original_methods"] == 4185
            and core["new_logical_methods"] == 9 and core["new_scenarios"] == 18
            and core["source_rows_git_verified"] == 1401
            and core["original_product_and_retained_tests_unchanged"] is True
            and core["source_and_compiler_unchanged"] is True,
            "Shared Core lacks authentic exact source-bound Apple continuation evidence")
    qualification = core["qualification"]
    require(qualification["status"] == "ACTUAL_APPLE_PACKAGE_QUALIFIED_WITH_RETAINED_PASSES"
            and qualification["source"] == CORE
            and qualification["qualified_logical_methods"] == 4194
            and qualification["actual_focused_methods"] == 1
            and qualification["retained_actual_passing_methods"] == 4193
            and all(qualification[k] == 0 for k in ("failed_methods", "errors", "skipped_methods",
                                                   "not_run_obligations", "retained_tests_replayed"))
            and qualification["source_and_compiler_unchanged"] is True
            and qualification["previous_run"] == 45275019854
            and qualification["previous_aggregate_conclusion"] == "failure"
            and qualification["previous_failure_preserved"] is True
            and qualification["xml_sha256"] == core["focused"]["xml_sha256"]
            and qualification["test_binary_sha256"] == core["focused"]["test_binary_sha256"],
            "Core qualification cannot relabel the prior failure or duplicate retained checks")
    prior = json.loads(clean(PACKET + "previous-live/DIAGNOSIS.json"))
    require(prior["run_id"] == 45253606271 and prior["source_sha"] == "0123b569d489984ade291b5c065eb5fe6500dec6"
            and prior["run_attempt"] == 1 and prior["workflow_conclusion"] == "cancelled"
            and prior["actual_ui_counts"] == {"pass": 0, "fail": 1, "skip": 0, "executed": 1},
            "Previous actual native failure was relabeled")
    cleanup = json.loads(clean(PACKET + "previous-live/CLEANUP_BINDING.json"))
    require(cleanup["run_id"] == 45253606271, "Wrong prior cleanup")
    receipt = cleanup["receipts"][0]["receipt"]
    absence = cleanup["receipts"][1]["receipt"]
    require(receipt["run_id"] == 45253606271 and receipt["checkout_sha"] == "0123b569d489984ade291b5c065eb5fe6500dec6"
            and receipt["delete_http_status"] == 204 and receipt["after_http_status"] == 404
            and absence["http_status"] == 404 and absence["independent_absence_verified"] is True
            and absence["run_id"] == 45253606271, "Previous owned secret cleanup is unproven")
    require(contract["native_result"] == "NOT_RUN"
            and contract["historical_passes_reused_as_current_acceptance"] is False
            and contract["provider_called_by_preparation"] is False
            and contract["credential_accessed_by_preparation"] is False,
            "Source admission cannot claim native or provider execution")
    return {
        "status": "SOURCE_ADMISSION_PASS", "checkout_sha": head,
        "application_source_sha": APPLICATION, "hanlin_gitlink": SDK,
        "swift_ai_sdk_source_sha": CORE, "source_admission_sha256": sha(contract_raw),
        "source_admission_git_blob": tree("HEAD", ADMISSION),
        "execution_input_count": len(actual), "original_ui_case_unchanged": True,
        "original_case_timeout_seconds": 600, "original_source_wait_seconds": 180,
        "manual_workflow_only": True, "prior_secret_cleanup": "DELETE204_GET404_VERIFIED",
        "native_result": "NOT_RUN_BY_THIS_CHECK", "provider_called": False,
        "credential_accessed": False,
    }


if __name__ == "__main__":
    print(json.dumps(verify(), sort_keys=True, indent=2))
