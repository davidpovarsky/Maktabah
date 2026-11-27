#!/usr/bin/env python3
"""Admit original completed v40 prerequisites before ordinary Settings update.

Read existing evidence; write one fresh prerequisite receipt only. This module
does not execute XCTest, launch a process/device, change app state, hash the
multi-GB corpus again, or turn an unqualified producer into a passing gate.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import re
import runpy
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
TARGET = "Maktabah-iOSUITests"
V40_SHA = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
V40_BYTES = 4_355_063_808
V40_COUNTS = {"book": 8259, "line": 7_925_185, "link": 7_001_824}
V32_SHA = "2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765"
V32_BYTES = 3_821_240_320
TREE_KEYS = {"Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"}
READER_CASES = {
    profile: ["FaithfulProductionReleaseTests/testTwentyOriginalFull" + version + "ReaderOpensAndForcedRelaunch",
              "FaithfulProductionReleaseTests/testOriginalFull" + version + "InspectorRelationshipScalesAndReturn"]
    for profile, version in (("full-v32", "V32"), ("full-v40", "V40"))
}
GROUPS_CASE = "StudyGroupStressNativeAcceptanceTests/testOneHundredOriginalFullV40GroupSwitchesPreserveDocumentsAndColdRestore"
EXTERNAL_KEYS = {"full-v32", "full-v40", "groups100", "offline", "perf01-03"}
MAX_RECEIPT = 16 * 1024 * 1024
PENDING_PRODUCERS = {
    "perf01-03": [
        "A source-qualified original producer contract for PERF01–03; the two Reader/Inspector observation cases explicitly leave performance acceptance open.",
        "Declared cold/warm first-content and p50/p95/CPU/RSS workloads with complete samples and exact source attribution; mixed ten-Chapter nearest-rank p95 is not per-book p95.",
        "Qualified original main-thread/main-slice and layout/hitch evidence, and actual attributable SQLite lock wait plus interaction while slow work remains pending.",
        "Separate original native cancellation/backend/DB/unit/selection/annotations/RTL/viewport correctness and bounded-memory evidence; no invented SLA, exact-first-pixel, continuous-peak or physical-PERF04 gate.",
    ],
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def finite(value, minimum=0):
    return type(value) in (int, float) and math.isfinite(value) and (minimum is None or value >= minimum)


def canonical_uuid(value):
    require(isinstance(value, str) and str(uuid.UUID(value)).upper() == value, "Canonical original UUID required")
    return value


def selector(value):
    require(isinstance(value, str) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*/test[A-Za-z0-9_]+", value),
            "Expected original class/method selector")
    return value


def strict_json(raw):
    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, "Duplicate evidence JSON key: " + key)
            result[key] = value
        return result
    def invalid(value):
        raise ValueError("Non-finite evidence JSON number: " + value)
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid)


class PrerequisitesNotMet(ValueError):
    def __init__(self, proof, witness):
        self.proof, self.witness = proof, witness
        names = [name for name, value in proof["gates"].items() if value["status"] != "VERIFIED_ORIGINAL_RECEIPTS"]
        super().__init__("Settings must preserve the sole v40 installation; unmet prerequisites: " + ", ".join(names))


class Evidence:
    def __init__(self, *, core, settings, udid, source, build, installation_result):
        self.core, self.settings = core, settings
        self.root = settings.canonical_path(core.ROOT, directory=True)
        self.udid = canonical_uuid(udid)
        self.source, self.build = source, build
        self.files = {}
        if isinstance(installation_result, dict):
            self.original = dict(installation_result)
            self.installation = self.read_witness(self.original)
        else:
            self.original, self.installation = self.read_path(installation_result)
        require(self.installation.get("status") == "ORIGINAL_INTEGRATED_V40_NATIVE_PASS"
                and self.installation.get("created_owned_simulator") == udid
                and self.installation.get("owned_simulator_cleanup") == "SHUTDOWN_RETAINED_FOR_ADDITIONAL_ACCEPTANCE"
                and self.installation.get("native_exit") == self.installation.get("evidence_admission_exit") == 0,
                "Current owner requires the actual retained successful v40 installation")
        require(isinstance(source, dict) and re.fullmatch(r"[a-f0-9]{40}", source.get("checkout_sha", ""))
                and set(source.get("application_trees", {})) == TREE_KEYS, "Current exact source/test trees are missing")
        require(core.git("rev-parse", "HEAD") == source["checkout_sha"], "Current checkout differs from the controller source")
        require({name: core.git("rev-parse", "HEAD:" + name) for name in TREE_KEYS} == source["application_trees"],
                "Current product/test trees changed")
        require(isinstance(build, dict) and build.get("built_binaries") and build.get("complete_native_images")
                and build.get("actual_macho_dwarf_uuids") and build.get("qualified_sdk_route"), "Current actual app/test/SDK build is incomplete")
        current_build = self.read_witness(build["build_receipt"])
        require(current_build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
                and current_build.get("checkout_sha") == source["checkout_sha"], "Current build receipt belongs to another source")
        self.read_witness(build["xctestrun"], json_value=False)
        self.source_identity(source, "full-v40")

    def read_witness(self, record, *, maximum=MAX_RECEIPT, json_value=True):
        raw = self.settings.verify_witness(record, maximum)
        previous = self.files.get(record["path"])
        require(previous is None or previous == record, "The same evidence path was assigned conflicting witnesses")
        self.files[record["path"]] = dict(record)
        return strict_json(raw) if json_value else raw

    def read_path(self, path, *, maximum=MAX_RECEIPT, json_value=True):
        path = self.settings.canonical_path(path)
        record = self.settings.witness(path, maximum)
        return record, self.read_witness(record, maximum=maximum, json_value=json_value)

    def source_identity(self, observed, profile):
        require(isinstance(observed, dict)
                and observed.get("checkout_sha") == self.source["checkout_sha"]
                and observed.get("application_trees") == self.source["application_trees"], "A prerequisite has different current source/test trees or checkout")
        ancestor = observed.get("application_source_sha", "")
        require(re.fullmatch(r"[a-f0-9]{40}", ancestor)
                and all(self.core.git("rev-parse", ancestor + ":" + name) == value
                        for name, value in observed["application_trees"].items()), "Frozen application source does not identify the actual current trees")
        input_path = self.root / ("Scripts/CI/reader-" + profile + "-ui-observation.inputs.json")
        input_record, inputs = self.read_path(input_path)
        require(observed.get("inputs_file_sha256") == input_record["sha256"]
                and inputs.get("schema") == "otzaria." + profile + ".original-ui-observation/1"
                and inputs.get("selected_case_ids") == READER_CASES[profile]
                and inputs.get("application_trees") == self.source["application_trees"]
                and inputs.get("application_source_sha") == ancestor, "Wrong original profile/frozen source inputs")
        execution = observed.get("execution_inputs")
        require(isinstance(execution, dict) and execution and set(execution) == set(inputs.get("execution_input_paths", [])),
                "Original execution input set differs")
        for relative, record in execution.items():
            path = Path(relative)
            require(not path.is_absolute() and ".." not in path.parts and path.parts, "Execution input escaped the current checkout")
            actual, _ = self.read_path(self.root / path, json_value=False)
            require(record == {"bytes": actual["bytes"], "sha256": actual["sha256"]}
                    and inputs.get("input_sha256", {}).get(relative) == actual["sha256"], "Original execution bytes differ: " + relative)
            require(self.core.git("hash-object", str(self.root / path)) == self.core.git("rev-parse", "HEAD:" + relative),
                    "A prerequisite execution input is dirty: " + relative)
        for key in ("study_ui_execution_sources",):
            values = observed.get(key, {})
            require(isinstance(values, dict), "Malformed study execution witnesses")
            if key in observed:
                require(values == self.source.get(key), "Study execution witnesses differ from the current qualified controller")
            for relative, record in values.items():
                require(record.get("path") == str(self.root / relative), "Study execution source belongs to another checkout")
                self.read_witness(record, json_value=False)
                require(self.core.git("hash-object", record["path"]) == self.core.git("rev-parse", "HEAD:" + relative),
                        "Study execution source is not the current committed file")
        if "groups100_controller" in observed:
            record = observed["groups100_controller"]
            relative = "Scripts/CI/reader-groups100-v40-focused-native.py"
            path = self.root / relative
            require(record.get("path") == str(path), "Groups100 controller belongs to another checkout")
            self.read_witness(record, json_value=False)
            require(self.core.git("hash-object", str(path)) == self.core.git("rev-parse", "HEAD:" + relative), "Groups100 controller source changed")
        return observed

    def build_identity(self, value):
        require(value == self.build, "Prerequisite app, runner, test, SDK or build receipt differs from the current build")
        self.read_witness(value["build_receipt"])
        self.read_witness(value["xctestrun"], json_value=False)

    def runtime_identity(self, report, *, same_device):
        actual, original = report.get("runtime"), self.installation.get("runtime")
        require(isinstance(actual, dict) and isinstance(original, dict)
                and all(isinstance(actual.get(key), str) and actual[key]
                        and actual[key] == original.get(key) for key in ("identifier", "version", "buildversion"))
                and actual["version"].split(".")[0] == "27", "Prerequisite runtime is not the original qualified current runtime")
        if same_device:
            require(report.get("device_type") == self.installation.get("device_type"), "Original retained iPad type differs")

    def retained_owner(self, report):
        require(report.get("reused_external_owned_simulator") == self.udid
                and report.get("external_simulator_will_be_retained") is True
                and report.get("original_installation", {}).get("result") == self.original,
                "Prerequisite belongs to another installation or Simulator owner")
        self.runtime_identity(report, same_device=True)

    def database_identity(self, value, profile="full-v40", *, expected_udid=None):
        expected_bytes, expected_sha = (V40_BYTES, V40_SHA) if profile == "full-v40" else (V32_BYTES, V32_SHA)
        require(isinstance(value, dict) and set(value) == {"path", "bytes", "sha256"}
                and type(value.get("bytes")) is int and value["bytes"] == expected_bytes
                and value.get("sha256") == expected_sha, "Original full corpus identity differs")
        path = Path(value["path"])
        require(path.is_absolute() and ".." not in path.parts and path.name == "seforim.db", "Invalid original database witness path")
        device = self.udid if profile == "full-v40" else expected_udid
        if device is not None:
            require("/Devices/" + canonical_uuid(device) + "/data/" in str(path),
                    "Original corpus witness belongs to another Simulator")
        return value

    def installed_images(self, records):
        require(isinstance(records, dict) and set(records) == {"Maktabah.app", "Maktabah-iOSUITests-Runner.app"},
                "Both original installed app and XCTest image closures are required")
        for product, record in records.items():
            prefix = "build/DerivedData/Build/Products/Debug-iphonesimulator/" + product + "/"
            expected = {name[len(prefix):]: value for name, value in self.build["complete_native_images"].items() if name.startswith(prefix)}
            require(expected and record.get("images") == expected, "Original installed native image closure differs: " + product)
            path = Path(record.get("installed_app_container", ""))
            require(path.is_absolute() and ".." not in path.parts and path.name == product
                    and "/Devices/" + self.udid + "/data/" in str(path), "Installed image belongs to another device")

    def retained_cleanup(self, value):
        require(isinstance(value, dict) and value.get("status") == "SHUTDOWN_RETAINED_FOR_INTEGRATION_OWNER"
                and value.get("udid") == self.udid and value.get("actual_device", {}).get("udid") == self.udid
                and value["actual_device"].get("state") == "Shutdown", "Original retained Simulator cleanup is incomplete")

    def study_phase(self, record, report, phase, cases):
        require(Path(record["path"]).name == "RESULT.json"
                and report.get("status") == "EXACT_REGISTERED_FULL_V40_STUDY_PHASE_UI_PASS"
                and report.get("study_phase") == phase and report.get("selected_case_ids") == cases
                and report.get("post_verification_failures") == [], "Original study phase did not completely pass its exact scope")
        require(report.get("source_before") == report.get("source_after"), "Study source changed during the original execution")
        observed = self.source_identity(report.get("source_before"), "full-v40")
        require(observed.get("study_ui_phase") == phase and observed.get("executed_case_ids") == cases
                and observed.get("study_ui_execution_sources"), "Missing original phase-specific source/selector witnesses")
        self.build_identity(report.get("build_before")); self.build_identity(report.get("build_after"))
        self.retained_owner(report)
        require(report.get("configuration") == "Debug", "Wrong original study build configuration")
        self.database_identity(report.get("database_after"))
        self.installation_admission(report.get("installation_before"))
        self.original_receipts(report.get("original_installation_receipts_after"))
        self.installed_images(report.get("installed_images_after"))
        self.retained_cleanup(report.get("owned_cleanup"))
        rows = report.get("case_results")
        require(isinstance(rows, list) and [value.get("case") for value in rows] == cases, "Missing, duplicate or reordered study case records")
        verified = []
        for case, row in zip(cases, rows):
            directory = self.settings.canonical_path(row.get("case_directory"), directory=True)
            require(directory.parent == Path(record["path"]).parent
                    and row.get("case_result", {}).get("path") == str(directory / "RESULT.json"), "Case directory/result is not bound to its original phase")
            raw = self.read_witness(row["case_result"])
            require(raw == {key: value for key, value in row.items() if key != "case_result"},
                    "Phase case record differs from the immutable original case RESULT")
            actual = self.settings.verified_execution(directory, TARGET + "/" + case, self.udid, repository_root=self.root)
            require(actual["caseResult"] == row["case_result"], "The actual file-based verifier selected another execution")
            for value in actual.values():
                if isinstance(value, dict) and set(value) == {"path", "bytes", "sha256"}:
                    self.read_witness(value, maximum=64 * 1024 * 1024, json_value=False)
            verified.append(actual)
        proof = {"caseExecutions": verified,
                 "scope": "Actual original exact study phase; prerequisite only, not Settings acceptance"}
        if phase == "reader-pending-sql":
            pending = runpy.run_path(str(self.root / "Scripts/CI/study-ui-pending-sql.py"))
            owner = runpy.run_path(str(self.root / "Scripts/CI/study-ui-pending-execution.py"))
            proof["pendingFetchArtifacts"] = pending["validate_phase_artifacts"](report, self)
            proof["pendingOwnedCleanup"] = owner["validate_cleanup"](report.get("pending_sql"), self, report)
            proof["fullPerformanceAcceptance"] = False
        return proof

    def suite_execution(self, directory, cases, udid, *, log_name, bundle_name):
        directory = self.settings.canonical_path(directory, directory=True)
        self.settings.canonical_path(directory / bundle_name, directory=True)
        zero_record, zero = self.read_path(directory / "zero-skip.json")
        summary_record, summary = self.read_path(directory / "zero-skip.summary.json")
        tree_record, tree = self.read_path(directory / "zero-skip.tests.json")
        log_record, raw_log = self.read_path(directory / log_name, maximum=64 * 1024 * 1024, json_value=False)
        for name, value in (("summary", summary), ("tests", tree)):
            require(zero.get(name + "_sha256") == hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest(),
                    "Original suite xcresult exports differ from its zero-skip receipt")
        verifier_path = self.root / "tools/verify_xcresult_zero_skips.py"
        verifier_record, _ = self.read_path(verifier_path, json_value=False)
        require(self.core.git("hash-object", str(verifier_path)) == self.core.git("rev-parse", "HEAD:tools/verify_xcresult_zero_skips.py"),
                "Original zero-skip verifier is not the current committed source")
        verifier = runpy.run_path(str(verifier_path))
        actual = verifier["verify"](summary, tree, raw_log.decode("utf-8"), cases, len(cases),
                                    expected_device=udid, expected_os_major=27)
        require(all(zero.get(key) == value for key, value in actual.items())
                and actual["executed_total"] == actual["required_ui_passed"] == len(cases)
                and actual["skipped"] == actual["failed"] == 0 and set(actual["cases"]) == set(cases),
                "Original suite did not execute exactly the required original cases")
        return {"actual": actual, "zeroSkip": zero_record, "summary": summary_record,
                "testTree": tree_record, "log": log_record, "verifier": verifier_record}

    def original_receipts(self, values):
        require(isinstance(values, dict) and values, "Original installer receipt set is missing")
        require(values.get("RESULT.json") == self.original, "Installer receipt set identifies another owner")
        for value in values.values():
            self.read_witness(value, json_value=False)

    def installation_admission(self, value):
        require(isinstance(value, dict), "Actual original v40 installation admission is missing")
        self.database_identity(value.get("database"))
        require(value.get("counts") == V40_COUNTS
                and value.get("original_installation", {}).get("result") == self.original
                and value.get("current_build_receipt") == self.build["build_receipt"],
                "Installation admission has another corpus, build or owner")
        metadata = value.get("installation_manifest")
        require(isinstance(metadata, dict) and set(metadata) == {"path", "bytes", "sha256"}
                and integer(metadata.get("bytes"), 1) and re.fullmatch(r"[a-f0-9]{64}", metadata.get("sha256", "")),
                "Actual v40 installation manifest witness is missing")
        require(metadata["path"] == str(Path(value["database"]["path"]).parent / "seforim-installation.json"),
                "Manifest does not belong to the observed managed corpus")
        self.original_receipts(value.get("original_receipts"))
        original_cleanup = self.read_witness(value["original_receipts"]["actual-filesystem-cleanup.json"])
        require(all(metadata[key] == original_cleanup.get("installation_manifest", {}).get(key) for key in ("bytes", "sha256"))
                and value.get("native_report") == value["original_receipts"].get("otzaria-native-bootstrap-acceptance.json"),
                "Current admission is not bound to the original native manifest/report")
        return value

    def resource_epoch(self, directory, row, kind, *, key="epoch"):
        epoch = canonical_uuid(row[key])
        record, value = self.read_path(directory / "resource-epochs" / (epoch + ".json"))
        require(value.get("epoch") == epoch and value.get("status") == "OBSERVED_NOT_PERFORMANCE_ACCEPTANCE"
                and value.get("kind") == kind and value.get("processID") == row["processID"]
                and value.get("target_key") == row["targetKey"] and value.get("mode") == row["mode"],
                "Original resource epoch does not match its actual native operation")
        samples = value.get("samples")
        require(isinstance(samples, list) and len(samples) >= 2
                and all(sample.get("processID") == row["processID"] and integer(sample.get("rss_kib"), 1)
                        and finite(sample.get("cpu_seconds")) and finite(sample.get("host_monotonic")) for sample in samples),
                "Original app PID/CPU/RSS samples are missing")
        require(all(left["host_monotonic"] <= right["host_monotonic"] and left["cpu_seconds"] <= right["cpu_seconds"]
                    for left, right in zip(samples, samples[1:]))
                and value.get("app_cpu_seconds") == samples[-1]["cpu_seconds"] - samples[0]["cpu_seconds"]
                and value.get("sampled_max_rss_bytes") == max(sample["rss_kib"] for sample in samples) * 1024,
                "Original resource summary differs from retained samples")
        return record

    def reader_workload(self, directory, profile):
        catalog_record, catalog = self.read_path(directory / "source-catalog/catalog.json")
        require(catalog.get("status") == "ORIGINAL_SOURCE_CATALOG_ONLY_NOT_UI"
                and catalog.get("databaseSHA256") == (V40_SHA if profile == "full-v40" else V32_SHA),
                "Original independently compiled source catalog differs")
        targets = catalog.get("targets")
        require(isinstance(targets, list) and len(targets) == 10
                and all(isinstance(target.get("key"), str) and target["key"] for target in targets)
                and len({target["key"] for target in targets}) == 10, "Original ten distinct catalogued units are required")
        target_keys = {target["key"] for target in targets}
        completion_record, completion = self.read_path(directory / "twenty-original-opens.json")
        rows, restores = completion.get("observations"), completion.get("forcedRestoreEvidence")
        require(isinstance(rows, list) and len(rows) == 20
                and {(row.get("targetKey"), row.get("mode")) for row in rows}
                    == {(key, mode) for key in target_keys for mode in ("process-cold", "warm")}
                and len({row.get("epoch") for row in rows}) == 20
                and len({row.get("sourceObservationID") for row in rows}) == 20,
                "All twenty distinct original cold/warm opens must be retained")
        overview_epochs = set()
        for row in rows:
            require(integer(row.get("processID"), 1), "Original Reader process identity is absent")
            self.resource_epoch(directory, row, "reader-open")
            interaction = row.get("firstInteraction", {})
            overview_epochs.add(canonical_uuid(interaction.get("epoch")))
            self.resource_epoch(directory, {**row, "epoch": interaction["epoch"]}, "reader-overview")
            identifier = canonical_uuid(row["sourceObservationID"])
            route_request = canonical_uuid(row.get("route", {}).get("receiptFields", {}).get("request"))
            _, source = self.read_path(directory / "source-proofs" / (identifier + ".json"))
            require(source.get("request_id") == identifier and source.get("epoch") == row["epoch"]
                    and source.get("native_process_id") == row["processID"] and source.get("target_key") == row["targetKey"]
                    and source.get("native_core_receipt_present") is True and source.get("post_resource_epoch") is True
                    and source.get("native_core_request_id") == route_request
                    and source.get("route_visibility_upper_bound_seconds") == row.get("route", {}).get("requestToNativeVisibleUpperBoundSeconds"),
                    "Original Reader source/visible-route proof is not bound to its native open")
        require(len(overview_epochs) == 20 and completion.get("forcedRelaunches") == 10
                and isinstance(restores, list) and len(restores) == 10
                and {row.get("targetKey") for row in restores} == target_keys, "Original overview/restoration cohort is incomplete")
        for row in restores:
            canonical_uuid(row.get("documentID")); canonical_uuid(row.get("groupID"))
            before_id, after_id = canonical_uuid(row["beforeRequestID"]), canonical_uuid(row["afterRequestID"])
            _, before = self.read_path(directory / "source-proofs" / (before_id + ".json"))
            _, after = self.read_path(directory / "source-proofs" / (after_id + ".json"))
            require(before_id != after_id and integer(row.get("beforeProcessID"), 1) and integer(row.get("afterProcessID"), 1)
                    and row["beforeProcessID"] != row["afterProcessID"]
                    and before.get("native_process_id") == row["beforeProcessID"]
                    and after.get("native_process_id") == row["afterProcessID"]
                    and before.get("actual_workspace_document_id") == after.get("actual_workspace_document_id") == row.get("documentID")
                    and before.get("actual_workspace_group_id") == after.get("actual_workspace_group_id") == row.get("groupID")
                    and before.get("source_index") == after.get("source_index") == row.get("beforeSource") == row.get("afterSource")
                    and finite(row.get("beforeOffset"), None) and finite(row.get("afterOffset"), None)
                    and before.get("pixel_offset") == row["beforeOffset"] and after.get("pixel_offset") == row["afterOffset"]
                    and abs(row["beforeOffset"] - row["afterOffset"]) <= 1,
                    "Original forced restore did not preserve the native owner/source/offset with a new PID")
        scales_record, scales = self.read_path(directory / "original-inspector-scales.json")
        rows, ids = scales.get("scales"), scales.get("observationIDs")
        require(isinstance(rows, list) and len(rows) == 3
                and [row.get("requestedCount") for row in rows] == [100, 500, 2000]
                and isinstance(ids, list) and ids and len(ids) == len(set(ids))
                and scales.get("natural_at_least_workloads_met") is True, "Original three natural Inspector workloads are incomplete")
        for row in rows:
            request = canonical_uuid(row["observationID"])
            require(request in ids and integer(row.get("actualCount"), row["requestedCount"])
                    and row.get("atLeastRequestedCount") is True, "Original at-least scale has no actual count")
            _, observed = self.read_path(directory / "inspector-proofs" / (request + ".json"))
            require(observed.get("status") == "ORIGINAL_CACHE_AND_VISIBLE_ROW_OBSERVATIONS_NOT_FULL_RENDER_ACCEPTANCE"
                    and observed.get("request_id") == request and observed.get("full_cached_count") == row["actualCount"]
                    and observed.get("actual_visible_rows") and observed.get("independent_sql_witnesses"),
                    "Original Inspector count/row/source witness is incomplete")
        return {"catalog": catalog_record, "readerCompletion": completion_record, "inspectorScales": scales_record,
                "actualReaderOpens": 20, "actualForcedRestores": 10, "actualInspectorScales": 3,
                "scope": "Original UI observations; no first-pixel/per-book-p95/full-performance claim"}, scales

    def reader_suite(self, record, report, profile):
        directory = Path(record["path"]).parent
        require(Path(record["path"]).name == "result.json"
                and report.get("status") == "ORIGINAL_UI_OBSERVATIONS_COMPLETE_METRICS_REVIEW_REQUIRED"
                and report.get("corpus_profile") == profile and report.get("data_profile") == "production"
                and report.get("configuration") == "Debug" and report.get("xcodebuild_exit") == report.get("zero_skip_exit") == 0
                and report.get("database_bytes_unchanged") is True and report.get("source_and_built_binary_bytes_unchanged") is True
                and report.get("cleanup_or_post_verification_failures") == [], "Original full-corpus suite or immutable postchecks are incomplete")
        self.source_identity(report.get("source"), profile)
        _, before_source = self.read_path(directory / "source-before.json")
        require(before_source == report["source"], "Original full-corpus source receipt differs")
        _, observed_build = self.read_path(directory / "actual-built-inputs.json")
        self.build_identity(observed_build)
        require(report.get("qualified_sdk_route") == self.build["qualified_sdk_route"]
                and report.get("complete_native_image_count") == len(self.build["complete_native_images"]), "Original full-corpus SDK/image closure differs")
        self.database_identity(report.get("post_ui_database"), profile)
        if profile == "full-v40":
            self.retained_owner(report)
            self.installation_admission(report.get("reused_installation"))
            self.installed_images(report.get("current_installed_images_after_ui"))
            self.original_receipts(report.get("original_installation_receipts_unchanged"))
            self.retained_cleanup(report.get("owned_cleanup", {}).get("retained_external_simulator"))
            udid = self.udid
        else:
            udid = canonical_uuid(report.get("created_owned_simulator"))
            require(udid != self.udid and "reused_external_owned_simulator" not in report,
                    "The original full-v32 case must use its own created Simulator")
            self.runtime_identity(report, same_device=False)
            cleanup = report.get("owned_cleanup", {})
            require(all(cleanup.get(key, {}).get("exit") == 0 for key in ("shutdown", "delete")),
                    "Original v32-created Simulator cleanup failed")
            _, installation = self.read_path(directory / "actual-full-v32-installation.json")
            self.database_identity(installation.get("database"), profile, expected_udid=udid)
            self.database_identity(report.get("post_ui_database"), profile, expected_udid=udid)
            require(installation.get("counts") == {"book": 7876, "line": 7080797}, "Original full-v32 SQL corpus counts differ")
        execution = self.suite_execution(directory, READER_CASES[profile], udid,
                                          log_name="original-ui-tests.log", bundle_name="original-" + profile + ".xcresult")
        workload, scales = self.reader_workload(directory, profile)
        if profile == "full-v40":
            natural_record, natural = self.read_path(directory / "v40-natural-inspector-final-gate.json")
            actual = [row["actualCount"] for row in scales["scales"]]
            requested = [row["requestedCount"] for row in scales["scales"]]
            require(natural.get("schema") == "otzaria.full-v40.natural-inspector-final-gate/1"
                    and natural.get("status") == "MET"
                    and natural.get("native_result") == record and natural.get("original_scales") == workload["inspectorScales"]
                    and natural.get("simulator_udid") == self.udid and natural.get("observed_source") == report["source"]
                    and natural.get("requested_counts") == natural.get("observed_requested_counts") == requested == [100, 500, 2000]
                    and natural.get("actual_counts") == actual
                    and all(type(count) is int and count >= minimum for count, minimum in zip(actual, requested))
                    and scales.get("natural_at_least_workloads_met") is True
                    and natural.get("exact_size_criterion_met") is scales.get("exact_size_criterion_met")
                    and scales.get("exact_size_criterion_met") is all(a == r for a, r in zip(actual, requested))
                    and all(row.get("exactRequestedCount") is (row["actualCount"] == row["requestedCount"])
                            for row in scales["scales"])
                    and len(set(natural.get("observation_ids", []))) == 3
                    and natural["observation_ids"] == [row["observationID"] for row in scales["scales"]],
                    "The original v40 natural workload gate is not genuinely MET")
            validator = runpy.run_path(str(self.root / "Scripts/CI/reader-full-v40-ui-observation.py"))
            actual_memberships = validator["natural_inspector_evidence"](directory, scales, self.read_path)
            require(natural.get("natural_memberships") == actual_memberships,
                    "Whole SQL/service/native memberships changed after original natural workload completion")
            workload["naturalInspectorGate"] = natural_record
            workload["naturalInspectorMemberships"] = actual_memberships
        return {"execution": execution, "workload": workload, "simulatorUDID": udid}

    def groups_suite(self, record, report):
        directory = Path(record["path"]).parent
        require(Path(record["path"]).name == "RESULT.json"
                and report.get("status") == "ORIGINAL_FULL_V40_GROUPS100_UI_PASS_METRICS_OBSERVED"
                and report.get("corpus_profile") == "full-v40" and report.get("data_profile") == "production"
                and report.get("configuration") == "Debug" and report.get("selected_case_ids") == [GROUPS_CASE]
                and report.get("post_verification_failures") == []
                and report.get("xcodebuild_exit") == report.get("zero_skip_exit") == report.get("attachment_export_exit") == 0,
                "Original Groups100 UI execution is incomplete")
        require(report.get("source_before") == report.get("source_after"), "Groups source changed during execution")
        self.source_identity(report.get("source_before"), "full-v40")
        self.build_identity(report.get("build_before"))
        self.retained_owner(report)
        self.database_identity(report.get("database_after"))
        self.installed_images(report.get("current_installed_images_after_ui"))
        self.original_receipts(report.get("original_installation_receipts_after"))
        self.retained_cleanup(report.get("owned_cleanup"))
        execution = self.suite_execution(directory, [GROUPS_CASE], self.udid,
                                          log_name="groups100-original-ui.log", bundle_name="groups100-full-v40.xcresult")
        inputs = report.get("test_inputs", {})
        installation = self.installation_admission(self.read_witness(inputs["installation"]))
        catalog = self.read_witness(inputs["catalog"])
        require(catalog.get("databaseSHA256") == V40_SHA and catalog.get("status") == "ORIGINAL_SOURCE_CATALOG_ONLY_NOT_UI",
                "Groups source catalog differs from the full-v40 corpus")
        metrics_record, metrics = self.read_path(directory / "actual-operation-rss-observations.json")
        rows = metrics.get("records")
        require(report.get("actual_observation_count") == metrics.get("count") == 100
                and isinstance(rows, list) and len(rows) == 100
                and [row.get("step") for row in rows] == list(range(1, 101)), "All 100 original group operations are required")
        namespace = canonical_uuid(metrics.get("namespace"))
        driver_path = self.root / "Scripts/CI/reader-groups100-v40-focused-native.py"
        original = runpy.run_path(str(driver_path))
        require(report["source_before"].get("groups100_controller") == self.settings.witness(driver_path),
                "The actual original Groups parser source is not bound")
        pids, launches, operations, profiles = set(), set(), set(), set()
        rss_values, previous_sequence, previous_end = [], None, None
        for row in rows:
            request = row["request"]
            require(request.get("namespace") == namespace and request.get("step") == row["step"]
                    and request.get("operation") == "end", "Groups operation is outside the actual namespace/cohort")
            profiles.add(canonical_uuid(request["profileID"]))
            for phase in ("beginSample", "endSample"):
                sample = row[phase]
                require(integer(sample.get("processID"), 1) and integer(sample.get("rss_kib"), 1)
                        and finite(sample.get("host_monotonic")), "Missing actual native app-PID RSS boundary sample")
                pids.add(sample["processID"]); rss_values.append(sample["rss_kib"] * 1024)
            require(row["beginSample"]["host_monotonic"] <= row["endSample"]["host_monotonic"]
                    and (previous_end is None or previous_end <= row["beginSample"]["host_monotonic"]),
                    "Original group operation samples overlap or move backwards")
            previous_end = row["endSample"]["host_monotonic"]
            metric = original["matched_operation"]([row["applicationMetric"]], request, row["endSample"]["processID"])
            require(previous_sequence is None or metric["sequence"] == previous_sequence + 1, "Original app operation sequence has a gap")
            previous_sequence = metric["sequence"]
            launches.add(canonical_uuid(metric["launchID"])); operations.add(canonical_uuid(metric["operationID"]))
            _, retained = self.read_path(directory / "host-observations" / (str(row["step"]).zfill(3) + ".json"))
            require(retained == row, "Groups summary changed its retained original per-step observation")
        require(len(pids) == len(launches) == len(profiles) == 1 and len(operations) == 100
                and len(rss_values) == 200 and report.get("boundary_rss_bytes") == self.core.percentiles(rss_values),
                "Actual 100-operation/200-RSS cohort identity or summary differs")
        ipc = self.settings.canonical_path(directory / "observer-ipc", directory=True)
        members = list(ipc.iterdir())
        require(len(members) == 200 and all(path.suffix == ".json" and path.stem == canonical_uuid(path.stem) for path in members),
                "Exactly 200 original nonce-bound RSS acknowledgements are required")
        by_step = {}
        for path in members:
            _, message = self.read_path(path)
            request, ack = message["request"], message["ack"]
            require(request.get("nonce") == ack.get("nonce") == path.stem and request.get("operation") in ("begin", "end")
                    and ack.get("operation") == request["operation"] and ack.get("step") == request.get("step")
                    and ack.get("status") == "ORIGINAL_APP_RSS_SAMPLE" and integer(request.get("step"), 1)
                    and request["step"] <= 100, "Original RSS request/ACK binding differs")
            pair = (request["step"], request["operation"])
            require(pair not in by_step, "A group boundary ACK was counted twice")
            by_step[pair] = message
        for row in rows:
            begin, end = by_step[(row["step"], "begin")], by_step[(row["step"], "end")]
            require(end["request"] == row["request"]
                    and all(begin["request"][key] == end["request"][key] for key in original["IDENTITY_KEYS"]),
                    "Original begin/end requests do not identify the same native transition")
            for message, name in ((begin, "beginSample"), (end, "endSample")):
                ack, sample = message["ack"], row[name]
                require(ack.get("processID") == sample["processID"] and ack.get("rssBytes") == sample["rss_kib"] * 1024
                        and ack.get("hostMonotonic") == sample["host_monotonic"], "ACK is not the retained actual app RSS sample")
            require("operationID" not in begin["ack"] and end["ack"].get("operationID") == row["applicationMetric"]["operationID"],
                    "Original operation ID is not bound to the end ACK")
        selected = self.settings.selected_attachment(directory / "captures", TARGET + "/" + GROUPS_CASE, self.udid,
                    "groups100-v40-cold-process-and-installation-proof")
        cold = report.get("actual_cold_process_and_installation", {})
        require(cold.get("file") == selected["file"] and cold.get("proof") == selected["contents"]
                and cold.get("attachment") == selected["exportRecord"] and cold.get("export_manifest") == selected["exportManifest"],
                "Groups cold proof differs from the original passed-case attachment")
        self.read_witness(selected["file"]); self.read_witness(selected["exportManifest"])
        _, container = self.read_path(directory / "actual-request-container.json")
        bound = Path(container["bound_container"])
        require(bound.is_absolute() and ".." not in bound.parts
                and "/Devices/" + self.udid + "/data/Containers/Data/Application/" in str(bound)
                and container.get("installation_manifest", {}).get("sha256") == installation["installation_manifest"]["sha256"],
                "Original Groups request container belongs to another install")
        relative = Path(container["database_relative_path"])
        require(not relative.is_absolute() and ".." not in relative.parts and relative.name == "seforim.db",
                "Groups database relative path escaped its observed owner")
        require(str(bound / relative) == report["database_after"]["path"], "Groups cold/source/post-UI data container differs")
        expected = {"namespace": namespace, "catalogSHA256": inputs["catalog"]["sha256"],
                    "databaseSHA256": V40_SHA, "installationManifestSHA256": installation["installation_manifest"]["sha256"],
                    "containerPath": str(bound), "databasePath": str(bound / relative)}
        original["validate_cold_fields"](selected["contents"], rows, expected)
        return {"execution": execution, "operationObservations": metrics_record, "actualOperations": 100,
                "actualRSSSamples": 200, "actualOriginalACKs": 200, "coldProof": selected["file"],
                "scope": "Actual original Groups100 transitions and cold restore; no invented performance SLA"}

    def reverify_files(self):
        for record in list(self.files.values()):
            self.settings.verify_witness(record, max(MAX_RECEIPT, record["bytes"]))


def admit_before_settings(receipts_path, *, core, settings, udid, source, build,
                          installation_result, required_study_phases):
    """Return {proof, witness}; raise PrerequisitesNotMet with both on failure.

    Gate names are study:<phase>, full-v32, full-v40, groups100, offline and
    perf01-03. Values are immutable FileWitnesses of actual original RESULT
    files. No operator acknowledgement or arbitrary status can waive a gate.
    """
    require(isinstance(required_study_phases, dict) and required_study_phases,
            "The integration owner must supply the complete original prerequisite phase/selector map")
    for phase, cases in required_study_phases.items():
        require(isinstance(phase, str) and re.fullmatch(r"[a-z][a-z0-9-]*", phase)
                and phase != "settings-update-last" and isinstance(cases, list) and cases
                and len(cases) == len(set(cases)), "Invalid or circular study prerequisite scope")
        for case in cases:
            selector(case)
    output = settings.evidence_output(Path(core.OUT) / "settings-prerequisites.json", core.ROOT)
    evidence = Evidence(core=core, settings=settings, udid=udid, source=source, build=build,
                        installation_result=installation_result)
    controller = Path(core.ROOT) / "Scripts/CI/production-study-v40-ui.py"
    require(source.get("study_ui_execution_sources", {}).get("Scripts/CI/production-study-v40-ui.py")
            == settings.witness(controller), "The original prerequisite phase-map producer is not source-bound")
    require(runpy.run_path(str(controller)).get("PRE_UPDATE_PHASES") == required_study_phases,
            "Supplied phase/selector map cannot waive an original required study phase")
    input_record, receipts = evidence.read_path(receipts_path)
    require(isinstance(receipts, dict), "Prerequisites input must map gate names to immutable FileWitnesses")
    required = {"study:" + phase for phase in required_study_phases} | EXTERNAL_KEYS
    require(not (set(receipts) - required), "Unknown prerequisite keys cannot create an alternate approval path")
    proof = {"schema": "otzaria.before-settings-prerequisites/1", "status": "NOT_ADMITTED",
             "simulatorUDID": udid, "checkoutSHA": source["checkout_sha"],
             "applicationTrees": source["application_trees"], "currentBuildReceipt": build["build_receipt"],
             "originalInstallationResult": evidence.original, "input": input_record,
             "requiredStudyPhases": required_study_phases, "receipts": {}, "gates": {},
             "nativeExecutions": 0, "databaseChanges": 0, "physicalPERF04Included": False,
             "scope": "Order/identity gate before ordinary Settings can replace the sole retained v40 corpus"}
    for key in sorted(required):
        gate = {"status": "NOT_QUALIFIED"}
        proof["gates"][key] = gate
        try:
            require(key in receipts, "Required original receipt is missing")
            report = evidence.read_witness(receipts[key])
            require(isinstance(report, dict), "Original result must be an object")
            proof["receipts"][key] = receipts[key]
            if key in PENDING_PRODUCERS:
                gate["outstandingValidationRequirements"] = PENDING_PRODUCERS[key]
                raise ValueError("No genuine source-qualified producer contract has been admitted for this gate")
            if key.startswith("study:"):
                phase = key.removeprefix("study:")
                gate["proof"] = evidence.study_phase(receipts[key], report, phase, required_study_phases[phase])
            elif key in READER_CASES:
                gate["proof"] = evidence.reader_suite(receipts[key], report, key)
            elif key == "groups100":
                gate["proof"] = evidence.groups_suite(receipts[key], report)
            elif key == "offline":
                # Reconstruct both complete original transport/native/root
                # joins from their retained immutable evidence. A status,
                # operator acknowledgement or ordinary-network case cannot
                # substitute for this producer's observed denial/cleanup.
                producer = Path(core.ROOT) / "Scripts/CI/study-ui-offline-execution.py"
                require(source.get("study_ui_execution_sources", {}).get("Scripts/CI/study-ui-offline-execution.py")
                        == settings.witness(producer), "Original offline validator is not source-bound")
                gate["proof"] = runpy.run_path(str(producer))["validate_suite"](receipts[key], evidence=evidence)
            else:
                raise ValueError("Required gate has no original evidence validator")
            gate["status"] = "VERIFIED_ORIGINAL_RECEIPTS"
        except Exception as error:
            gate.update(errorType=type(error).__name__, error=str(error))
            if key in PENDING_PRODUCERS:
                gate["outstandingValidationRequirements"] = PENDING_PRODUCERS[key]
    evidence.reverify_files()
    require(core.git("rev-parse", "HEAD") == source["checkout_sha"], "Source changed while admitting prerequisite evidence")
    proof["evidenceFiles"] = [evidence.files[name] for name in sorted(evidence.files)]
    proof["observedAtUnix"] = time.time()
    if all(value["status"] == "VERIFIED_ORIGINAL_RECEIPTS" for value in proof["gates"].values()):
        proof["status"] = "ADMITTED_BEFORE_ORIGINAL_SETTINGS"
    result = settings.write_new(output, proof)
    if proof["status"] != "ADMITTED_BEFORE_ORIGINAL_SETTINGS":
        raise PrerequisitesNotMet(proof, result)
    return {"proof": proof, "witness": result}
