#!/usr/bin/env python3
"""Synthetic file-admission controls; no app, XCTest, Simulator or corpus IO.

The only subprocesses are local git commands in a new temporary repository.
Original producer/parsers are copied byte-for-byte; their main functions are
never called. Synthetic Passed exports exercise the original file verifier and
are explicitly not native receipts. The complete order gate must remain blocked
by offline/PERF until genuine producer contracts exist.
"""
from __future__ import annotations

import argparse
import contextlib
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
import time
from types import SimpleNamespace
import unittest
import uuid

HERE = Path(__file__).resolve().parent
ARGS = None


def uid():
    return str(uuid.uuid4()).upper()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    return path


def read_json(path):
    return json.loads(path.read_bytes())


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


@contextlib.contextmanager
def replaced(path, value, *, raw=False):
    before = path.read_bytes()
    try:
        path.write_bytes(value if raw else (json.dumps(value) + "\n").encode())
        yield
    finally:
        path.write_bytes(before)


class SyntheticOriginalFiles:
    """Small test-only producer-shaped evidence, never an actual UI run."""
    def __init__(self, root):
        self.root = root
        self.root.mkdir()
        self.bindings = {}
        for relative in (
            "Scripts/CI/production-study-v40-ui.py", "Scripts/CI/study-ui-settings-receipts.py",
            "Scripts/CI/reader-groups100-v40-focused-native.py", "Scripts/CI/reader-full-v32-ui-observation.py",
            "Scripts/CI/reader-full-v40-ui-observation.py", "tools/verify_xcresult_zero_skips.py",
        ):
            source = ARGS.producer_root / relative
            data = source.read_bytes()
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
            self.bindings[relative] = {"originalPath": str(source), "bytes": len(data), "sha256": sha(data)}
        candidate = root / "Scripts/CI/study-ui-prerequisites.py"
        candidate.write_bytes(ARGS.candidate.read_bytes())
        self.helper = module(candidate, "prerequisites_fixture_" + uuid.uuid4().hex)
        self.settings = module(root / "Scripts/CI/study-ui-settings-receipts.py", "settings_fixture_" + uuid.uuid4().hex)
        for name in self.helper.TREE_KEYS:
            directory = root / name
            directory.mkdir()
            (directory / "SYNTHETIC_CONTROL.txt").write_text("Admission parser fixture; not an app or build.\n")
        self.git("init", "-q", "--initial-branch=source-controls")
        self.git("add", ".")
        self.git("-c", "user.name=Source Controls", "-c", "user.email=source-controls@example.invalid",
                 "commit", "-q", "-m", "Synthetic producer byte fixtures")
        self.anchor = self.git("rev-parse", "HEAD")
        self.trees = {key: self.git("rev-parse", "HEAD:" + key) for key in self.helper.TREE_KEYS}
        self.execution_paths = sorted(self.bindings)
        for profile in self.helper.READER_CASES:
            inputs = {"schema": "otzaria." + profile + ".original-ui-observation/1",
                      "selected_case_ids": self.helper.READER_CASES[profile],
                      "application_trees": self.trees, "application_source_sha": self.anchor,
                      "execution_input_paths": self.execution_paths,
                      "input_sha256": {key: self.settings.witness(root / key)["sha256"] for key in self.execution_paths}}
            write_json(root / ("Scripts/CI/reader-" + profile + "-ui-observation.inputs.json"), inputs)
        self.git("add", "Scripts/CI")
        self.git("-c", "user.name=Source Controls", "-c", "user.email=source-controls@example.invalid",
                 "commit", "-q", "-m", "Freeze synthetic source inputs")
        self.checkout = self.git("rev-parse", "HEAD")
        self.udid, self.v32_udid = uid(), uid()
        self.runtime = {"identifier": "synthetic.iOS-27-0", "version": "27.0", "buildversion": "SYNTHETIC_ONLY"}
        self.source = self.source_for("full-v40")
        self.source["study_ui_execution_sources"] = {
            key: self.settings.witness(root / key)
            for key in self.execution_paths + ["Scripts/CI/study-ui-prerequisites.py"]
        }
        controller = runpy.run_path(str(root / "Scripts/CI/production-study-v40-ui.py"))
        self.phases = controller["PRE_UPDATE_PHASES"]
        self.source.update(study_ui_phase="settings-update-last", executed_case_ids=controller["PHASES"]["settings-update-last"]["cases"])
        self.artifacts = root / "build/artifacts/synthetic-admission"
        self.artifacts.mkdir(parents=True)
        receipt = write_json(self.artifacts / "synthetic-build.json", {
            "status": "SIMULATOR_BUILD_FOR_REAL_UI_PASS", "checkout_sha": self.checkout,
            "SYNTHETIC_CONTROL_NOT_A_REAL_BUILD": True,
        })
        xctestrun = self.artifacts / "synthetic.xctestrun"
        xctestrun.write_text("SYNTHETIC FILE; not an XCTest input\n")
        self.images = {}
        for product, binary in (("Maktabah.app", "Maktabah"), ("Maktabah-iOSUITests-Runner.app", "Maktabah-iOSUITests-Runner")):
            self.images["build/DerivedData/Build/Products/Debug-iphonesimulator/" + product + "/" + binary] = {
                "bytes": 8, "sha256": sha(b"SYNTHETIC"), "scope": "SYNTHETIC_NOT_MACHO"}
        self.build = {"build_receipt": self.settings.witness(receipt), "xctestrun": self.settings.witness(xctestrun),
                      "built_binaries": {"synthetic": True}, "complete_native_images": self.images,
                      "actual_macho_dwarf_uuids": {"synthetic": uid()}, "qualified_sdk_route": {"synthetic": True}}
        core = runpy.run_path(str(root / "Scripts/CI/reader-full-v32-ui-observation.py"))
        self.core = SimpleNamespace(ROOT=root, OUT=self.artifacts / "gate", git=self.git, percentiles=core["percentiles"])
        self.core.OUT.mkdir()
        self.container = root / "Devices" / self.udid / "data/Containers/Data/Application" / uid()
        self.database = self.db_witness("full-v40", self.udid)
        manifest = json.dumps({"releaseID": 455390662, "releaseTag": "v40-20261123094345", "synthetic": True}).encode()
        self.manifest = {"path": str(Path(self.database["path"]).parent / "seforim-installation.json"),
                         "bytes": len(manifest), "sha256": sha(manifest)}
        installer = self.artifacts / "installer"
        installer.mkdir()
        original = {"status": "ORIGINAL_INTEGRATED_V40_NATIVE_PASS", "created_owned_simulator": self.udid,
                    "owned_simulator_cleanup": "SHUTDOWN_RETAINED_FOR_ADDITIONAL_ACCEPTANCE", "native_exit": 0,
                    "evidence_admission_exit": 0, "runtime": self.runtime, "device_type": "synthetic-iPad",
                    "SYNTHETIC_CONTROL_NOT_AN_INSTALLATION": True}
        self.original = self.settings.witness(write_json(installer / "RESULT.json", original))
        cleanup = self.settings.witness(write_json(installer / "actual-filesystem-cleanup.json", {"installation_manifest": self.manifest}))
        native = self.settings.witness(write_json(installer / "otzaria-native-bootstrap-acceptance.json", {"synthetic": True}))
        self.original_files = {"RESULT.json": self.original, "actual-filesystem-cleanup.json": cleanup,
                               "otzaria-native-bootstrap-acceptance.json": native}
        self.admission = {"database": self.database, "counts": self.helper.V40_COUNTS,
                          "original_installation": {"result": self.original}, "current_build_receipt": self.build["build_receipt"],
                          "installation_manifest": self.manifest, "original_receipts": self.original_files, "native_report": native}
        self.receipts, self.phase_paths = {}, {}
        for phase, cases in self.phases.items():
            path = self.make_phase(phase, cases)
            self.receipts["study:" + phase] = self.settings.witness(path)
            self.phase_paths[phase] = path
        self.reader_paths = {}
        for profile in self.helper.READER_CASES:
            path = self.make_reader(profile)
            self.reader_paths[profile] = path
            self.receipts[profile] = self.settings.witness(path)
        self.groups_path = self.make_groups()
        self.receipts["groups100"] = self.settings.witness(self.groups_path)
        for name in ("offline", "perf01-03"):
            self.receipts[name] = self.settings.witness(write_json(self.artifacts / name / "RESULT.json", {
                "status": "PASS", "manualSignOff": True, "scope": "Intentionally untrusted synthetic status; must never waive the gate"}))
        self.receipts_path = write_json(self.artifacts / "receipts.json", self.receipts)

    def git(self, *args):
        return subprocess.check_output(["git", "-c", "gc.auto=0", "-C", str(self.root), *args], text=True, stderr=subprocess.STDOUT).strip()

    def source_for(self, profile):
        return {"checkout_sha": getattr(self, "checkout", None), "application_source_sha": self.anchor,
                "application_trees": self.trees,
                "inputs_file_sha256": self.settings.witness(self.root / ("Scripts/CI/reader-" + profile + "-ui-observation.inputs.json"))["sha256"],
                "execution_inputs": {key: {name: value for name, value in self.settings.witness(self.root / key).items() if name != "path"}
                                     for key in self.execution_paths}}

    def db_witness(self, profile, udid):
        base = self.container if udid == self.udid else self.root / "Devices" / udid / "data/Containers/Data/Application" / uid()
        return {"path": str(base / "Documents/Otzaria/seforim.db"),
                "bytes": self.helper.V40_BYTES if profile == "full-v40" else self.helper.V32_BYTES,
                "sha256": self.helper.V40_SHA if profile == "full-v40" else self.helper.V32_SHA}

    def retained(self):
        return {"reused_external_owned_simulator": self.udid, "external_simulator_will_be_retained": True,
                "original_installation": {"result": self.original}, "runtime": self.runtime, "device_type": "synthetic-iPad"}

    def retained_cleanup(self):
        return {"status": "SHUTDOWN_RETAINED_FOR_INTEGRATION_OWNER", "udid": self.udid,
                "actual_device": {"udid": self.udid, "state": "Shutdown"}}

    def installed_images(self):
        result = {}
        for product in ("Maktabah.app", "Maktabah-iOSUITests-Runner.app"):
            prefix = "build/DerivedData/Build/Products/Debug-iphonesimulator/" + product + "/"
            result[product] = {"installed_app_container": str(self.root / "Devices" / self.udid / "data/Containers/Bundle/Application" / uid() / product),
                               "images": {key[len(prefix):]: value for key, value in self.images.items() if key.startswith(prefix)}}
        return result

    def zero_exports(self, directory, cases, device, log_name, bundle_name):
        directory.mkdir(parents=True, exist_ok=True)
        (directory / bundle_name).mkdir()
        summary = {"result": "Passed", "totalTestCount": len(cases), "passedTests": len(cases), "failedTests": 0,
                   "skippedTests": 0, "expectedFailures": 0, "testFailures": [], "SYNTHETIC_CONTROL": True}
        tree = {"devices": [{"deviceId": device, "osVersion": "27.0"}], "testNodes": [{"nodeType": "UI test bundle",
                "name": "Maktabah-iOSUITests.xctest", "result": "Passed", "children": [
                    {"nodeType": "Test Suite", "name": case.split("/")[0], "children": [
                        {"nodeType": "Test Case", "name": case.split("/")[1] + "()", "result": "Passed", "testIdentifier": case}]} for case in cases]}]}
        log = "SYNTHETIC FILE-VERIFIER CONTROL; NO XCODEBUILD EXECUTION\n" + "\n".join(
            "Test Case '-[Maktabah_iOSUITests." + case.replace("/", " ") + "]' passed (0.1 seconds)." for case in cases
        ) + "\nExecuted " + str(len(cases)) + " tests, with 0 failures\n** TEST EXECUTE SUCCEEDED **\n"
        zero = runpy.run_path(str(self.root / "tools/verify_xcresult_zero_skips.py"))["verify"](
            summary, tree, log, cases, len(cases), expected_device=device, expected_os_major=27)
        zero.update(summary_sha256=sha(json.dumps(summary, sort_keys=True).encode()), tests_sha256=sha(json.dumps(tree, sort_keys=True).encode()))
        write_json(directory / "zero-skip.json", zero)
        write_json(directory / "zero-skip.summary.json", summary)
        write_json(directory / "zero-skip.tests.json", tree)
        (directory / log_name).write_text(log)

    def make_phase(self, phase, cases):
        directory = self.artifacts / ("phase-" + phase)
        source = copy.deepcopy(self.source)
        source.update(study_ui_phase=phase, executed_case_ids=cases)
        rows = []
        for number, case in enumerate(cases, 1):
            child = directory / (str(number).zfill(2) + "-original-case")
            self.zero_exports(child, [case], self.udid, "original-ui.log", "original.xcresult")
            result = {"case": case, "case_directory": str(child), "passed": True, "xcodebuild_exit": 0, "zero_skip_exit": 0,
                      "attachment_export_exit": 0, "declaration_status": "EXECUTED_PASS",
                      "command": ["xcodebuild", "test-without-building", "-destination", "platform=iOS Simulator,id=" + self.udid,
                                  "-resultBundlePath", str(child / "original.xcresult"), "-only-testing:Maktabah-iOSUITests/" + case]}
            path = write_json(child / "RESULT.json", result)
            rows.append({**result, "case_result": self.settings.witness(path)})
        return write_json(directory / "RESULT.json", {
            **self.retained(), "status": "EXACT_REGISTERED_FULL_V40_STUDY_PHASE_UI_PASS", "study_phase": phase,
            "selected_case_ids": cases, "source_before": source, "source_after": source, "build_before": self.build,
            "build_after": self.build, "configuration": "Debug", "database_after": self.database,
            "installation_before": self.admission, "original_installation_receipts_after": self.original_files,
            "installed_images_after": self.installed_images(), "owned_cleanup": self.retained_cleanup(),
            "post_verification_failures": [], "case_results": rows, "SYNTHETIC_CONTROL_NOT_UI": True})

    def make_reader(self, profile):
        directory = self.artifacts / profile
        udid = self.udid if profile == "full-v40" else self.v32_udid
        self.zero_exports(directory, self.helper.READER_CASES[profile], udid, "original-ui-tests.log", "original-" + profile + ".xcresult")
        source = self.source_for(profile)
        write_json(directory / "source-before.json", source)
        write_json(directory / "actual-built-inputs.json", self.build)
        catalog = {"status": "ORIGINAL_SOURCE_CATALOG_ONLY_NOT_UI", "databaseSHA256": self.helper.V40_SHA if profile == "full-v40" else self.helper.V32_SHA,
                   "targets": [{"key": "synthetic-target-" + str(i)} for i in range(10)], "synthetic": True}
        write_json(directory / "source-catalog/catalog.json", catalog)
        rows, restores = [], []
        for index, target in enumerate(catalog["targets"]):
            for mode in ("process-cold", "warm"):
                epoch, observation, route_request, overview = uid(), uid(), uid(), uid()
                pid = 1000 + index
                row = {"epoch": epoch, "sourceObservationID": observation, "targetKey": target["key"], "mode": mode,
                       "processID": pid, "firstInteraction": {"epoch": overview}, "route": {
                           "receiptFields": {"request": route_request}, "requestToNativeVisibleUpperBoundSeconds": 0.25}}
                rows.append(row)
                for identifier, kind in ((epoch, "reader-open"), (overview, "reader-overview")):
                    samples = [{"processID": pid, "rss_kib": 10, "cpu_seconds": 1.0, "host_monotonic": 1.0},
                               {"processID": pid, "rss_kib": 11, "cpu_seconds": 2.0, "host_monotonic": 2.0}]
                    write_json(directory / "resource-epochs" / (identifier + ".json"), {
                        "epoch": identifier, "status": "OBSERVED_NOT_PERFORMANCE_ACCEPTANCE", "kind": kind, "processID": pid,
                        "target_key": target["key"], "mode": mode, "samples": samples, "app_cpu_seconds": 1.0,
                        "sampled_max_rss_bytes": 11 * 1024, "synthetic": True})
                write_json(directory / "source-proofs" / (observation + ".json"), {
                    "request_id": observation, "epoch": epoch, "native_process_id": pid, "target_key": target["key"],
                    "native_core_receipt_present": True, "post_resource_epoch": True, "native_core_request_id": route_request,
                    "route_visibility_upper_bound_seconds": 0.25, "synthetic": True})
            before, after, document, group = uid(), uid(), uid(), uid()
            for identifier, pid in ((before, 2000 + index), (after, 3000 + index)):
                write_json(directory / "source-proofs" / (identifier + ".json"), {
                    "native_process_id": pid, "actual_workspace_document_id": document, "actual_workspace_group_id": group,
                    "source_index": 1, "pixel_offset": -0.25, "synthetic": True})
            restores.append({"targetKey": target["key"], "documentID": document, "groupID": group,
                             "beforeRequestID": before, "afterRequestID": after, "beforeProcessID": 2000 + index,
                             "afterProcessID": 3000 + index, "beforeSource": 1, "afterSource": 1, "beforeOffset": -0.25, "afterOffset": -0.25})
        write_json(directory / "twenty-original-opens.json", {"observations": rows, "forcedRestoreEvidence": restores,
                   "forcedRelaunches": 10, "SYNTHETIC_CONTROL_NOT_UI": True})
        scales = []
        for requested in (100, 500, 2000):
            actual, identifier = requested + (1 if profile == "full-v32" else 0), uid()
            scales.append({"requestedCount": requested, "actualCount": actual, "observationID": identifier,
                           "atLeastRequestedCount": True, "exactRequestedCount": actual == requested})
            write_json(directory / "inspector-proofs" / (identifier + ".json"), {
                "status": "ORIGINAL_CACHE_AND_VISIBLE_ROW_OBSERVATIONS_NOT_FULL_RENDER_ACCEPTANCE", "request_id": identifier,
                "full_cached_count": actual, "actual_visible_rows": [{"synthetic": True}], "independent_sql_witnesses": [{"synthetic": True}]})
        scale_path = write_json(directory / "original-inspector-scales.json", {"scales": scales,
            "observationIDs": [row["observationID"] for row in scales], "natural_at_least_workloads_met": True,
            "exact_size_criterion_met": profile == "full-v40"})
        database = self.database if profile == "full-v40" else self.db_witness(profile, udid)
        report = {"status": "ORIGINAL_UI_OBSERVATIONS_COMPLETE_METRICS_REVIEW_REQUIRED", "corpus_profile": profile,
                  "data_profile": "production", "configuration": "Debug", "xcodebuild_exit": 0, "zero_skip_exit": 0,
                  "database_bytes_unchanged": True, "source_and_built_binary_bytes_unchanged": True,
                  "cleanup_or_post_verification_failures": [], "source": source, "qualified_sdk_route": self.build["qualified_sdk_route"],
                  "complete_native_image_count": len(self.images), "post_ui_database": database,
                  "runtime": self.runtime, "SYNTHETIC_CONTROL_NOT_UI": True}
        if profile == "full-v40":
            report.update(self.retained())
            report.update(reused_installation=self.admission, current_installed_images_after_ui=self.installed_images(),
                          original_installation_receipts_unchanged=self.original_files,
                          owned_cleanup={"retained_external_simulator": self.retained_cleanup()})
        else:
            report.update(created_owned_simulator=udid, owned_cleanup={"shutdown": {"exit": 0}, "delete": {"exit": 0}})
            write_json(directory / "actual-full-v32-installation.json", {"database": database, "counts": {"book": 7876, "line": 7080797}})
        path = write_json(directory / "result.json", report)
        if profile == "full-v40":
            write_json(directory / "v40-exact-inspector-final-gate.json", {
                "schema": "otzaria.full-v40.exact-inspector-final-gate/1", "status": "MET", "native_result": self.settings.witness(path),
                "original_scales": self.settings.witness(scale_path), "simulator_udid": self.udid, "observed_source": source,
                "requested_counts": [100, 500, 2000], "observed_requested_counts": [100, 500, 2000], "actual_counts": [100, 500, 2000],
                "observation_ids": [row["observationID"] for row in scales]})
        return path

    def make_groups(self):
        directory = self.artifacts / "groups100"
        self.zero_exports(directory, [self.helper.GROUPS_CASE], self.udid, "groups100-original-ui.log", "groups100-full-v40.xcresult")
        source = self.source_for("full-v40")
        source["groups100_controller"] = self.settings.witness(self.root / "Scripts/CI/reader-groups100-v40-focused-native.py")
        catalog = self.settings.witness(self.reader_paths["full-v40"].parent / "source-catalog/catalog.json")
        installation = self.settings.witness(write_json(directory / "actual-full-v40-installation.json", self.admission))
        namespace, profile, launch, scene = uid(), uid(), uid(), "synthetic-scene"
        groups, documents = [uid(), uid()], [uid(), uid()]
        records, rss = [], []
        for step in range(1, 101):
            begin_nonce, end_nonce, operation = uid(), uid(), uid()
            request = {"namespace": namespace, "profileID": profile, "sceneID": scene, "step": step,
                       "fromGroupID": groups[(step - 1) % 2], "toGroupID": groups[step % 2],
                       "fromDocumentID": documents[(step - 1) % 2], "toDocumentID": documents[step % 2],
                       "beforeRevision": step * 2, "afterRevision": step * 2 + 1, "operation": "end", "nonce": end_nonce}
            samples = [{"processID": 4000, "rss_kib": 50 + step, "host_monotonic": step * 10.0 + offset} for offset in (0, 1)]
            metric = {"schema": 1, "returnedNormally": True, "namespace": namespace, "sceneID": scene,
                      "fromGroupID": request["fromGroupID"], "toGroupID": request["toGroupID"], "observedGroupID": request["toGroupID"],
                      "fromDocumentID": request["fromDocumentID"], "observedDocumentID": request["toDocumentID"],
                      "beforeRevision": request["beforeRevision"], "afterRevision": request["afterRevision"], "processID": 4000,
                      "sequence": 100 + step, "operationID": operation, "launchID": launch, "fromBackend": "otzaria", "observedBackend": "otzaria",
                      "timingScope": "original group operation through ordinary session persistence", "memoryMetric": "phys_footprint_bytes",
                      "memoryScope": "operation boundary samples; not continuous peak RSS", "footprintBeforeBytes": 10000,
                      "footprintAfterBytes": 10000, "elapsedSeconds": 0.01}
            row = {"step": step, "request": request, "beginSample": samples[0], "endSample": samples[1], "applicationMetric": metric}
            records.append(row)
            write_json(directory / "host-observations" / (str(step).zfill(3) + ".json"), row)
            for name, nonce, sample in (("begin", begin_nonce, samples[0]), ("end", end_nonce, samples[1])):
                ack = {"nonce": nonce, "operation": name, "step": step, "status": "ORIGINAL_APP_RSS_SAMPLE",
                       "processID": 4000, "rssBytes": sample["rss_kib"] * 1024, "hostMonotonic": sample["host_monotonic"]}
                if name == "end":
                    ack["operationID"] = operation
                write_json(directory / "observer-ipc" / (nonce + ".json"), {"request": {**request, "operation": name, "nonce": nonce}, "ack": ack})
                rss.append(sample["rss_kib"] * 1024)
        write_json(directory / "actual-operation-rss-observations.json", {"namespace": namespace, "count": 100, "records": records})
        last = records[-1]["request"]
        phases = {}
        for name, pid in (("preCold", 4000), ("postCold", 5000)):
            phases[name] = {"processID": pid, "requestID": uid(), "observedUptime": 1.0, "sceneID": scene,
                            "profileID": profile, "groupID": last["toGroupID"], "documentID": last["toDocumentID"],
                            "workspaceRevision": last["afterRevision"], "canonicalLocator": "otzaria|book:28|line:1"}
        proof = {"schema": 1, "namespace": namespace, "catalogSHA256": catalog["sha256"], "databaseSHA256": self.helper.V40_SHA,
                 "installationManifestSHA256": self.manifest["sha256"], "containerPath": str(self.container),
                 "databasePath": self.database["path"], **phases}
        capture_id = uid()
        captures = directory / "captures"
        write_json(captures / (capture_id + ".json"), proof)
        export = {"deviceId": self.udid, "suggestedHumanReadableName": "groups100-v40-cold-process-and-installation-proof_1_" + capture_id + ".json",
                  "exportedFileName": capture_id + ".json"}
        write_json(captures / "manifest.json", [{"testIdentifier": self.helper.GROUPS_CASE + "()", "attachments": [export]}])
        cold = {"file": self.settings.witness(captures / (capture_id + ".json")), "proof": proof, "attachment": export,
                "export_manifest": self.settings.witness(captures / "manifest.json")}
        write_json(directory / "actual-request-container.json", {"bound_container": str(self.container),
                   "installation_manifest": self.manifest, "database_relative_path": "Documents/Otzaria/seforim.db"})
        return write_json(directory / "RESULT.json", {**self.retained(), "status": "ORIGINAL_FULL_V40_GROUPS100_UI_PASS_METRICS_OBSERVED",
            "corpus_profile": "full-v40", "data_profile": "production", "configuration": "Debug", "selected_case_ids": [self.helper.GROUPS_CASE],
            "post_verification_failures": [], "xcodebuild_exit": 0, "zero_skip_exit": 0, "attachment_export_exit": 0,
            "source_before": source, "source_after": source, "build_before": self.build, "database_after": self.database,
            "current_installed_images_after_ui": self.installed_images(), "original_installation_receipts_after": self.original_files,
            "owned_cleanup": self.retained_cleanup(), "test_inputs": {"installation": installation, "catalog": catalog},
            "actual_observation_count": 100, "boundary_rss_bytes": self.core.percentiles(rss),
            "actual_cold_process_and_installation": cold, "SYNTHETIC_CONTROL_NOT_UI": True})

    def evidence(self, **overrides):
        return self.helper.Evidence(**{**dict(core=self.core, settings=self.settings, udid=self.udid,
            source=self.source, build=self.build, installation_result=self.original), **overrides})

    def phase(self, phase="pages"):
        path = self.phase_paths[phase]
        evidence = self.evidence()
        record = self.settings.witness(path)
        return evidence.study_phase(record, evidence.read_witness(record), phase, self.phases[phase])

    def reader(self, profile):
        path = self.reader_paths[profile]
        evidence = self.evidence()
        record = self.settings.witness(path)
        return evidence.reader_suite(record, evidence.read_witness(record), profile)

    def groups(self):
        evidence = self.evidence()
        record = self.settings.witness(self.groups_path)
        return evidence.groups_suite(record, evidence.read_witness(record))


class AdmissionControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="otzaria-prerequisite-source-controls-")
        cls.fixture = SyntheticOriginalFiles(Path(cls.temporary.name) / "repository")

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def test_all_known_producer_shapes_reverify_but_no_offline_or_perf_bypass(self):
        f = self.fixture
        with self.assertRaises(f.helper.PrerequisitesNotMet) as caught:
            f.helper.admit_before_settings(f.receipts_path, core=f.core, settings=f.settings, udid=f.udid,
                source=f.source, build=f.build, installation_result=f.original, required_study_phases=f.phases)
        proof = caught.exception.proof
        self.assertEqual(proof["status"], "NOT_ADMITTED")
        self.assertEqual(proof["receipts"], f.receipts)
        for key, gate in proof["gates"].items():
            if key in ("offline", "perf01-03"):
                self.assertEqual(gate["status"], "NOT_QUALIFIED")
                self.assertTrue(gate["outstandingValidationRequirements"])
            else:
                self.assertEqual(gate["status"], "VERIFIED_ORIGINAL_RECEIPTS", (key, gate))
        self.assertEqual(proof["nativeExecutions"], 0)
        self.assertEqual(proof["databaseChanges"], 0)
        self.assertLess(caught.exception.witness["bytes"], 2 * 1024 * 1024)

    def test_v32_at_least_counts_and_own_udid_remain_accepted(self):
        result = self.fixture.reader("full-v32")
        self.assertEqual(result["simulatorUDID"], self.fixture.v32_udid)
        self.assertNotEqual(result["simulatorUDID"], self.fixture.udid)
        self.assertNotIn("exactInspectorGate", result["workload"])

    def test_current_source_tree_and_checkout_mismatch_fail(self):
        f = self.fixture
        for key, value in (("checkout_sha", "0" * 40), ("application_trees", {**f.trees, "Source": "0" * 40})):
            with self.subTest(key=key), self.assertRaises(ValueError):
                f.evidence(source={**f.source, key: value})

    def test_current_build_receipt_from_other_source_fails(self):
        f = self.fixture
        path = Path(f.build["build_receipt"]["path"])
        altered = {**read_json(path), "checkout_sha": "0" * 40}
        with replaced(path, altered), self.assertRaisesRegex(ValueError, "another source"):
            f.evidence(build={**f.build, "build_receipt": f.settings.witness(path)})

    def test_dirty_execution_input_fails_without_native_launch(self):
        f = self.fixture
        path = f.root / f.execution_paths[0]
        with replaced(path, path.read_bytes() + b"\n# dirty synthetic control\n", raw=True), self.assertRaises(ValueError):
            f.evidence()

    def test_lowered_phase_map_cannot_waive_required_study(self):
        f = self.fixture
        f.core.OUT = f.artifacts / "lowered-map"
        f.core.OUT.mkdir()
        with self.assertRaisesRegex(ValueError, "cannot waive"):
            f.helper.admit_before_settings(f.receipts_path, core=f.core, settings=f.settings, udid=f.udid,
                source=f.source, build=f.build, installation_result=f.original, required_study_phases={"pages": f.phases["pages"]})

    def test_study_owner_runtime_case_set_build_and_postfailure_rejected(self):
        f = self.fixture
        path = f.phase_paths["pages"]
        base = read_json(path)
        mutations = {
            "owner": ("reused_external_owned_simulator", uid()),
            "runtime": ("runtime", {**f.runtime, "buildversion": "OTHER"}),
            "case-order": ("selected_case_ids", list(reversed(f.phases["pages"]))),
            "post-failure": ("post_verification_failures", ["observed original failure"]),
            "build-after": ("build_after", {**f.build, "qualified_sdk_route": {"other": True}}),
            "source-after": ("source_after", {**base["source_after"], "checkout_sha": "0" * 40}),
        }
        for name, (key, value) in mutations.items():
            with self.subTest(name=name), replaced(path, {**base, key: value}), self.assertRaises(ValueError):
                f.phase()

    def test_case_record_must_equal_immutable_result_including_directory(self):
        f = self.fixture
        path = f.phase_paths["pages"]
        value = read_json(path)
        value["case_results"][0]["passed"] = False
        with replaced(path, value), self.assertRaisesRegex(ValueError, "differs from the immutable"):
            f.phase()

    def test_actual_file_verifier_rejects_skip_even_when_outer_phase_says_pass(self):
        f = self.fixture
        phase = read_json(f.phase_paths["pages"])
        directory = Path(phase["case_results"][0]["case_directory"])
        path, zero_path = directory / "zero-skip.summary.json", directory / "zero-skip.json"
        summary, zero = read_json(path), read_json(zero_path)
        summary.update(passedTests=0, skippedTests=1)
        zero["summary_sha256"] = sha(json.dumps(summary, sort_keys=True).encode())
        with replaced(path, summary), replaced(zero_path, zero), self.assertRaisesRegex(ValueError, "failed/skipped"):
            f.phase()

    def test_installed_runner_image_and_manifest_owner_rejected(self):
        f = self.fixture
        path = f.phase_paths["pages"]
        for mutation in ("runner", "manifest", "foreign-db"):
            report = read_json(path)
            if mutation == "runner":
                report["installed_images_after"]["Maktabah-iOSUITests-Runner.app"]["images"] = {}
            elif mutation == "manifest":
                report["installation_before"]["installation_manifest"]["sha256"] = "0" * 64
            else:
                report["database_after"]["path"] = report["database_after"]["path"].replace(f.udid, uid())
            with self.subTest(mutation=mutation), replaced(path, report), self.assertRaises(ValueError):
                f.phase()

    def test_full_v40_requires_twenty_distinct_opens_and_ten_new_pid_restores(self):
        f = self.fixture
        path = f.reader_paths["full-v40"].parent / "twenty-original-opens.json"
        for mutation in ("missing-open", "reused-epoch", "same-pid", "missing-owner", "reused-source-request"):
            value = read_json(path)
            if mutation == "missing-open":
                value["observations"].pop()
            elif mutation == "reused-epoch":
                value["observations"][1]["epoch"] = value["observations"][0]["epoch"]
            elif mutation == "same-pid":
                value["forcedRestoreEvidence"][0]["afterProcessID"] = value["forcedRestoreEvidence"][0]["beforeProcessID"]
            elif mutation == "missing-owner":
                del value["forcedRestoreEvidence"][0]["documentID"]
            else:
                value["observations"][1]["sourceObservationID"] = value["observations"][0]["sourceObservationID"]
            with self.subTest(mutation=mutation), replaced(path, value), self.assertRaises((ValueError, KeyError, TypeError)):
                f.reader("full-v40")

    def test_resource_epoch_requires_actual_pid_bound_samples(self):
        f = self.fixture
        directory = f.reader_paths["full-v40"].parent
        first = read_json(directory / "twenty-original-opens.json")["observations"][0]
        path = directory / "resource-epochs" / (first["epoch"] + ".json")
        for mutation in ("one-sample", "other-pid", "backward-cpu"):
            value = read_json(path)
            if mutation == "one-sample":
                value["samples"].pop()
            elif mutation == "other-pid":
                value["samples"][1]["processID"] += 1
            else:
                value["samples"][1]["cpu_seconds"] = 0
            with self.subTest(mutation=mutation), replaced(path, value), self.assertRaises(ValueError):
                f.reader("full-v40")

    def test_v40_exact_gate_cannot_relabel_at_least_or_foreign_witness(self):
        f = self.fixture
        directory = f.reader_paths["full-v40"].parent
        path = directory / "v40-exact-inspector-final-gate.json"
        for mutation in ("pending", "wrong-count", "different-native", "different-scale", "duplicate-observation"):
            value = read_json(path)
            if mutation == "pending": value["status"] = "NOT_MET"
            elif mutation == "wrong-count": value["actual_counts"] = [101, 501, 2001]
            elif mutation == "different-native": value["native_result"]["sha256"] = "0" * 64
            elif mutation == "different-scale": value["original_scales"]["sha256"] = "0" * 64
            else: value["observation_ids"][1] = value["observation_ids"][0]
            with self.subTest(mutation=mutation), replaced(path, value), self.assertRaisesRegex(ValueError, "exact-size"):
                f.reader("full-v40")

    def test_groups_hundred_cohort_and_real_nonce_ack_count_required(self):
        f = self.fixture
        self.assertEqual(f.groups()["actualOriginalACKs"], 200)
        directory = f.groups_path.parent
        path = directory / "actual-operation-rss-observations.json"
        value = read_json(path)
        value["records"].pop()
        with replaced(path, value), self.assertRaisesRegex(ValueError, "100 original"):
            f.groups()
        ipc_path = next((directory / "observer-ipc").iterdir())
        message = read_json(ipc_path)
        message["ack"]["nonce"] = uid()
        with replaced(ipc_path, message), self.assertRaisesRegex(ValueError, "ACK binding"):
            f.groups()

    def test_groups_metrics_cannot_change_retained_step_or_sequence(self):
        f = self.fixture
        path = f.groups_path.parent / "actual-operation-rss-observations.json"
        value = read_json(path)
        value["records"][50]["applicationMetric"]["sequence"] += 1
        with replaced(path, value), self.assertRaisesRegex(ValueError, "sequence has a gap"):
            f.groups()

    def test_groups_cold_requires_new_pid_and_original_export_attachment(self):
        f = self.fixture
        base = read_json(f.groups_path)
        path = Path(base["actual_cold_process_and_installation"]["file"]["path"])
        proof = read_json(path)
        proof["postCold"]["processID"] = proof["preCold"]["processID"]
        with replaced(path, proof):
            changed = copy.deepcopy(base)
            changed["actual_cold_process_and_installation"]["proof"] = proof
            changed["actual_cold_process_and_installation"]["file"] = f.settings.witness(path)
            with replaced(f.groups_path, changed), self.assertRaisesRegex(ValueError, "distinct original app PID"):
                f.groups()

    def test_groups_original_export_other_device_rejected(self):
        f = self.fixture
        path = f.groups_path.parent / "captures/manifest.json"
        value = read_json(path)
        value[0]["attachments"][0]["deviceId"] = uid()
        with replaced(path, value), self.assertRaisesRegex(ValueError, "Wrong attachment device"):
            f.groups()

    def test_changed_file_duplicate_json_and_symlink_witness_rejected(self):
        f = self.fixture
        path = f.artifacts / "malformed.json"
        path.write_text('{"status":"PASS","status":"FAIL"}')
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            f.evidence().read_path(path)
        original = f.settings.witness(path)
        path.write_text('{"changed":true}')
        with self.assertRaisesRegex(ValueError, "Changed immutable"):
            f.evidence().read_witness(original)
        link = path.with_name("redirected.json")
        link.symlink_to(path)
        with self.assertRaisesRegex(ValueError, "Redirected"):
            f.evidence().read_path(link)


