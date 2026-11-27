#!/usr/bin/env python3
"""Seal actual ordinary Settings update evidence for the separate R08 UI case.

This helper only observes existing files and writes fresh evidence files. It
does not launch an app, install a corpus, mutate a store or create a trace.
The controller owns execution, source/build admission and simulator allocation.
"""
from __future__ import annotations

import base64
import contextlib
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import runpy
import sqlite3
import stat
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[2]
BUNDLE = "com.davidpovarsky.chavrusatext"
GROUP = "group.com.davidpovarsky.itorah"
REPOSITORY = "Otzaria/SeforimLibrary"
TARGET = "Maktabah-iOSUITests"
SETTINGS_CASE = TARGET + "/ManagedLibraryUpdateAcceptanceTests/testOrdinarySettingsUpdatePreservesProductionLibraryAndUserState"
V40_TAG = "v40-20261123094345"
V40_ID = 455390662
V40_BYTES = 4355063808
V40_SHA = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
V41_ID = 459809828
V41_TAG = "v41-20261126162443"
INDEXES = {
    "otzaria": ("Otzaria/TantivySearchIndex/managed-library", "otzaria_prebuilt_installation.json",
                "f8fea8efcac5fc06b272a061b44f0e0ee66d16ae12f1e864f9510e437e929139"),
    "zayit": ("Otzaria/Zayit", "zayit-installation.json",
              "17cabb80e86ac8c2d1a3ce16a4e1457d4351709798f2b91a84120d4dd0c6c480"),
}
PAGE_CASES = {
    TARGET + "/PublishedProductionSearchDataTests/testPublishedV40OtzariaPagesRetainCumulativeSQLMetadata": "otzaria",
    TARGET + "/PublishedProductionSearchDataTests/testPublishedV40ZayitPages50_100_150RetainSQLIdentity": "zayit",
}
MAX_METADATA = 2_000_000
MAX_EVIDENCE = 8 * 1024 * 1024
MAX_DATABASE = 16 * 1024 ** 3


def require(condition, message):
    if not condition:
        raise ValueError(message)


def require_production_profile(manifest):
    """Match the original optional Codable production profile exactly."""
    require(isinstance(manifest, dict), "Installation manifest must be an object")
    identifier, version = manifest.get("profileID"), manifest.get("profileVersion")
    require(identifier is None or identifier == "production", "Foreign or empty installation profile")
    require(version is None or (type(version) is int and version == 1), "Foreign or malformed production profile version")


def canonical_uuid(value):
    require(isinstance(value, str) and str(uuid.UUID(value)).upper() == value, "Require a canonical owned UUID")
    return value


def canonical_path(value, *, exists=True, directory=False):
    path = Path(value)
    require(path.is_absolute() and path == path.resolve(strict=exists), "Redirected/noncanonical path: " + str(path))
    if exists:
        mode = path.lstat().st_mode
        require(stat.S_ISDIR(mode) if directory else stat.S_ISREG(mode), "Wrong original file type: " + str(path))
    return path


def file_identity(path):
    value = canonical_path(path).lstat()
    fields = {"device": value.st_dev, "inode": value.st_ino, "bytes": value.st_size,
              "mtimeNs": value.st_mtime_ns, "ctimeNs": value.st_ctime_ns}
    require(all(type(v) is int and 0 <= v <= 2 ** 63 - 1 for v in fields.values()), "File identity exceeds Int64")
    return fields


def read_bytes(path, maximum=MAX_EVIDENCE):
    path = canonical_path(path)
    before = file_identity(path)
    require(before["bytes"] <= maximum, "Bound the complete evidence read: " + str(path))
    with path.open("rb") as stream:
        data = stream.read(maximum + 1)
    require(len(data) == before["bytes"] and file_identity(path) == before, "Evidence changed during read: " + str(path))
    return data


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def witness(path, maximum=MAX_EVIDENCE):
    data = read_bytes(path, maximum)
    return {"path": str(Path(path)), "bytes": len(data), "sha256": sha256(data)}


def verify_witness(value, maximum=MAX_EVIDENCE):
    require(isinstance(value, dict) and set(value) == {"path", "bytes", "sha256"}, "Malformed FileWitness")
    require(type(value["bytes"]) is int and 0 <= value["bytes"] <= maximum
            and re.fullmatch(r"[a-f0-9]{64}", value["sha256"] or ""), "Invalid file witness size/digest")
    data = read_bytes(value["path"], maximum)
    require(len(data) == value["bytes"] and sha256(data) == value["sha256"], "Changed immutable receipt: " + value["path"])
    return data


def decode_json(data):
    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, "Duplicate JSON key")
            result[key] = value
        return result
    return json.loads(data, object_pairs_hook=pairs)


def read_json(path, maximum=MAX_EVIDENCE):
    return decode_json(read_bytes(path, maximum))


def raw_manifest(path):
    data = read_bytes(path, MAX_METADATA)
    require(isinstance(decode_json(data), dict), "Manifest must be an object")
    return {"sourcePath": str(Path(path)), "rawBase64": base64.b64encode(data).decode(),
            "bytes": len(data), "sha256": sha256(data)}


