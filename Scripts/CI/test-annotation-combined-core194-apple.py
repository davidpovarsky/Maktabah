#!/usr/bin/env python3
"""Finite route/source/receipt controls. Synthetic receipts; no Swift or Native."""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("combined_route_under_test", ROOT / "Scripts/CI/annotation-combined-core194-apple.py")
route = importlib.util.module_from_spec(spec); spec.loader.exec_module(route)


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(route.json_bytes(value))


def authority():
    head = "a" * 40
    ref = "refs/heads/" + route.BRANCH
    env = {"GITHUB_EVENT_NAME": "push", "GITHUB_REPOSITORY": route.REPOSITORY,
           "GITHUB_REPOSITORY_ID": str(route.REPOSITORY_ID), "GITHUB_REF": ref,
           "GITHUB_WORKFLOW_REF": route.REPOSITORY + "/" + route.WORKFLOW + "@" + ref,
           "GITHUB_SHA": head, "GITHUB_WORKFLOW_SHA": head, "EXPECTED_CHECKOUT_SHA": head,
           "GITHUB_RUN_ID": "111", "GITHUB_RUN_ATTEMPT": "1"}
    event = {"ref": ref, "after": head, "deleted": False,
             "repository": {"id": route.REPOSITORY_ID, "full_name": route.REPOSITORY, "fork": True}}
    return env, event


def sample_source(scope):
    env, event = authority()
    return {"identity": route.identity(env, event), "scope": scope, "application_source": route.SOURCE_M,
            "application_tree": route.SOURCE_TREE, "application_trees": route.PROTECTED_TREES,
            "core_tree": route.CORE_TREE, "files": {"explicit.synthetic": {"sha256": "b" * 64}},
            "execution_inputs": {"synthetic.control": {"sha256": "c" * 64}},
            "case_names": {"local": ["explicit fixture"]}, "changed_paths": {},
            "post_build_product_audit": None, "checkout_root": "/explicit/synthetic/not-an-executed-source"}


def sample_core():
    return {"status": "PASS_ACTUAL_CORE194_AND_EXPECTED_BASELINE20", "stages": {
        "baseline20": {"qualified": True, "actual_completed": 20, "passed": 11, "failed": 9, "skipped": 0},
        "candidate194": {"qualified": True, "actual_completed": 194, "passed": 194, "failed": 0, "skipped": 0}}}


def sample_original():
    return {"local_cases": 43, "cloud_cases": 48, "local_cold_reopen_gates": 2,
            "exchange_cases": 28, "exchange_abrupt_process_reopen_gates": 2}


def sample_race():
    return {"status": "PASS_ACTUAL_REPOSITORY_RED_AND10_GREEN", "candidate_green": 10,
            "original_red": 1, "original_red_counts_as_pass": False, "cold_reads": 11}


def aggregate_fixture():
    before, after, jobs = {}, {}, []
    for index, scope in enumerate(route.JOBS, 1):
        source = sample_source(scope)
        before[scope] = {"status": "SOURCE_BOUND_NOT_EXECUTED", "source": copy.deepcopy(source)}
        if scope == "full_app": source["post_build_product_audit"] = {"explicit_synthetic": True}
        after[scope] = {"status": "PASS_CORE194_ALL_ORIGINAL_COMPONENTS" if scope == "components" else "PASS_ORIGINAL_FULL_APP_COMPILE",
                        "source": source, "core": sample_core(), "original_gates": sample_original(), "race_gates": sample_race(),
                        "app": {"status": "PASS_ORIGINAL_FULL_APP_COMPILE", "actual_file_lists": [{"explicit_synthetic": True}]}}
        context = source["identity"]
        names = ("Require complete Core and original component gates", "Retain exact raw component evidence") if scope == "components" else (
            "Require original full app and unchanged source", "Retain actual full app compile evidence")
        jobs.append({"id": index, "name": route.JOBS[scope], "run_id": context["run_id"],
            "run_attempt": context["run_attempt"], "head_sha": context["head_sha"], "head_branch": route.BRANCH,
            "status": "completed", "conclusion": "success", "started_at": "2026-11-20T00:00:00Z",
            "completed_at": "2026-11-20T00:01:00Z", "steps": [
                {"name": name, "status": "completed", "conclusion": "success"} for name in names]})
    return before, after, jobs, context, {scope: "success" for scope in route.JOBS}


