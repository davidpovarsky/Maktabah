#!/usr/bin/env python3
"""Read-only reconciliation of a failed full Release UI artifact.

Counts original finalized xcresult leaves by configuration. Prototype oracle
executions are separate. This does not run Native or convert any failed gate
into a successful one.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

CHECKOUT = "9cc346601bdb3fdda34c2c6ac59894f71dc9ea49"
APP = "7e777509d486a17bec5b4bd437a9ac7f51d3a43a"
ARCHIVE_SHA = "9cbc4b9b7a3fa7195430bbeb987094ac1fbc6398805641fd79981cd8f4953e63"
CURRENT = "c61213d9fcc8b80a8606ba00a1562215312ca2ed"
LABELS = {
    "ipad11-native": "11",
    "ipad13-native": "13",
    "ipad13-largest-text": "13-large-text",
    "iphone-native": "phone",
    "ipad13-production-release": "production-release",
}
STATUSES = {"Passed": "PASS", "Failed": "FAIL", "Skipped": "SKIP"}
START = re.compile(r"Test Case '-\[([^ ]+) ([^\]]+)\]' (started|passed|failed)([^\n]*)")
LOCATION = re.compile(r"/Maktabah-iOSUITests/([^:\r\n]+\.swift):([0-9]+): error:")
def digest(raw):
    return hashlib.sha256(raw).hexdigest()

def git(*args):
    return subprocess.check_output(["git", *args])

def walk(value):
    if isinstance(value, dict):
        if value.get("nodeType") == "Test Case":
            yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)

def case_id(identifier):
    return identifier.removesuffix("()")

def raw_cases(text):
    events = []
    for match in START.finditer(text):
        events.append({
            "case_id": match[1].rsplit(".", 1)[-1] + "/" + match[2],
            "event": match[3], "suffix": match[4].strip(), "offset": match.start(),
        })
    blocks = {}
    for index, event in enumerate(events):
        if event["event"] != "started":
            continue
        end = events[index + 1]["offset"] if index + 1 < len(events) else len(text)
        body = text[event["offset"]:end]
        errors = [line for line in body.splitlines() if ": error:" in line]
        locations = [{"path": "Maktabah-iOSUITests/" + m[1], "line": int(m[2])}
                     for m in LOCATION.finditer(body)]
        blocks.setdefault(event["case_id"], []).append({"errors": errors, "locations": locations})
    return events, blocks

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    with args.archive.open("rb") as source:
        archive_sha = hashlib.file_digest(source, "sha256").hexdigest()
    assert archive_sha == ARCHIVE_SHA, "Whole original artifact SHA mismatch"
    errors = []
    def check(condition, message):
        if not condition:
            errors.append(message)
    manifest_raw = git("show", CHECKOUT + ":Scripts/CI/runtime27-release-manifest.json")
    manifest = json.loads(manifest_raw)
    report = {
        "run_id": 44665679661, "checkout_sha": CHECKOUT, "application_and_tests_sha": APP,
        "comparison_source_sha": CURRENT, "artifact_sha256": archive_sha,
        "artifact_bytes": args.archive.stat().st_size,
        "release_manifest_sha256": digest(manifest_raw),
        "status": "FAILED_WORKFLOW_RECONCILED", "native_executed_by_this_review": 0,
        "scope": "Original run only; no PASS transfers to comparison source.",
        "configurations": [], "case_outcomes": [], "separate_oracle_outcomes": [],
    }
    with zipfile.ZipFile(args.archive) as archive:
        names = set(archive.namelist())
        check(len(names) == len(archive.namelist()), "Duplicate ZIP entry names")
        read = lambda name: json.loads(archive.read(name))
        result = read("artifacts/runtime27/result.json")
        build = read("hq-stage2/result.json")
        check(result["checkout_sha"] == build["checkout_sha"] == CHECKOUT, "Checkout mismatch")
        check(result["test_source_commit"] == build["application_source_sha"] == APP, "App/test source mismatch")
        check(result["scope"] == "full-release-ui", "Wrong source scope")
        check(result["release_manifest_sha256"] == digest(manifest_raw), "Manifest SHA mismatch")
        check(archive.read("artifacts/runtime27/release-manifest.json") == manifest_raw, "Artifact manifest bytes differ")
        check(result["test_tree"] == git("rev-parse", APP + ":Maktabah-iOSUITests").decode().strip(), "Test tree mismatch")
        check(build["status"] == "SIMULATOR_BUILD_FOR_REAL_UI_PASS", "Original Debug build not verified")
        for path, expected in build["application_trees"].items():
            actual = git("rev-parse", APP + ":" + path).decode().strip()
            check(actual == expected, "Application tree mismatch: " + path)
        input_rows = []
        for field in ("test_inputs_sha256", "helper_inputs_sha256"):
            for path, expected in result[field].items():
                actual = digest(git("show", CHECKOUT + ":" + path))
                check(actual == expected, "Input mismatch: " + path)
                input_rows.append({"kind": field, "path": path, "expected": expected, "actual": actual})
        resolved_path = "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        resolved = git("show", APP + ":" + resolved_path)
        pins = {row["identity"]: row["state"]["revision"] for row in json.loads(resolved)["pins"]}
        check(digest(resolved) == build["package_resolved_sha256"] == build["package_resolved_after_sha256"], "Package lock mismatch")
        check(pins == build["package_pins"], "Package pins mismatch")
        check(build["actual_package_checkouts"] == {k: {"head": v, "status": "CLEAN"} for k, v in pins.items()}, "Actual package sources mismatch")
        check(build["actual_source_inputs_verified"] > 0, "Missing original actual-source proof")
        report["source_verification"] = {
            "application_trees": build["application_trees"], "test_tree": result["test_tree"],
            "actual_source_inputs_verified_by_original_build": build["actual_source_inputs_verified"],
            "package_pins": pins, "input_rows": input_rows,
            "built_binary_sha256": result["built_binary_sha256"],
        }
        report["original_producer_result"] = {
            key: result.get(key) for key in ("status", "executed_ui_pass", "executed_ui_fail",
                "requested_ui_case_count", "full_release_acceptance", "error")
        }
        report["original_producer_scalar_limit"] = (
            "executed_ui_pass/fail remain initialization values 0/0 because the Release producer "
            "raises after the failed native matrix, before collect_configurations and final aggregation. "
            "Finalized original trees below independently establish actual execution."
        )
        matrix = read("artifacts/faithful-ipad-matrix.json")
        check(matrix["appSHA"] == matrix["testSHA"] == CHECKOUT, "Matrix checkout mismatch")
        report["matrix"] = {key: matrix.get(key) for key in ("appSHA", "testSHA", "configuration", "dataProfile", "status", "error")}
        for required in manifest["configurations"]:
            config_id = required["id"]
            label = LABELS[config_id]
            ui = required["required_ui_cases"]
            oracle = required.get("required_oracle_cases", [])
            check(len(ui) == len(set(ui)), "Repeated UI declaration in " + config_id)
            check(not set(ui).intersection(oracle), "Oracle/UI overlap in " + config_id)
            prefix = "artifacts/runtime27/verified-" + label
            tree_path, summary_path = prefix + ".tests.json", prefix + ".summary.json"
            item = {"configuration_id": config_id, "label": label,
                    "declared_ui": len(ui), "declared_separate_oracle": len(oracle),
                    "data_profile": required["data_profile"],
                    "requested_configuration": required.get("configuration", "Debug"),
                    "raw_execution": {}}
            if tree_path not in names or summary_path not in names:
                check(required["data_profile"] == "production", "Unexpected missing original result: " + label)
                for case in ui:
                    report["case_outcomes"].append({
                        "configuration_id": config_id, "case_id": case, "status": "NOT_RUN",
                        "basis": "Producer stopped before production invocation; no production log, report or finalized tree."
                    })
                item.update(ui_counts={"NOT_RUN": len(ui)}, oracle_counts={}, finalized_leaves=0)
                report["configurations"].append(item)
                continue
            tree_raw, summary_raw = archive.read(tree_path), archive.read(summary_path)
            tree, summary = json.loads(tree_raw), json.loads(summary_raw)
            leaves = list(walk(tree))
            by_id = collections.defaultdict(list)
            for leaf in leaves:
                by_id[case_id(leaf.get("nodeIdentifier", ""))].append(leaf)
            check(all(len(rows) == 1 for rows in by_id.values()), "Duplicate finalized leaf: " + label)
            check(set(by_id) == set(ui + oracle), "Manifest/finalized identities differ: " + label)
            counts = collections.Counter(leaf.get("result") for leaf in leaves)
            for status, key in (("Passed", "passedTests"), ("Failed", "failedTests"), ("Skipped", "skippedTests")):
                check(counts[status] == summary[key], "Summary/leaf count mismatch: " + label + "/" + status)
            check(len(leaves) == summary["totalTestCount"], "Summary total mismatch: " + label)
            checked = read(prefix + ".json")
            # The original verifier hashes sorted JSON values, then exports indented JSON bytes.
            check(checked["summary_sha256"] == digest(json.dumps(summary, sort_keys=True).encode()) and
                  checked["tests_sha256"] == digest(json.dumps(tree, sort_keys=True).encode()), "Original verifier canonical hash mismatch: " + label)
            log_name = "artifacts/test-simulator-" + label + ".log"
            text = archive.read(log_name).decode("utf-8", "replace")
            events, blocks = raw_cases(text)
            item["raw_execution"] = {
                "log_sha256": digest(archive.read(log_name)),
                "started": [e for e in events if e["event"] == "started"],
                "terminal": [e for e in events if e["event"] != "started"],
            }
            failures = collections.defaultdict(list)
            for failure in summary.get("testFailures", []):
                failures[case_id(failure["testIdentifierString"])].append(failure["failureText"])
            for collection, wanted in ((report["case_outcomes"], ui), (report["separate_oracle_outcomes"], oracle)):
                for case in wanted:
                    leaf = by_id[case][0]
                    check(leaf.get("result") in STATUSES, "Unknown finalized status: " + label + "/" + case)
                    collection.append({
                        "configuration_id": config_id, "case_id": case,
                        "status": STATUSES.get(leaf.get("result"), "UNKNOWN"),
                        "failure_messages": failures.get(case, []),
                        "raw_locations_and_errors": blocks.get(case, []),
                        "basis": tree_path, "summary_path": summary_path,
                    })
            item.update(
                ui_counts=dict(collections.Counter(STATUSES.get(by_id[c][0].get("result"), "UNKNOWN") for c in ui)),
                oracle_counts=dict(collections.Counter(STATUSES.get(by_id[c][0].get("result"), "UNKNOWN") for c in oracle)),
                finalized_leaves=len(leaves), tree_sha256=digest(tree_raw), summary_sha256=digest(summary_raw),
                start_time=summary.get("startTime"), finish_time=summary.get("finishTime"),
                device=tree.get("devices", []),
            )
            report["configurations"].append(item)
        production_entries = sorted(n for n in names if "production" in n.lower())
        check(not production_entries, "Unexpected production evidence must be inspected")
        source = git("show", CHECKOUT + ":Scripts/CI/runtime27-release.py").decode()
        expected_error = "The complete native matrix failed; production Release and distribution remain blocked"
        check(result.get("error") == expected_error, "Unexpected producer failure")
        check(source.index('raise RuntimeError("' + expected_error + '")') <
              source.index('"Scripts/CI/run-faithful-production-release.py"],'), "Production ordering changed")
        report["production"] = {
            "status": "NOT_RUN", "evidence_entries": production_entries,
            "basis": "Exact original producer exception precedes production invocation (lines184-189); no production artifacts.",
            "no_release_binary_or_full_corpus_ui_execution_claim": True,
        }
        report["totals"] = dict(collections.Counter(x["status"] for x in report["case_outcomes"]))
        report["separate_oracle_totals"] = dict(collections.Counter(x["status"] for x in report["separate_oracle_outcomes"]))
        check(len(report["case_outcomes"]) == sum(len(x["required_ui_cases"]) for x in manifest["configurations"]) == 96, "Wrong UI inventory")
        check(len(report["separate_oracle_outcomes"]) == 2, "Wrong separate oracle inventory")
    report["reconciliation_errors"] = errors
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("totals", "separate_oracle_totals", "reconciliation_errors")}, ensure_ascii=False))
    return 1 if errors else 0
if __name__ == "__main__":
    raise SystemExit(main())