def decode_raw(value):
    require(isinstance(value, dict) and set(value) == {"sourcePath", "rawBase64", "bytes", "sha256"}, "Malformed raw manifest")
    require(type(value["bytes"]) is int and 0 < value["bytes"] <= MAX_METADATA, "Unbounded raw manifest")
    data = base64.b64decode(value["rawBase64"], validate=True)
    require(len(data) == value["bytes"] and sha256(data) == value["sha256"], "Raw manifest bytes differ")
    parsed = decode_json(data)
    require(isinstance(parsed, dict), "Manifest must be an object")
    return data, parsed


def write_new(path, value):
    path = canonical_path(path, exists=False)
    canonical_path(path.parent, directory=True)
    encoded = (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode()
    require(len(encoded) <= MAX_METADATA, "The complete sealed envelope must fit the XCTest input bound")
    with path.open("xb") as stream:
        stream.write(encoded)
    return witness(path)


def evidence_output(path, repository_root):
    path = canonical_path(path, exists=False)
    root = canonical_path(repository_root, directory=True)
    require(path.is_relative_to(root / "build/artifacts") and not os.path.lexists(path),
            "Choose a fresh evidence file under this checkout's build/artifacts, outside app data")
    canonical_path(path.parent, directory=True)
    return path


def discover_owner(simulator_udid, container_parent):
    """Find the sole actual MCM app/group owner within the supplied same UDID."""
    canonical_uuid(simulator_udid)
    parent = canonical_path(container_parent, directory=True)
    data = parent.parents[2]
    require(parent.parts[-3:] == ("Containers", "Data", "Application")
            and data.name == "data" and data.parent.name == simulator_udid
            and data.parent.parent.name == "Devices", "Wrong simulator container parent")

    def owners(base, identifier):
        if not base.exists():
            return []
        canonical_path(base, directory=True)
        children = list(base.iterdir())
        require(len(children) <= 256, "Bound original MCM owner discovery")
        found = []
        for child in children:
            if not stat.S_ISDIR(child.lstat().st_mode):
                continue
            try:
                canonical_uuid(child.name)
            except (ValueError, AttributeError):
                continue
            metadata = child / ".com.apple.mobile_container_manager.metadata.plist"
            if not metadata.exists():
                continue
            raw = read_bytes(metadata, 65536)
            record = plistlib.loads(raw)
            if isinstance(record, dict) and record.get("MCMMetadataIdentifier") == identifier:
                found.append((canonical_path(child, directory=True), metadata, raw))
        return found

    apps = owners(parent, BUNDLE)
    require(len(apps) == 1, "Require exactly one original application owner")
    groups = owners(data / "Containers/Shared/AppGroup", GROUP)
    require(len(groups) <= 1, "Ambiguous original App Group ownership")
    app, app_metadata, app_bytes = apps[0]
    group = groups[0] if groups else None
    root = group[0] if group else app / "Library/Application Support/Maktabah-Debug"
    canonical_path(root, directory=True)
    require(root.is_relative_to(data), "Storage owner escaped the owned simulator")
    def metadata(path, raw):
        return {"sourcePath": str(path), "rawBase64": base64.b64encode(raw).decode(), "bytes": len(raw), "sha256": sha256(raw)}
    return {"simulatorUDID": simulator_udid, "bundleID": BUNDLE, "simulatorData": str(data),
            "containerParent": str(parent), "dataContainer": str(app), "storageRoot": str(root),
            "appOwnerMetadata": metadata(app_metadata, app_bytes),
            "storageOwnerMetadata": metadata(group[1], group[2]) if group else metadata(app_metadata, app_bytes)}


def verified_owner(owner):
    validate_owner_record(owner)
    require(discover_owner(owner["simulatorUDID"], owner["containerParent"]) == owner, "Original storage ownership changed")
    return owner


def validate_owner_record(owner):
    """Validate a historical MCM observation without needing its old path live."""
    canonical_uuid(owner["simulatorUDID"])
    require(owner.get("bundleID") == BUNDLE, "Foreign app owner")
    parent, data, app, root = (Path(owner[key]) for key in ("containerParent", "simulatorData", "dataContainer", "storageRoot"))
    require(all(p.is_absolute() and ".." not in p.parts for p in (parent, data, app, root)), "Owner path escape")
    require(parent == data / "Containers/Data/Application" and data.name == "data"
            and data.parent.name == owner["simulatorUDID"] and data.parent.parent.name == "Devices"
            and app.parent == parent, "Wrong historical same-device owner")
    canonical_uuid(app.name)
    fallback = app / "Library/Application Support/Maktabah-Debug"
    if root != fallback:
        require(root.parent == data / "Containers/Shared/AppGroup", "Foreign shared storage owner")
        canonical_uuid(root.name)
    for field, base, identifier in (("appOwnerMetadata", app, BUNDLE),
                                    ("storageOwnerMetadata", app if root == fallback else root, BUNDLE if root == fallback else GROUP)):
        record = owner[field]
        require(record["sourcePath"] == str(base / ".com.apple.mobile_container_manager.metadata.plist")
                and type(record["bytes"]) is int and 0 < record["bytes"] <= 65536, "Unbound MCM metadata path/size")
        raw = base64.b64decode(record["rawBase64"], validate=True)
        require(len(raw) == record["bytes"] and sha256(raw) == record["sha256"], "Changed MCM metadata bytes")
        require(plistlib.loads(raw).get("MCMMetadataIdentifier") == identifier, "Foreign MCM identifier")


def index_inventory(root):
    root = canonical_path(root, directory=True)
    rows, visited = [], 0
    def unreadable(error):
        raise error
    for current, directories, files in os.walk(root, followlinks=False, onerror=unreadable):
        for name in directories + files:
            visited += 1
            require(visited <= 2048, "Unbounded index tree")
            path = Path(current) / name
            mode = path.lstat().st_mode
            require(not stat.S_ISLNK(mode), "Index member is redirected")
            if stat.S_ISDIR(mode):
                canonical_path(path, directory=True)
                continue
            identity = file_identity(path)
            rows.append({"relativePath": path.relative_to(root).as_posix(),
                         **{key: identity[key] for key in ("bytes", "inode", "mtimeNs", "ctimeNs")}})
            require(len(rows) <= 1024, "Unbounded index file inventory")
    require(rows, "An empty package is not retained production data")
    return sorted(rows, key=lambda row: row["relativePath"])


def capture_indexes(storage_root):
    rows = []
    for engine, (relative, name, artifact) in INDEXES.items():
        root = Path(storage_root) / relative
        metadata = raw_manifest(root / name)
        _, parsed = decode_raw(metadata)
        require(parsed.get("artifactIdentity") == artifact, "Wrong retained public package: " + engine)
        source = parsed.get("sourceDatabase" if engine == "otzaria" else "requiredDatabase", {})
        key = "databaseSHA256" if engine == "otzaria" else "canonicalSHA256"
        require(source.get("releaseTag") == V40_TAG and source.get(key) == V40_SHA,
                "A package is not bound to the original full v40 source")
        files = index_inventory(root)
        require(raw_manifest(root / name) == metadata, "Package manifest changed during inventory")
        rows.append({"engine": engine, "storageRoot": str(root), "artifactID": artifact,
                     "manifest": metadata, "files": files})
    return rows


def require_retained_indexes(before, after):
    require(len(before) == len(after) == 2
            and {v["engine"] for v in before} == {v["engine"] for v in after} == set(INDEXES), "Both original packages are required")
    for previous in before:
        current = next(v for v in after if v["engine"] == previous["engine"])
        require(previous["artifactID"] == current["artifactID"] == INDEXES[current["engine"]][2], "Package artifact identity changed")
        require(decode_raw(previous["manifest"])[0] == decode_raw(current["manifest"])[0], "Retained manifest bytes changed")
        require(previous["files"] == current["files"], "Retained package inventory changed")


def capture_before(*, owner, actual_installation_receipt, output, repository_root=ROOT):
    """Reuse root's just-verified full-v40 admission; UI rehashes v40 before edit."""
    output = evidence_output(output, repository_root)
    verified_owner(owner)
    admission_witness = witness(actual_installation_receipt)
    admission = decode_json(verify_witness(admission_witness))
    database = Path(owner["storageRoot"]) / "Otzaria/seforim.db"
    expected = {"path": str(database), "bytes": V40_BYTES, "sha256": V40_SHA}
    require(admission.get("database") == expected and file_identity(database)["bytes"] == V40_BYTES,
            "Require the controller's actual full-v40 database admission")
    require(admission.get("counts") == {"book": 8259, "line": 7925185, "link": 7001824}, "Wrong original corpus counts")
    metadata = raw_manifest(database.parent / "seforim-installation.json")
    _, installed = decode_raw(metadata)
    require_production_profile(installed)
    require(installed.get("releaseID") == V40_ID and installed.get("releaseTag") == V40_TAG
            and installed.get("repository") == REPOSITORY
            and installed.get("databaseFileSize") == V40_BYTES, "Wrong actual managed-v40 manifest")
    require(admission.get("installation_manifest") == {"path": metadata["sourcePath"], "bytes": metadata["bytes"], "sha256": metadata["sha256"]},
            "Root admission and current original manifest differ")
    indexes = capture_indexes(owner["storageRoot"])
    verified_owner(owner)
    require(raw_manifest(metadata["sourcePath"]) == metadata, "Installed identity changed before Settings")
    record = {"schemaVersion": 1, "status": "BEFORE_ORIGINAL_SETTINGS_UI_NOT_RUN", "owner": owner,
              "databaseAdmission": admission_witness,
              "snapshot": {"database": expected, "installationManifest": metadata, "indexes": indexes}}
    return write_new(output, record)


def selected_attachment(captures, case_id, simulator_udid, name):
    canonical_uuid(simulator_udid)
    require(case_id.startswith(TARGET + "/") and case_id.count("/") == 2, "Require full only-testing selector")
    captures = canonical_path(captures, directory=True)
    manifest_path = captures / "manifest.json"
    exported = read_json(manifest_path)
    require(isinstance(exported, list), "Actual xcresult export manifest must be a list")
    pattern = re.compile(re.escape(name) + r"_[0-9]+_([0-9a-fA-F-]{36})\.json")
    matches = []
    for test in exported:
        identifier = test.get("testIdentifier", "").removesuffix("()")
        if identifier not in (case_id, case_id.removeprefix(TARGET + "/")):
            continue
        for attachment in test.get("attachments", []):
            match = pattern.fullmatch(attachment.get("suggestedHumanReadableName", ""))
            if not match:
                continue
            canonical_uuid(match.group(1).upper())
            require(attachment.get("deviceId", "").upper() == simulator_udid, "Wrong attachment device")
            filename = attachment.get("exportedFileName", "")
            require(re.fullmatch(r"[0-9a-fA-F-]{36}\.json", filename), "Escaped or invalid exported attachment filename")
            canonical_uuid(filename.removesuffix(".json").upper())
            path = captures / filename
            matches.append((witness(path), read_json(path), attachment))
    require(len(matches) == 1, "Exactly one actual named case attachment is required: " + name)
    return {"file": matches[0][0], "contents": matches[0][1], "exportRecord": matches[0][2],
            "exportManifest": witness(manifest_path)}


def verified_execution(case_directory, case_id, simulator_udid, *, repository_root=ROOT):
    """Re-run only the existing file-based xcresult verifier, never xcodebuild."""
    directory = canonical_path(case_directory, directory=True)
    result_path, zero_path = directory / "RESULT.json", directory / "zero-skip.json"
    result, zero = read_json(result_path), read_json(zero_path)
    short = case_id.removeprefix(TARGET + "/")
    require(case_id.startswith(TARGET + "/") and case_id.count("/") == 2 and result.get("case") == short,
            "Case result belongs to a different original selector")
    require(result.get("passed") is True and result.get("xcodebuild_exit") == 0
            and result.get("zero_skip_exit") == 0 and result.get("attachment_export_exit") == 0
            and result.get("declaration_status") == "EXECUTED_PASS", "Actual original case did not fully pass")
    command = result.get("command", [])
    bundle = canonical_path(directory / "original.xcresult", directory=True)
    require(command[:2] == ["xcodebuild", "test-without-building"], "Expected actual test-without-building execution")
    require([v for v in command if v.startswith("-only-testing:")] == ["-only-testing:" + case_id], "Wrong selected native scope")
    for key, expected in (("-destination", "platform=iOS Simulator,id=" + simulator_udid), ("-resultBundlePath", str(bundle))):
        require(command.count(key) == 1 and command.index(key) + 1 < len(command)
                and command[command.index(key) + 1] == expected, "Case command identity differs: " + key)
    summary = read_json(zero_path.with_suffix(".summary.json"))
    tree = read_json(zero_path.with_suffix(".tests.json"))
    for key, value in (("summary", summary), ("tests", tree)):
        require(zero.get(key + "_sha256") == sha256(json.dumps(value, sort_keys=True).encode()), "Unbound xcresult " + key)
    verifier_path = canonical_path(Path(repository_root) / "tools/verify_xcresult_zero_skips.py")
    verifier = runpy.run_path(str(verifier_path))
    actual = verifier["verify"](summary, tree, read_bytes(directory / "original-ui.log", 64 * 1024 * 1024).decode(),
                                [short], 1, expected_device=simulator_udid, expected_os_major=27)
    require(all(zero.get(key) == value for key, value in actual.items()), "Stored zero-skip result differs from actual retained xcresult exports")
    require(actual["executed_total"] == actual["required_ui_passed"] == 1
            and actual["skipped"] == actual["failed"] == 0 and set(actual["cases"]) == {short}, "Incomplete/expanded native execution scope")
    return {"caseID": case_id, "caseStatus": "Passed", "executedTests": 1, "skippedTests": 0,
            "caseResult": witness(result_path), "zeroSkipResult": witness(zero_path), "xcresultPath": str(bundle),
            "summary": witness(zero_path.with_suffix(".summary.json")), "testTree": witness(zero_path.with_suffix(".tests.json")),
            "log": witness(directory / "original-ui.log", 64 * 1024 * 1024), "verifierSource": witness(verifier_path)}


def official_target(metadata_paths, expected_id, expected_tag):
    require(set(metadata_paths) == {"release", "fullManifest", "statistics"}, "Require all three original official metadata files")
    records = {key: witness(value, MAX_METADATA) for key, value in metadata_paths.items()}
    release = decode_json(verify_witness(records["release"], MAX_METADATA))
    require(expected_id == V41_ID and expected_tag == V41_TAG, "This v1 gate explicitly observes v40 to the published v41")
    require(release.get("id") == expected_id and release.get("tag_name") == expected_tag
            and release.get("draft") is False and release.get("prerelease") is False
            and release.get("url") == "https://api.github.com/repos/" + REPOSITORY + "/releases/" + str(expected_id),
            "Wrong official target release metadata")
    assets, parsed = {}, {}
    for key, filename in (("fullManifest", "seforim-schema7.db.zst.manifest.json"), ("statistics", "library_stats.json")):
        found = [v for v in release.get("assets", []) if v.get("name") == filename]
        require(len(found) == 1, "Ambiguous official metadata asset")
        asset = found[0]
        require(type(asset.get("id")) is int and asset["id"] > 0 and asset.get("size") == records[key]["bytes"]
                and asset.get("digest") == "sha256:" + records[key]["sha256"]
                and asset.get("browser_download_url") == "https://github.com/" + REPOSITORY + "/releases/download/" + expected_tag + "/" + filename,
                "Official metadata asset identity/digest differs: " + key)
        assets[key] = {"id": asset["id"], "name": filename, "bytes": asset["size"], "digest": asset["digest"]}
        parsed[key] = decode_json(verify_witness(records[key], MAX_METADATA))
    statistics = parsed["statistics"]
    require(statistics.get("db_version") == 41 and all(type(statistics.get(k)) is int and statistics[k] > 0 for k in ("books", "lines", "links")),
            "Missing official full-v41 corpus counts")
    return {"releaseID": expected_id, "releaseTag": expected_tag, "repository": REPOSITORY,
            "fullManifestAsset": assets["fullManifest"], "statisticsAsset": assets["statistics"],
            "statistics": statistics, "metadataReceipts": records}, parsed["fullManifest"]


def require_installed_identity(installed, official, archive):
    require_production_profile(installed)
    metadata = official["fullManifestAsset"]
    require(installed.get("repository") == REPOSITORY and installed.get("releaseID") == official["releaseID"]
            and installed.get("releaseTag") == official["releaseTag"] and installed.get("assetID") == metadata["id"]
            and installed.get("assetName") == metadata["name"] and installed.get("compressedSize") == metadata["bytes"]
            and installed.get("digest") == metadata["digest"], "Final installed release/manifest asset identity differs")
    multipart = installed.get("multipart")
    require(isinstance(multipart, dict) and multipart.get("archiveName") == archive.get("archive")
            and multipart.get("compressedSize") == archive.get("size")
            and multipart.get("digest") == "sha256:" + archive.get("sha256", ""), "Final full archive identity differs")
    published = decode_json(verify_witness(official["metadataReceipts"]["release"], MAX_METADATA))["assets"]
    def asset(actual, name, size, digest):
        found = [value for value in published if value.get("name") == name]
        require(len(found) == 1 and isinstance(actual, dict), "Missing exact original multipart asset")
        selected = found[0]
        require(type(selected.get("id")) is int and selected["id"] > 0 and actual.get("id") == selected["id"]
                and actual.get("name") == name and actual.get("compressedSize") == size == selected.get("size")
                and actual.get("digest") == digest == selected.get("digest")
                and actual.get("downloadURL") == selected.get("browser_download_url")
                == "https://github.com/" + REPOSITORY + "/releases/download/" + official["releaseTag"] + "/" + name,
                "Final original multipart member identity differs")
    asset(multipart.get("manifest"), metadata["name"], metadata["bytes"], metadata["digest"])
    parts = multipart.get("parts")
    require(isinstance(parts, list) and len(parts) == len(archive.get("parts", [])) == 2, "Missing original full-v41 parts")
    for actual, part in zip(parts, archive["parts"]):
        asset(actual, part["name"], part["size"], "sha256:" + part["sha256"])
    require(sum(part["size"] for part in archive["parts"]) == archive["size"], "Official multipart lengths differ")


def final_database(database, expected_sha256, official_statistics):
    database = canonical_path(database)
    before = file_identity(database)
    require(0 < before["bytes"] <= MAX_DATABASE and re.fullmatch(r"[a-f0-9]{64}", expected_sha256 or ""), "Unbounded or unidentified updated corpus")
    digest = hashlib.sha256()
    total = 0
    with database.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            total += len(block)
            require(total <= before["bytes"], "Updated corpus grew during hash")
            digest.update(block)
    require(total == before["bytes"] and digest.hexdigest() == expected_sha256, "Final DB differs from the actual installed UI attachment")
    with contextlib.closing(sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)) as sql:
        sql.execute("PRAGMA query_only=ON")
        counts = {table: sql.execute("SELECT COUNT(*) FROM " + table).fetchone()[0] for table in ("book", "line", "link")}
        quick_check = sql.execute("PRAGMA quick_check").fetchall()
    require(quick_check == [("ok",)], "Final original DB failed SQLite integrity")
    require(counts == {"book": official_statistics["books"], "line": official_statistics["lines"], "link": official_statistics["links"]},
            "Actual complete updated corpus counts differ from verified official statistics")
    require(file_identity(database) == before, "Updated corpus changed during final verification")
    return {"path": str(database), "bytes": total, "sha256": digest.hexdigest()}, {"counts": counts, "quickCheck": "ok", "fileIdentity": before}


