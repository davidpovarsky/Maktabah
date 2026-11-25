"""New source-composition admission controls; no simulator or artifact qualification."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
ROUTE = runpy.run_path(str(ROOT / "Scripts/CI/runtime27-original-editor-native.py"))
COMPOSITION = json.loads(ROUTE["COMPOSITION_INPUTS"].read_bytes())
BUILD = json.loads((ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json").read_bytes())


class FinalCompositionControls(unittest.TestCase):
    def mutated_manifest(self, change, *, bind_mutation=True):
        config = copy.deepcopy(COMPOSITION)
        change(config)
        raw = (json.dumps(config, sort_keys=True, indent=2) + "\n").encode()
        function = ROUTE["composed_product_source"]
        with tempfile.TemporaryDirectory(prefix="otzaria-composition-control-") as temporary:
            path = Path(temporary) / "composition.json"
            path.write_bytes(raw)
            values = {"COMPOSITION_INPUTS": path}
            if bind_mutation:
                values["COMPOSITION_SHA256"] = hashlib.sha256(raw).hexdigest()
            with mock.patch.dict(function.__globals__, values):
                return function()

    def test_actual_18_product_paths_equal_accepted_ancestor_objects(self):
        result = ROUTE["composed_product_source"]()
        self.assertEqual(result["accepted_source_objects_verified"], 18)
        self.assertEqual(result["application_source_sha"], "7d5510dd29af2b66d740de136352916868c341ed")
        self.assertFalse(result["expanded_sdk_artifact_qualified"])
        self.assertFalse(result["native_stageb_qualified"])

    def test_dependency_leaf_stays_separate_from_full_composition(self):
        self.assertNotEqual(ROUTE["DEPENDENCY_SOURCE"], ROUTE["SOURCE"])
        result = ROUTE["qualified_dependency_source"]()
        self.assertEqual(result["qualified_dependency_source"], ROUTE["DEPENDENCY_SOURCE"])
        self.assertEqual(result["product_delta"], [ROUTE["HOST_LOCK"], "Vendor/HanlinSDK"])
        self.assertTrue(result["original_interface_and_tests_unchanged"])

    def test_manifest_body_drift_is_rejected_before_interpretation(self):
        with self.assertRaisesRegex(RuntimeError, "composition manifest changed"):
            self.mutated_manifest(lambda d: d.update(status="changed"), bind_mutation=False)

    def test_unreviewed_application_source_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "source identity differs"):
            self.mutated_manifest(lambda d: d.update(application_source_sha="0" * 40))

    def test_missing_product_delta_cannot_hide_a_component(self):
        with self.assertRaisesRegex(RuntimeError, "undeclared product delta"):
            self.mutated_manifest(lambda d: d["product_delta"].pop())

    def test_forged_owner_object_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "does not equal its accepted source"):
            self.mutated_manifest(lambda d: d["product_delta"][0].update(accepted_source_object="0" * 40))

    def test_changed_original_preimage_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "does not equal its accepted source"):
            self.mutated_manifest(lambda d: d["product_delta"][0]["before"].update(object="0" * 40))

    def test_source_binding_rejects_historical_reader_hanlin(self):
        changed = copy.deepcopy(BUILD)
        changed["hanlin_gitlink"] = "e00498e33f106cc43be0476ffa2e09329c8ca300"
        with self.assertRaisesRegex(RuntimeError, "exact composed application"):
            ROUTE["verify_composed_build_inputs"](changed, COMPOSITION)

    def test_existing_artifact_pin_cannot_change_as_source_binding(self):
        changed = copy.deepcopy(BUILD)
        changed["artifacts"][0]["id"] += 1
        with self.assertRaisesRegex(RuntimeError, "Artifact or engine/resource"):
            ROUTE["verify_composed_build_inputs"](changed, COMPOSITION)

    def test_only_complete_schema_is_eligible_for_later_actual_admission(self):
        for schema in (1, 2, 0, 4, True, "3", None):
            with self.subTest(schema=schema), self.assertRaisesRegex(RuntimeError, "legacy pins are UNQUALIFIED"):
                ROUTE["require_composed_sdk_input"]({"schema": schema})
        self.assertIsNone(ROUTE["require_composed_sdk_input"]({"schema": 3}))
        actual = json.loads(ROUTE["ADMISSION"].read_bytes())
        with self.assertRaisesRegex(RuntimeError, "legacy pins are UNQUALIFIED"):
            ROUTE["require_composed_sdk_input"](actual)

    def test_reader_bindings_keep_original_selectors_release_and_historical_provenance(self):
        names = ["reader-groups100-focused-native", "library-morph-focused-native",
                 "reader-full-v32-ui-observation"]
        for name in names:
            relative = "Scripts/CI/" + name + ".inputs.json"
            old_raw = subprocess.check_output(["git", "show", ROUTE["SOURCE"] + ":" + relative], cwd=ROOT)
            old = json.loads(old_raw)
            current = json.loads((ROOT / relative).read_bytes())
            with self.subTest(name=name):
                self.assertEqual(current["application_source_sha"], ROUTE["SOURCE"])
                self.assertEqual(current["application_trees"], COMPOSITION["application_trees"])
                provenance = current["composition_provenance"]
                self.assertEqual(provenance["previous_input_sha256"], hashlib.sha256(old_raw).hexdigest())
                self.assertEqual(provenance["previous_application_source_sha"], old["application_source_sha"])
                self.assertEqual(provenance["previous_application_trees"], old["application_trees"])
                self.assertFalse(provenance["historical_passes_counted_as_current"])
                for key in ["execution_groups", "selected_case_ids", "source_database",
                            "required_reader_opens", "required_forced_relaunches", "required_inspector_counts"]:
                    if key in old:
                        self.assertEqual(current[key], old[key])
                for path, expected in current.get("input_sha256", {}).items():
                    value = (ROOT / path).read_bytes() if (ROOT / path).is_file() else subprocess.check_output(
                        ["git", "show", "HEAD:" + path], cwd=ROOT)
                    self.assertEqual(hashlib.sha256(value).hexdigest(), expected, path)

    def test_current_multipart_native_acceptance_cannot_be_replaced_by_v32_or_components(self):
        gate = next(g for g in COMPOSITION["gates"] if g["id"] == "v40_multipart_native_install_restore")
        self.assertEqual(gate["release_id"], 455390662)
        self.assertEqual(gate["status"], "NOT_RUN_ON_COMPOSED_APP")
        self.assertFalse(gate["v32_or_component_controls_satisfy_gate"])
        self.assertFalse(gate["large_assets_on_oracle"])
        for required in ["same_composed_app_build", "original_native_bootstrap_cancel",
                         "original_native_bootstrap_install", "original_native_bootstrap_restore",
                         "actual_full_archive_hash", "SQLite_validation_and_actual_database_counts"]:
            self.assertIn(required, gate["requires"])


if __name__ == "__main__":
    unittest.main()
