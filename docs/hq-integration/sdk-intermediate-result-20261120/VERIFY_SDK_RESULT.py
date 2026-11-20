#!/usr/bin/env python3
"""Replay retained SDK evidence and source hashes; does not compile or run tests."""
from __future__ import annotations
import argparse
import collections
import gzip
import hashlib
import json
from pathlib import Path
import re
import stat
import zipfile

RUN = 44765034019
SOURCE = "86e817f6c9b9f3d8726832280c6ee9916bfcf7ad"
APPLICATION = "e603d8182a1c10c4b37b14c92b5f0bc3829edea8"
BRANCH = "codex/otzaria-ui-sdk-intermediate-20261120"
WORKFLOW = ".github/workflows/otzaria-ui-sdk-intermediate.yml"
ARTIFACT = 14646210906
ZIP_BYTES = 231140
ZIP_SHA = "1f8dcea4aea110eb40a206c9fba5748e448ea27cb07b63354a075240323a0792"
SDK_PIN = "e00498e33f106cc43be0476ffa2e09329c8ca300"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def verify(base):
    archive = base / "artifact-14646210906.zip"
    artifact_bytes = archive.read_bytes()
    assert len(artifact_bytes) == ZIP_BYTES and sha(artifact_bytes) == ZIP_SHA
    receipts = json.loads((base / "GITHUB_RECEIPTS.json").read_bytes())
    run = receipts["run"]
    assert (run["id"], run["head_sha"], run["head_branch"], run["path"], run["event"], run["run_attempt"], run["status"], run["conclusion"]) == (
        RUN, SOURCE, BRANCH, WORKFLOW, "push", 1, "completed", "success")
    artifacts = receipts["artifacts"]
    assert artifacts["total_count"] == len(artifacts["artifacts"]) == 1
    metadata = artifacts["artifacts"][0]
    assert (metadata["id"], metadata["name"], metadata["size_in_bytes"], metadata["digest"], metadata["expired"]) == (
        ARTIFACT, "faithful-ui-sdk-check", ZIP_BYTES, "sha256:" + ZIP_SHA, False)
    origin = metadata["workflow_run"]
    assert origin["id"] == RUN and origin["head_sha"] == SOURCE and origin["head_branch"] == BRANCH
    assert origin["repository_id"] == origin["head_repository_id"] == 1280062128
    jobs = receipts["jobs"]
    assert jobs["total_count"] == len(jobs["jobs"]) == 1
    job = jobs["jobs"][0]
    assert job["id"] == 136387248090 and job["conclusion"] == "success" and job["status"] == "completed"
    assert all(step["status"] == "completed" and step["conclusion"] == "success" for step in job["steps"])
    contents, members = {}, []
    with zipfile.ZipFile(archive) as zipped:
        assert len(zipped.infolist()) == len(set(zipped.namelist())) == 48 and zipped.testzip() is None
        for entry in zipped.infolist():
            assert not Path(entry.filename).is_absolute() and ".." not in Path(entry.filename).parts
            assert not entry.is_dir() and not stat.S_ISLNK(entry.external_attr >> 16)
            data = zipped.read(entry)
            assert len(data) == entry.file_size
            if (base / "extracted").exists():
                assert (base / "extracted" / entry.filename).read_bytes() == data
            contents[entry.filename] = data
            members.append({"path": entry.filename, "bytes": len(data), "sha256": sha(data), "zip_crc32": f"{entry.CRC:08x}"})
    def read(name):
        return json.loads(contents[name])
    def log(name):
        return contents[name].decode("utf-8")
    before = read("ui-acceptance-typecheck.intermediate-source.before.json")
    after = read("ui-acceptance-typecheck.intermediate-source.after.json")
    assert before["status"] == "SOURCE_BOUND" and after["status"] == "SOURCE_UNCHANGED"
    assert before["observation"] == after["observation"]
    for observation in [before, after]:
        assert observation["github_run_id"] == str(RUN) and observation["github_run_attempt"] == "1"
        assert observation["native_ui_executed"] == 0
    observed = before["observation"]
    assert observed["head"] == SOURCE and observed["reviewed_application_test_source"] == APPLICATION
    assert observed["repository"] == "davidpovarsky/Maktabah" and observed["ref"] == "refs/heads/" + BRANCH
    tree = {r["path"]: r["sha"] for r in receipts["base_root_tree"]["tree"]}
    assert all(tree[path] == value for path, value in observed["source_trees"].items())
    compare = receipts["addition_compare"]
    assert compare["base_commit"]["sha"] == compare["merge_base_commit"]["sha"] == APPLICATION
    assert compare["ahead_by"] == compare["total_commits"] == 1 and compare["behind_by"] == 0
    runtime_delta = [row for row in compare["files"] if not row["filename"].startswith("docs/")]
    assert {row["filename"] for row in runtime_delta} == {WORKFLOW, "Scripts/CI/verify-ui-sdk-intermediate-source.py"}
    assert all(row["status"] == "added" for row in compare["files"])
    source_rows = json.loads((base / "ROOT_GIT_INPUTS.json").read_bytes())
    assert len(source_rows) == len({r["path"] for r in source_rows}) == 24
    source = {}
    source_proof = []
    observed_inputs = {r["path"]: r for r in observed["inputs"]}
    assert set(observed_inputs) == {r["path"] for r in source_rows}
    for row in source_rows:
        data = row["content"].encode("utf-8")
        assert len(data) == row["bytes"] and sha(data) == row["sha256"] and blob(data) == row["git_blob"], row["path"]
        assert all(row[k] == observed_inputs[row["path"]][k] for k in ("bytes", "sha256", "git_blob"))
        source[row["path"]] = data
        source_proof.append({k: v for k, v in row.items() if k != "content"})
    report = read("ui-acceptance-typecheck.json")
    assert report["sourceSHA"] == SOURCE and report["status"] == "SDK_COMPILE_PASS" and report["aggregateSDKStatus"] == "PASS"
    assert report["includesCodeGeneration"] is True and report["notRuntimeAcceptance"] is True and report["nativeUITestsExecuted"] == 0
    assert report["target"] == "arm64-apple-ios27.0-simulator" and report["sdk"].endswith("iPhoneSimulator27.2.sdk")
    assert report["xcode"] == "Xcode 27.2\nBuild version 27B52" and "Apple Swift version 6.4.2 " in report["swift"]
    assert len(report["sourceHashes"]) == 11 and set(report["sourceHashes"]) == set(observed["complete_sdk_test_sources"])
    assert all(sha(source[name]) == expected for name, expected in report["sourceHashes"].items())
    decl = report["nativeDeclarationPreflight"]
    assert decl["selectedCount"] == 116 and decl["compilerRegressionExitCode"] == 0 and decl["nativeUITestsExecuted"] == 0
    declarations = decl["declarations"]
    assert declarations["status"] == "DECLARATIONS_MATCH"
    selected = [row["selection"] for row in declarations["suites"]]
    assert len(selected) == len(set(selected)) == 116 and all(r["status"] == "DECLARATIONS_MATCH" for r in declarations["suites"])
    catalog = json.loads(source["docs/hq-integration/runtime27/R27_CASES.json"])
    assert selected == [case for group in catalog["execution_groups"] for case in group["case_ids"]]
    driver = source["Scripts/CI/typecheck-faithful-ui-tests.py"].decode()
    assert '"-c", "-whole-module-optimization"' in driver and '"-swift-version", "6"' in driver
    assert '"-D", "DEBUG"' in driver
    combined = log("ui-acceptance-typecheck.log")
    sections = ["Compiler declaration regression checks (not Native):", "=== Exact native sidebar adapter SDK compilation ===",
                "=== Actual native reader TextKit witness SDK compilation ===", "=== Native routing host SDK compilation ==="]
    offsets = [0] + [combined.index(m) for m in sections] + [len(combined)]
    warning_sections = []
    for i, name in enumerate(["11 complete UI files code generation", *sections]):
        body = combined[offsets[i]:offsets[i + 1]]
        warning_sections.append({"section": name, "warning_occurrences": body.count("warning:"),
            "source_location_warning_headers": len(re.findall(r"^.+:[0-9]+:[0-9]+: warning:", body, re.MULTILINE)),
            "compiler_error_headers": len(re.findall(r"^.+:[0-9]+:[0-9]+: error:", body, re.MULTILINE))})
    assert warning_sections[0]["warning_occurrences"] == report["warningCount"] == 2844
    assert warning_sections[0]["source_location_warning_headers"] == 1422
    assert [r["warning_occurrences"] for r in warning_sections[1:]] == [0, 0, 0, 4]
    assert all(row["compiler_error_headers"] == 0 for row in warning_sections)
    parser_raw = combined[offsets[1]:offsets[2]]
    assert re.search(r"Ran 8 tests in [0-9.]+s\n\nOK", parser_raw)
    for key in ("sidebarNativeSearch", "sidebarAdapterSDK", "nativeReaderTextVisibilitySDK", "nativeRoutingHost"):
        assert report[key]["status"] == "SDK_COMPILE_PASS" and report[key]["sourceSHA"] == SOURCE
    assert report["appMembershipStatus"] == "PASS" and report["toolbarSDKStatus"] == "SDK_COMPILE_PASS"
    assert read("toolbar-sdk-compile.json")["includesCodeGeneration"] is True
    assert report["appComposedSidebar"]["status"] == report["appComposedGlobalSearchField"]["status"] == "REQUIRES_FULL_APP_BUILD"
    toolkit = read("ui-acceptance-typecheck.toolchain.json")
    assert toolkit["status"] == "MATCHED_MATRIX_PAIR_SELECTED" and toolkit["selected"]["sdk_version"] == "27.2"
    assert toolkit["global_xcode_select_changed"] is False and toolkit["toolchains_installed"] is False
    sdk = read("ui-acceptance-typecheck.hanlin-sdk-inputs.json")
    assert sdk["sha"] == SDK_PIN and sdk["verified_files"] == len(sdk["git_blobs"]) == 424
    assert json.loads(source["Scripts/CI/hq-stage2-focused-apple.inputs.json"])["hanlin_gitlink"] == SDK_PIN
    component = {}
    def pass_lines(name):
        return re.findall(r"^PASS (.+)$", log(name), re.MULTILINE)
    def record(label, names, count, boundary):
        assert len(names) == len(set(names)) == count, label
        component[label] = {"passed": count, "failed": 0, "case_names": names, "boundary": boundary}
    sql = read("ui-acceptance-typecheck.sqlite-RESULT.json")
    assert sql == report["actualSQLite"] and sql["compile_exit"] == sql["execute_exit"] == 0
    assert sql["actual_sqlite"]["sqliteVersion"] == "3.54.0" and sql["sqlite_is_real"] is True
    assert all(r["passed"] is True for r in sql["actual_sqlite"]["cases"])
    names = [r["name"] for r in sql["actual_sqlite"]["cases"]]
    assert names == pass_lines("ui-acceptance-typecheck.sqlite-tests.log")
    assert "ACTUAL_SQLITE 25 cases; 0 failures; version 3.54.0" in log("ui-acceptance-typecheck.sqlite-tests.log")
    assert sql["real_source_readonly_count"] == sql["native_ui_executed"] == sql["physical_device_executed"] == 0
    record("sqlite", names, 25, "Actual original SQLite wrapper and disposable SQLite3.54 files; no real corpus read, UI or decompressor execution")
    ann = read("ui-acceptance-typecheck.annotation-exchange-RESULT.json")
    assert ann == report["annotation-exchange"] and ann["compile_exit"] == ann["execute_exit"] == 0
    assert ann["passed_cases"] == 28 and ann["failed_cases"] == 0 and all(r["status"] == "PASS" for r in ann["cases"])
    assert ann["actual_sqlite"] is True and ann["actual_original_sync_pending_store"] is True
    assert ann["source_files_before"] == ann["source_files_after"] and ann["source_bytes_unchanged_during_run"] is True
    assert ann["original_annotation_repository_runtime_executed"] is False
    names = [r["name"] for r in ann["cases"]]
    assert names == pass_lines("ui-acceptance-typecheck.annotation-exchange-tests.log")
    record("annotation_ledger", names, 28, "Real SQLite/CryptoKit/original sync-pending component; original AnnotationRepository runtime, Anytype, CloudKit and UI not executed")
    assert {r["phase"] for r in ann["process_termination_checks"]} == {"before", "after"}
    for row in ann["process_termination_checks"]:
        assert row["status"] == "PASS" and row["terminated_exit"] == row["expected_terminated_exit"] == 73 and row["verify_exit"] == 0
        assert "CRASH_JOURNAL_MODE wal; synchronous=2" in log("ui-acceptance-typecheck.annotation-exchange-crash-" + row["phase"] + ".log")
        assert pass_lines("ui-acceptance-typecheck.annotation-exchange-verify-crash-" + row["phase"] + ".log") == ["actual_process_termination_" + row["phase"] + "_commit_reopen"]
    record("annotation_process_reopen", ["before_commit", "after_commit"], 2, "Actual process exit73 and reopen using SQLite WAL/full synchronous; separate from UI and the original repository runtime")
    heb = read("ui-acceptance-typecheck.hebrew-ranges-RESULT.json")
    assert heb == report["hebrew-ranges"] and heb["compile_exit"] == heb["test_exit"] == 0
    assert read("ui-acceptance-typecheck.hebrew-ranges-tests.log") == heb["actual"]
    assert all(r["passed"] is True and r["expected"] == r["actual"] for r in heb["actual"]["cases"])
    record("hebrew_ranges", [r["name"] for r in heb["actual"]["cases"]], 15, heb["actual"]["boundary"])
    cache = read("ui-acceptance-typecheck.book-page-cache-RESULT.json")
    cache_lines, separator, cache_json = log("ui-acceptance-typecheck.book-page-cache-tests.log").partition("\n{\n")
    assert separator and cache_lines.splitlines() == ["PASS: " + name for name in cache["passed"]]
    cache_log = json.loads("{\n" + cache_json)
    assert cache == report["book-page-cache"] and cache["compile_exit"] == cache["test_exit"] == 0
    assert cache["failed"] == [] and cache_log["failed"] == [] and cache_log["passed"] == cache["passed"]
    record("book_page_cache", cache["passed"], 26, "Compiled original cache behavior/capacity/lifetime component; no UI or physical performance acceptance")
    inspector = read("ui-acceptance-typecheck.inspector-owner-RESULT.json")
    assert inspector == report["inspector-owner"] and inspector["compile_exit"] == inspector["test_exit"] == 0
    assert inspector["failed"] == [] and inspector["passed"] == pass_lines("ui-acceptance-typecheck.inspector-owner-tests.log")
    record("inspector_owner", inspector["passed"], 17, inspector["boundary"])
    for label, count, expected_key, passed_key in [("hanlin-navigation-contract", 8, "expected", "passed"),
            ("hanlin-consumer-store", 11, "expected", "passed"), ("hanlin-api12-host", 48, "expected_tests", "passed_tests")]:
        result = read("ui-acceptance-typecheck." + label + "-RESULT.json")
        assert result == report[label] and result["exit_code"] == 0
        assert sorted(result[expected_key]) == sorted(result[passed_key])
        raw = log("ui-acceptance-typecheck." + label + "-swift-test.log")
        names = re.findall(r"^Test Case '-\[[^\] ]+ (test[^\] ]+)\]' passed \(", raw, re.MULTILINE)
        assert sorted(names) == sorted(result[expected_key]) and len(names) == count
        assert not re.findall(r"^Test Case .+ (?:failed|skipped) \(", raw, re.MULTILINE)
        assert f"Executed {count} tests, with 0 failures (0 unexpected)" in raw
        record(label, names, count, result["boundary"])
    workspace = log("workspace-test-results.log")
    assert workspace.strip() == "PASS: 89 workspace persistence/migration/rollback/scene/semantic-location checks"
    assert not contents["workspace-compile.log"].strip()
    component["workspace"] = {"passed_assertions_reported": 89, "raw_summary": workspace.strip(),
        "individual_runtime_leaf_names_emitted": False, "boundary": "Original executable assertions, not XCTest/UI leaves; raw aggregate only"}
    return {"status": "SDK_EVIDENCE_VERIFIED", "run": {key: run[key] for key in ["id", "head_sha", "head_branch", "path", "event", "run_attempt", "status", "conclusion", "created_at", "updated_at"]},
            "job": {key: job[key] for key in ["id", "name", "started_at", "completed_at", "conclusion"]},
            "artifact": {"id": ARTIFACT, "bytes": ZIP_BYTES, "sha256": ZIP_SHA, "members": members, "all_crc_passed": True},
            "source": {"reviewed_application": APPLICATION, "four_trees": observed["source_trees"], "root_fetched_inputs_verified": source_proof,
                "before_after_equal": True, "before": before["observed_at"], "after": after["observed_at"]},
            "sdk": {"xcode": report["xcode"], "swift": report["swift"], "sdk": report["sdk"], "target": report["target"],
                "complete_ui_files": list(report["sourceHashes"]), "declarations": selected, "compiler_regression_controls": 8,
                "warnings_by_log_section": warning_sections, "native_ui_executed": 0}, "components": component,
            "limits": {"full_app_build": "NOT_RUN", "app_composed_sidebar": "REQUIRES_FULL_APP_BUILD", "app_composed_global_search_field": "REQUIRES_FULL_APP_BUILD",
                "full_18_ui_file_codegen": "NOT_RUN_ONLY_ORIGINAL_11", "native_116": "NOT_RUN_DECLARATIONS_ONLY", "physical_device": "NOT_RUN",
                "original_annotation_repository_runtime": False, "cold_core_798_credit": False, "anytype_new_local_body_credit": False}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.input_dir)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({"status": result["status"], "archive_members": 48, "root_git_inputs": 24,
                      "complete_ui_files": 11, "declarations_only": 116, "ui_warning_occurrences": 2844,
                      "additional_host_log_warnings": 4, "native_ui_executed": 0}))


if __name__ == "__main__":
    main()