def cleanup_observation(database, downloads):
    database = canonical_path(database)
    downloads = canonical_path(downloads, exists=False)
    expected = database.parent / "Downloads/Maktabah/Otzaria/Downloads"
    require(downloads == expected, "Downloads path does not belong to the original managed profile")
    transaction = ["seforim.db.previous", "seforim-installation.json.previous", "seforim-installation.json.installing"]
    payload = ["seforim.db.zst.part", "seforim.db.zst.part.json", "seforim.db.zst.parts", "seforim.db.zst.assembling"]
    # lexists rejects even dangling links; evidence cleanup never deletes them.
    require(not any(os.path.lexists(database.parent / name) for name in transaction), "Completed update left a transaction artifact")
    require(not any(os.path.lexists(downloads / name) for name in payload), "Completed update left a download artifact")
    staging = list(database.parent.glob("seforim.db.installing*"))
    require(not staging, "Completed update left a staging database")
    return {"transactionAbsent": True, "downloadsAbsent": True, "stagingMatches": [],
            "databaseRoot": str(database.parent), "downloadsRoot": str(downloads),
            "transactionNames": transaction, "downloadNames": payload}


def verified_trace_baseline(value, owner, source_manifest_sha256, *, repository_root=ROOT):
    require(value.get("caseID") in PAGE_CASES and value.get("caseStatus") == "Passed", "Only an actual passed original v40 pages case is eligible")
    namespace = canonical_uuid(value.get("namespace"))
    relative = "Documents/OtzariaLogs/search-native-" + namespace + ".jsonl"
    require(value.get("relativePath") == relative and value.get("sourceDatabaseManifestSHA256") == source_manifest_sha256,
            "Trace source manifest or namespace differs")
    require(type(value.get("processID")) is int and value["processID"] > 0, "Missing actual trace process")
    execution = verified_execution(Path(value["caseResult"]["path"]).parent, value["caseID"], owner["simulatorUDID"], repository_root=repository_root)
    require(value["caseResult"] == execution["caseResult"] and value["xcresultPath"] == execution["xcresultPath"], "Trace result belongs to another execution")
    engine = PAGE_CASES[value["caseID"]]
    attachment = selected_attachment(Path(value["caseResult"]["path"]).parent / "captures", value["caseID"], owner["simulatorUDID"],
                                     "published-v40-" + engine + "-original-pages-and-independent-sql")
    require(attachment["file"] == value["sourceAttachment"], "Trace is not bound to the actual selected-case SQL attachment")
    path = Path(owner["dataContainer"]) / relative
    raw = read_bytes(path)
    identity = file_identity(path)
    require(all(type(value.get(k)) is int and value[k] == identity[k] for k in ("bytes", "inode", "mtimeNs", "ctimeNs"))
            and value.get("sha256") == sha256(raw), "Existing positive trace identity/bytes differ")
    require(raw.endswith(b"\n"), "Original trace is truncated")
    events = [decode_json(line) for line in raw.splitlines()]
    require(0 < len(events) <= 4096 and any(v.get("event") == "provider" for v in events)
            and any(v.get("event") == "published" for v in events), "Absent or unexercised trace cannot prove a negative")
    require(all(v.get("namespace") == namespace and v.get("schemaVersion") == 1 and v.get("profileID") == "production"
                and v.get("engine") == engine and v.get("processID") == value["processID"] for v in events), "Trace carries a different source/process identity")
    proof = attachment["contents"]
    require(proof.get("events") == events and isinstance(proof.get("independentSQL"), dict) and proof["independentSQL"],
            "Actual original pages/SQL attachment does not match the existing trace prefix")
    return value


