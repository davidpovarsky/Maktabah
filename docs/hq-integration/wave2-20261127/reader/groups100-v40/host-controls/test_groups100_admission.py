#!/usr/bin/env python3
"""Negative admission controls only. This script runs no app or Simulator."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import tempfile
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument("--driver", type=Path, required=True)
parser.add_argument("--core", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
if args.output.exists():
    raise FileExistsError("Preserve the previous admission-control receipt")


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


driver = module("groups100_control_target", args.driver)
core = module("original_bounded_evidence", args.core)
results = []


def check(name, expected, action):
    try:
        action()
        outcome = "accept"
    except (ValueError, OSError, KeyError, TypeError):
        outcome = "reject"
    passed = outcome == expected
    results.append({"name": name, "expected": expected, "observed": outcome, "passed": passed})
    if not passed:
        raise AssertionError(name + ": " + outcome)


def u(value):
    return "00000000-0000-4000-8000-" + str(value).zfill(12)


request = {"namespace": u(1), "sceneID": "real-scene-identifier", "profileID": u(2),
           "fromGroupID": u(3), "toGroupID": u(4), "fromDocumentID": u(5), "toDocumentID": u(6),
           "beforeRevision": 100, "afterRevision": 104, "step": 100}
metric = {"schema": 1, "namespace": u(1), "sceneID": request["sceneID"],
          "fromGroupID": u(3), "toGroupID": u(4), "observedGroupID": u(4),
          "fromDocumentID": u(5), "observedDocumentID": u(6), "beforeRevision": 101, "afterRevision": 103,
          "processID": 12345, "sequence": 101, "operationID": u(7), "launchID": u(8),
          "returnedNormally": True, "fromBackend": "otzaria", "observedBackend": "otzaria",
          "timingScope": "original group operation through ordinary session persistence",
          "memoryMetric": "phys_footprint_bytes", "memoryScope": "operation boundary samples; not continuous peak RSS",
          "footprintBeforeBytes": 123456, "footprintAfterBytes": 234567, "elapsedSeconds": 0.05}
check("unique_real_operation_shape_inside_revision_interval", "accept", lambda: driver.matched_operation([metric], request, 12345))
check("no_operation_cannot_be_inferred", "reject", lambda: driver.matched_operation([], request, 12345))
check("duplicate_original_operation_is_ambiguous", "reject", lambda: driver.matched_operation([metric, metric], request, 12345))
for key, bad in [("processID", 999), ("schema", True), ("observedDocumentID", u(99)),
                 ("observedGroupID", u(99)), ("namespace", u(99)), ("sceneID", "other"),
                 ("beforeRevision", 99), ("afterRevision", 105), ("returnedNormally", False),
                 ("observedBackend", "sefaria"), ("footprintAfterBytes", 0),
                 ("memoryMetric", "rss"), ("elapsedSeconds", float("nan"))]:
    changed = dict(metric, **{key: bad})
    check("reject_operation_" + key, "reject", lambda row=changed: driver.matched_operation([row], request, 12345))

last = {"request": request, "endSample": {"processID": 12345}}
records = [copy.deepcopy(last) for _ in range(100)]
expected = {"namespace": u(1), "catalogSHA256": "a" * 64, "databaseSHA256": "b" * 64,
            "installationManifestSHA256": "c" * 64, "containerPath": "/owned/current-container",
            "databasePath": "/owned/current-container/Library/Caches/Otzaria/seforim.db"}
pre = {"processID": 12345, "requestID": u(10), "observedUptime": 123456.0,
       "sceneID": request["sceneID"], "profileID": u(2), "groupID": u(4), "documentID": u(6),
       "canonicalLocator": "original-canonical-fixture-locator", "workspaceRevision": 105}
post = dict(pre, processID=12346, requestID=u(11), observedUptime=123499.0,
            sceneID="fresh-cold-scene", workspaceRevision=106)
proof = dict(expected, schema=1, preCold=pre, postCold=post)
check("distinct_cold_process_with_new_scene_same_owner", "accept", lambda: driver.validate_cold_fields(proof, records, expected))
check("partial99_cohort_cannot_accept_cold_proof", "reject", lambda: driver.validate_cold_fields(proof, records[:-1], expected))
for phase, key, bad in [("postCold", "processID", 12345), ("preCold", "processID", 999),
                        ("postCold", "requestID", u(10)), ("postCold", "profileID", u(99)),
                        ("postCold", "groupID", u(99)), ("postCold", "documentID", u(99)),
                        ("postCold", "canonicalLocator", "wrong"), ("postCold", "workspaceRevision", 1),
                        ("postCold", "observedUptime", float("inf"))]:
    changed = copy.deepcopy(proof); changed[phase][key] = bad
    check("reject_cold_" + phase + "_" + key, "reject", lambda p=changed: driver.validate_cold_fields(p, records, expected))
for key in ("catalogSHA256", "databaseSHA256", "installationManifestSHA256", "containerPath"):
    changed = dict(proof, **{key: "wrong"})
    check("reject_cold_" + key, "reject", lambda p=changed: driver.validate_cold_fields(p, records, expected))

with tempfile.TemporaryDirectory(prefix="groups100-admission-") as temporary:
    directory = Path(temporary)
    attachment_id = u(21)
    filename = attachment_id + ".json"
    (directory / filename).write_text(json.dumps(proof))
    udid = u(20)
    attachment = {"exportedFileName": filename,
                  "suggestedHumanReadableName": "groups100-v40-cold-process-and-installation-proof_0_" + u(22) + ".json",
                  "deviceId": udid, "configurationName": "Actual preserved manifest fixture"}
    manifest = [{"testIdentifier": driver.SELECTED[0] + "()", "attachments": [attachment]}]
    host = SimpleNamespace(namespace=u(1), records=records, container=Path(expected["containerPath"]),
                           database_relative=Path("Library/Caches/Otzaria/seforim.db"))
    inputs = {"catalog": {"sha256": "a" * 64}}
    installation = {"database": {"sha256": "b" * 64}, "installation_manifest": {"sha256": "c" * 64}}
    def read(value):
        (directory / "manifest.json").write_text(json.dumps(value))
        return driver.read_cold_proof(core, directory, udid, host, inputs, installation)
    check("genuine_export_manifest_shape_admits_one_exact_case", "accept", lambda: read(manifest))
    changed = copy.deepcopy(manifest); changed[0]["testIdentifier"] = "Other/testCase()"
    check("wrong_test_attachment_rejected", "reject", lambda: read(changed))
    changed = copy.deepcopy(manifest); changed[0]["attachments"][0]["deviceId"] = u(99)
    check("wrong_device_attachment_rejected", "reject", lambda: read(changed))
    changed = copy.deepcopy(manifest); changed[0]["attachments"].append(attachment)
    check("duplicate_cold_attachment_rejected", "reject", lambda: read(changed))
    changed = copy.deepcopy(manifest); changed[0]["attachments"][0]["exportedFileName"] = "../outside.json"
    check("escaped_export_path_rejected", "reject", lambda: read(changed))
    (directory / filename).unlink(); (directory / "actual.json").write_text(json.dumps(proof))
    (directory / filename).symlink_to("actual.json")
    check("symlink_cold_receipt_rejected", "reject", lambda: read(manifest))

report = {"status": "PASS_SOURCE_ADMISSION_CONTROLS_ONLY", "platform": platform.platform(),
          "python": platform.python_version(), "native_ui_executed": 0, "simulator_executed": 0,
          "actual_app_rss_measured": 0, "actual_cold_app_proved": 0, "cases": results,
          "driver_sha256": hashlib.sha256(args.driver.read_bytes()).hexdigest(),
          "control_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          "original_bounded_read_source_sha256": hashlib.sha256(args.core.read_bytes()).hexdigest()}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"status": report["status"], "passed": len(results), "native_ui_executed": 0}))
