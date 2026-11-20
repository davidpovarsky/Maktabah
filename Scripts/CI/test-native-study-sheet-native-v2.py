#!/usr/bin/env python3
"""Synthetic source/result controls only; no app or Native execution credit."""
import argparse
import contextlib
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PARSER = argparse.ArgumentParser()
PARSER.add_argument("--base-dir", type=Path)
ARGS, OTHER = PARSER.parse_known_args()
if ARGS.base_dir:
    sys.path.insert(0, str(ARGS.base_dir / "Scripts/CI"))
G = runpy.run_path(str(HERE / "native-study-sheet-native-v2.py"))
RUNTIME = runpy.run_path(str(HERE / "runtime27.py"))


def original(path):
    if ARGS.base_dir:
        return (ARGS.base_dir / path).read_bytes()
    return subprocess.check_output(["git", "show", G["BASE"] + ":" + path], cwd=ROOT)


class FocusedBoundary(unittest.TestCase):
    def setUp(self):
        self.old_manifest = json.loads(original(G["ORIGINAL_MANIFEST"]))
        self.manifests = {name: json.loads((ROOT / row["manifest"]).read_bytes()) for name, row in G["CONFIGURATIONS"].items()}
        self.pins = [json.loads((ROOT / G["INPUTS"]).read_bytes()), json.loads(original(G["INPUTS"])),
                     (ROOT / G["ADDITIONS"]).read_bytes(), original(G["ADDITIONS"]),
                     (ROOT / G["RUNTIME"]).read_bytes(), original(G["RUNTIME"])]
        self.head = "a" * 40
        self.context = {"repository": "davidpovarsky/Maktabah", "run_id": "123456",
                        "run_attempt": "1", "head": self.head, "ref": G["REF"]}
        self.build = {"checkout_sha": self.head, "status": "SIMULATOR_BUILD_FOR_REAL_UI_PASS",
                      "application_source_sha": G["BASE"],
                      "application_trees": {k: G["TREES"][k] for k in ("Source", "Vendor", "Maktabah.xcodeproj")}}
        self.data = {}
        self.records = {}
        for name, config in G["CONFIGURATIONS"].items():
            count = len(config["cases"])
            outcomes = [dict(case_id=case, actual="Passed", device=name, configuration_label=config["label"]) for case in config["cases"]]
            ui = {"checkout_sha": self.head, "status": "SELECTED_UI_EXECUTED_PASS", "mode": "ui",
                  "full_release_acceptance": False, "distribution": False, "test_source_commit": G["BASE"],
                  "test_tree": G["TREES"]["Maktabah-iOSUITests"], "requested_ui_case_count": count,
                  "executed_ui_pass": count, "executed_ui_fail": 0, "executed_ui_skip": 0, "ui_not_run": 0,
                  "case_outcomes": outcomes,
                  "case_manifest_sha256": hashlib.sha256((ROOT / config["manifest"]).read_bytes()).hexdigest(),
                  "helper_inputs_sha256": {G["RUNTIME"]: hashlib.sha256((ROOT / G["RUNTIME"]).read_bytes()).hexdigest()}}
            self.data[name] = {"ui": ui, "summary": {"passedTests": count, "failedTests": 0, "skippedTests": 0, "expectedFailures": 0},
                               "leaves": [(case, "Passed") for case in config["cases"]]}
            common = {"head": self.head, "application_and_tests": G["BASE"], "context": copy.deepcopy(self.context),
                      "configuration": name, "full_native116_acceptance": False, "full_release114_acceptance": False}
            source = {**common, "status": "SOURCE_BOUND_ONLY", "trees": G["TREES"], "manifest": config["manifest"],
                      "execution_inputs": {G["RUNTIME"]: {"sha256": ui["helper_inputs_sha256"][G["RUNTIME"]]}}}
            self.records[name] = {"result": {**common, "status": "SELECTED_ADDITIVE_NATIVE_CASES_PASS", "selected_count": count, "case_outcomes": outcomes},
                                  "before": copy.deepcopy({**source, "phase": "before"}), "after": copy.deepcopy({**source, "phase": "after"})}

    def validate(self, name="ipad11"):
        d = self.data[name]
        G["validate_outcomes"](d["ui"], self.build, d["summary"], d["leaves"], self.head, name)

    def rejected(self, name="ipad11"):
        with self.assertRaises(ValueError):
            self.validate(name)

    def aggregate(self, matrix="success"):
        return G["validate_aggregate"](self.records, self.head, self.context, matrix)

    def foundation_data(self):
        driver = runpy.run_path(str(ROOT / "tools/hq-native-study-sheet-lifecycle.py"))
        raw_inputs, execution, product = {}, {}, {}
        for path, entry in G["BINDING"]["foundation_inputs"].items():
            record = {"blob": entry["git_blob"], "bytes": entry["bytes"], "sha256": entry["sha256"]}
            (product if path.startswith("Source/") else execution)[path] = record
            if path == "tools/hq-native-study-sheet-lifecycle.py":
                continue
            key = "before_workspace" if path.endswith("/interactive-dismissal-before.swift") else path
            raw_inputs[key] = entry["sha256"]
        stages = []
        for phase, file, failures in (
                ("baseline", "NativeStudySheetOwnerAcceptance.swift", driver["EXPECTED_RED"]),
                ("candidate", "NativeStudySheetOwnerAcceptance.swift", set()),
                ("lifecycle", "NativeStudySheetLifecycleAcceptance.swift", set())):
            declared = driver["case_ids"]((ROOT / driver["FIXTURES"] / file).read_text())
            stages.append({"phase": phase, "declared": declared, "expected_failures": sorted(failures),
                           "compile": {"returncode": 0, "timeout": False},
                           "runtime": {"returncode": 1 if failures else 0, "timeout": False},
                           "checks": [{"id": name, "passed": name not in failures} for name in declared],
                           "executed": len(declared), "qualified": True})
        raw = {"qualified": True, "before": raw_inputs, "after": copy.deepcopy(raw_inputs), "stages": stages}
        result = {"status": "FOUNDATION25_PASS", "head": self.head, "application_and_tests": G["BASE"],
                  "context": copy.deepcopy(self.context), "driver_exit": 0,
                  "before": execution, "after": copy.deepcopy(execution),
                  "before_product": product, "after_product": copy.deepcopy(product)}
        return raw, result

    def write_foundation_using_actual_producer(self, evidence):
        # Only the Swift process and original checkout observations are doubles.
        # The real main/foundation writer, serializer and aggregate reader choose
        # every receipt path themselves, on a case-sensitive filesystem.
        raw, result = self.foundation_data()
        namespace = G["main"].__globals__
        directory = evidence / "native-study-sheet-foundation-evidence"
        output = directory / "artifacts/native-study-sheet-native"
        with tempfile.TemporaryDirectory(prefix="foundation-source-boundary-") as temporary:
            source = Path(temporary)
            for path in G["BINDING"]["foundation_inputs"]:
                destination = source / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / path, destination)
            def source_boundary(phase, expected, configuration):
                self.assertEqual((phase, expected, configuration), ("before", self.head, "ipad11"))
                return {"execution_inputs": copy.deepcopy(result["before"]),
                        "product_inputs": copy.deepcopy(result["before_product"])}
            def process_boundary(command, **kwargs):
                self.assertEqual(command[1], "tools/hq-native-study-sheet-lifecycle.py")
                self.assertEqual(command[command.index("--before-workspace") + 1],
                                 "docs/hq-integration/native-study-sheet-20261120/interactive-dismissal-before.swift")
                target = Path(command[command.index("--output") + 1])
                G["write"](target / "RESULT.json", raw)
                return mock.Mock(wait=mock.Mock(return_value=0))
            with mock.patch.dict(namespace, {"ROOT": source, "OUT": output, "source_check": source_boundary,
                                            "github_context": lambda: self.context}), \
                    mock.patch.object(sys, "platform", "darwin"), \
                    mock.patch.object(subprocess, "Popen", side_effect=process_boundary), \
                    mock.patch.object(sys, "argv", [__file__, "foundation"]):
                self.assertEqual(G["main"](), 0)
            shutil.copytree(source / "build/native-study-sheet-foundation", directory / "native-study-sheet-foundation")

    def test_actual_foundation_qualifier_accepts_exact_twenty_plus_five(self):
        raw, result = self.foundation_data()
        self.assertEqual(G["validate_foundation"](raw, result, self.head, self.context), 25)

    def test_foundation_compile_failure_is_zero_not_expected_red(self):
        raw, result = self.foundation_data()
        raw["stages"][0]["compile"]["returncode"] = 1
        with self.assertRaises(ValueError): G["validate_foundation"](raw, result, self.head, self.context)

    def test_foundation_missing_lifecycle_or_owner_stage_rejected(self):
        for position in range(3):
            raw, result = self.foundation_data(); raw["stages"].pop(position)
            with self.subTest(position=position), self.assertRaises(ValueError):
                G["validate_foundation"](raw, result, self.head, self.context)

    def test_foundation_signal_after_complete_rows_rejected(self):
        for phase in range(3):
            raw, result = self.foundation_data(); raw["stages"][phase]["runtime"]["returncode"] = -9
            with self.subTest(phase=phase), self.assertRaises(ValueError):
                G["validate_foundation"](raw, result, self.head, self.context)

    def test_foundation_wrong_baseline_refusal_or_timeout_rejected(self):
        raw, result = self.foundation_data(); raw["stages"][0]["checks"][0]["passed"] = not raw["stages"][0]["checks"][0]["passed"]
        with self.assertRaises(ValueError): G["validate_foundation"](raw, result, self.head, self.context)
        raw, result = self.foundation_data(); raw["stages"][0]["runtime"]["timeout"] = True
        with self.assertRaises(ValueError): G["validate_foundation"](raw, result, self.head, self.context)

    def test_foundation_raw_same_but_wrong_source_rejected(self):
        raw, result = self.foundation_data()
        raw["before"]["before_workspace"] = raw["after"]["before_workspace"] = "0" * 64
        with self.assertRaises(ValueError): G["validate_foundation"](raw, result, self.head, self.context)

    def test_foundation_product_drift_after_passing_controls_rejected(self):
        raw, result = self.foundation_data(); result["after_product"] = {}
        with self.assertRaises(ValueError): G["validate_foundation"](raw, result, self.head, self.context)

    def test_foundation_unbound_driver_or_execution_source_rejected(self):
        raw, result = self.foundation_data()
        result["before"].pop("tools/hq-native-study-sheet-lifecycle.py")
        result["after"] = copy.deepcopy(result["before"])
        with self.assertRaises(ValueError): G["validate_foundation"](raw, result, self.head, self.context)

    def test_foundation_wrong_run_attempt_or_driver_exit_rejected(self):
        raw, result = self.foundation_data(); result["context"]["run_attempt"] = "2"
        with self.assertRaises(ValueError): G["validate_foundation"](raw, result, self.head, self.context)
        raw, result = self.foundation_data(); result["driver_exit"] = -9
        with self.assertRaises(ValueError): G["validate_foundation"](raw, result, self.head, self.context)

    def test_missing_foundation_artifact_cannot_qualify(self):
        with tempfile.TemporaryDirectory() as directory, self.assertRaises(FileNotFoundError):
            G["require_downloaded_foundation"](Path(directory), self.head, self.context)

    def test_current_two_metadata_scopes_preserve_all_original116(self):
        for name, manifest in self.manifests.items():
            G["validate_manifest"](manifest, self.old_manifest, name)
            groups = RUNTIME["execution_groups"](manifest)
            self.assertEqual(sum(len(group["case_ids"]) for group in groups), 11 if name == "ipad11" else 1)

    def test_actual_original_collector_accepts_new_metadata_without_execution_credit(self):
        namespace = RUNTIME["collect_cases"].__globals__
        for name, config in G["CONFIGURATIONS"].items():
            with self.subTest(configuration=name), tempfile.TemporaryDirectory() as temporary:
                report = {}
                with mock.patch.dict(namespace, {"OUT": Path(temporary)}):
                    RUNTIME["collect_cases"](report, self.manifests[name])
                self.assertEqual(report["executed_ui_pass"], 0)
                self.assertEqual(report["ui_not_run"], len(config["cases"]))
                self.assertEqual([row["case_id"] for row in report["case_outcomes"]], config["cases"])
                self.assertTrue(all(row["expected"] and row["actual"] == "NOT_RUN" for row in report["case_outcomes"]))

    def test_original_default_scope_and_unique_guard_unchanged(self):
        baseline = runpy.run_path(str(ARGS.base_dir / G["RUNTIME"])) if ARGS.base_dir else {}
        if baseline:
            self.assertEqual(RUNTIME["execution_groups"](self.old_manifest), baseline["execution_groups"](self.old_manifest))
        combined = copy.deepcopy(self.manifests["ipad11"])
        combined["execution_case_ids"].append(combined["execution_case_ids"][0])
        with self.assertRaises(ValueError): RUNTIME["execution_groups"](combined)

    def test_current_exact_runtime_path_and_project_pin_inverse(self):
        G["validate_pins"](*self.pins)

    def test_default_and_exact_two_manifest_paths_only(self):
        self.assertEqual(RUNTIME["case_contract_path"](None), ROOT / G["ORIGINAL_MANIFEST"])
        for config in G["CONFIGURATIONS"].values():
            self.assertEqual(RUNTIME["case_contract_path"](config["manifest"]), ROOT / config["manifest"])
        for path in ("", G["ORIGINAL_MANIFEST"], "/tmp/cases.json", "../cases.json", "docs/hq-integration/runtime27/native-study-sheet-ipad14.json"):
            with self.subTest(path=path), self.assertRaises(ValueError): RUNTIME["case_contract_path"](path)

    def test_finally_reuses_same_contract_path(self):
        text = (ROOT / G["RUNTIME"]).read_text()
        self.assertEqual(text.count('contract_path = case_contract_path(os.environ.get("RUNTIME27_CASE_MANIFEST"))'), 1)
        self.assertEqual(text.count("collect_cases(report, json.loads(contract_path.read_text()))"), 1)
        self.assertNotIn('collect_cases(report, json.loads((ROOT / "docs/hq-integration/runtime27/R27_CASES.json")', text)

    def test_unfinalized_binding_rejected(self):
        binding = copy.deepcopy(G["BINDING"]); binding["source_sealed"] = False
        with self.assertRaises(ValueError): G["require_finalized"](binding)

    def test_changed_original_oracle_rejected(self):
        self.manifests["ipad11"]["cases"][0]["oracle"] += " relaxed"
        with self.assertRaises(ValueError): G["validate_manifest"](self.manifests["ipad11"], self.old_manifest, "ipad11")

    def test_missing_original_row_rejected(self):
        self.manifests["ipad11"]["supplemental_cases"].pop(0)
        with self.assertRaises(ValueError): G["validate_manifest"](self.manifests["ipad11"], self.old_manifest, "ipad11")

    def test_missing_new_native_selection_rejected(self):
        for name, manifest in self.manifests.items():
            manifest["execution_case_ids"].pop(0)
            with self.subTest(configuration=name), self.assertRaises(ValueError): G["validate_manifest"](manifest, self.old_manifest, name)

    def test_wrong_device_group_rejected(self):
        self.manifests["iphone"]["execution_groups"][0]["size"] = "11"
        with self.assertRaises(ValueError): G["validate_manifest"](self.manifests["iphone"], self.old_manifest, "iphone")

    def test_historical_or_full_phase_credit_rejected(self):
        manifest = self.manifests["ipad11"]
        manifest["native_cases_executed"] = 4
        with self.assertRaises(ValueError): G["validate_manifest"](manifest, self.old_manifest, "ipad11")
        manifest["native_cases_executed"] = 0
        manifest["native_study_sheet_diagnostic_20261120"]["full_native116_acceptance"] = True
        with self.assertRaises(ValueError): G["validate_manifest"](manifest, self.old_manifest, "ipad11")

    def test_original_runtime_body_edit_rejected(self):
        self.pins[4] += b"\n# changed original helper\n"
        with self.assertRaises(ValueError): G["validate_pins"](*self.pins)

    def test_source_or_artifact_pin_edit_rejected(self):
        self.pins[0]["engine_producer_sha"] = "0" * 40
        with self.assertRaises(ValueError): G["validate_pins"](*self.pins)

    def test_test_additions_exemption_edit_rejected(self):
        self.pins[2] += b"\n"
        with self.assertRaises(ValueError): G["validate_pins"](*self.pins)

    def test_exact_immutable_child_permitted(self):
        G["validate_identity"](self.head, self.head, G["REF"], [G["BASE"]], G["TREES"], G["ALLOWED"])

    def test_wrong_head_ref_or_parent_rejected(self):
        for head, ref, parents in [("b" * 40, G["REF"], [G["BASE"]]), (self.head, "refs/heads/main", [G["BASE"]]), (self.head, G["REF"], []), (self.head, G["REF"], [G["BASE"], "b" * 40])]:
            with self.subTest(head=head, ref=ref, parents=parents), self.assertRaises(ValueError):
                G["validate_identity"](head, self.head, ref, parents, G["TREES"], G["ALLOWED"])

    def test_unreviewed_product_or_test_tree_rejected(self):
        for key in G["TREES"]:
            trees = dict(G["TREES"]); trees[key] = "b" * 40
            with self.subTest(tree=key), self.assertRaises(ValueError):
                G["validate_identity"](self.head, self.head, G["REF"], [G["BASE"]], trees, G["ALLOWED"])

    def test_original_catalog_or_matrix_edit_rejected(self):
        for path in (G["ORIGINAL_MANIFEST"], "Scripts/CI/run-faithful-ipad-matrix.py"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                G["validate_identity"](self.head, self.head, G["REF"], [G["BASE"]], G["TREES"], G["ALLOWED"] | {path})

    def test_eleven_and_one_matching_synthetic_outcomes(self):
        self.validate("ipad11"); self.validate("iphone")
        self.assertEqual(len(self.aggregate()), 12)

    def test_build_only_cannot_qualify_native(self):
        self.data["ipad11"]["ui"]["status"] = "BUILD_ONLY"; self.rejected()

    def test_full_phase_status_cannot_qualify_subset(self):
        self.data["ipad11"]["ui"]["status"] = "EXECUTED_PASS"; self.rejected()

    def test_incomplete_or_wrong_head_build_rejected(self):
        self.build["status"] = "FAILED"; self.rejected()
        self.build["status"] = "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
        self.build["checkout_sha"] = "b" * 40; self.rejected()

    def test_wrong_actual_test_tree_rejected(self):
        self.data["ipad11"]["ui"]["test_tree"] = "b" * 40; self.rejected()

    def test_one_ui_failure_rejected(self):
        self.data["iphone"]["ui"]["executed_ui_pass"] = 0
        self.data["iphone"]["ui"]["executed_ui_fail"] = 1; self.rejected("iphone")

    def test_skip_or_not_run_rejected(self):
        for key in ("executed_ui_skip", "ui_not_run"):
            self.data["ipad11"]["ui"][key] = 1
            with self.subTest(key=key): self.rejected()
            self.data["ipad11"]["ui"][key] = 0

    def test_raw_missing_duplicate_or_expected_failure_leaf_rejected(self):
        d = self.data["ipad11"]
        original_leaves = list(d["leaves"])
        for leaves in (original_leaves[:-1], original_leaves + [original_leaves[0]], [(original_leaves[0][0], "Expected Failure")] + original_leaves[1:]):
            d["leaves"] = leaves
            with self.subTest(leaves=leaves): self.rejected()

    def test_raw_summary_disagrees_rejected(self):
        self.data["ipad11"]["summary"]["failedTests"] = 1; self.rejected()

    def test_wrong_case_device_or_configuration_label_rejected(self):
        row = self.data["iphone"]["ui"]["case_outcomes"][0]
        for key, bad in (("case_id", "OtherTests/testFake"), ("device", "ipad11"), ("configuration_label", "11-reader")):
            old = row[key]; row[key] = bad
            with self.subTest(key=key): self.rejected("iphone")
            row[key] = old

    def test_different_manifest_or_runtime_report_hash_rejected(self):
        ui = self.data["ipad11"]["ui"]
        old = ui["case_manifest_sha256"]; ui["case_manifest_sha256"] = "0" * 64; self.rejected()
        ui["case_manifest_sha256"] = old
        ui["helper_inputs_sha256"][G["RUNTIME"]] = "0" * 64; self.rejected()

    def test_aggregate_missing_configuration_rejected(self):
        del self.records["iphone"]
        with self.assertRaises(ValueError): self.aggregate()

    def test_aggregate_matrix_failure_even_after_twelve_labels_rejected(self):
        for status in ("failure", "cancelled", "skipped", ""):
            with self.subTest(status=status), self.assertRaises(ValueError): self.aggregate(status)

    def test_aggregate_wrong_run_attempt_head_or_config_rejected(self):
        result = self.records["iphone"]["result"]
        for key, bad in (("run_id", "999999"), ("run_attempt", "2"), ("head", "b" * 40)):
            old = result["context"][key]; result["context"][key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError): self.aggregate()
            result["context"][key] = old
        result["configuration"] = "ipad11"
        with self.assertRaises(ValueError): self.aggregate()

    def test_aggregate_cannot_reuse_ipad11_as_iphone(self):
        self.records["iphone"] = copy.deepcopy(self.records["ipad11"])
        with self.assertRaises(ValueError): self.aggregate()

    def test_aggregate_source_drift_after_passing_cases_rejected(self):
        self.records["iphone"]["after"]["execution_inputs"][G["RUNTIME"]]["sha256"] = "b" * 64
        with self.assertRaises(ValueError): self.aggregate()

    def test_aggregate_missing_after_or_full_phase_claim_rejected(self):
        result = self.records["ipad11"]["result"]
        result["full_release114_acceptance"] = True
        with self.assertRaises(ValueError): self.aggregate()
        result["full_release114_acceptance"] = False
        self.records["ipad11"]["after"]["status"] = "FAIL"
        with self.assertRaises(ValueError): self.aggregate()

    def test_aggregate_consumes_receipts_written_by_actual_main(self):
        # Real producer/consumer and case-sensitive filesystem. Only the source
        # and Native outcome boundaries are synthetic, as in the other controls;
        # neither receipt names nor receipt serialization are recreated here.
        namespace = G["main"].__globals__
        with tempfile.TemporaryDirectory(prefix="native-study-sheet-receipts-") as temporary:
            evidence = Path(temporary)
            with mock.patch.dict(os.environ, {"EXPECTED_CHECKOUT_SHA": self.head, "MATRIX_JOB_RESULT": "success", "FOUNDATION_JOB_RESULT": "success"}), contextlib.redirect_stdout(io.StringIO()):
                self.write_foundation_using_actual_producer(evidence)
                for configuration in G["CONFIGURATIONS"]:
                    directory = evidence / ("native-study-sheet-native-evidence-" + configuration)
                    output = directory / "artifacts/native-study-sheet-native"
                    record = self.records[configuration]
                    def source_boundary(phase, expected, selected, record=record, configuration=configuration):
                        self.assertEqual((expected, selected), (self.head, configuration))
                        return copy.deepcopy(record[phase])
                    def native_boundary(expected, selected, record=record, configuration=configuration):
                        self.assertEqual((expected, selected), (self.head, configuration))
                        return copy.deepcopy(record["result"])
                    with mock.patch.dict(namespace, {"OUT": output, "source_check": source_boundary,
                                                    "qualify": native_boundary, "github_context": lambda: self.context}):
                        for phase in ("before", "after"):
                            with mock.patch.object(sys, "argv", [__file__, phase, "--configuration", configuration]):
                                self.assertEqual(G["main"](), 0)
                    G["write"](directory / "artifacts/runtime27/result.json", self.data[configuration]["ui"])
                def replay_boundary(expected, selected, artifact_root=None):
                    self.assertEqual(expected, self.head)
                    self.assertEqual(artifact_root, evidence / ("native-study-sheet-native-evidence-" + selected))
                    self.validate(selected)
                    return self.records[selected]["result"]
                with mock.patch.dict(namespace, {"OUT": evidence / "aggregate", "qualify": replay_boundary,
                                                "github_context": lambda: self.context,
                                                "git": lambda *args: (self.head + "\n").encode()}):
                    exit_code = G["aggregate"](self.head, evidence)
                    result = json.loads((evidence / "aggregate/AGGREGATE.json").read_bytes())
                    self.assertEqual(exit_code, 0, json.dumps(result.get("errors"), indent=2))
                    self.assertEqual(result["status"], "TWELVE_ADDITIVE_NATIVE_AND_FOUNDATION25_PASS")
                    self.assertEqual(len(result["case_outcomes"]), 12)


if __name__ == "__main__":
    unittest.main(argv=[__file__, *OTHER], verbosity=2)
