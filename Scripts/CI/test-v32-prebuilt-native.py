#!/usr/bin/env python3
"""Synthetic negative controls for the v32 evidence wrapper; no native pass."""
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("v32_gate", ROOT / "Scripts/CI/hq-v32-prebuilt-native.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class EvidenceControls(unittest.TestCase):
    def fixture(self):
        common = dict(passed=True, artifactIdentity=gate.IDENTITY, documentCount=7080797,
                      sourceCount=7876, stagingAbsent=True, localIndexingRan=False,
                      productionDiscoveryRan=True, productionValidatorRan=True,
                      selectedReleaseTag=gate.TAG,
                      checks=[dict(mode=mode, query="משה", count=20, firstFilePath="otzaria-book:1")
                              for mode in ["exact", "fuzzy", "advanced"]],
                      golden=dict(query=gate.GOLDEN_QUERY, normalizedQuery="controlled query",
                                  orderedResultIDs=[101, 102], stableSourceIDs=["otzaria-book:1"] * 2,
                                  references=["reference one", "reference two"], highlightedTopResults=2))
        common.update(self.occurrence_fixture())
        install = copy.deepcopy(common) | dict(phase="install", nativeDownloadRan=True, resumedDownloadBytes=1048576)
        reopen = copy.deepcopy(common) | dict(phase="reopen", nativeDownloadRan=False, resumedDownloadBytes=0)
        log = "Captured prebuilt install PID: 123\nCaptured prebuilt reopen PID: 456\n"
        return install, reopen, log


    def occurrence_fixture(self):
        # Controlled schema examples from the retained Windows C report.
        # These synthetic gate fixtures are never Native execution evidence.
        oracle = gate.load_occurrence_oracle()
        manifest, review = oracle["manifest"], oracle["review"]
        consumer = {
            "upstreamRepository": "davidpovarsky/otzaria_search_engine",
            "upstreamBranch": "codex/otzaria-exact-occurrences-20261120",
            "upstreamCommit": review["consumerCommit"], "engineVersion": "0.1.0",
            "indexSchemaVersion": 4, "defaultGenerationOrder": 5, "adapterVersion": "0.1.0",
            "semanticEnabled": False, "syncedAt": "synthetic evidence-gate fixture",
            "semanticSidecarRevision": manifest["lexicalEngine"]["semanticSidecarRevision"],
            "resourceHashes": {k: v["sha256"] for k, v in manifest["resources"].items()
                               if k.startswith("Vendor/OtzariaSearchEngine/Resources/")},
        }
        checks = []
        for observed in review["full"]["globalSQLComparisons"]:
            query = observed["query"]
            checks.append({
                "query": query,
                "request": {"version": 1, "mode": "exact", "query": query, "facets": ["/"],
                            "bookIds": [], "timeoutMs": 60_000,
                            "limits": copy.deepcopy(gate.EXACT_OCCURRENCE_LIMITS)},
                "result": {"occurrences": observed["occurrences"],
                           "matchingLiveDocuments": observed["matchingLiveDocuments"],
                           "proof": copy.deepcopy(observed["proof"]),
                           "work": copy.deepcopy(observed["actualWork"])},
            })
        return {"consumerBuild": consumer, "artifactProducer": copy.deepcopy(manifest["lexicalEngine"]),
                "exactOccurrences": checks}

    def reject_occurrence(self, change):
        self.reject(lambda install, reopen, log: change(reopen))

    def test_both_native_phases_require_exact_occurrence_evidence(self):
        for phase in ("install", "reopen"):
            with self.subTest(phase=phase):
                self.reject(lambda a, b, log: (a if phase == "install" else b).pop("exactOccurrences") and None)

    def test_occurrence_query_inventory_rejects_missing_duplicate_and_unknown(self):
        for mode in ("missing", "duplicate", "unknown"):
            with self.subTest(mode=mode):
                def mutate(item):
                    if mode == "missing":
                        item["exactOccurrences"].pop()
                    elif mode == "duplicate":
                        item["exactOccurrences"][1] = copy.deepcopy(item["exactOccurrences"][0])
                    else:
                        item["exactOccurrences"][0]["query"] = "unknown"
                self.reject_occurrence(mutate)

    def test_document_hits_cannot_be_reported_as_occurrences(self):
        def mutate(item):
            value = item["exactOccurrences"][0]["result"]
            value["occurrences"] = value["matchingLiveDocuments"]
        self.reject_occurrence(mutate)

    def test_consumer_and_producer_must_both_match_the_directional_contract(self):
        changes = [
            lambda x: x["consumerBuild"].update(upstreamCommit=gate.load_occurrence_oracle()["review"]["producerCommit"]),
            lambda x: x["consumerBuild"].update(upstreamRepository="another/repository"),
            lambda x: x["consumerBuild"].update(resourceHashes={}),
            lambda x: x["consumerBuild"].update(indexSchemaVersion=4.0),
            lambda x: x["artifactProducer"].update(defaultGenerationOrder=5.0),
            lambda x: x["artifactProducer"].update(commit=gate.load_occurrence_oracle()["review"]["consumerCommit"]),
        ]
        for index, change in enumerate(changes):
            with self.subTest(change=index):
                self.reject_occurrence(change)

    def test_proof_refuses_other_query_scope_engine_corpus_and_count_kind(self):
        changes = [
            {"engineCommit": "0" * 40}, {"originalUpstreamBase": "1" * 40},
            {"analyzedToken": "משה"}, {"requestedFacets": ["/book/1"]},
            {"liveIndexDocuments": 18879}, {"countKind": "matchingDocuments"}, {"exact": False},
            {"requestToken": 0},
        ]
        for change in changes:
            with self.subTest(change=change):
                self.reject_occurrence(lambda x: x["exactOccurrences"][0]["result"]["proof"].update(change))

    def test_partial_error_or_invalid_scalar_cannot_pass_as_a_count(self):
        changes = [
            lambda v: v.pop("proof"),
            lambda v: v.update(error="budget_exceeded"),
            lambda v: v.update(occurrences=-1),
            lambda v: v.update(matchingLiveDocuments=True),
        ]
        for index, change in enumerate(changes):
            with self.subTest(change=index):
                self.reject_occurrence(lambda x: change(x["exactOccurrences"][0]["result"]))

    def test_reported_request_must_keep_full_scope_and_published_hard_bounds(self):
        changes = [
            lambda q: q.update(bookIds=[1]), lambda q: q.update(facets=["/book/1"]),
            lambda q: q.update(mode="fuzzy"), lambda q: q.update(timeoutMs=60_001),
            lambda q: q["limits"].update(maxCandidateDocuments=1_000_001),
            lambda q: q.update(version=True),
            lambda q: q.update(timeoutMs=60_000.0),
            lambda q: q["limits"].update(maxPositions=10_000_000.0),
        ]
        for index, change in enumerate(changes):
            with self.subTest(change=index):
                self.reject_occurrence(lambda x: change(x["exactOccurrences"][0]["request"]))

    def test_snapshot_requires_the_original_full_index_segment_without_deletes(self):
        changes = [
            lambda g: g["segments"][0].update(segmentId="a" * 32),
            lambda g: g["segments"][0].update(deleteOpstamp=1),
            lambda g: g["segments"].append(copy.deepcopy(g["segments"][0])),
            lambda g: g.update(generationId=-1),
        ]
        for index, change in enumerate(changes):
            with self.subTest(change=index):
                self.reject_occurrence(lambda x: change(x["exactOccurrences"][0]["result"]["proof"]["searcherGeneration"]))

    def test_work_evidence_must_be_complete_and_within_the_actual_request_budget(self):
        changes = [
            {"visitedCandidateDocuments": 0}, {"visitedCandidateDocuments": 1_000_001},
            {"inspectedPositions": 10_000_001}, {"visitedSegments": 0},
        ]
        for change in changes:
            with self.subTest(change=change):
                self.reject_occurrence(lambda x: x["exactOccurrences"][0]["result"]["work"].update(change))

    def test_process_local_request_tokens_and_generations_may_change_after_cold_reopen(self):
        install, reopen, log = self.fixture()
        for check in reopen["exactOccurrences"]:
            check["result"]["proof"]["requestToken"] += 1_000
            check["result"]["proof"]["searcherGeneration"]["generationId"] += 100
            # Swift may omit a nil Optional property; this still means no deletes.
            check["result"]["proof"]["searcherGeneration"]["segments"][0].pop("deleteOpstamp")
        result = gate.validate_reports(install, reopen, log)
        self.assertEqual(result["exact_occurrence_checks_per_phase"], 2)
        self.assertEqual(result["exact_occurrence_boundary"], "ACTUAL_NATIVE_SWIFT_C_BRIDGE_NOT_CORE_OR_UI")

    def test_independent_oracle_requires_both_pinned_representations(self):
        with patch.object(gate, "QUALIFICATION_REVIEW_SHA256_LF", "0" * 64):
            with self.assertRaises(RuntimeError):
                gate.load_occurrence_oracle()
        raw = gate.gzip.decompress((gate.QUALIFICATION_ROOT /
            "raw/full-sql-global-oracle/attempt4-partitioned/RESULT.json.gz").read_bytes())
        with patch.object(gate.gzip, "decompress", return_value=raw + b"\n"):
            with self.assertRaises(RuntimeError):
                gate.load_occurrence_oracle()


    def reject(self, change):
        install, reopen, log = self.fixture()
        changed_log = change(install, reopen, log)
        with self.assertRaises(RuntimeError):
            gate.validate_reports(install, reopen, log if changed_log is None else changed_log)

    def test_controlled_complete_report_is_accepted(self):
        self.assertTrue(gate.validate_reports(*self.fixture())["golden_result_identities_equal_after_restart"])

    def test_report_failure_is_not_promoted(self):
        self.reject(lambda a, b, log: b.update(passed=False))

    def test_wrong_artifact_is_rejected(self):
        self.reject(lambda a, b, log: b.update(artifactIdentity="another artifact"))

    def test_partial_corpus_is_rejected(self):
        self.reject(lambda a, b, log: b.update(sourceCount=10))

    def test_missing_native_resume_is_rejected(self):
        self.reject(lambda a, b, log: a.update(nativeDownloadRan=False, resumedDownloadBytes=0))

    def test_full_native_redownload_does_not_count_as_resume(self):
        self.reject(lambda a, b, log: a.update(nativeDownloadRan=True, resumedDownloadBytes=0))

    def test_reopen_download_is_rejected(self):
        self.reject(lambda a, b, log: b.update(nativeDownloadRan=True))

    def test_reindex_on_reopen_is_rejected(self):
        self.reject(lambda a, b, log: b.update(localIndexingRan=True))

    def test_skipped_original_validator_is_rejected(self):
        self.reject(lambda a, b, log: b.update(productionValidatorRan=False))

    def test_same_process_is_not_a_restart(self):
        self.reject(lambda a, b, log: log.replace("456", "123"))

    def test_changed_order_after_restart_is_rejected(self):
        self.reject(lambda a, b, log: b["golden"].update(orderedResultIDs=[102, 101]))

    def test_missing_query_mode_is_rejected(self):
        self.reject(lambda a, b, log: b["checks"].pop())

    def test_exact_real_manifest_passes_and_modified_bytes_fail(self):
        raw = (ROOT / "docs/hq-integration/full-v32-native-20261119/otzaria-search-manifest.json").read_bytes()
        self.assertEqual(gate.exact_manifest(raw)["artifactIdentity"], gate.IDENTITY)
        with self.assertRaises(RuntimeError):
            gate.exact_manifest(raw + b"\n")

    def selection(self, requested):
        text = (ROOT / "Scripts/run-otzaria-prebuilt-acceptance.sh").read_text()
        source = text.split("python3 <<'PY'\n", 1)[1].split("\nPY\n", 1)[0]
        runtime = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
        responses = [
            json.dumps({"runtimes": [{"identifier": runtime, "version": "27.2", "isAvailable": True}]}),
            json.dumps({"devices": {runtime: [{"name": "owned iPad", "isAvailable": True, "udid": "owned-id"},
                                              {"name": "existing device", "isAvailable": True, "udid": "existing-id"}]}})
        ]
        output = io.StringIO()
        with patch.dict(os.environ, {"OTZARIA_PREBUILT_SIMULATOR_UDID": requested}), \
             patch("subprocess.check_output", side_effect=responses), redirect_stdout(output):
            with self.assertRaises(SystemExit) as stopped:
                exec(compile(source, "<original simulator selector>", "exec"), {})
        return stopped.exception.code, output.getvalue().strip()

    def test_explicit_owned_simulator_is_used(self):
        self.assertEqual(self.selection("owned-id"), (0, "owned-id"))

    def test_unavailable_owned_simulator_cannot_fall_back(self):
        code, output = self.selection("unavailable-id")
        self.assertNotEqual(code, 0)
        self.assertEqual(output, "")


if __name__ == "__main__":
    unittest.main(verbosity=2)