def verify_context_binding(binding, before_owner, after_owner):
    """Validate root's immutable input and separately observed effective context.

    Root may produce effective files after real container relocation; this helper
    never rewrites either file. Original MCM owner receipts must be supplied for
    each relocation; arbitrary same-device path substitution is not admission.
    """
    original = decode_json(verify_witness(binding["input"], 65536))
    effective = decode_json(verify_witness(binding["effective"], 65536))
    require(original.get("simulatorUDID") == effective.get("simulatorUDID") == before_owner["simulatorUDID"] == after_owner["simulatorUDID"],
            "Context belongs to another owned simulator")
    path_keys = {"databasePath", "downloadsPath", "annotationsPath", "qualifiedLocatorsPath", "workspacePath"}
    require(set(original) == set(effective) and all(original[k] == effective[k] for k in original.keys() - path_keys),
            "Context relocation changed non-path source/target inputs")
    require(effective.get("expectedCurrentTag") == V40_TAG and effective.get("expectedCurrentSHA256") == V40_SHA
            and effective.get("expectedTargetID") == V41_ID and effective.get("expectedTargetTag") == V41_TAG, "Wrong context release selection")
    # The effective context is the exact one consumed by Settings. It may refer
    # to the pre-XCTest owner; every later move needs its own observed owner pair.
    relocations = binding.get("relocations")
    require(isinstance(relocations, list) and len(relocations) <= 8, "Unbounded context relocation chain")
    owners = [relocations[0]["before"] if relocations else before_owner]
    validate_owner_record(owners[0])
    for relocation in relocations:
        require(set(relocation) == {"before", "after"} and relocation["before"] == owners[-1], "Broken observed owner chain")
        nxt = relocation["after"]
        require(nxt.get("simulatorUDID") == before_owner["simulatorUDID"] and nxt.get("bundleID") == BUNDLE
                and nxt.get("containerParent") == before_owner["containerParent"], "Relocation escaped the original owner/device")
        validate_owner_record(nxt)
        owners.append(nxt)
    require(before_owner in owners and owners[-1] == after_owner, "Unrecorded initial/final container relocation")
    annotation_slots = []
    for candidate in (original, effective):
        matching = []
        for owner in owners:
            app, storage = Path(owner["dataContainer"]), Path(owner["storageRoot"])
            expected = {"databasePath": str(storage / "Otzaria/seforim.db"),
                        "downloadsPath": str(storage / "Otzaria/Downloads/Maktabah/Otzaria/Downloads"),
                        "qualifiedLocatorsPath": str(app / "Library/Application Support/Maktabah/qualified-locators-v1.json"),
                        "workspacePath": str(app / "Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json")}
            annotation = Path(candidate["annotationsPath"])
            if all(candidate.get(k) == v for k, v in expected.items()) and annotation.name == "Annotations.sqlite" \
                    and (annotation.is_relative_to(app) or annotation.is_relative_to(storage)):
                matching.append(owner)
                annotation_slots.append(("storage", annotation.relative_to(storage).as_posix()) if annotation.is_relative_to(storage)
                                        else ("app", annotation.relative_to(app).as_posix()))
        require(matching, "Context paths are not bound to an observed original MCM owner")
        require(all(Path(candidate[k]).is_absolute() and ".." not in Path(candidate[k]).parts for k in path_keys), "Context path escape")
    require(len(set(annotation_slots)) == 1, "Context relocation changed the logical annotation store")
    return effective


