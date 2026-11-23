#!/usr/bin/env python3
"""NEW completion/cohort controls. Synthetic protocol values only, no native output."""
from pathlib import Path
import copy
import hashlib
import importlib.util
import json
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[3]
DRIVER = ROOT / "Scripts/CI/reader-full-v32-ui-observation.py"
spec = importlib.util.spec_from_file_location("full_v32_completion_control", DRIVER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def identifier(label):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "synthetic-control-not-native/" + label)).upper()

class CompletionCohortControls(unittest.TestCase):
    def setUp(self):
        self.original_write = module.write
        self.recorded_only_in_memory = []
        # Never emit a synthetic Native acceptance/result artifact.
        module.write = lambda path, value: self.recorded_only_in_memory.append((str(path), copy.deepcopy(value)))

    def tearDown(self):
        module.write = self.original_write

    def fixture(self):
        host = module.ObservationHost.__new__(module.ObservationHost)
        host.active = host.pending_inspector = None
        host.reader_complete = host.inspector_complete = None
        host.epochs, host.source_proofs, host.inspector_records = {}, [], {}
        host.targets = {
            "synthetic-" + str(i): {"bookID": (103, 28, 3152)[i // 3] if i < 9 else 5869}
            for i in range(10)
        }
        rows, restores = [], []
        for number, key in enumerate(host.targets):
            pid = 1000 + number * 2
            document, group = identifier(key + "-document"), identifier("group")
            for mode in ("process-cold", "warm"):
                stem = key + "/" + mode
                epoch, overview = identifier(stem + "-open"), identifier(stem + "-overview")
                source, core = identifier(stem + "-source"), identifier(stem + "-core")
                host.epochs[epoch] = {"kind": "reader-open", "status": "OBSERVED_NOT_PERFORMANCE_ACCEPTANCE",
                    "processID": pid, "target_key": key, "mode": mode, "resource_end_host_monotonic": 10.0}
                host.epochs[overview] = {"kind": "reader-overview", "status": "OBSERVED_NOT_PERFORMANCE_ACCEPTANCE",
                    "processID": pid, "target_key": key, "mode": mode, "resource_start_host_monotonic": 11.0}
                proof = {"request_id": source, "target_key": key, "epoch": epoch,
                    "native_core_receipt_present": True, "native_core_request_id": core,
                    "route_visibility_upper_bound_seconds": 1.25, "native_process_id": pid,
                    "actual_workspace_document_id": document, "actual_workspace_group_id": group,
                    "source_index": 40, "pixel_offset": 0.25}
                host.source_proofs.append(proof)
                interaction = {"epoch": overview, "actualOverviewIdentifier": "study-groups-overview",
                    "actualCardIdentifier": ("tab-switcher-grid-cell-" if mode == "process-cold" else "tab-switcher-list-cell-") + document,
                    "actualDocumentID": document, "observationStartedUptime": 12.0, "nativeActionRequestedUptime": 12.5,
                    "originalOverviewObservedUptime": 13.5, "requestToOriginalOverviewUpperBoundSeconds": 1.5,
                    "nativeActionToOverviewUpperBoundSeconds": 1.0}
                rows.append({"epoch": epoch, "targetKey": key, "mode": mode, "processID": pid,
                    "sourceObservationID": source, "route": {"receiptFields": {"request": core},
                    "requestToNativeVisibleUpperBoundSeconds": 1.25}, "firstInteraction": interaction})
            before_id, after_id = identifier(key + "-before-restore"), identifier(key + "-after-restore")
            for request_id, process_id, offset in ((before_id, pid, 0.25), (after_id, pid + 101, 0.5)):
                host.source_proofs.append({"request_id": request_id, "target_key": key, "epoch": None,
                    "native_core_receipt_present": False, "native_core_request_id": None,
                    "route_visibility_upper_bound_seconds": None, "native_process_id": process_id,
                    "actual_workspace_document_id": document, "actual_workspace_group_id": group,
                    "source_index": 40, "pixel_offset": offset})
            restores.append({"targetKey": key, "beforeProcessID": pid, "afterProcessID": pid + 101,
                "documentID": document, "groupID": group, "beforeRequestID": before_id, "afterRequestID": after_id,
                "beforeSource": 40, "afterSource": 40, "beforeOffset": 0.25, "afterOffset": 0.5})
        return host, {"observations": rows, "forcedRelaunches": 10, "forcedRestoreEvidence": restores}

    def test_valid_twenty_opens_twenty_original_interactions_ten_restores(self):
        host, request = self.fixture()
        result = host.complete_reader(request)
        self.assertEqual(result["observations"], 20)
        self.assertEqual(result["verifiedForcedRestores"], 10)
        self.assertEqual(len(self.recorded_only_in_memory), 1)

    def test_wrong_source_observation_join_is_rejected(self):
        host, request = self.fixture()
        request["observations"][0]["sourceObservationID"] = request["observations"][1]["sourceObservationID"]
        with self.assertRaises(ValueError): host.complete_reader(request)
        self.assertEqual(self.recorded_only_in_memory, [])

    def test_wrong_original_core_request_join_is_rejected(self):
        host, request = self.fixture()
        request["observations"][0]["route"]["receiptFields"]["request"] = identifier("wrong-native-request")
        with self.assertRaises(ValueError): host.complete_reader(request)
        self.assertEqual(self.recorded_only_in_memory, [])

    def test_wrong_overview_document_even_with_matching_card_suffix_is_rejected(self):
        host, request = self.fixture()
        observation = request["observations"][0]["firstInteraction"]
        observation["actualDocumentID"] = identifier("another-document")
        observation["actualCardIdentifier"] = "tab-switcher-grid-cell-" + observation["actualDocumentID"]
        with self.assertRaises(ValueError): host.complete_reader(request)
        self.assertEqual(self.recorded_only_in_memory, [])

    def test_wrong_card_prefix_even_with_correct_document_is_rejected(self):
        host, request = self.fixture()
        observation = request["observations"][0]["firstInteraction"]
        observation["actualCardIdentifier"] = "unrelated-card-" + observation["actualDocumentID"]
        with self.assertRaises(ValueError): host.complete_reader(request)
        self.assertEqual(self.recorded_only_in_memory, [])

    def test_wrong_overview_process_is_rejected(self):
        host, request = self.fixture()
        host.epochs[request["observations"][0]["firstInteraction"]["epoch"]]["processID"] += 1
        with self.assertRaises(ValueError): host.complete_reader(request)
        self.assertEqual(self.recorded_only_in_memory, [])

    def test_overview_overlapping_reader_resource_epoch_is_rejected(self):
        host, request = self.fixture()
        host.epochs[request["observations"][0]["firstInteraction"]["epoch"]]["resource_start_host_monotonic"] = 9.9
        with self.assertRaises(ValueError): host.complete_reader(request)
        self.assertEqual(self.recorded_only_in_memory, [])

    def inspector_fixture(self):
        host, _ = self.fixture()
        observations, exploration = [], []
        for number in range(9):
            key, request_id = "synthetic-" + str(number), identifier("inspector-" + str(number))
            count = 100 if number < 3 else 500 if number < 6 else 2000
            record = {"request_id": request_id, "target_key": key, "full_cached_count": count,
                      "actual_visible_rows": [{"id": "synthetic-row-not-native"}]}
            host.inspector_records[request_id] = record
            observations.append(request_id)
            exploration.append({"targetKey": key, "observationID": request_id, "actualCount": count, "visibleRows": 1})
        scales = [{"requestedCount": n, "actualCount": n, "observationID": observations[i]}
                  for n, i in ((100, 0), (500, 3), (2000, 6))]
        return host, {"action": "complete_inspector", "observationIDs": observations, "exploration": exploration, "scales": scales}

    def test_valid_nine_inspector_outcomes_remain_protocol_control_only(self):
        host, request = self.inspector_fixture()
        result = host.handle(request, Path("/unused-synthetic"))
        self.assertEqual(result["observations"], 9)
        self.assertTrue(result["exactSizeCriterionMet"])
        self.assertFalse(result["fullRowRenderingAcceptance"])
        self.assertEqual(len(self.recorded_only_in_memory), 1)

    def test_missing_original_inspector_exploration_outcome_is_rejected(self):
        host, request = self.inspector_fixture()
        request["exploration"].pop()
        with self.assertRaises(ValueError): host.handle(request, Path("/unused-synthetic"))
        self.assertEqual(self.recorded_only_in_memory, [])

    def test_duplicated_original_inspector_exploration_outcome_is_rejected(self):
        host, request = self.inspector_fixture()
        request["exploration"][-1] = copy.deepcopy(request["exploration"][0])
        with self.assertRaises(ValueError): host.handle(request, Path("/unused-synthetic"))
        self.assertEqual(self.recorded_only_in_memory, [])

if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(CompletionCohortControls)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    print(json.dumps({"scope": "NEW synthetic completion/cohort controls only; no native acceptance artifacts emitted",
        "testsRun": result.testsRun, "failures": len(result.failures), "errors": len(result.errors), "skipped": len(result.skipped),
        "driverSHA256": hashlib.sha256(DRIVER.read_bytes()).hexdigest(),
        "existingNineteenReplayed": False, "nativeUIExecuted": 0, "productionCorpusUsed": False}, sort_keys=True))
    raise SystemExit(not result.wasSuccessful())
