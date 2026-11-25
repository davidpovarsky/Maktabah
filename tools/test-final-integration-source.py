#!/usr/bin/env python3
"""Tamper controls for exact integrated source admission; no Apple execution."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
API = runpy.run_path(str(ROOT / "Scripts/CI/final_integration_source.py"))
MANIFEST = "Scripts/CI/final-integration-source.inputs.json"
VALUE = json.loads((ROOT / MANIFEST).read_bytes())
DIGEST = hashlib.sha256((ROOT / MANIFEST).read_bytes()).hexdigest()
BEFORE = json.loads(subprocess.check_output(
    ["git", "show", API["INTEGRATION_BASE"] + ":" + API["INPUTS"]], cwd=ROOT))
AFTER = json.loads((ROOT / API["INPUTS"]).read_bytes())
ADDITIONS = json.loads((ROOT / API["ADDITIONS"]).read_bytes())
PRIOR_ADDITIONS = json.loads(subprocess.check_output(
    ["git", "show", API["INTEGRATION_BASE"] + ":" + API["ADDITIONS"]], cwd=ROOT))
PROJECT_BLOB = subprocess.check_output(
    ["git", "rev-parse", VALUE["application_source_sha"] + ":" + API["PROJECT"]],
    cwd=ROOT, text=True).strip()
ADDITIONS_DIGEST = hashlib.sha256((ROOT / API["ADDITIONS"]).read_bytes()).hexdigest()


class IntegratedSourceTamperControls(unittest.TestCase):
    def binding(self, value):
        API["verify_build_binding"](BEFORE, value, VALUE, MANIFEST, DIGEST, ADDITIONS_DIGEST)

    def test_exact_reviewed_source_objects_and_build_binding(self):
        API["verify_shape"](VALUE)
        API["verify_rows"](ROOT, VALUE)
        self.binding(AFTER)
        API["verify_additions"](PRIOR_ADDITIONS, ADDITIONS, PROJECT_BLOB)

    def test_native_qualification_cannot_be_claimed_by_source_manifest(self):
        value = copy.deepcopy(VALUE)
        value["native_qualified"] = True
        with self.assertRaisesRegex(RuntimeError, "contract"):
            API["verify_shape"](value)

    def test_missing_product_delta_is_rejected(self):
        value = copy.deepcopy(VALUE)
        value["product_delta"].pop()
        with self.assertRaisesRegex(RuntimeError, "undeclared"):
            API["verify_rows"](ROOT, value)

    def test_source_object_digest_mutation_is_rejected(self):
        value = copy.deepcopy(VALUE)
        value["product_delta"][0]["after"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(RuntimeError, "source object"):
            API["verify_rows"](ROOT, value)

    def test_component_substitution_is_rejected(self):
        value = copy.deepcopy(VALUE)
        row = next(row for row in value["product_delta"]
                   if row["adoption"] == "UNCHANGED_COMPONENT_OBJECT"
                   and row["after"] != API["source_object"](
                       ROOT, value["accepted_components"]["library"], row["path"]))
        row["component"] = "library"
        with self.assertRaisesRegex(RuntimeError, "Component object"):
            API["verify_rows"](ROOT, value)

    def test_reviewed_merge_patch_mutation_is_rejected(self):
        value = copy.deepcopy(VALUE)
        row = next(row for row in value["product_delta"] if row["adoption"] == "EXPLICIT_REVIEWED_MERGE")
        row["patch"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(RuntimeError, "merge patch"):
            API["verify_rows"](ROOT, value)

    def test_merge_parent_substitution_is_rejected(self):
        value = copy.deepcopy(VALUE)
        row = next(row for row in value["product_delta"] if row["adoption"] == "EXPLICIT_REVIEWED_MERGE")
        row["component_objects"]["library"] = {"mode": "100644", "kind": "blob",
                                                "object": "0" * 40, "sha256": "0" * 64, "bytes": 0}
        with self.assertRaisesRegex(RuntimeError, "parent objects"):
            API["verify_rows"](ROOT, value)

    def test_duplicate_product_path_is_rejected(self):
        value = copy.deepcopy(VALUE)
        value["product_delta"].append(copy.deepcopy(value["product_delta"][-1]))
        with self.assertRaisesRegex(RuntimeError, "duplicate"):
            API["verify_shape"](value)

    def test_path_escape_is_rejected(self):
        value = copy.deepcopy(VALUE)
        value["product_delta"][0]["path"] = "../Source/foreign.swift"
        with self.assertRaisesRegex(RuntimeError, "product paths"):
            API["verify_shape"](value)

    def test_retained_engine_artifact_change_is_rejected(self):
        value = copy.deepcopy(AFTER)
        value["artifacts"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(RuntimeError, "Retained engine"):
            self.binding(value)

    def test_unreviewed_build_input_is_rejected(self):
        value = copy.deepcopy(AFTER)
        value["skip_sdk_ownership"] = True
        with self.assertRaisesRegex(RuntimeError, "Retained engine"):
            self.binding(value)

    def test_wrong_product_source_is_rejected(self):
        value = copy.deepcopy(AFTER)
        value["application_source_sha"] = API["INTEGRATION_BASE"]
        with self.assertRaisesRegex(RuntimeError, "exact reviewed source"):
            self.binding(value)

    def test_wrong_shared_dependency_is_rejected(self):
        value = copy.deepcopy(AFTER)
        value["hanlin_gitlink"] = "0" * 40
        with self.assertRaisesRegex(RuntimeError, "exact reviewed source"):
            self.binding(value)

    def test_original_engine_test_object_change_is_rejected(self):
        value = copy.deepcopy(ADDITIONS)
        value["entries"][0]["blob"] = "0" * 40
        with self.assertRaisesRegex(RuntimeError, "Original engine test"):
            API["verify_additions"](PRIOR_ADDITIONS, value, PROJECT_BLOB)

    def test_original_engine_build_script_change_is_rejected(self):
        value = copy.deepcopy(ADDITIONS)
        value["excluded_build_inputs"]["Vendor/OtzariaSearchEngine/build_xcframework.sh"] = "0" * 40
        with self.assertRaisesRegex(RuntimeError, "Engine build input"):
            API["verify_additions"](PRIOR_ADDITIONS, value, PROJECT_BLOB)

    def test_stale_project_exclusion_is_rejected(self):
        value = copy.deepcopy(ADDITIONS)
        value["excluded_build_inputs"][API["PROJECT"]] = "0" * 40
        with self.assertRaisesRegex(RuntimeError, "Engine build input"):
            API["verify_additions"](PRIOR_ADDITIONS, value, PROJECT_BLOB)


if __name__ == "__main__":
    unittest.main(verbosity=2)