def current_source_identity(repository_root, checkout_sha):
    repository_root = canonical_path(repository_root, directory=True)
    def git(*args):
        return subprocess.check_output(["git", "-c", "gc.auto=0", "-C", str(repository_root), *args], timeout=30)
    require(git("rev-parse", "HEAD").decode().strip() == checkout_sha, "Current checkout changed")
    paths = ["Scripts/CI/study-ui-settings-receipts.py", "Scripts/CI/prepare-managed-library-update-context.py",
             "Maktabah-iOSUITests/ProductionOtzariaAcceptanceTests.swift", "Maktabah-iOSUITests/GlobalSearchNativeAcceptanceTests.swift",
             "tools/verify_xcresult_zero_skips.py"]
    records = {}
    for path in paths:
        original = git("show", "HEAD:" + path)
        require(read_bytes(repository_root / path) == original, "Dirty receipt/registered UI source: " + path)
        records[path] = witness(repository_root / path)
    return {"checkoutSHA": checkout_sha, "files": records}


def seal_success(*, before_receipt, before_sha256, owner_after, context_binding,
                 case_directory, original_installation_result, checkout_sha,
                 official_metadata_paths, trace_baseline, output, repository_root=ROOT):
    """Write schema v1 only after actual native + source + retained-file checks.

    `before_receipt` is capture_before's immutable output; `context_binding`
    contains FileWitness input/effective and the root's observed owner chain.
    `trace_baseline` is the existing prior pages-case witness, never a new trace.
    """
    require(re.fullmatch(r"[a-f0-9]{40}", checkout_sha or ""), "Require exact current checkout SHA")
    output = evidence_output(output, repository_root)
    source_identity = current_source_identity(repository_root, checkout_sha)
    before_file = witness(before_receipt)
    require(before_file["sha256"] == before_sha256, "Pre-update receipt changed")
    before_record = decode_json(verify_witness(before_file))
    require(before_record.get("schemaVersion") == 1 and before_record.get("status") == "BEFORE_ORIGINAL_SETTINGS_UI_NOT_RUN", "Wrong pre-update receipt")
    before, owner_before = before_record["snapshot"], before_record["owner"]
    admission = decode_json(verify_witness(before_record["databaseAdmission"]))
    verified_owner(owner_after)
    effective = verify_context_binding(context_binding, owner_before, owner_after)
    execution = verified_execution(case_directory, SETTINGS_CASE, owner_after["simulatorUDID"], repository_root=repository_root)
    captures = Path(case_directory) / "captures"
    installed = selected_attachment(captures, SETTINGS_CASE, owner_after["simulatorUDID"], "settings-update-installed")
    target_attachment = selected_attachment(captures, SETTINGS_CASE, owner_after["simulatorUDID"], "settings-update-official-target")
    official, archive = official_target(official_metadata_paths, effective["expectedTargetID"], effective["expectedTargetTag"])
    require(target_attachment["contents"] == {"release_id": official["releaseID"], "tag": official["releaseTag"],
                                               "archive": archive, "statistics": official["statistics"]}, "Actual UI target differs from independently verified official assets")
    before_raw, before_manifest = decode_raw(before["installationManifest"])
    require(before["database"]["bytes"] == V40_BYTES and before["database"]["sha256"] == V40_SHA
            and before_manifest.get("releaseID") == V40_ID and before_manifest.get("releaseTag") == V40_TAG,
            "The actual Settings source is not the retained production v40")
    proof = installed["contents"]
    require(proof.get("old_database_sha256") == V40_SHA and proof.get("new_database_sha256") != V40_SHA
            and type(proof.get("paused_download_bytes")) is int and proof["paused_download_bytes"] >= 1048576
            and proof.get("scope") == "ordinary-Settings-UI-current-to-latest"
            and proof.get("metadata_promotion_failure") and proof.get("retry_and_recovery"), "Incomplete original update/pause/rollback/retry attachment")
    database = Path(owner_after["storageRoot"]) / "Otzaria/seforim.db"
    metadata = raw_manifest(database.parent / "seforim-installation.json")
    _, final_manifest = decode_raw(metadata)
    require(final_manifest == proof.get("installed_manifest"), "Final manifest differs from the actual UI attachment")
    require_installed_identity(final_manifest, official, archive)
    final, integrity = final_database(database, proof.get("new_database_sha256"), official["statistics"])
    require(final_manifest.get("databaseFileSize") == final["bytes"], "Final manifest database size differs")
    indexes = capture_indexes(owner_after["storageRoot"])
    require_retained_indexes(before["indexes"], indexes)
    cleanup = cleanup_observation(database, database.parent / "Downloads/Maktabah/Otzaria/Downloads")
    trace = verified_trace_baseline(trace_baseline, owner_after, before["installationManifest"]["sha256"], repository_root=repository_root)
    original = witness(original_installation_result)
    original_value = decode_json(verify_witness(original))
    require(original_value.get("status") == "ORIGINAL_INTEGRATED_V40_NATIVE_PASS"
            and original_value.get("created_owned_simulator") == owner_after["simulatorUDID"]
            and original_value.get("owned_simulator_cleanup") == "SHUTDOWN_RETAINED_FOR_ADDITIONAL_ACCEPTANCE"
            and original_value.get("native_exit") == original_value.get("evidence_admission_exit") == 0
            and admission.get("original_installation", {}).get("result") == original,
            "Original successful v40 installation/UDID differs from the controller's admitted owner")
    current_build = decode_json(verify_witness(admission["current_build_receipt"]))
    require(current_build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS" and current_build.get("checkout_sha") == checkout_sha,
            "Actual admitted app/UI build belongs to a different checkout")
    for record in admission["original_receipts"].values():
        verify_witness(record)
    states = {kind: selected_attachment(captures, SETTINGS_CASE, owner_after["simulatorUDID"], "settings-update-user-state-" + kind)
              for kind in ("before", "after")}
    require(states["before"]["contents"] and states["before"]["contents"] == states["after"]["contents"], "Actual UI logical user-state attachments differ")
    execution.update(installedAttachment=installed["file"], officialTargetAttachment=target_attachment["file"],
                     exportManifest=installed["exportManifest"])
    envelope = {"schemaVersion": 1, "status": "ORIGINAL_SETTINGS_UPDATE_VERIFIED",
                "simulatorUDID": owner_after["simulatorUDID"], "bundleID": BUNDLE, "checkoutSHA": checkout_sha,
                "dataContainerBefore": owner_before["dataContainer"], "dataContainerAfter": owner_after["dataContainer"],
                "originalInstallationResult": original, "settingsExecution": execution, "context": context_binding,
                "before": before, "after": {"database": final, "installationManifest": metadata, "indexes": indexes},
                "officialTarget": official, "cleanup": cleanup, "traceBaseline": trace,
                "beforeReceipt": before_file, "databaseAdmission": before_record["databaseAdmission"],
                "ownershipBefore": owner_before, "ownershipAfter": owner_after, "finalIntegrity": integrity,
                "helperSource": witness(Path(__file__).resolve()), "sourceIdentity": source_identity,
                "currentBuildReceipt": admission["current_build_receipt"],
                "userStateAttachments": {key: value["file"] for key, value in states.items()}}
    # Inputs and live identities must still match immediately before publication.
    verify_witness(before_file); verify_witness(original)
    verify_witness(context_binding["input"]); verify_witness(context_binding["effective"])
    verified_owner(owner_after)
    require(raw_manifest(metadata["sourcePath"]) == metadata and file_identity(database) == integrity["fileIdentity"], "Installation changed before sealing")
    require(capture_indexes(owner_after["storageRoot"]) == indexes, "Packages changed before sealing")
    cleanup_observation(database, database.parent / "Downloads/Maktabah/Otzaria/Downloads")
    require(current_source_identity(repository_root, checkout_sha) == source_identity, "Source changed before sealing")
    return write_new(output, envelope)
