#!/usr/bin/env python3
"""Run the existing native prebuilt acceptance on the exact full v32 package.

This is app installer/engine/relaunch evidence. It executes no XCTest UI cases,
does not publish or reindex, and never uses an existing simulator or user data.
"""
import argparse
import datetime
import hashlib
import gzip
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import shutil
import sqlite3
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/hq-v32-prebuilt-native"
REPORTS = OUT / "reports"
TAG = "otzaria-search-data-v32-20261010190601-102293b3a63c"
IDENTITY = "102293b3a63c7f73fa05298457073804e57e020486753f8f6b8f7964ce29f17e"
MANIFEST_SHA = "34319ced48e76f22a5ae2df23745a03332160ddab2dd64244a5c917e0ce00a57"
DATABASE_SHA = "2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765"
ARCHIVE_SHA = "6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44"
DATABASE_BYTES = 3_821_240_320
ARCHIVE_BYTES = 1_850_679_582
APP_SOURCE = "e982ce60a8003752c0b9c6be11ba7293299d5fc8"
GOLDEN_QUERY = "לחתוך צנון בסכין בשרי"

QUALIFICATION_ROOT = ROOT / "docs/hq-integration/index-read-qualification-20261120"
QUALIFICATION_REVIEW_SHA256_LF = "3ccd704a831f4a96ec06a691bdc17e7a8988168659bad766815018c9106983a1"
SQL_ORACLE_SHA256_RAW = "015b4ac382b8c6005d672234cfa7fc1ddaf291f7e5e0d07982f2c89db242f781"
EXACT_OCCURRENCE_LIMITS = {
    "maxCandidateDocuments": 1_000_000, "maxPositions": 10_000_000,
    "maxPositionsPerDocument": 262_144, "maxSegments": 4_096,
}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def command(args, **kwargs):
    return subprocess.check_output(args, cwd=ROOT, text=True, encoding="utf-8", **kwargs).strip()


def api(endpoint):
    return json.loads(command(["gh", "api", endpoint]))


def checked_file(path, size, digest):
    require(path.is_file() and path.stat().st_size == size, "Wrong byte count: " + str(path.name))
    require(sha(path) == digest, "Wrong SHA256: " + str(path.name))


def authenticate_asset(asset, name, size, digest):
    require(asset["name"] == name and asset["size"] == size, "GitHub asset name/size mismatch")
    require(asset.get("digest") == "sha256:" + digest, "GitHub asset digest mismatch")
    require(asset["browser_download_url"].startswith("https://github.com/"), "Unexpected asset URL")


def download(asset, destination, size, digest):
    authenticate_asset(asset, destination.name, size, digest)
    if destination.exists():
        checked_file(destination, size, digest)
        return {"name": destination.name, "bytes": size, "sha256": digest, "reused_verified": True}
    temporary = destination.with_name(destination.name + ".part")
    subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--continue-at", "-",
                    "--output", str(temporary), asset["browser_download_url"]],
                   cwd=ROOT, check=True, timeout=2400)
    checked_file(temporary, size, digest)
    temporary.replace(destination)
    return {"name": destination.name, "bytes": size, "sha256": digest, "reused_verified": False}