class Controls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="combined-annotation-route-controls-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def test_exact_push_identity_accepts_only_bound_run(self):
        env, event = authority()
        value = route.identity(env, event)
        self.assertEqual((value["run_id"], value["run_attempt"]), (111, 1))
        for key, replacement in (("GITHUB_EVENT_NAME", "workflow_dispatch"), ("GITHUB_REF", "refs/heads/main"),
                ("GITHUB_REPOSITORY", "other/repository"), ("GITHUB_WORKFLOW_SHA", "b" * 40),
                ("EXPECTED_CHECKOUT_SHA", "b" * 40), ("GITHUB_RUN_ATTEMPT", "0")):
            bad = dict(env); bad[key] = replacement
            with self.subTest(key=key), self.assertRaises(ValueError): route.identity(bad, event)

    def test_push_payload_cannot_substitute_another_source_or_fork(self):
        env, event = authority()
        for update in (lambda x: x.update(after="b" * 40), lambda x: x.update(deleted=True),
                       lambda x: x["repository"].update(fork=False), lambda x: x["repository"].update(id=True)):
            bad = copy.deepcopy(event); update(bad)
            with self.assertRaises(ValueError): route.identity(env, bad)

    def test_bound_source_core_counts_budgets_and_api_scope(self):
        binding = route.load_json(ROOT / route.BINDING)
        route.validate_binding(binding)
        for key in ("application_source", "application_tree", "source_parent", "core_tree"):
            bad = copy.deepcopy(binding); bad[key] = "0" * 40
            with self.subTest(key=key), self.assertRaises(ValueError): route.validate_binding(bad)
        for path in ("counts", "budgets"):
            for key in binding[path]:
                bad = copy.deepcopy(binding); bad[path][key] += 1
                with self.subTest(path=path, key=key), self.assertRaises(ValueError): route.validate_binding(bad)

    def test_unfinalized_or_syntax_enforcement_claim_cannot_execute(self):
        binding = route.load_json(ROOT / route.BINDING)
        for update in (lambda x: x.update(source_sealed=False),
                       lambda x: x["api_compatibility"].update(explicit_label_syntax_enforced=True)):
            bad = copy.deepcopy(binding); update(bad)
            with self.assertRaises(ValueError): route.validate_binding(bad)

    def test_source_delta_preserves_product_and_swift_oracles(self):
        rows = [("M", p) for p in route.MODIFIED] + [("A", p) for p in route.ADDED_RUNTIME]
        rows += [("A", route.DOCS + "review.json"), ("A", route.HISTORICAL_DOC)]
        route.validate_delta(rows)
        for extra in (("M", route.CORE_MANAGER), ("M", route.SYNC_MANAGER), ("M", route.PROJECT),
                      ("A", "Source/Injected.swift"), ("D", route.HQ_DRIVER), ("A", "Scripts/CI/unreviewed.py")):
            with self.subTest(extra=extra), self.assertRaises(ValueError): route.validate_delta(rows + [extra])

    def test_missing_original_metadata_path_or_duplicate_delta_is_rejected(self):
        rows = [("M", p) for p in route.MODIFIED] + [("A", p) for p in route.ADDED_RUNTIME]
        for bad in (rows[1:], rows + [rows[0]]):
            with self.assertRaises(ValueError): route.validate_delta(bad)

    def test_original_core_classifier_retains_signal_and_partial_leaf_refusals(self):
        core = route.module(ROOT, route.CORE_DRIVER, "original_core_classifier_controls")
        expected = {"A/testOne": "passed", "A/testTwo": "failed"}
        raw = "\n".join(["Test Case 'A.testOne' started.", "Test Case 'A.testOne' passed (0.001 seconds).",
                         "Test Case 'A.testTwo' started.", "Test Case 'A.testTwo' failed (0.001 seconds).",
                         "Executed 2 tests, with 1 failure (0 unexpected)"])
        parsed = core.parse_xctest(raw)
        self.assertTrue(core.classify_run({"returncode": 1, "timed_out": False}, parsed, expected)["qualified"])
        for code in (-9, -15, 2, 70, 137, 0, None):
            with self.subTest(code=code):
                self.assertFalse(core.classify_run({"returncode": code, "timed_out": False}, parsed, expected)["qualified"])
        partial = copy.deepcopy(parsed); partial["leaves"].pop()
        self.assertFalse(core.classify_run({"returncode": 1, "timed_out": False}, partial, expected)["qualified"])

    def test_original_core_whole_input_closure_is_exact_candidate_source(self):
        core = route.module(ROOT, route.CORE_DRIVER, "original_core_source_controls")
        manifest = route.load_json(ROOT / route.CORE_MANIFEST)
        rows = core.verify_inputs(ROOT, manifest)
        declarations = manifest["core_inputs"] + manifest["review_inputs"] + manifest["support_inputs"]
        self.assertEqual(len(declarations), 62)
        self.assertEqual({row["path"] for row in rows}, {row["path"] for row in declarations})
        self.assertEqual(len(rows), len({row["path"] for row in declarations}))
        self.assertEqual(len(core.declared_cases(ROOT)), 194)
        self.assertEqual((len(manifest["baseline_expected_pass"]), len(manifest["baseline_expected_fail"])), (11, 9))

    def core_fixture(self):
        """Exact declared source and explicitly synthetic XCTest output only."""
        core = route.module(ROOT, route.CORE_DRIVER, "core_raw_route_fixture")
        manifest = route.load_json(ROOT / route.CORE_MANIFEST)
        output = self.root / route.CORE_OUTPUT
        output.mkdir(parents=True)
        source = sample_source("components")
        source["checkout_root"] = str(self.root)
        source["files"] = {route.CORE_MANIFEST: route.record(ROOT, route.CORE_MANIFEST)}
        rows = core.verify_inputs(ROOT, manifest)
        write(output / "source-before.json", rows); write(output / "source-after.json", rows)
        context = source["identity"]
        report = {"status": "PASS_APPLE_CORE_194_WITH_BASELINE20_RED", "git_head": context["head_sha"],
            "inputs_sha256": source["files"][route.CORE_MANIFEST]["sha256"], "declared_original": 174,
            "declared_added": 20, "actual_xctest_completed": 214, "native_ui_executed": 0, "actual_c_engine_executed": 0,
            "github": {"GITHUB_REPOSITORY": route.REPOSITORY, "GITHUB_REF": "refs/heads/" + route.BRANCH,
                "GITHUB_SHA": context["head_sha"], "GITHUB_RUN_ID": str(context["run_id"]),
                "GITHUB_RUN_ATTEMPT": str(context["run_attempt"]), "GITHUB_JOB": "components"}, "stages": {}}
        for name in ("baseline20", "candidate194"):
            expected = ({case: "passed" for case in manifest["baseline_expected_pass"]} |
                        {case: "failed" for case in manifest["baseline_expected_fail"]}) if name == "baseline20" else {
                            case: "passed" for case in manifest["original_cases"] + manifest["added_cases"]}
            lines = ["EXPLICIT SYNTHETIC XCTEST RECEIPT; NO SWIFT EXECUTED"]
            for case, outcome in expected.items():
                owner, method = case.split("/")
                lines.extend([f"Test Case '{owner}.{method}' started.", f"Test Case '{owner}.{method}' {outcome} (0.001 seconds)."])
            lines.append(f"Executed {len(expected)} tests, with {sum(x == 'failed' for x in expected.values())} failures (0 unexpected)")
            data = ("\n".join(lines) + "\n").encode(); (output / (name + ".log")).write_bytes(data)
            command = ["xcrun", "swift", "test", "--package-path", str(output / "exact-source-work" / route.CORE),
                       "--scratch-path", str(output / "swiftpm-cache"), "--jobs", "1", "--disable-swift-testing"]
            if name == "baseline20": command += ["--filter", "ColdSearchExecutionOfflineTests"]
            process = {"returncode": 1 if name == "baseline20" else 0, "timed_out": False,
                       "command": command, "cwd": str(self.root), "log_sha256": route.digest(data)}
            stage = {"process": process, **core.classify_run(process, core.parse_xctest(data.decode()), expected), "source_unchanged": True}
            report["stages"][name] = stage; write(output / (name + ".result.json"), stage)
            hashes = {row["path"]: row["sha256"] for row in manifest["core_inputs"]}
            if name == "baseline20": hashes[core.EXECUTOR] = manifest["baseline_executor"]["sha256"]
            write(output / (name + ".source-before.json"), hashes); write(output / (name + ".source-after.json"), hashes)
        write(output / "RESULT.json", report)
        return output, source

    def test_whole_core_result_consumer_replays_exact_twenty_and194_raw_leaf_names(self):
        output, source = self.core_fixture()
        result = route.verify_core(ROOT, source, output)
        self.assertEqual(result["stages"]["baseline20"]["failed"], 9)
        self.assertEqual(result["stages"]["candidate194"]["passed"], 194)

    def test_core_raw_result_cannot_move_to_another_attempt(self):
        output, source = self.core_fixture()
        path = output / "RESULT.json"; report = route.load_json(path)
        report["github"]["GITHUB_RUN_ATTEMPT"] = "2"; write(path, report)
        with self.assertRaises(ValueError): route.verify_core(ROOT, source, output)

    def test_core_post_summary_signal_is_rejected_even_if_all_receipts_agree(self):
        output, source = self.core_fixture()
        report_path = output / "RESULT.json"; report = route.load_json(report_path)
        stage = report["stages"]["baseline20"]; stage["process"]["returncode"] = -9
        write(output / "baseline20.result.json", stage); write(report_path, report)
        with self.assertRaises(ValueError): route.verify_core(ROOT, source, output)

    def test_core_raw_leaf_failure_cannot_be_hidden_by_summary_or_pass_receipt(self):
        output, source = self.core_fixture()
        path = output / "candidate194.log"
        data = path.read_bytes().replace(b"passed (0.001 seconds).", b"failed (0.001 seconds).", 1); path.write_bytes(data)
        report_path = output / "RESULT.json"; report = route.load_json(report_path)
        stage = report["stages"]["candidate194"]; stage["process"]["log_sha256"] = route.digest(data)
        write(output / "candidate194.result.json", stage); write(report_path, report)
        with self.assertRaises(ValueError): route.verify_core(ROOT, source, output)

    def test_core_baseline_cannot_run_candidate_executor_and_claim_expected_red(self):
        output, source = self.core_fixture()
        candidate = route.load_json(output / "candidate194.source-before.json")
        write(output / "baseline20.source-before.json", candidate)
        write(output / "baseline20.source-after.json", candidate)
        with self.assertRaises(ValueError): route.verify_core(ROOT, source, output)

    def test_core_original_swiftpm_invocation_cannot_drop_jobs_or_select_subset(self):
        output, source = self.core_fixture()
        path = output / "RESULT.json"; report = route.load_json(path)
        stage = report["stages"]["candidate194"]; stage["process"]["command"] += ["--filter", "OnlyOneCase"]
        write(output / "candidate194.result.json", stage); write(path, report)
        with self.assertRaises(ValueError): route.verify_core(ROOT, source, output)

    def test_two_successful_exact_jobs_and_complete_receipts_are_required(self):
        fixture = aggregate_fixture()
        result = route.validate_aggregate(*fixture)
        self.assertEqual(set(result), {"components", "full_app"})

    def test_partial_success_or_skipped_full_app_never_qualifies(self):
        for scope in route.JOBS:
            for outcome in ("failure", "cancelled", "skipped", None):
                values = list(aggregate_fixture()); values[4][scope] = outcome
                with self.subTest(scope=scope, outcome=outcome), self.assertRaises(ValueError): route.validate_aggregate(*values)

    def test_missing_or_duplicate_job_cannot_count_twice(self):
        for kind in ("missing", "duplicate", "same_id"):
            values = list(aggregate_fixture())
            if kind == "missing": values[2].pop()
            elif kind == "duplicate": values[2].append(copy.deepcopy(values[2][0]))
            else: values[2][1]["id"] = values[2][0]["id"]
            with self.subTest(kind=kind), self.assertRaises(ValueError): route.validate_aggregate(*values)

    def test_cross_run_attempt_head_and_branch_job_rejected(self):
        for key, value in (("run_id", 222), ("run_attempt", 2), ("head_sha", "b" * 40), ("head_branch", "main")):
            values = list(aggregate_fixture()); values[2][0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): route.validate_aggregate(*values)

    def test_failed_gate_or_upload_step_never_qualifies(self):
        for scope_index in range(2):
            for step_index in range(2):
                for value in ("failure", "skipped", "cancelled"):
                    values = list(aggregate_fixture()); values[2][scope_index]["steps"][step_index]["conclusion"] = value
                    with self.subTest(scope=scope_index, step=step_index, value=value), self.assertRaises(ValueError): route.validate_aggregate(*values)

    def test_unqualified_or_failed_producer_status_rejected(self):
        for scope in route.JOBS:
            for status in ("FAILED", "UNQUALIFIED", "SOURCE_BOUND_NOT_EXECUTED"):
                values = list(aggregate_fixture()); values[1][scope]["status"] = status
                with self.subTest(scope=scope, status=status), self.assertRaises(ValueError): route.validate_aggregate(*values)

    def test_before_after_source_change_rejected(self):
        for scope in route.JOBS:
            values = list(aggregate_fixture()); values[1][scope]["source"]["files"]["new"] = {"sha256": "e" * 64}
            with self.subTest(scope=scope), self.assertRaises(ValueError): route.validate_aggregate(*values)

    def test_two_jobs_cannot_use_distinct_internally_stable_inputs(self):
        values = list(aggregate_fixture())
        for receipts in values[:2]: receipts["full_app"]["source"]["files"]["new"] = {"sha256": "e" * 64}
        with self.assertRaises(ValueError): route.validate_aggregate(*values)

    def test_current_core194_cannot_be_inferred_from_old_component_gate(self):
        values = list(aggregate_fixture()); values[1]["components"].pop("core")
        with self.assertRaises(ValueError): route.validate_aggregate(*values)
        values = list(aggregate_fixture())
        for receipts in values[:2]: receipts["components"]["source"]["core_tree"] = "5d0ee482c8f10726fe3863792dac94c18e94d792"
        with self.assertRaises(ValueError): route.validate_aggregate(*values)

    def test_missing_local_cloud_cold_exchange_or_race_result_rejected(self):
        for key in ("local_cases", "cloud_cases", "local_cold_reopen_gates", "exchange_cases", "exchange_abrupt_process_reopen_gates"):
            values = list(aggregate_fixture()); values[1]["components"]["original_gates"][key] -= 1
            with self.subTest(key=key), self.assertRaises(ValueError): route.validate_aggregate(*values)
        values = list(aggregate_fixture()); values[1]["components"]["race_gates"]["original_red_counts_as_pass"] = True
        with self.assertRaises(ValueError): route.validate_aggregate(*values)

    def test_full_app_must_retain_actual_caller_compiler_inputs(self):
        values = list(aggregate_fixture()); values[1]["full_app"]["app"]["actual_file_lists"] = []
        with self.assertRaises(ValueError): route.validate_aggregate(*values)
        values = list(aggregate_fixture()); values[1]["full_app"]["source"]["post_build_product_audit"] = None
        with self.assertRaises(ValueError): route.validate_aggregate(*values)

    def test_main_produced_uppercase_receipts_are_read_by_actual_aggregate_consumer(self):
        # Execute actual main's file producer and the actual consumer, with
        # explicit source/execution doubles only at external-operation seams.
        env = {"COMBINED_" + name.upper() + "_OUTCOME": "success"
               for name in ("toolchain", "controls", "core", "local", "exchange", "race", "node", "ruby", "build")}
        archive = {"archive": "synthetic-not-a-real-run.tar.gz", "members": []}
        for scope in route.JOBS:
            source = sample_source(scope)
            for phase in ("before", "after"):
                observed = copy.deepcopy(source)
                if phase == "after" and scope == "full_app": observed["post_build_product_audit"] = {"synthetic": True}
                argv = ["gate", "--root", str(self.root), "--phase", phase, "--scope", scope]
                with patch.object(sys, "argv", argv), patch.dict(os.environ, env), patch.object(route, "observe", return_value=observed), \
                     patch.object(route, "archive_sources", return_value={"synthetic": True}), patch.object(route, "verify_python_controls", return_value={}), \
                     patch.object(route, "verify_core", return_value=sample_core()), patch.object(route, "verify_original_gates", return_value=sample_original()), \
                     patch.object(route, "verify_race", return_value=sample_race()), patch.object(route, "verify_full_app", return_value={"status": "PASS_ORIGINAL_FULL_APP_COMPILE", "actual_file_lists": [{"synthetic": True}]}), \
                     patch.object(route, "pack_raw", return_value=archive):
                    self.assertEqual(route.main(), 0)
        before, after = route.read_producer_receipts(self.root / route.OUTPUT)
        self.assertEqual(set(before), set(route.JOBS))
        self.assertEqual(after["components"]["status"], "PASS_CORE194_ALL_ORIGINAL_COMPONENTS")
        for scope in route.JOBS:
            directory = self.root / route.OUTPUT / scope
            self.assertTrue((directory / "RESULT_AFTER.json").is_file())
            self.assertNotIn("RESULT_after.json", {entry.name for entry in directory.iterdir()})

    def test_main_missing_stage_outcome_keeps_failed_receipt(self):
        scope = "components"; output = self.root / route.OUTPUT / scope
        source = sample_source(scope)
        write(output / route.receipt_name("before"), {"status": "SOURCE_BOUND_NOT_EXECUTED", "source": source})
        argv = ["gate", "--root", str(self.root), "--phase", "after", "--scope", scope]
        with patch.object(sys, "argv", argv), patch.dict(os.environ, {}, clear=True), \
             patch.object(route, "observe", return_value=source), patch.object(route, "archive_sources", return_value={}), \
             patch.object(route, "pack_raw", return_value={"explicit_partial": True}):
            self.assertEqual(route.main(), 1)
        result = route.load_json(output / route.receipt_name("after"))
        self.assertEqual(result["status"], "FAILED")
        self.assertNotIn("core", result)

    def test_original_receipt_cannot_be_overwritten_by_second_main(self):
        output = self.root / route.OUTPUT / "components"
        write(output / route.receipt_name("before"), {"retained": True})
        with patch.object(sys, "argv", ["gate", "--root", str(self.root), "--phase", "before", "--scope", "components"]), self.assertRaises(ValueError):
            route.main()
        self.assertEqual(route.load_json(output / route.receipt_name("before")), {"retained": True})

    def make_raw(self):
        output = self.root / route.OUTPUT / "components"; output.mkdir(parents=True)
        owned = self.root / route.RACE_OUTPUT / "owned-explicit-controls"
        (owned / "fixtures/case/markers").mkdir(parents=True)
        (owned / "package/Sources/Target").mkdir(parents=True)
        (owned / "package/Sources/Target/Whole.swift").write_text("// explicit noncompiled source boundary\n")
        binary = owned / "package/.build/arm64-apple-macosx/debug/DisconnectCandidate"
        binary.parent.mkdir(parents=True); binary.write_bytes(b"explicit binary-shaped bytes; never executed")
        binary.chmod(0o755)
        write(self.root / route.RACE_OUTPUT / "RESULT.json", {"executables": {str(binary): route.digest(binary.read_bytes())}})
        manifest = route.pack_raw(self.root, "components", output / "RAW_EVIDENCE.tar.gz")
        write(output / "RAW_MANIFEST.json", manifest)
        return output, owned, binary, manifest

    def test_raw_pack_retains_empty_marker_directory_and_exact_binary_bytes(self):
        output, owned, binary, manifest = self.make_raw()
        destination = self.root / "readback"
        route.unpack_raw(output, destination)
        marker = destination / owned.relative_to(self.root) / "fixtures/case/markers"
        self.assertTrue(marker.is_dir()); self.assertEqual(list(marker.iterdir()), [])
        self.assertEqual((destination / binary.relative_to(self.root)).read_bytes(), binary.read_bytes())
        self.assertTrue(any(row["path"] == str(binary.relative_to(self.root)) and row["mode"] == 0o755 for row in manifest["members"]))

    def test_raw_archive_hash_or_inventory_tamper_is_rejected(self):
        output, _, _, manifest = self.make_raw()
        manifest["sha256"] = "0" * 64; write(output / "RAW_MANIFEST.json", manifest)
        with self.assertRaises(ValueError): route.unpack_raw(output, self.root / "bad")

    def test_raw_producer_cannot_silently_omit_or_change_reported_executable(self):
        output, _, binary, _ = self.make_raw()
        binary.write_bytes(b"changed after the real producer gate")
        with self.assertRaises(ValueError): route.pack_raw(self.root, "components", output / "changed-raw.tar.gz")
        binary.unlink()
        with self.assertRaises(ValueError): route.pack_raw(self.root, "components", output / "missing-raw.tar.gz")

    def test_linux_retention_gate_reads_both_binaries_and_all_empty_marker_dirs_without_execution(self):
        binding = route.load_json(ROOT / route.BINDING)
        original = Path("/Users/runner/work/Maktabah/Maktabah")
        relative = Path(route.RACE_OUTPUT) / "owned-explicit-retention-controls"
        owned = self.root / relative
        names = ["baseline-deadlock", *binding["case_names"]["disconnect"]]
        for name in names: (owned / "fixtures" / name / "markers").mkdir(parents=True)
        pins = {}
        for name in ("DisconnectBaseline", "DisconnectCandidate"):
            path = owned / "package/.build/arm64-apple-macosx/debug" / name
            path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(b"explicit nonexecutable fixture " + name.encode())
            pins[str(original / path.relative_to(self.root))] = route.digest(path.read_bytes())
        write(self.root / route.RACE_OUTPUT / "RESULT.json", {"status": "PASS_APPLE_REPOSITORY_RED_AND10_GREEN",
            "executables": pins, "executables_after": pins, "owned_directory": str(original / relative)})
        result = route.verify_retained_repository(self.root, {"checkout_root": str(original)}, binding)
        self.assertEqual(result["Apple_executables_executed_on_aggregate"], 0)
        self.assertEqual(result["original_marker_directories"], 11)
        (owned / "fixtures" / names[-1] / "markers").rmdir()
        with self.assertRaises(ValueError): route.verify_retained_repository(self.root, {"checkout_root": str(original)}, binding)

    def test_raw_member_duplicate_type_or_mode_cannot_be_substituted(self):
        for kind in ("duplicate", "mode", "type"):
            case_root = self.root / kind; case_root.mkdir()
            output = case_root / "artifact"; output.mkdir()
            data = b"retained raw"
            path = output / "RAW_EVIDENCE.tar.gz"
            with tarfile.open(path, "w:gz") as archive:
                entry = tarfile.TarInfo("build/one.txt"); entry.size = len(data); entry.mode = 0o644
                archive.addfile(entry, io.BytesIO(data))
            row = {"path": "build/one.txt", "type": "file", "mode": 0o644, "bytes": len(data), "sha256": route.digest(data)}
            manifest = {"archive": path.name, "bytes": path.stat().st_size, "sha256": route.digest(path.read_bytes()), "members": [row]}
            if kind == "duplicate": manifest["members"].append(dict(row))
            elif kind == "mode": row["mode"] = 0o755
            else: row["type"] = "directory"
            write(output / "RAW_MANIFEST.json", manifest)
            with self.subTest(kind=kind), self.assertRaises(ValueError): route.unpack_raw(output, case_root / "readback")

    def test_raw_symlink_cannot_escape_owned_evidence(self):
        output = self.root / route.OUTPUT / "components"; output.mkdir(parents=True)
        directory = self.root / route.RACE_OUTPUT / "owned-fixture/fixtures"; directory.mkdir(parents=True)
        external = self.root / "outside.txt"; external.write_text("outside owned fixture")
        (directory / "alias").symlink_to(external)
        with self.assertRaises(ValueError): route.pack_raw(self.root, "components", output / "RAW_EVIDENCE.tar.gz")

    def test_raw_traversal_member_denied_before_any_external_write(self):
        output = self.root / "artifact"; output.mkdir()
        archive = output / "RAW_EVIDENCE.tar.gz"
        data = b"not admitted"
        with tarfile.open(archive, "w:gz") as source:
            item = tarfile.TarInfo("../escaped"); item.size = len(data); item.mode = 0o644
            source.addfile(item, io.BytesIO(data))
        write(output / "RAW_MANIFEST.json", {"archive": archive.name, "bytes": archive.stat().st_size,
            "sha256": route.digest(archive.read_bytes()), "members": [
                {"path": "../escaped", "type": "file", "mode": 0o644, "bytes": len(data), "sha256": route.digest(data)}]})
        with self.assertRaises(ValueError): route.unpack_raw(output, self.root / "readback")
        self.assertFalse((self.root / "escaped").exists())

    def app_fixture(self, members):
        source = sample_source("full_app")
        source["files"] = {path: route.record(ROOT, path) for path in (route.HQ_DRIVER, route.HQ_INPUTS, route.CORE_MANAGER, route.SYNC_MANAGER)}
        rawlog = self.root / "build/artifacts/runtime27/build-for-testing-driver.log"
        rawlog.parent.mkdir(parents=True); rawlog.write_bytes(b"EXPLICIT SYNTHETIC BUILD RECEIPT ONLY\n")
        write(self.root / route.OUTPUT / "full_app/BUILD_PROCESS.json", {
            "status": "ORIGINAL_BUILD_DRIVER_EXIT_ZERO", "exit_code": 0, "timed_out": False, "timeout_seconds": 4200,
            "identity": source["identity"], "application_source": route.SOURCE_M, "native_ui_executed": 0,
            "command": ["python3", route.HQ_DRIVER, "--build-for-testing", "--derived-data", "build/DerivedData"],
            "supervisor": route.RUNTIME, "log_sha256": route.digest(rawlog.read_bytes())})
        write(self.root / "build/hq-stage2/result.json", {
            "status": "SIMULATOR_BUILD_FOR_REAL_UI_PASS", "scope": "SIMULATOR_BUILD_FOR_REAL_UI", "signing": "SIMULATOR_AD_HOC_ONLY",
            "checkout_sha": source["identity"]["head_sha"], "application_source_sha": route.SOURCE_M,
            "application_trees": {p: route.PROTECTED_TREES[p] for p in ("Source", "Vendor", "Maktabah.xcodeproj")},
            "validator_sha256": source["files"][route.HQ_DRIVER]["sha256"], "inputs_sha256": source["files"][route.HQ_INPUTS]["sha256"]})
        lists = self.root / "build/DerivedData/Build/Intermediates.noindex/OriginalTarget.build/Objects-normal/arm64/Original.SwiftFileList"
        lists.parent.mkdir(parents=True)
        lists.write_text("\n".join(str((self.root / p).resolve()) for p in members) + "\n")
        return source, lists

    def test_full_app_actual_list_requires_both_original_complete_sources(self):
        source, lists = self.app_fixture([route.CORE_MANAGER, route.SYNC_MANAGER])
        report = route.verify_full_app(self.root, source)
        self.assertEqual(len(report["actual_file_lists"]), 1)
        self.assertEqual(set(report["actual_file_lists"][0]["actual_original_sources"]), {route.CORE_MANAGER, route.SYNC_MANAGER})

    def test_full_app_incomplete_or_basename_only_list_is_rejected(self):
        source, lists = self.app_fixture([route.CORE_MANAGER])
        with self.assertRaises(ValueError): route.verify_full_app(self.root, source)
        lists.write_text(Path(route.CORE_MANAGER).name + "\n" + Path(route.SYNC_MANAGER).name + "\n")
        with self.assertRaises(ValueError): route.verify_full_app(self.root, source)

    def test_full_app_original_timeout_and_log_digest_are_required(self):
        source, _ = self.app_fixture([route.CORE_MANAGER, route.SYNC_MANAGER])
        path = self.root / route.OUTPUT / "full_app/BUILD_PROCESS.json"
        original = route.load_json(path)
        for key, value in (("timeout_seconds", 4201), ("timed_out", True), ("exit_code", 1), ("log_sha256", "e" * 64)):
            bad = dict(original); bad[key] = value; write(path, bad)
            with self.subTest(key=key), self.assertRaises(ValueError): route.verify_full_app(self.root, source)

    def test_no_component_success_can_stand_in_for_full_app_helper_status(self):
        source, _ = self.app_fixture([route.CORE_MANAGER, route.SYNC_MANAGER])
        path = self.root / "build/hq-stage2/result.json"; report = route.load_json(path)
        report["status"] = "PASS_APPLE_FOUNDATION_CLOUD48_LOCAL43_COLD2"; write(path, report)
        with self.assertRaises(ValueError): route.verify_full_app(self.root, source)

    def test_new_workflow_keeps_two_required_jobs_original_arguments_and_zero_native_execution(self):
        text = (ROOT / route.WORKFLOW).read_text()
        self.assertIn("needs: [components, full_app]", text)
        self.assertIn("COMBINED_COMPONENTS_JOB_RESULT: ${{ needs.components.result }}", text)
        self.assertIn("COMBINED_FULL_APP_JOB_RESULT: ${{ needs.full_app.result }}", text)
        self.assertEqual(text.count("runs-on: xcode-27"), 2)
        self.assertIn("--expected-inputs-sha256 " + route.record(ROOT, route.CORE_MANIFEST)["sha256"], text)
        self.assertNotIn("test-without-building", text)
        self.assertNotIn("--runtime-only", text)
        self.assertNotIn("continue-on-error: true\n        run: python3 Scripts/CI/annotation-combined-core194-apple.py --phase after", text)


    def test_complete_core_inventory_includes_the_original_integration_inputs(self):
        pins = route.load_json(ROOT / route.BINDING)["source_pins"]
        core = {path: value for path, value in pins.items() if path.startswith(route.CORE + "/")}
        self.assertEqual(len(core), 54)
        required = {route.CORE + "/Integration/" + name for name in (
            "ActionAppIdentityBridge.swift", "ActionLiveOccurrenceCounter.swift",
            "ActionOccurrenceCoveragePolicy.swift")}
        self.assertTrue(required <= set(core))
        route.require_complete_core_source_inventory(pins, core)

    def test_actual_v2_missing_core_inputs_and_changed_records_are_refused_before_execution(self):
        pins = route.load_json(ROOT / route.BINDING)["source_pins"]
        core = {path: value for path, value in pins.items() if path.startswith(route.CORE + "/")}
        omitted = {route.CORE + "/" + path for path in (
            ".gitignore", "README.md", "Integration/ActionAppIdentityBridge.swift",
            "Integration/ActionLiveOccurrenceCounter.swift",
            "Integration/ActionOccurrenceCoveragePolicy.swift")}
        actual_v2 = {path: value for path, value in pins.items() if path not in omitted}
        with self.assertRaisesRegex(ValueError, "Whole original Core input missing or changed"):
            route.require_complete_core_source_inventory(actual_v2, core)
        for path in sorted(omitted):
            with self.subTest(path=path):
                changed = copy.deepcopy(pins)
                changed[path]["bytes"] += 1
                with self.assertRaisesRegex(ValueError, "Whole original Core input missing or changed"):
                    route.require_complete_core_source_inventory(changed, core)
        with self.assertRaisesRegex(ValueError, "Whole original Core inventory missing"):
            route.require_complete_core_source_inventory(pins, {})


