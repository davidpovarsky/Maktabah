#!/usr/bin/env python3
"""Synthetic file/metadata controls only. Never produces native UI acceptance."""
import argparse
import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import plistlib
import runpy
import sqlite3
import tempfile
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--helper", type=Path, required=True)
parser.add_argument("--repository-root", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
spec = importlib.util.spec_from_file_location("settings_receipt_gate", args.helper)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
results = []


def check(name, expected, action, contains=None):
    try:
        value = action()
    except (ValueError, OSError, KeyError, TypeError) as error:
        passed = expected == "reject" and (contains is None or contains in str(error))
        results.append({"name": name, "expected": expected, "passed": passed, "observedError": type(error).__name__ + ": " + str(error)})
    else:
        results.append({"name": name, "expected": expected, "passed": expected == "accept"})


def write(path, value):
    path.write_text(json.dumps(value, sort_keys=True) + "\n")


def uid(number):
    return str(uuid.UUID(int=number)).upper()


for name, value in (("missing", {}), ("null", {"profileID": None, "profileVersion": None}),
                    ("explicit", {"profileID": "production", "profileVersion": 1})):
    check("production-profile-" + name, "accept", lambda value=value: gate.require_production_profile(value))
for key, value in (("profileID", ""), ("profileID", "miniTest10"), ("profileID", True),
                   ("profileVersion", True), ("profileVersion", "1"), ("profileVersion", ""), ("profileVersion", 2)):
    check("reject-profile-" + key + "-" + repr(value), "reject", lambda key=key, value=value: gate.require_production_profile({key: value}))

with tempfile.TemporaryDirectory(prefix="synthetic-settings-evidence-gate-") as temporary:
    root = Path(temporary).resolve()
    evidence = root / "build/artifacts"; evidence.mkdir(parents=True)
    check("fresh-owned-evidence-output", "accept", lambda: gate.evidence_output(evidence / "receipt.json", root))
    check("reject-evidence-output-in-app-data", "reject", lambda: gate.evidence_output(root / "AppData.json", root), "outside app data")
    occupied = evidence / "occupied.json"; occupied.write_bytes(b"original")
    check("reject-overwriting-an-original-evidence-file", "reject", lambda: gate.evidence_output(occupied, root), "fresh evidence file")
    small = root / "immutable-input.json"; write(small, {"synthetic": True})
    sealed = gate.witness(small)
    check("exact-immutable-input", "accept", lambda: gate.verify_witness(sealed))
    write(small, {"synthetic": "changed"})
    check("reject-changed-immutable-input", "reject", lambda: gate.verify_witness(sealed), "Changed immutable receipt")
    alias = root / "redirected.json"; alias.symlink_to(small)
    check("reject-evidence-symlink", "reject", lambda: gate.read_bytes(alias), "Redirected/noncanonical")

    captures = root / "captures"; captures.mkdir()
    filename = uid(3) + ".json"; write(captures / filename, {"synthetic": True})
    record = {"exportedFileName": filename, "deviceId": uid(1),
              "suggestedHumanReadableName": "settings-update-installed_0_" + uid(4) + ".json"}
    export = [{"testIdentifier": gate.SETTINGS_CASE.removeprefix(gate.TARGET + "/") + "()", "attachments": [record]}]
    def selected(value):
        write(captures / "manifest.json", value)
        return gate.selected_attachment(captures, gate.SETTINGS_CASE, uid(1), "settings-update-installed")
    check("original-export-manifest-shape", "accept", lambda: selected(export))
    altered = copy.deepcopy(export); altered[0]["testIdentifier"] = "Other/testUnrelated()"
    check("reject-wrong-case-attachment", "reject", lambda: selected(altered), "Exactly one")
    altered = copy.deepcopy(export); altered[0]["attachments"][0]["deviceId"] = uid(2)
    check("reject-wrong-device-attachment", "reject", lambda: selected(altered), "Wrong attachment device")
    altered = copy.deepcopy(export); altered[0]["attachments"][0]["exportedFileName"] = "../outside.json"
    check("reject-escaped-attachment-path", "reject", lambda: selected(altered), "Escaped or invalid")
    altered = copy.deepcopy(export); altered[0]["attachments"].append(record)
    check("reject-duplicate-attachment", "reject", lambda: selected(altered), "Exactly one")

    synthetic_archive = {"schemaVersion": 1, "archive": "seforim-schema7.db.zst", "size": 7,
                         "sha256": "b" * 64, "parts": [
                             {"name": "seforim-schema7.db.zst.part-000", "size": 3, "sha256": "c" * 64},
                             {"name": "seforim-schema7.db.zst.part-001", "size": 4, "sha256": "d" * 64}]}
    archive_path, stats_path, release_path = (root / name for name in ("synthetic-archive.json", "synthetic-statistics.json", "synthetic-release.json"))
    write(archive_path, synthetic_archive); write(stats_path, {"db_version": 41, "books": 2, "lines": 3, "links": 4})
    assets = []
    for number, name, size, digest in [
        (101, "seforim-schema7.db.zst.manifest.json", archive_path.stat().st_size, hashlib.sha256(archive_path.read_bytes()).hexdigest()),
        (102, "library_stats.json", stats_path.stat().st_size, hashlib.sha256(stats_path.read_bytes()).hexdigest()),
        *[(103 + index, part["name"], part["size"], part["sha256"]) for index, part in enumerate(synthetic_archive["parts"])]]:
        assets.append({"id": number, "name": name, "size": size, "digest": "sha256:" + digest,
                       "browser_download_url": "https://github.com/" + gate.REPOSITORY + "/releases/download/" + gate.V41_TAG + "/" + name})
    release = {"id": gate.V41_ID, "tag_name": gate.V41_TAG, "draft": False, "prerelease": False,
               "url": "https://api.github.com/repos/" + gate.REPOSITORY + "/releases/" + str(gate.V41_ID), "assets": assets}
    write(release_path, release)
    paths = {"release": release_path, "fullManifest": archive_path, "statistics": stats_path}
    check("official-asset-metadata-shape-and-exact-byte-binding", "accept", lambda: gate.official_target(paths, gate.V41_ID, gate.V41_TAG))
    official, parsed_archive = gate.official_target(paths, gate.V41_ID, gate.V41_TAG)
    def managed_asset(value):
        return {"id": value["id"], "name": value["name"], "compressedSize": value["size"],
                "digest": value["digest"], "downloadURL": value["browser_download_url"]}
    manifest = {"repository": gate.REPOSITORY, "releaseID": gate.V41_ID, "releaseTag": gate.V41_TAG,
                "assetID": assets[0]["id"], "assetName": assets[0]["name"], "compressedSize": assets[0]["size"],
                "digest": assets[0]["digest"], "multipart": {"manifest": managed_asset(assets[0]),
                    "archiveName": parsed_archive["archive"], "compressedSize": 7, "digest": "sha256:" + "b" * 64,
                    "parts": [managed_asset(asset) for asset in assets[2:]]}}
    check("managed-production-profile-omission-and-multipart-identity", "accept", lambda: gate.require_installed_identity(manifest, official, parsed_archive))
    altered_manifest = copy.deepcopy(manifest); altered_manifest["compressedSize"] = 7
    check("reject-confusing-manifest-size-with-assembled-archive", "reject", lambda: gate.require_installed_identity(altered_manifest, official, parsed_archive), "manifest asset identity")
    altered_manifest = copy.deepcopy(manifest); altered_manifest["multipart"]["parts"][0]["id"] = 999
    check("reject-foreign-multipart-asset-id", "reject", lambda: gate.require_installed_identity(altered_manifest, official, parsed_archive), "multipart member identity")
    changed_release = copy.deepcopy(release); changed_release["assets"][0]["digest"] = "sha256:" + "0" * 64
    write(release_path, changed_release)
    check("reject-metadata-asset-digest-mismatch", "reject", lambda: gate.official_target(paths, gate.V41_ID, gate.V41_TAG), "asset identity/digest differs")
    write(release_path, release)

    owner_parent = root / "CoreSimulator/Devices" / uid(1) / "data/Containers/Data/Application"
    app = owner_parent / uid(10); app.mkdir(parents=True)
    metadata = app / ".com.apple.mobile_container_manager.metadata.plist"
    metadata.write_bytes(plistlib.dumps({"MCMMetadataIdentifier": gate.BUNDLE}))
    storage = app / "Library/Application Support/Maktabah-Debug"; storage.mkdir(parents=True)
    owner = gate.discover_owner(uid(1), owner_parent)
    check("original-MCM-owner-shape", "accept", lambda: gate.verified_owner(owner))
    second = owner_parent / uid(11); second.mkdir()
    (second / metadata.name).write_bytes(metadata.read_bytes())
    check("reject-ambiguous-MCM-owner", "reject", lambda: gate.discover_owner(uid(1), owner_parent), "exactly one")
    (second / metadata.name).unlink(); second.rmdir()
    check("reject-cross-device-parent", "reject", lambda: gate.discover_owner(uid(2), owner_parent), "Wrong simulator")

    for engine, (relative, manifest_name, artifact) in gate.INDEXES.items():
        index = storage / relative; index.mkdir(parents=True)
        source_key = "sourceDatabase" if engine == "otzaria" else "requiredDatabase"
        digest_key = "databaseSHA256" if engine == "otzaria" else "canonicalSHA256"
        write(index / manifest_name, {"artifactIdentity": artifact, source_key: {"releaseTag": gate.V40_TAG, digest_key: gate.V40_SHA}})
        (index / "synthetic-payload").write_bytes(b"source-control-only\n")
    before_indexes = gate.capture_indexes(storage)
    check("exact-retained-package-metadata-and-inventory", "accept", lambda: gate.require_retained_indexes(before_indexes, gate.capture_indexes(storage)))
    changed = copy.deepcopy(before_indexes)
    raw, value = gate.decode_raw(changed[0]["manifest"])
    raw = json.dumps(value, indent=2).encode()
    changed[0]["manifest"].update(rawBase64=base64.b64encode(raw).decode(), bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
    check("reject-reserialized-manifest-even-if-object-equal", "reject", lambda: gate.require_retained_indexes(before_indexes, changed), "manifest bytes")
    changed = copy.deepcopy(before_indexes); changed[1]["files"][0]["mtimeNs"] += 1
    check("reject-retained-inventory-change", "reject", lambda: gate.require_retained_indexes(before_indexes, changed), "inventory changed")
    index_root = Path(before_indexes[0]["storageRoot"])
    (index_root / "redirected-payload").symlink_to(index_root / "synthetic-payload")
    check("reject-index-symlink", "reject", lambda: gate.index_inventory(index_root), "Index member is redirected")
    (index_root / "redirected-payload").unlink()

    database = storage / "Otzaria/seforim.db"
    sql = sqlite3.connect(database)
    for table, count in (("book", 2), ("line", 3), ("link", 4)):
        sql.execute("CREATE TABLE " + table + "(id INTEGER PRIMARY KEY)")
        sql.executemany("INSERT INTO " + table + " VALUES (?)", [(n,) for n in range(count)])
    sql.commit(); sql.close()
    digest = hashlib.sha256(database.read_bytes()).hexdigest()
    statistics = {"books": 2, "lines": 3, "links": 4}
    check("read-only-small-SQL-fixture-hash-and-counts", "accept", lambda: gate.final_database(database, digest, statistics))
    check("reject-final-database-hash-mismatch", "reject", lambda: gate.final_database(database, "0" * 64, statistics), "differs from the actual installed UI attachment")
    check("reject-final-published-count-mismatch", "reject", lambda: gate.final_database(database, digest, dict(statistics, lines=2)), "counts differ")
    downloads = database.parent / "Downloads/Maktabah/Otzaria/Downloads"
    check("clean-transaction-observation", "accept", lambda: gate.cleanup_observation(database, downloads))
    pending = database.parent / "seforim-installation.json.installing"; pending.write_bytes(b"synthetic-owned-pending")
    check("reject-pending-transaction-remnant", "reject", lambda: gate.cleanup_observation(database, downloads), "transaction artifact")
    pending.unlink(); downloads.mkdir(parents=True)
    part = downloads / "seforim.db.zst.parts"; part.mkdir()
    check("reject-download-remnant", "reject", lambda: gate.cleanup_observation(database, downloads), "download artifact")
    part.rmdir()
    staging = database.parent / "seforim.db.installing.synthetic"; staging.symlink_to(database.parent / "missing")
    check("reject-dangling-staging-artifact", "reject", lambda: gate.cleanup_observation(database, downloads), "staging database")
    staging.unlink()

    context = {"simulatorUDID": uid(1), "databasePath": str(database), "downloadsPath": str(downloads),
               "annotationsPath": str(storage / "Annotations.sqlite"),
               "qualifiedLocatorsPath": str(app / "Library/Application Support/Maktabah/qualified-locators-v1.json"),
               "workspacePath": str(app / "Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json"),
               "expectedCurrentTag": gate.V40_TAG, "expectedCurrentSHA256": gate.V40_SHA,
               "expectedTargetID": gate.V41_ID, "expectedTargetTag": gate.V41_TAG}
    context_input = root / "original-context.json"; write(context_input, context)
    original_context_witness = gate.witness(context_input)
    new_app = owner_parent / uid(12)
    app.rename(new_app)
    new_owner = gate.discover_owner(uid(1), owner_parent)
    effective = {k: (str(new_app) + v[len(str(app)):] if isinstance(v, str) and v.startswith(str(app) + "/") else v)
                 for k, v in context.items()}
    effective_path = root / "effective-context.json"; write(effective_path, effective)
    binding = {"input": original_context_witness, "effective": gate.witness(effective_path),
               "relocations": [{"before": owner, "after": new_owner}]}
    check("observed-same-UDID-relocation-with-original-input-immutable", "accept", lambda: gate.verify_context_binding(binding, owner, new_owner))
    check("original-input-retained-after-relocation", "accept", lambda: gate.verify_witness(original_context_witness))
    escaped = dict(effective, annotationsPath=str(root / "Annotations.sqlite")); write(effective_path, escaped)
    changed_binding = dict(binding, effective=gate.witness(effective_path))
    check("reject-relocated-context-path-escape", "reject", lambda: gate.verify_context_binding(changed_binding, owner, new_owner), "not bound to an observed original MCM owner")
    write(effective_path, effective)
    binding["effective"] = gate.witness(effective_path)
    check("reject-unrecorded-relocation", "reject", lambda: gate.verify_context_binding(dict(binding, relocations=[]), owner, new_owner), "Unrecorded")

    # These are explicitly synthetic verifier inputs in a temporary directory;
    # no output native pass receipt or production envelope is retained.
    case_id = next(iter(gate.PAGE_CASES)); short = case_id.removeprefix(gate.TARGET + "/")
    klass, method = short.split("/")
    case = root / "synthetic-case"; case.mkdir()
    (case / "original.xcresult").mkdir()
    (case / "captures").mkdir()
    log = "Test Case '-[" + klass + " " + method + "]' passed (0.001 seconds).\nExecuted 1 test, with 0 failures\n** TEST EXECUTE SUCCEEDED **\n"
    (case / "original-ui.log").write_text(log)
    summary = {"result": "Passed", "totalTestCount": 1, "passedTests": 1, "failedTests": 0, "skippedTests": 0,
               "expectedFailures": 0, "testFailures": []}
    tree = {"devices": [{"deviceId": uid(1), "osVersion": "27.0"}], "testNodes": [
        {"nodeType": "UI test bundle", "name": gate.TARGET + ".xctest", "result": "Passed", "children": [
            {"nodeType": "Test Suite", "name": klass, "result": "Passed", "children": [
                {"nodeType": "Test Case", "name": method + "()", "result": "Passed", "testIdentifier": short + "()"}]}]}]}
    verifier = runpy.run_path(str(args.repository_root / "tools/verify_xcresult_zero_skips.py"))
    zero = verifier["verify"](summary, tree, log, [short], 1, expected_device=uid(1), expected_os_major=27)
    zero.update(summary_sha256=hashlib.sha256(json.dumps(summary, sort_keys=True).encode()).hexdigest(),
                tests_sha256=hashlib.sha256(json.dumps(tree, sort_keys=True).encode()).hexdigest())
    write(case / "zero-skip.json", zero); write(case / "zero-skip.summary.json", summary); write(case / "zero-skip.tests.json", tree)
    case_result = {"case": short, "passed": True, "xcodebuild_exit": 0, "zero_skip_exit": 0,
                   "attachment_export_exit": 0, "declaration_status": "EXECUTED_PASS",
                   "command": ["xcodebuild", "test-without-building", "-destination", "platform=iOS Simulator,id=" + uid(1),
                               "-resultBundlePath", str(case / "original.xcresult"), "-only-testing:" + case_id]}
    write(case / "RESULT.json", case_result)
    check("original-file-verifier-admits-consistent-synthetic-shape", "accept", lambda: gate.verified_execution(case, case_id, uid(1), repository_root=args.repository_root))
    altered_zero = dict(zero, skipped=1); write(case / "zero-skip.json", altered_zero)
    check("reject-zero-skip-receipt-inconsistency", "reject", lambda: gate.verified_execution(case, case_id, uid(1), repository_root=args.repository_root), "Stored zero-skip result differs")
    write(case / "zero-skip.json", zero)
    events = [{"event": kind, "namespace": uid(20), "schemaVersion": 1, "profileID": "production", "engine": "otzaria", "processID": 23}
              for kind in ("provider", "published")]
    source_name = "published-v40-otzaria-original-pages-and-independent-sql"
    attachment_filename = uid(21) + ".json"
    write(case / "captures" / attachment_filename, {"events": events, "independentSQL": {"synthetic-control": {"lineID": 1}}})
    write(case / "captures/manifest.json", [{"testIdentifier": short + "()", "attachments": [
        {"exportedFileName": attachment_filename, "deviceId": uid(1), "suggestedHumanReadableName": source_name + "_0_" + uid(22) + ".json"}]}])
    relative = "Documents/OtzariaLogs/search-native-" + uid(20) + ".jsonl"
    trace = new_app / relative; trace.parent.mkdir(parents=True)
    trace.write_text("".join(json.dumps(event) + "\n" for event in events))
    identity = gate.file_identity(trace)
    trace_baseline = {"namespace": uid(20), "relativePath": relative, "sha256": hashlib.sha256(trace.read_bytes()).hexdigest(),
                      **{key: identity[key] for key in ("bytes", "inode", "mtimeNs", "ctimeNs")}, "processID": 23,
                      "caseID": case_id, "caseStatus": "Passed", "xcresultPath": str(case / "original.xcresult"),
                      "caseResult": gate.witness(case / "RESULT.json"), "sourceAttachment": gate.witness(case / "captures" / attachment_filename),
                      "sourceDatabaseManifestSHA256": "a" * 64}
    check("existing-qualified-trace-prefix-required", "accept", lambda: gate.verified_trace_baseline(trace_baseline, new_owner, "a" * 64, repository_root=args.repository_root))
    trace.unlink()
    check("reject-absent-trace-instead-of-accepting-no-pages", "reject", lambda: gate.verified_trace_baseline(trace_baseline, new_owner, "a" * 64, repository_root=args.repository_root), "search-native-")
    trace.write_bytes(b"")
    empty_identity = gate.file_identity(trace)
    empty = dict(trace_baseline, sha256=hashlib.sha256(b"").hexdigest(), **{key: empty_identity[key] for key in ("bytes", "inode", "mtimeNs", "ctimeNs")})
    check("reject-empty-trace", "reject", lambda: gate.verified_trace_baseline(empty, new_owner, "a" * 64, repository_root=args.repository_root), "truncated")

report = {"status": "SOURCE_RECEIPT_GATE_CONTROLS_ONLY", "platform": platform.platform(), "python": platform.python_version(),
          "actualNativeUIExecutions": 0, "actualSimulatorExecutions": 0, "productionDatabasesCreatedOrRead": 0,
          "positiveProductionEnvelopesWritten": 0, "passed": sum(v["passed"] for v in results), "total": len(results),
          "helperSHA256": hashlib.sha256(args.helper.read_bytes()).hexdigest(),
          "controlSHA256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          "actualFileVerifierSHA256": hashlib.sha256((args.repository_root / "tools/verify_xcresult_zero_skips.py").read_bytes()).hexdigest(),
          "cases": results}
args.output.parent.mkdir(parents=True, exist_ok=True)
with args.output.open("x") as stream:
    json.dump(report, stream, indent=2); stream.write("\n")
print(json.dumps({key: report[key] for key in ("status", "passed", "total", "actualNativeUIExecutions")}))
raise SystemExit(0 if report["passed"] == report["total"] else 1)