def preflight(expected):
    require(re.fullmatch(r"[a-f0-9]{40}", expected), "An immutable checkout SHA is required")
    require(command(["git", "rev-parse", "HEAD"]) == expected, "Wrong checkout")
    config = json.loads((ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json").read_text())
    require(config["application_source_sha"] == APP_SOURCE, "Unreviewed app source")
    load_occurrence_oracle()
    original = json.loads(command([sys.executable, "Scripts/CI/hq-stage2-focused-apple.py", "--preflight-only"]))
    return {"checkout_sha": expected, "application_source_sha": APP_SOURCE,
            "original_build_preflight": original,
            "driver_sha256": sha(__file__),
            "native_launcher_sha256": sha(ROOT / "Scripts/run-otzaria-prebuilt-acceptance.sh"),
            "native_runner_sha256": sha(ROOT / "Source/Otzaria/Search/Distribution/OtzariaPrebuiltSearchAcceptanceRunner.swift"),
            "workflow_sha256": sha(ROOT / ".github/workflows/otzaria-search-artifacts.yml"),
            "ui_xctest_cases_executed": 0, "physical_device": "NOT_RUN",
            "publication": False, "reindex": False}


def exact_manifest(raw):
    require(len(raw) == 7032 and hashlib.sha256(raw).hexdigest() == MANIFEST_SHA, "Manifest bytes changed")
    value = json.loads(raw)
    require(value["artifactIdentity"] == IDENTITY, "Wrong artifact identity")
    source = value["sourceDatabase"]
    require(source["repository"] == "Otzaria/SeforimLibrary"
            and source["releaseID"] == 409213893 and source["assetID"] == 629048655
            and source["releaseTag"] == "v32-20261010190601"
            and source["databaseSHA256"] == DATABASE_SHA
            and source["databaseBytes"] == DATABASE_BYTES
            and source["sourceAssetDigest"] == "sha256:" + ARCHIVE_SHA
            and source["compressedBytes"] == ARCHIVE_BYTES, "Wrong canonical source")
    lexical = value["lexicalArtifact"]
    require(lexical["sourceCount"] == 7876 and lexical["documentCount"] == 7080797
            and len(lexical["parts"]) == 14
            and lexical["packagedBytes"] == 3809352289
            and lexical["extractedBytes"] == 5219903297, "Wrong full corpus index")
    return value


def prepare(report):
    require(sys.platform == "darwin", "Only the isolated Apple CI runner prepares full payloads")
    OUT.mkdir(parents=True, exist_ok=True)
    require(shutil.disk_usage(OUT).free >= 22 * 1024**3, "Need 22 GiB free after the app build")
    release = api("repos/davidpovarsky/Maktabah/releases/tags/" + TAG)
    require(release["id"] == 419282321 and release["tag_name"] == TAG
            and release.get("immutable") is True and not release["draft"], "Wrong immutable release")
    assets = {entry["name"]: entry for entry in release["assets"]}
    manifest_asset = assets["otzaria-search-manifest.json"]
    require(manifest_asset["id"] == 661747835, "Wrong manifest asset ID")
    package = OUT / "seed-package"
    package.mkdir(exist_ok=True)
    manifest_path = OUT / "otzaria-search-manifest.json"
    report["downloads"] = [download(manifest_asset, manifest_path, 7032, MANIFEST_SHA)]
    manifest = exact_manifest(manifest_path.read_bytes())
    # Authenticate metadata for every original part. Only the original partial-
    # resume seed is downloaded here; the real app downloader fetches all parts.
    for part in manifest["lexicalArtifact"]["parts"]:
        authenticate_asset(assets[part["assetName"]], part["assetName"], part["packagedBytes"], part["sha256"])
    seed = next(part for part in manifest["lexicalArtifact"]["parts"] if part["packagedBytes"] > 1048576)
    report["downloads"].append(download(assets[seed["assetName"]], package / seed["assetName"],
                                        seed["packagedBytes"], seed["sha256"]))
    source_release = api("repos/Otzaria/SeforimLibrary/releases/tags/v32-20261010190601")
    require(source_release["id"] == 409213893 and source_release["tag_name"] == "v32-20261010190601",
            "Wrong official database release")
    source_asset = next(entry for entry in source_release["assets"] if entry["id"] == 629048655)
    archive = OUT / "seforim-schema6.db.zst"
    database = OUT / "seforim.db"
    if not database.exists():
        report["downloads"].append(download(source_asset, archive, ARCHIVE_BYTES, ARCHIVE_SHA))
        subprocess.run(["zstd", "-d", "--long=31", "--no-progress", "-f", str(archive),
                        "-o", str(database)], cwd=ROOT, check=True, timeout=1800)
    checked_file(database, DATABASE_BYTES, DATABASE_SHA)
    # Release only this reproducible CI-owned compressed copy after the complete
    # canonical database is verified. Original data on connected hosts is unused.
    if archive.exists():
        checked_file(archive, ARCHIVE_BYTES, ARCHIVE_SHA)
        archive.unlink()
    with sqlite3.connect(database.resolve().as_uri() + "?mode=ro&immutable=1", uri=True) as db:
        books = db.execute("SELECT COUNT(*) FROM book").fetchone()[0]
        lines = db.execute("SELECT COUNT(*) FROM line").fetchone()[0]
    require((books, lines) == (7876, 7080797), "Canonical SQL corpus counts changed")
    releases = api("repos/davidpovarsky/Maktabah/releases?per_page=100")
    require(any(item["id"] == release["id"] for item in releases), "Pinned release missing from live discovery")
    save(OUT / "otzaria-search-releases.json", releases)
    save(OUT / "pinned-index-release.json", release)
    save(OUT / "pinned-database-release.json", source_release)
    report.update(status="DATA_READY", artifact_identity=IDENTITY, manifest_sha256=MANIFEST_SHA,
                  authenticated_part_metadata=14, seed_part=seed["assetName"],
                  database={"bytes": DATABASE_BYTES, "sha256": DATABASE_SHA, "books": books, "lines": lines},
                  native_download_and_install="NOT_RUN")



def load_occurrence_oracle():
    """Authenticate the independent SQL result, not a native scalar being judged."""
    review_raw = (QUALIFICATION_ROOT / "QUALIFICATION_REVIEW.json").read_bytes()
    # Git stores this JSON as LF; Windows checkouts may use CRLF. The raw
    # Windows hash is separately preserved in the immutable evidence archive.
    review_lf = review_raw.replace(b"\r\n", b"\n")
    require(hashlib.sha256(review_lf).hexdigest() == QUALIFICATION_REVIEW_SHA256_LF,
            "Unreviewed original-index qualification record")
    review = json.loads(review_lf)
    sql_raw = gzip.decompress((QUALIFICATION_ROOT /
        "raw/full-sql-global-oracle/attempt4-partitioned/RESULT.json.gz").read_bytes())
    require(hashlib.sha256(sql_raw).hexdigest() == SQL_ORACLE_SHA256_RAW,
            "Independent SQL oracle bytes changed")
    sql = json.loads(sql_raw)
    require(sql["status"] == "COMPLETE_INDEPENDENT_SQL_ORACLE_NOT_ENGINE_QUALIFICATION"
            and sql["rowsScanned"] == 7_080_797 and sql["originalBooks"] == 7_876
            and sql["partitionCount"] == 71 and sql["allOriginalRowIDsVerifiedExactlyOnce"] is True
            and sql["partial"] is False and sql["engineLoaded"] is False and sql["indexRead"] is False
            and sql["databaseSHA256BeforeAndAfter"] == DATABASE_SHA,
            "Independent SQL coverage is incomplete or has another source")
    require(review["producerCommit"] == "265a14ea54f959a3e266d6e8acfa3a3b98101d68"
            and review["consumerCommit"] == "d5d59d1269bdf87fb0a6901cf31941726a0c699b"
            and review["inputs"]["full-v32"]["artifactIdentity"] == IDENTITY,
            "Qualification is for another producer, consumer or corpus")
    require(set(sql["counts"]) == {"בראשית", "אברהם"}, "Unexpected independent query set")
    manifest = exact_manifest((ROOT /
        "docs/hq-integration/full-v32-native-20261119/otzaria-search-manifest.json").read_bytes())
    return {"sql": sql, "review": review, "manifest": manifest}


def validate_exact_occurrences(item, phase, oracle):
    """Require actual d5 bridge evidence in each native process, without a Core/UI claim."""
    def uint(value, positive=False):
        return type(value) is int and (1 if positive else 0) <= value <= (1 << 64) - 1

    sql, review, manifest = oracle["sql"], oracle["review"], oracle["manifest"]
    producer = item.get("artifactProducer")
    require(producer == manifest["lexicalEngine"]
            and all(type(producer.get(k)) is int for k in ("indexSchemaVersion", "defaultGenerationOrder")),
            phase + " did not retain the original artifact producer")
    build = item.get("consumerBuild")
    expected_build = {
        "upstreamRepository": "davidpovarsky/otzaria_search_engine",
        "upstreamBranch": "codex/otzaria-exact-occurrences-20261120",
        "upstreamCommit": review["consumerCommit"], "engineVersion": "0.1.0",
        "indexSchemaVersion": 4, "defaultGenerationOrder": 5, "adapterVersion": "0.1.0",
        "semanticSidecarRevision": manifest["lexicalEngine"]["semanticSidecarRevision"],
        "resourceHashes": {key: value["sha256"] for key, value in manifest["resources"].items()
                           if key.startswith("Vendor/OtzariaSearchEngine/Resources/")},
    }
    require(isinstance(build, dict) and all(build.get(k) == v for k, v in expected_build.items())
            and all(type(build.get(k)) is int for k in ("indexSchemaVersion", "defaultGenerationOrder"))
            and type(build.get("semanticEnabled")) is bool
            and isinstance(build.get("syncedAt"), str) and bool(build["syncedAt"]),
            phase + " native consumer build identity is missing or mismatched")
    checks = item.get("exactOccurrences")
    require(isinstance(checks, list) and len(checks) == len(sql["counts"]),
            phase + " must contain both actual exact occurrence checks")
    require(all(isinstance(check, dict) and set(check) == {"query", "request", "result"}
                for check in checks), phase + " malformed exact occurrence wrapper")
    queries = [check.get("query") for check in checks]
    require(all(isinstance(q, str) for q in queries) and len(set(queries)) == len(queries)
            and set(queries) == set(sql["counts"]), phase + " missing, duplicate or unexpected count query")
    expected_segments = sorted(segment["segment_id"].replace("-", "")
                               for segment in review["inputs"]["full-v32"]["originalSegments"])
    for check in checks:
        query = check["query"]
        request = check["request"]
        expected_request = {"version": 1, "mode": "exact", "query": query, "facets": ["/"],
                            "bookIds": [], "timeoutMs": 60_000, "limits": EXACT_OCCURRENCE_LIMITS}
        require(isinstance(request, dict) and request == expected_request
                and all(uint(request.get(k)) for k in ("version", "timeoutMs"))
                and all(uint(v) for v in request["limits"].values()),
                phase + " count request changed its scope, semantics or hard limits")
        value = check["result"]
        require(isinstance(value, dict)
                and set(value) == {"occurrences", "matchingLiveDocuments", "proof", "work"},
                phase + " missing or partial exact occurrence result")
        expected = sql["counts"][query]
        require(uint(value.get("occurrences")) and uint(value.get("matchingLiveDocuments"))
                and value["occurrences"] == expected["occurrences"]
                and value["matchingLiveDocuments"] == expected["matchingLiveDocuments"],
                phase + " exact occurrences/documents differ from the independent full SQL oracle")
        proof, work = value["proof"], value["work"]
        proof_keys = {"requestToken", "countKind", "exact", "analyzedToken", "requestedFacets",
                      "searcherGeneration", "liveIndexDocuments", "indexSchemaVersion",
                      "enginePackageVersion", "engineCommit", "originalUpstreamBase",
                      "engineRepository", "engineBranch"}
        require(isinstance(proof, dict) and set(proof) == proof_keys
                and uint(proof.get("requestToken"), positive=True)
                and proof["countKind"] == "distinctTokenPositions" and proof["exact"] is True
                and proof["analyzedToken"] == query and proof["requestedFacets"] == ["/"]
                and type(proof["liveIndexDocuments"]) is int and proof["liveIndexDocuments"] == 7_080_797
                and type(proof["indexSchemaVersion"]) is int and proof["indexSchemaVersion"] == 4
                and proof["enginePackageVersion"] == "0.1.0"
                and proof["engineCommit"] == review["consumerCommit"]
                and proof["originalUpstreamBase"] == review["producerCommit"]
                and proof["engineRepository"] == build["upstreamRepository"]
                and proof["engineBranch"] == build["upstreamBranch"],
                phase + " exact occurrence proof has another source, scope, query or count kind")
        generation = proof["searcherGeneration"]
        require(isinstance(generation, dict) and set(generation) == {"generationId", "segments"}
                and uint(generation.get("generationId")) and isinstance(generation.get("segments"), list),
                phase + " missing original engine snapshot")
        segments = generation["segments"]
        require(all(isinstance(seg, dict) and set(seg) in
                    ({"segmentId"}, {"segmentId", "deleteOpstamp"})
                    and isinstance(seg.get("segmentId"), str)
                    and seg.get("deleteOpstamp") is None for seg in segments)
                and sorted(seg["segmentId"] for seg in segments) == expected_segments,
                phase + " original full index segment identity or deletion state changed")
        require(isinstance(work, dict)
                and set(work) == {"visitedCandidateDocuments", "inspectedPositions", "visitedSegments"}
                and all(uint(v) for v in work.values())
                and value["matchingLiveDocuments"] <= work["visitedCandidateDocuments"]
                    <= EXACT_OCCURRENCE_LIMITS["maxCandidateDocuments"]
                and value["occurrences"] <= work["inspectedPositions"]
                    <= EXACT_OCCURRENCE_LIMITS["maxPositions"]
                and work["visitedSegments"] == len(segments)
                    <= EXACT_OCCURRENCE_LIMITS["maxSegments"],
                phase + " exact count has missing or out-of-budget work evidence")
    # Request tokens and generation numbers are local to an engine/process.
    # They are validated in each phase, never forced equal across cold reopen.
    return len(checks)


def validate_reports(install, reopen, log):
    occurrence_oracle = load_occurrence_oracle()
    for phase, item in [("install", install), ("reopen", reopen)]:
        require(item.get("passed") is True and item["phase"] == phase, phase + " did not pass")
        require(item["artifactIdentity"] == IDENTITY and item["documentCount"] == 7080797
                and item["sourceCount"] == 7876, phase + " corpus identity mismatch")
        require(item["stagingAbsent"] is True and item["localIndexingRan"] is False,
                phase + " staging/local-indexing invariant failed")
        require(item["productionDiscoveryRan"] is True and item["productionValidatorRan"] is True
                and item["selectedReleaseTag"] == TAG, phase + " original discovery/validation missing")
        checks = item["checks"]
        require(len(checks) == 3 and {entry["mode"] for entry in checks} == {"exact", "fuzzy", "advanced"}
                and all(entry["count"] > 0 and entry["firstFilePath"].startswith("otzaria-book:")
                        for entry in checks), phase + " original three-mode query evidence missing")
        golden = item["golden"]
        require(golden["query"] == GOLDEN_QUERY and golden["normalizedQuery"]
                and golden["orderedResultIDs"] and golden["highlightedTopResults"] > 0,
                phase + " golden query evidence missing")
        require(len(set(golden["orderedResultIDs"])) == len(golden["orderedResultIDs"]),
                phase + " repeated result identity")
        validate_exact_occurrences(item, phase, occurrence_oracle)
    require(install["nativeDownloadRan"] is True and install["resumedDownloadBytes"] == 1048576,
            "Real native partial-download resume did not occur")
    require(reopen["nativeDownloadRan"] is False and reopen["resumedDownloadBytes"] == 0,
            "Reopen downloaded instead of reusing the installed index")
    require(install["checks"] == reopen["checks"] and install["golden"] == reopen["golden"],
            "Search identities changed across actual process restart")
    pids = dict(re.findall(r"Captured prebuilt (install|reopen) PID: ([0-9]+)", log))
    require(set(pids) == {"install", "reopen"} and pids["install"] != pids["reopen"],
            "Distinct actual app process IDs were not observed")
    return {"app_pids": pids, "original_modes": ["exact", "fuzzy", "advanced"],
            "golden_results": len(install["golden"]["orderedResultIDs"]),
            "golden_result_identities_equal_after_restart": True,
            "native_resumed_bytes": install["resumedDownloadBytes"],
            "exact_occurrence_checks_per_phase": 2,
            "exact_occurrence_engine_revision": occurrence_oracle["review"]["consumerCommit"],
            "independent_sql_oracle_sha256_raw": SQL_ORACLE_SHA256_RAW,
            "qualification_review_sha256_git_lf": QUALIFICATION_REVIEW_SHA256_LF,
            "exact_occurrence_boundary": "ACTUAL_NATIVE_SWIFT_C_BRIDGE_NOT_CORE_OR_UI"}


def validated_container_witness(witness, expected_udid, expected_bundle, expected_nonce):
    """Bind the live launcher's exact path to this invocation and owned device.

    This only resolves the original recorded path. It never supplies a successful
    database hash, creates a simulator, opens the app or accepts another folder.
    The unchanged checked_file call remains the final installed-data gate.
    """
    require(isinstance(witness, dict) and set(witness) == {
        "schema_version", "simulator_udid", "bundle_id", "data_container", "invocation_nonce"
    }, "Missing or unknown container witness fields")
    require(type(witness["schema_version"]) is int and witness["schema_version"] == 1,
            "Unsupported container witness version")
    require(re.fullmatch(r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}", expected_udid),
            "Invalid owned simulator identity")
    require(isinstance(expected_nonce, str) and re.fullmatch(r"[a-f0-9]{64}", expected_nonce),
            "Missing fresh container invocation")
    require(witness["simulator_udid"] == expected_udid and witness["bundle_id"] == expected_bundle
            and witness["invocation_nonce"] == expected_nonce, "Foreign or stale container witness")
    raw = witness["data_container"]
    require(isinstance(raw, str) and 0 < len(raw) <= 4096
            and not any(value in raw for value in ["\0", "\r", "\n", "\\"]),
            "Invalid container path")
    path = PurePosixPath(raw)
    require(path.is_absolute() and str(path) == raw and raw.startswith("/") and not raw.startswith("//")
            and ".." not in path.parts, "Non-canonical container path")
    require(len(path.parts) >= 8 and path.parts[-7:-1] == (
        "Devices", expected_udid, "data", "Containers", "Data", "Application"
    ) and re.fullmatch(r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}", path.name),
            "Container does not belong to the exact owned simulator")
    return raw


def run_native(report):
    require(sys.platform == "darwin", "Actual app installer acceptance requires macOS/Xcode")
    ready = json.loads((OUT / "prepare.json").read_text(encoding="utf-8"))
    require(ready["status"] == "DATA_READY" and ready["checkout_sha"] == report["checkout_sha"],
            "Missing data preparation for this exact checkout")
    build = json.loads((ROOT / "build/hq-stage2/result.json").read_text())
    require(build["status"] == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
            and build["checkout_sha"] == report["checkout_sha"], "Missing matching complete app build")
    database = OUT / "seforim.db"
    checked_file(database, DATABASE_BYTES, DATABASE_SHA)
    exact_manifest((OUT / "otzaria-search-manifest.json").read_bytes())
    toolchain = json.loads((OUT / "toolchain.json").read_text())
    selected = toolchain["selected"]
    runtime = selected["runtime_identifier"]
    require(runtime == os.environ.get("FAITHFUL_RUNTIME27_IDENTIFIER"), "Runtime selection drift")
    runtimes = json.loads(command(["xcrun", "simctl", "list", "runtimes", "available", "-j"]))["runtimes"]
    actual_runtime = next(item for item in runtimes if item["identifier"] == runtime and item["isAvailable"])
    types = [item for item in actual_runtime["supportedDeviceTypes"]
             if "iPad Pro" in item["name"] and "11-inch" in item["name"]]
    require(types, "No original 11-inch iPad type for the matched runtime")
    device_type = sorted(types, key=lambda item: item["name"])[-1]
    app = ROOT / "build/hq-stage2/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app"
    require(app.is_dir(), "Original app product is missing")
    udid = command(["xcrun", "simctl", "create", "Otzaria-v32-" + report["checkout_sha"][:12],
                    device_type["identifier"], runtime])
    require(re.fullmatch(r"[A-Fa-f0-9-]{36}", udid), "Unexpected newly created simulator ID")
    report["simulator"] = {"created_by_this_run": True, "udid": udid, "type": device_type, "runtime": runtime}
    save(OUT / "run.json", report)
    REPORTS.mkdir(parents=True, exist_ok=True)
    container_nonce = secrets.token_hex(32)
    environment = dict(os.environ, OTZARIA_PREBUILT_SIMULATOR_UDID=udid,
                       OTZARIA_PREBUILT_REPORT_DIR=str(REPORTS),
                       OTZARIA_PREBUILT_CONTAINER_NONCE=container_nonce,
                       OTZARIA_PREBUILT_ACCEPTANCE_GOLDEN_QUERY=GOLDEN_QUERY)
    log_path = OUT / "native-prebuilt.log"
    try:
        with log_path.open("w", encoding="utf-8") as output:
            result = subprocess.run(["bash", "Scripts/run-otzaria-prebuilt-acceptance.sh",
                                     str(app), str(database), str(OUT / "otzaria-search-manifest.json"),
                                     str(OUT / "seed-package"), "https://github.com/davidpovarsky/Maktabah/releases/download/" + TAG,
                                     str(OUT / "otzaria-search-releases.json")],
                                    cwd=ROOT, env=environment, stdout=output, stderr=subprocess.STDOUT, timeout=1200)
        report["original_launcher_exit_code"] = result.returncode
        require(result.returncode == 0, "Original native acceptance launcher failed; raw log retained")
        install = json.loads((REPORTS / "otzaria-prebuilt-install.json").read_text())
        reopen = json.loads((REPORTS / "otzaria-prebuilt-reopen.json").read_text())
        report["verification"] = validate_reports(install, reopen, log_path.read_text())
        checked_file(database, DATABASE_BYTES, DATABASE_SHA)
        report["source_database_unchanged"] = True
        bundle = command(["/usr/libexec/PlistBuddy", "-c", "Print :CFBundleIdentifier", str(app / "Info.plist")])
        witness_path = REPORTS / "otzaria-prebuilt-container.json"
        require(witness_path.is_file() and witness_path.stat().st_size <= 8192,
                "Missing or oversized live container witness")
        witness = json.loads(witness_path.read_text(encoding="utf-8"))
        container = Path(validated_container_witness(witness, udid, bundle, container_nonce))
        require(container.is_dir() and not container.is_symlink(), "Original app container is missing")
        report["app_container_witness"] = witness
        installed_database = container / "Documents/otzaria-prebuilt.db"
        checked_file(installed_database, DATABASE_BYTES, DATABASE_SHA)
        report["actual_app_database_sha256"] = DATABASE_SHA
        report["status"] = "FULL_V32_ORIGINAL_APP_INSTALL_QUERY_RELAUNCH_PASS"
        report["scope"] = "Original native downloader, installer, d5 engine, exact/fuzzy/advanced queries, SQL-qualified exact occurrences and process restart; no Core admission, XCTest UI or physical device"
    finally:
        # Only the exact simulator created above is eligible. Preserve failure
        # reports/logs first; canonical release data remains reproducible.
        cleanup = subprocess.run(["xcrun", "simctl", "delete", udid], capture_output=True, text=True)
        report["owned_simulator_cleanup"] = {"exit_code": cleanup.returncode, "stderr": cleanup.stderr}
        if log_path.exists():
            report["raw_log_sha256"] = sha(log_path)
        report["report_sha256"] = {path.name: sha(path) for path in sorted(REPORTS.glob("*.json"))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["preflight", "prepare", "run"])
    parser.add_argument("--expected-sha", required=True)
    args = parser.parse_args()
    report = {"status": "FAILED", "mode": args.mode,
              "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    try:
        report.update(preflight(args.expected_sha))
        if args.mode == "prepare":
            prepare(report)
        elif args.mode == "run":
            run_native(report)
        else:
            report["status"] = "SOURCE_PREFLIGHT_PASS"
        return 0
    except Exception as error:
        report["error"] = str(error)
        return 1
    finally:
        save(OUT / (args.mode + ".json"), report)
        print(json.dumps({key: report.get(key) for key in
                         ["status", "mode", "checkout_sha", "application_source_sha", "error"]}, indent=2))


if __name__ == "__main__":
    raise SystemExit(main())