def case_names():
    return unittest.defaultTestLoader.getTestCaseNames(Controls)


class RecordingResult(unittest.TextTestResult):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs); self.rows = []
    def startTest(self, test):
        self.failed_current = False; super().startTest(test)
    def addFailure(self, test, err):
        self.failed_current = True; super().addFailure(test, err)
    def addError(self, test, err):
        self.failed_current = True; super().addError(test, err)
    def addSkip(self, test, reason):
        self.failed_current = True; super().addSkip(test, reason)
    def addSubTest(self, test, subtest, err):
        if err is not None: self.failed_current = True
        super().addSubTest(test, subtest, err)
    def stopTest(self, test):
        self.rows.append({"name": test._testMethodName, "status": "FAIL" if self.failed_current else "PASS"})
        super().stopTest(test)


def main():
    parser = argparse.ArgumentParser(); parser.add_argument("--artifacts-dir", type=Path, required=True)
    args = parser.parse_args(); destination = args.artifacts_dir / "RESULT.json"
    if destination.exists(): raise ValueError("Preserve prior control result")
    args.artifacts_dir.mkdir(parents=True, exist_ok=True)
    names = case_names()
    result = unittest.TextTestRunner(verbosity=2, resultclass=RecordingResult).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    passed = result.wasSuccessful() and not result.skipped and [row["name"] for row in result.rows] == names
    report = {"status": "PASS_PYTHON_ROUTE_CONTROLS" if passed else "FAILED", "names": names,
        "cases": result.rows, "executed": result.testsRun, "failures": len(result.failures), "errors": len(result.errors),
        "skips": len(result.skipped), "Swift_executed": 0, "Native_executed": 0,
        "scope": "Actual Python source/packaging checks, original parser with explicit synthetic receipts; no Apple execution"}
    write(destination, report)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
