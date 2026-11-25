#!/usr/bin/env python3
"""Integrity controls over the actual fresh SDK provenance; no app/UI credit."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("fresh_admission",
    ROOT / "Scripts/CI/original_editor_local_admission.py")
local = importlib.util.module_from_spec(spec)
spec.loader.exec_module(local)
PROOF = None


class FreshOriginalABI(unittest.TestCase):
    def setUp(self):
        self.data = copy.deepcopy(PROOF)

    def verify(self):
        d = self.data
        local.validate_abi_adapter(d["values"]["abi"], d["heart"], d["config"]["source_sha"])
        return local.validate_fresh_abi(d["values"], d["config"], d["heart"], d["before"])

    def rejected(self, mutate, pattern):
        mutate(self.data)
        with self.assertRaisesRegex(RuntimeError, pattern):
            self.verify()

    def test_actual_new_native_and_swift_origins_are_preserved(self):
        proof = self.verify()
        self.assertFalse(proof["new_sdk_or_ui_credit"])
        self.assertFalse(proof["native_tests_rerun_by_transport"])

    def test_legacy_route_cannot_admit_fresh_schema(self):
        self.rejected(lambda d: d["config"].pop("abi_provenance"), "explicit complete files")

    def test_fresh_origin_requires_current_file_contract(self):
        self.rejected(lambda d: d["config"].update(public_host_contract_sha256=local.MINIAPPS_CONTRACT),
                      "explicit complete files")

    def test_old_verifier_source_cannot_admit_new_route(self):
        self.rejected(lambda d: d["before"]["source_inputs"]["Tools/OriginalEditor/fresh_swift_input.py"]
                      .update(sha256="0" * 64), "exact qualified source")

    def test_verifier_must_bind_current_abi_bytes(self):
        self.rejected(lambda d: d["values"]["abi_fresh_verification"].update(abi_sha256="0" * 64),
                      "exact qualified source")

    def test_other_sdk_source_is_rejected(self):
        self.rejected(lambda d: d["values"]["abi_fresh_verification"].update(producer_source_sha="1" * 40),
                      "exact qualified source")

    def test_verifier_cannot_claim_native_execution(self):
        self.rejected(lambda d: d["values"]["abi_fresh_verification"].update(new_native_tests=66),
                      "exact qualified source")

    def test_native_counts_are_exact(self):
        self.rejected(lambda d: d["values"]["abi_final_native_rpc_union"]["counts"]["native9"].update(passes=8),
                      "native66")

    def test_native_origin_cannot_borrow_github_identity(self):
        self.rejected(lambda d: d["values"]["abi_final_native_rpc_union"].update(github_run_id=123),
                      "native66")

    def test_swift_origin_cannot_be_relabelled_as_current_framework(self):
        self.rejected(lambda d: d["values"]["abi_changed_swift_qualification"]
                      .update(original_control_source=d["config"]["source_sha"]), "Swift origin")

    def test_swift_gate_cannot_be_promoted_to_full_sdk(self):
        self.rejected(lambda d: d["values"]["abi_changed_swift_qualification"].update(full_sdk_typechecked=True),
                      "Swift origin")

    def test_generation_failure_remains_historical_failure(self):
        self.rejected(lambda d: d["values"]["abi_generation_qualification"]
                      .update(aggregate_producer_outcome="PASS"), "failed generation history")

    def test_exact_three_target_wrapper_is_required(self):
        self.rejected(lambda d: d["config"]["local_receipts"]["abi_pinned_wrapper"].update(bytes=1),
                      "wrapper receipt")

    def test_installed_native_abi_cannot_be_incomplete(self):
        self.rejected(lambda d: d["values"]["abi"]["lib_files"].pop(), "installed native ABI")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--proof-json", type=Path, required=True)
    args = parser.parse_args()
    PROOF = json.loads(args.proof_json.read_bytes())
    unittest.main(argv=[sys.argv[0]], verbosity=2)
