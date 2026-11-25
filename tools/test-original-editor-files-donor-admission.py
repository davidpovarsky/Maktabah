#!/usr/bin/env python3
"""Controls over real retained schema3 donor metadata; no build or UI credit."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "files_donor_admission", ROOT / "Scripts/CI/original_editor_local_admission.py")
local = importlib.util.module_from_spec(spec)
spec.loader.exec_module(local)
PROOF = None


class RetainedFilesABI(unittest.TestCase):
    def setUp(self):
        self.data = copy.deepcopy(PROOF)

    def verify(self):
        d = self.data
        return local.validate_donor_abi(d["values"], d["config"], d["heart"], d["before"])

    def rejected(self, mutate, pattern):
        mutate(self.data)
        with self.assertRaisesRegex(RuntimeError, pattern):
            self.verify()

    def test_real_donor_retains_fresh_native_and_swift_identity(self):
        result = self.verify()
        self.assertEqual(result["donor_source_sha"], local.FILES_DONOR_SOURCE)
        self.assertNotEqual(result["original_abi_producer_identity"]["run_id"],
                            self.data["config"]["run_id"])
        self.assertFalse(result["native_tests_rerun"])
        self.assertFalse(result["new_sdk_acceptance_granted"])
        self.assertFalse(result["original_fresh_abi_provenance"]["new_sdk_or_ui_credit"])

    def test_unknown_donor_is_not_a_version_fallback(self):
        self.rejected(lambda d: d["config"].update(abi_donor_source_sha="0" * 40),
                      "Unreviewed original native ABI donor")

    def test_original_policy_is_pinned_independently(self):
        self.rejected(lambda d: d["config"]["local_receipts"]["abi_donor_policy"]
                      .update(sha256="0" * 64), "relabelled|exact reviewed policy")

    def test_current_verifier_must_be_the_reviewed_source(self):
        self.rejected(lambda d: d["before"]["source_inputs"][local.FILES_DONOR_VERIFIER]
                      .update(sha256="0" * 64), "exact reviewed policy")

    def test_original_native_source_is_not_current_framework_source(self):
        self.rejected(lambda d: d["values"]["abi_donor_abi"]
                      .update(sdk_source_sha=d["config"]["source_sha"]),
                      "original donor ABI|Original donor ABI")

    def test_native66_proof_cannot_be_replaced_by_a_count_claim(self):
        self.rejected(lambda d: d["values"]["abi_donor_final_native_rpc_union"]["counts"]["native9"]
                      .update(passes=8), "native66")

    def test_original_generation_failure_is_preserved(self):
        self.rejected(lambda d: d["values"]["abi_donor_generation_qualification"]
                      .update(aggregate_producer_outcome="PASS"), "failed generation history")

    def test_original_34b_continuation_base_is_not_relabelled(self):
        self.rejected(lambda d: d["before"]["generated_import_source"]["annotation_exchange"]
                      .update(base_source=local.FILES_DONOR_SOURCE),
                      "generated or application source scope")

    def test_resource_tree_changes_require_new_native_source_review(self):
        self.rejected(lambda d: d["before"]["original_trees"]
                      .update({"Anytype/Resources": "0" * 40}),
                      "generated or application source scope")

    def test_current_installed_native_bytes_cannot_be_substituted(self):
        self.rejected(lambda d: d["heart"]["lib_files"][0].update(sha256="0" * 64),
                      "original donor installation")

    def test_donor_transport_cannot_award_new_native_execution(self):
        self.rejected(lambda d: d["heart"]["abi_reuse"].update(native_tests_rerun=True),
                      "reuse scope")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--proof-json", type=Path, required=True)
    args = parser.parse_args()
    PROOF = json.loads(args.proof_json.read_bytes())
    unittest.main(argv=[sys.argv[0]], verbosity=2)