def main():
    global ARGS
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--producer-root", type=Path, default=HERE / "control-inputs")
    parser.add_argument("--candidate", type=Path, default=HERE / "study-ui-prerequisites.py")
    parser.add_argument("--output", type=Path, required=True)
    ARGS = parser.parse_args()
    ARGS.producer_root, ARGS.candidate, ARGS.output = (p.resolve() for p in (ARGS.producer_root, ARGS.candidate, ARGS.output))
    ARGS.output.mkdir(exist_ok=False)
    start = time.time()
    with (ARGS.output / "controls.log").open("x") as log:
        result = unittest.TextTestRunner(stream=log, verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(AdmissionControls))
    bindings = getattr(getattr(AdmissionControls, "fixture", None), "bindings", {})
    report = {"schema": 1, "status": "SYNTHETIC_SOURCE_ADMISSION_CONTROLS_PASS" if result.wasSuccessful() else "SYNTHETIC_SOURCE_ADMISSION_CONTROLS_FAILED",
              "tests": result.testsRun, "failures": len(result.failures), "errors": len(result.errors), "skips": len(result.skipped),
              "candidate": {"path": str(ARGS.candidate), "bytes": ARGS.candidate.stat().st_size, "sha256": sha(ARGS.candidate.read_bytes())},
              "controlScriptSHA256": sha(Path(__file__).read_bytes()), "producerSources": bindings,
              "startedAtUnix": start, "finishedAtUnix": time.time(), "nativeExecutions": 0, "simulatorConnections": 0,
              "productionDatabaseReads": 0, "actualInstallations": 0, "positiveCompleteAdmissionClaimed": False,
              "scope": "Synthetic producer-shaped files, original file verifier and a temporary local git repository only. No UI/SDK/performance acceptance."}
    write_json(ARGS.output / "RESULT.json", report)
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
