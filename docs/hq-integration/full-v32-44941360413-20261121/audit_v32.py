import argparse
import datetime
import gzip
import hashlib
import json
import plistlib
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import zipfile

REPO = Path(__file__).resolve().parents[3]
BUILD = Path(__file__).resolve().parent
CHECKOUT = "1da5532834315d6aebe3402751a3bf0682753c9f"
APP = "cf44ada2a47aa0abb152af1fdce4f14d5417456d"
CURRENT = "2818019c7dcecda953c74caa4f38823fb97cf70f"
ZIP_SHA = "d9d26b6035f7a282f3217045308d82bf3c00df3b3c9acf61e5b2005471754316"


def git(*args):
    return subprocess.run(["git", "-C", str(REPO), *args], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=True).stdout


def digest(data):
    return hashlib.sha256(data).hexdigest()


def tree(ref):
    entries = {}
    for row in git("ls-tree", "-rz", "--full-tree", ref).split(b"\0"):
        if row:
            header, path = row.split(b"\t", 1)
            mode, kind, oid = header.decode().split()
            entries[path.decode("utf-8")] = {"mode": mode, "kind": kind, "oid": oid}
    return entries


def main():
    global REPO, BUILD
    parser = argparse.ArgumentParser(description="Read-only audit of retained full-v32 evidence; never runs Native or corpus work.")
    parser.add_argument("--repo", type=Path, default=REPO)
    parser.add_argument("--evidence", type=Path, default=BUILD)
    parser.add_argument("--output", type=Path, help="Optional new audit report; omitted by default.")
    args = parser.parse_args()
    REPO, BUILD = args.repo.resolve(), args.evidence.resolve()
    archive = BUILD / "full-v32-native-prebuilt-evidence.zip"
    raw = archive.read_bytes()
    assert len(raw) == 1358070 and digest(raw) == ZIP_SHA
    api_artifact = json.loads((BUILD / "artifact-metadata.json").read_bytes())
    api_run = json.loads((BUILD / "run-metadata.json").read_bytes())
    assert api_artifact["id"] == 14722834927
    assert api_artifact["name"] == "full-v32-native-prebuilt-evidence"
    assert api_artifact["size_in_bytes"] == len(raw)
    assert api_artifact["digest"] == "sha256:" + ZIP_SHA
    assert api_artifact["workflow_run"]["id"] == api_run["id"] == 44941360413
    assert api_artifact["workflow_run"]["head_sha"] == api_run["head_sha"] == CHECKOUT
    assert api_run["status"] == "completed" and api_run["conclusion"] == "success"
    assert api_run["run_attempt"] == 1 and api_run["event"] == "workflow_dispatch"

    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        members = z.infolist()
        assert len({m.filename for m in members}) == len(members)
        assert all(not PurePosixPath(m.filename).is_absolute() and ".." not in PurePosixPath(m.filename).parts for m in members)
        load = lambda name: json.loads(z.read(name))
        run = load("hq-v32-prebuilt-native/run.json")
        preflight = load("hq-v32-prebuilt-native/preflight.json")
        prepare = load("hq-v32-prebuilt-native/prepare.json")
        install = load("hq-v32-prebuilt-native/reports/otzaria-prebuilt-install.json")
        reopen = load("hq-v32-prebuilt-native/reports/otzaria-prebuilt-reopen.json")
        witness = load("hq-v32-prebuilt-native/reports/otzaria-prebuilt-container.json")
        manifest = load("hq-v32-prebuilt-native/otzaria-search-manifest.json")
        build = load("hq-stage2/result.json")
        inputs = load("hq-stage2/actual-source-inputs.json")
        native_log = z.read("hq-v32-prebuilt-native/native-prebuilt.log")
        assert run["status"] == "FULL_V32_ORIGINAL_APP_INSTALL_QUERY_RELAUNCH_PASS"
        assert preflight["status"] == "SOURCE_PREFLIGHT_PASS"
        assert prepare["status"] == "DATA_READY"
        assert build["status"] == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
        for item in (run, preflight, prepare, build):
            assert item["checkout_sha"] == CHECKOUT and item["application_source_sha"] == APP
        assert digest(native_log) == run["raw_log_sha256"]
        for name, sha in run["report_sha256"].items():
            assert digest(z.read("hq-v32-prebuilt-native/reports/" + name)) == sha
        assert digest(z.read("hq-v32-prebuilt-native/otzaria-search-manifest.json")) == prepare["manifest_sha256"]
        assert len(z.read("hq-v32-prebuilt-native/otzaria-search-manifest.json")) == 7032

        source_bindings = {}
        for field, path in (
            ("driver_sha256", "Scripts/CI/hq-v32-prebuilt-native.py"),
            ("native_launcher_sha256", "Scripts/run-otzaria-prebuilt-acceptance.sh"),
            ("native_runner_sha256", "Source/Otzaria/Search/Distribution/OtzariaPrebuiltSearchAcceptanceRunner.swift"),
            ("workflow_sha256", ".github/workflows/otzaria-search-artifacts.yml"),
        ):
            actual = digest(git("show", CHECKOUT + ":" + path))
            assert actual == run[field] == preflight[field] == prepare[field], (path, actual)
            source_bindings[path] = actual
        for field, path in (("validator_sha256", "Scripts/CI/hq-stage2-focused-apple.py"),
                            ("inputs_sha256", "Scripts/CI/hq-stage2-focused-apple.inputs.json")):
            assert digest(git("show", CHECKOUT + ":" + path)) == build[field]

        # Recheck the existing pure evidence validator; this does not execute
        # the native route, query engine, downloader, SQL scan or index builder.
        source = git("show", CHECKOUT + ":Scripts/CI/hq-v32-prebuilt-native.py")
        namespace = {"__name__": "read_only_evidence_audit",
                     "__file__": str(REPO / "Scripts/CI/hq-v32-prebuilt-native.py")}
        exec(compile(source, namespace["__file__"], "exec"), namespace)
        validation = namespace["validate_reports"](install, reopen, native_log.decode("utf-8"))
        assert validation == run["verification"]
        oracle = namespace["load_occurrence_oracle"]()
        assert witness == run["app_container_witness"]
        assert witness["simulator_udid"] == run["simulator"]["udid"]
        namespace["validated_container_witness"](witness, run["simulator"]["udid"],
                                                  "com.davidpovarsky.chavrusatext", witness["invocation_nonce"])
        assert run["source_database_unchanged"] is True
        assert run["actual_app_database_sha256"] == prepare["database"]["sha256"] == namespace["DATABASE_SHA"]
        assert prepare["database"]["bytes"] == 3821240320
        assert prepare["database"]["books"] == 7876 and prepare["database"]["lines"] == 7080797
        assert prepare["authenticated_part_metadata"] == len(manifest["lexicalArtifact"]["parts"]) == 14
        assert run["ui_xctest_cases_executed"] == 0 and run["physical_device"] == "NOT_RUN"
        assert run["publication"] is False and run["reindex"] is False
        assert run["owned_simulator_cleanup"]["exit_code"] == 0

        app_tree, current_tree = tree(APP), tree(CURRENT)
        mismatches = [path for path, oid in inputs.items()
                      if path not in app_tree or app_tree[path]["oid"] != oid]
        # The original CocoaPods step declares and retains its generated
        # privacy aggregation separately; do not pretend this is a Git blob.
        assert mismatches == ["Source/PrivacyInfo.xcprivacy"], mismatches[:20]
        generated = build["generated_configuration"]
        assert len(generated) == 1 and generated[0]["path"] == mismatches[0]
        privacy = generated[0]
        original_privacy = z.read("hq-stage2/privacy-original.xcprivacy")
        compiled_privacy = z.read("hq-stage2/privacy-generated.xcprivacy")
        git_blob = lambda data: hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        assert git_blob(original_privacy) == privacy["original_git_blob"] == app_tree[mismatches[0]]["oid"]
        assert git_blob(compiled_privacy) == inputs[mismatches[0]]
        assert digest(original_privacy) == privacy["original_sha256"]
        assert digest(compiled_privacy) == privacy["compiled_sha256"]
        original_plist, compiled_plist = plistlib.loads(original_privacy), plistlib.loads(compiled_privacy)
        api_key = "NSPrivacyAccessedAPITypes"
        assert {k: v for k, v in original_plist.items() if k != api_key} == {k: v for k, v in compiled_plist.items() if k != api_key}
        reasons = lambda data: {(entry["NSPrivacyAccessedAPIType"], reason)
                                for entry in data.get(api_key, []) for reason in entry["NSPrivacyAccessedAPITypeReasons"]}
        before_reasons, after_reasons = reasons(original_plist), reasons(compiled_plist)
        assert before_reasons <= after_reasons
        assert after_reasons - before_reasons == {(entry["category"], entry["reason"]) for entry in privacy["added_reasons"]}
        for addition in privacy["added_reasons"]:
            assert addition["dependency_inputs"]
            for dependency in addition["dependency_inputs"]:
                dependency_raw = z.read("hq-stage2/" + dependency["artifact_path"])
                assert digest(dependency_raw) == dependency["sha256"]
                assert (addition["category"], addition["reason"]) in reasons(plistlib.loads(dependency_raw))
        assert len(inputs) == build["actual_source_inputs_verified"] == 1007
        for path, expected in build["application_trees"].items():
            assert git("rev-parse", APP + ":" + path).decode().strip() == expected
        changed_inputs = [
            {"path": path, "run_source_blob": app_tree[path]["oid"],
             "current_blob": current_tree.get(path, {}).get("oid"),
             "same_blob_current_paths": [p for p, entry in current_tree.items() if entry["oid"] == app_tree[path]["oid"]]}
            for path, oid in inputs.items()
            if current_tree.get(path, {}).get("oid") != app_tree[path]["oid"]
        ]
        closures = {}
        for prefix in ("Source/Otzaria/Search", "Source/Otzaria/Storage", "Source/Otzaria/App",
                       "Source/LibraryBackend", "Vendor/OtzariaSearchEngine"):
            before = git("rev-parse", APP + ":" + prefix).decode().strip()
            after = git("rev-parse", CURRENT + ":" + prefix).decode().strip()
            assert before == after, "Changed v32 dependency: " + prefix
            closures[prefix] = {"tree": before, "unchanged": True,
                                "recorded_inputs": sum(p.startswith(prefix + "/") for p in inputs)}
        assert git("rev-parse", APP + ":Vendor") == git("rev-parse", CURRENT + ":Vendor")

        framework = next(row for row in build["artifact_inputs"] if row["name"] == "ios-build-otzaria-xcframework")
        assert framework["id"] == 14596463166
        assert framework["sha256"] == framework["verified_sha256"] == "efc73de90d74fdd380ffecfa334fe9dcece38519832b89cf3fb2a5741dcc25ad"
        producer = framework["verified_producer"]
        assert producer["producer_job"] == 136041463727 and producer["producer_job_conclusion"] == "success"
        assert producer["producer_run"] == 44661774024 and producer["producer_run_conclusion"] == "failure"
        framework_api = json.loads((BUILD / "framework-artifact-metadata.json").read_bytes())
        producer_job_api = json.loads((BUILD / "framework-producer-job.json").read_bytes())
        assert framework_api["id"] == framework["id"]
        assert framework_api["size_in_bytes"] == 201330360
        assert framework_api["digest"] == "sha256:" + framework["sha256"]
        assert framework_api["workflow_run"]["head_sha"] == framework["producer_sha"]
        assert framework_api["workflow_run"]["id"] == framework["producer_run"]
        assert producer_job_api["id"] == framework["producer_job"]
        assert producer_job_api["run_id"] == framework["producer_run"]
        assert producer_job_api["status"] == "completed" and producer_job_api["conclusion"] == "success"
        sdk_prefix = "Vendor/OtzariaSearchEngine/"
        producer_sdk = {p: v for p, v in tree(framework["producer_sha"]).items() if p.startswith(sdk_prefix)}
        consumer_sdk = {p: v for p, v in app_tree.items() if p.startswith(sdk_prefix)}
        assert len(producer_sdk) == 43
        assert all(consumer_sdk.get(p) == v for p, v in producer_sdk.items())
        sdk_added = sorted(set(consumer_sdk) - set(producer_sdk))
        assert len(sdk_added) == 78 and all(p.startswith(sdk_prefix + "Tests/") for p in sdk_added)
        assert all(consumer_sdk[p]["mode"] == "100644" and consumer_sdk[p]["kind"] == "blob" for p in sdk_added)
        assert install["consumerBuild"] == reopen["consumerBuild"]
        assert install["consumerBuild"]["upstreamCommit"] == "d5d59d1269bdf87fb0a6901cf31941726a0c699b"
        assert install["artifactProducer"] == reopen["artifactProducer"] == manifest["lexicalEngine"]

        report = {
            "status": "ARTIFACT_AND_SCOPED_INPUT_CLOSURE_VERIFIED",
            "audited_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "run_url": api_run["html_url"], "run_id": 44941360413, "attempt": 1,
            "artifact_id": 14722834927, "zip_bytes": len(raw), "zip_sha256": ZIP_SHA,
            "zip_crc_verified": True, "zip_members": len(members),
            "checkout_sha": CHECKOUT, "application_source_sha": APP, "current_source_sha": CURRENT,
            "source_bindings_sha256": source_bindings,
            "source_inputs": {"recorded": len(inputs), "direct_git_blob_matches": len(inputs) - len(mismatches),
                              "declared_generated_configuration_verified": len(mismatches),
                              "source_baselines_unchanged_at_current_path": len(inputs) - len(changed_inputs),
                              "changed_inputs": changed_inputs, "v32_closure": closures,
                              "all_vendor_tree_unchanged": True},
            "generated_privacy": {"original_blob": privacy["original_git_blob"],
                                  "compiled_sha256": privacy["compiled_sha256"],
                                  "preserved_original_declarations": True,
                                  "dependency_backed_added_reasons": len(privacy["added_reasons"])},
            "application_diff": git("diff", "--name-status", "--find-renames=100%", APP, CURRENT,
                                    "--", "Source", "Vendor", "Maktabah.xcodeproj").decode().splitlines(),
            "manifest_summary": {k: v for k, v in manifest.items() if not isinstance(v, (dict, list))},
            "manifest_structure": {k: {a: b for a, b in v.items() if not isinstance(b, (dict, list))}
                                   for k, v in manifest.items() if isinstance(v, dict)},
            "database": prepare["database"], "database_source_after_and_app_copy_hash_equal": True,
            "schema_credit": {"canonical_asset": "seforim-schema6.db.zst", "native_index_schema": 4,
                              "source_book_and_line_tables_counted_in_read_only_sqlite": True,
                              "sqlite_user_version_numeric_assertion": "NOT_RECORDED"},
            "database_local_rehash": "NOT_PERFORMED_DB_NOT_IN_ARTIFACT; verified executed CI gate and hash-bound reports",
            "native": {"simulator": run["simulator"], "pids": validation["app_pids"],
                       "resume_bytes": install["resumedDownloadBytes"], "reopen_download": reopen["nativeDownloadRan"],
                       "reopen_resume_bytes": reopen["resumedDownloadBytes"],
                       "checks": install["checks"], "same_checks_and_golden_after_restart": True,
                       "golden_query": install["golden"]["query"],
                       "golden_ordered_result_ids": install["golden"]["orderedResultIDs"],
                       "golden_highlighted_top_results": install["golden"]["highlightedTopResults"],
                       "sources": install["sourceCount"], "documents": install["documentCount"],
                       "production_discovery_and_validator": True, "staging_absent_both_phases": True},
            "exact_occurrences": [{"query": c["query"], "documents": c["result"]["matchingLiveDocuments"],
                                   "occurrences": c["result"]["occurrences"],
                                   "engine_revision": c["result"]["proof"]["engineCommit"]}
                                  for c in install["exactOccurrences"]],
            "independent_sql": {"raw_sha256": namespace["SQL_ORACLE_SHA256_RAW"],
                                "rows": oracle["sql"]["rowsScanned"], "books": oracle["sql"]["originalBooks"],
                                "partitions": oracle["sql"]["partitionCount"],
                                "exactly_once": oracle["sql"]["allOriginalRowIDsVerifiedExactlyOnce"],
                                "engine_loaded": oracle["sql"]["engineLoaded"], "index_read": oracle["sql"]["indexRead"],
                                "counts": oracle["sql"]["counts"]},
            "otzaria_framework": {k: framework[k] for k in ("id", "sha256", "producer_sha", "producer_run", "producer_job")},
            "framework_success_scope": producer["scope"],
            "framework_producer_input_closure": {"original_entries_preserved_mode_type_blob": len(producer_sdk),
                                                  "test_only_regular_file_additions": len(sdk_added),
                                                  "current_whole_vendor_unchanged": True,
                                                  "fresh_github_metadata_matches": True,
                                                  "framework_zip_downloaded_by_audit": False},
            "consumer_build": install["consumerBuild"], "producer_index_build": install["artifactProducer"],
            "final_app_macho_sha256": "NOT_RECORDED_IN_THIS_ARTIFACT",
            "allowed_credit": ["exact pinned existing full-v32 native downloader/install and 1MiB resume",
                               "production release discovery/validation with authenticated catalog snapshot",
                               "native d5 Swift/C bridge exact/fuzzy/advanced queries and two SQL-qualified occurrence counts",
                               "actual separate-process reopen, same ordered query identities, no redownload/reindex",
                               "unchanged exact v32 component inputs at current source; not whole-app binary equivalence"],
            "excluded_credit": ["Core request/admission path and real-UI query presentation", "XCTest UI and physical-device acceptance",
                                "crash/interrupted-install recovery beyond observed partial-download resume",
                                "release signing/archive/publication", "broad corpus benchmark or additional query qualification",
                                "runtime acceptance of new Hanlin view/test changes or entire current app binary"],
        }
        if args.output:
            args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(json.dumps({"status": report["status"], "source_inputs": report["source_inputs"],
                          "application_diff": report["application_diff"], "manifest_summary": report["manifest_summary"],
                          "manifest_structure": report["manifest_structure"], "database": report["database"],
                          "pids": report["native"]["pids"], "counts": report["exact_occurrences"],
                          "app_binary_digest": report["final_app_macho_sha256"]}, ensure_ascii=True))


if __name__ == "__main__":
    main()
