#!/usr/bin/env python3
"""Admit original bootstrap reports against genuine release and archive identities.

This CI observer never installs a database or substitutes native acceptance.
A multipart remote asset is the small manifest; archive bytes/hash are separate.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import urllib.parse
import urllib.request

MAX_MANIFEST_BYTES = 1_048_576
INT64_MAX = 9_223_372_036_854_775_807
ARCHIVE_NAME = re.compile(r"seforim(?:-schema[1-9][0-9]*)?\.db\.zst")
SHA256 = re.compile(r"[0-9a-f]{64}")


def require(value, message):
    if not value:
        raise ValueError(message)


def positive(value):
    return type(value) is int and 0 < value <= INT64_MAX


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON object key")
        result[key] = value
    return result


def decode(raw):
    return json.loads(raw, object_pairs_hook=unique_object)


def asset_digest(asset):
    digest = asset.get("digest")
    require(isinstance(digest, str) and digest.startswith("sha256:")
            and SHA256.fullmatch(digest[7:]) is not None,
            "Official asset lacks an exact SHA-256 identity")
    return digest


def release_asset(release, asset_id, name):
    require(positive(asset_id), "Remote asset ID is invalid")
    rows = release.get("assets")
    require(isinstance(rows, list), "Official release assets are absent")
    same_id = [row for row in rows if row.get("id") == asset_id]
    same_name = [row for row in rows if row.get("name") == name]
    require(len(same_id) == len(same_name) == 1 and same_id[0] == same_name[0],
            "Remote asset identity is ambiguous or absent")
    asset = same_id[0]
    require(positive(asset.get("size")), "Official asset size is invalid")
    tag = release.get("tag_name")
    require(isinstance(tag, str) and tag, "Official release tag is absent")
    expected = ("https://github.com/Otzaria/SeforimLibrary/releases/download/"
                + urllib.parse.quote(tag, safe="") + "/"
                + urllib.parse.quote(name, safe=""))
    require(asset.get("browser_download_url") == expected,
            "Asset is not the exact official same-release download")
    asset_digest(asset)
    return asset


def selected_asset(report, release):
    require(positive(release.get("id")) and report.get("releaseID") == release["id"]
            and report.get("releaseTag") == release.get("tag_name"),
            "Native report identifies a different official release")
    name = report.get("assetName")
    require(isinstance(name, str), "Native remote asset name is absent")
    asset = release_asset(release, report.get("assetID"), name)
    require(report.get("assetBytes") == asset["size"]
            and report.get("assetDigest") == asset_digest(asset),
            "Native remote asset bytes/hash differ from official metadata")
    return asset


def validate_release_report(report, release, manifest_raw=None):
    require(report.get("passed") is True and report.get("profileID") == "production"
            and type(report.get("profileVersion")) is int and report["profileVersion"] == 1,
            "Original production bootstrap report did not pass")
    asset = selected_asset(report, release)
    name = asset["name"]
    parts = []
    if name.endswith(".manifest.json"):
        require(asset["size"] <= MAX_MANIFEST_BYTES
                and isinstance(manifest_raw, bytes)
                and len(manifest_raw) == asset["size"]
                and hashlib.sha256(manifest_raw).hexdigest() == asset["digest"][7:],
                "Official manifest bytes/hash do not match the remote asset")
        manifest = decode(manifest_raw)
        require(type(manifest.get("schemaVersion")) is int and manifest["schemaVersion"] == 1,
                "Unsupported multipart manifest format")
        archive = manifest.get("archive")
        require(isinstance(archive, str) and ARCHIVE_NAME.fullmatch(archive) is not None
                and name == archive + ".manifest.json", "Manifest archive name differs")
        size, digest = manifest.get("size"), manifest.get("sha256")
        require(positive(size) and isinstance(digest, str) and SHA256.fullmatch(digest),
                "Manifest archive bytes/hash are invalid")
        rows = manifest.get("parts")
        require(isinstance(rows, list) and 1 <= len(rows) <= 1000,
                "Manifest part inventory is invalid")
        seen_ids = {asset["id"]}
        for index, row in enumerate(rows):
            part_name = archive + ".part-" + str(index).zfill(3)
            require(row.get("name") == part_name and positive(row.get("size"))
                    and isinstance(row.get("sha256"), str) and SHA256.fullmatch(row["sha256"]),
                    "Manifest part order or identity is invalid")
            matches = [item for item in release["assets"] if item.get("name") == part_name]
            require(len(matches) == 1, "Official part asset is absent or duplicated")
            part = release_asset(release, matches[0].get("id"), part_name)
            require(part["id"] not in seen_ids and part["size"] == row["size"]
                    and part["digest"] == "sha256:" + row["sha256"],
                    "Official part bytes/hash differ from manifest")
            seen_ids.add(part["id"])
            parts.append({"id": part["id"], "name": part_name,
                          "bytes": part["size"], "sha256": row["sha256"]})
        require(sum(part["bytes"] for part in parts) == size,
                "Multipart total does not equal archive size")
    else:
        require(ARCHIVE_NAME.fullmatch(name) is not None and manifest_raw is None,
                "Unsupported direct asset or unexpected manifest")
        archive, size, digest = name, asset["size"], asset["digest"][7:]
    require(report.get("archiveName") == archive
            and report.get("expectedCompressedBytes") == size
            and report.get("expectedSHA256") == digest,
            "Native archive facts differ from the genuine archive identity")
    require(report.get("actualSHA256") == digest and report.get("shaMatched") is True,
            "Native whole-archive hash did not match")
    return {"release_id": release["id"], "release_tag": release["tag_name"],
            "remote_asset": {"id": asset["id"], "name": name, "bytes": asset["size"],
                             "digest": asset["digest"]},
            "archive": {"name": archive, "bytes": size, "sha256": digest},
            "parts": parts}


def validate_phases(cancel, install, restore, release, manifest_raw, require_resume):
    identity = validate_release_report(install, release, manifest_raw)
    require(validate_release_report(restore, release, manifest_raw) == identity,
            "Restore changed the installed release/archive identity")
    require(cancel.get("passed") is True and cancel.get("phase") == "cancel"
            and cancel.get("finalExists") is False
            and type(cancel.get("downloadedBytes")) is int
            and cancel["downloadedBytes"] >= 67_108_864,
            "Original native cancellation did not retain the requested partial archive")
    require(install.get("phase") == "install" and restore.get("phase") == "restore",
            "Original install/restore phases are absent")
    require(cancel.get("errors") == [], "Original native cancellation contains errors")
    selected_asset(cancel, release)
    for key in ("releaseID", "releaseTag", "assetID", "assetName", "assetBytes",
                "assetDigest", "archiveName", "expectedCompressedBytes", "expectedSHA256"):
        require(cancel.get(key) == install.get(key) == restore.get(key),
                "Original native phases changed archive identity: " + key)
    if require_resume:
        require(type(install.get("resumeFromBytes")) is int
                and 0 < install["resumeFromBytes"] <= cancel["downloadedBytes"],
                "Native install did not actually resume the retained cancellation")
    for report in (install, restore):
        final_path = report.get("finalPath")
        require(isinstance(final_path, str) and bool(final_path)
                and Path(final_path).is_absolute()
                and "\n" not in final_path and "\r" not in final_path,
                "Original native report has no valid absolute managed database path")
        require(report.get("quickCheck", "").lower() == "ok"
                and sorted(report.get("requiredTables", [])) == ["book", "category", "line"]
                and type(report.get("bookCount")) is int and report["bookCount"] >= 7000
                and type(report.get("lineCount")) is int and report["lineCount"] > 0
                and report.get("source") == "managedInternal",
                "Original production SQLite/count/managed validation did not pass")
        for key in ("partCleanedAfterSuccess", "sidecarCleanedAfterSuccess", "finalExists",
                    "stagingAbsentAfterSuccess", "previousAbsentAfterSuccess",
                    "installationManifestExists", "backupExcluded",
                    "managedWithoutSecurityScope", "dictionaryConfigured"):
            require(report.get(key) is True, "Original native installation gate failed: " + key)
        require(report.get("errors") == [], "Original native phase contains errors")
    require(restore.get("restoreAfterRelaunch") is True
            and install.get("finalPath") == restore.get("finalPath")
            and install["bookCount"] == restore["bookCount"]
            and install["lineCount"] == restore["lineCount"],
            "Original forced-relaunch restoration changed the installed database")
    return {"cancel_bytes": cancel["downloadedBytes"],
            "resumed_bytes": install["resumeFromBytes"],
            "book_count": restore["bookCount"], "line_count": restore["lineCount"],
            "restore_after_relaunch": True, "sqlite_quick_check": "ok"}


def fetch_manifest(asset):
    require(asset["name"].endswith(".manifest.json")
            and positive(asset["size"]) and asset["size"] <= MAX_MANIFEST_BYTES,
            "Only a bounded official manifest may be fetched")
    request = urllib.request.Request(asset["browser_download_url"],
                                     headers={"User-Agent": "Otzaria-bootstrap-evidence/1",
                                              "Accept": "application/octet-stream"})
    with urllib.request.urlopen(request, timeout=30) as response:
        require(response.status == 200, "Official manifest download did not return HTTP200")
        raw = response.read(asset["size"] + 1)
    require(len(raw) == asset["size"], "Official manifest download length differs")
    return raw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--release", type=Path, required=True)
    inputs = parser.add_mutually_exclusive_group()
    inputs.add_argument("--manifest", type=Path)
    inputs.add_argument("--fetch-manifest", action="store_true")
    parser.add_argument("--phases-dir", type=Path)
    parser.add_argument("--require-resume", action="store_true")
    parser.add_argument("--expected-release", type=int)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report_raw, release_raw = args.report.read_bytes(), args.release.read_bytes()
    report, release = decode(report_raw), decode(release_raw)
    if args.expected_release is not None:
        require(release.get("id") == args.expected_release, "Frozen native release identity differs")
    asset = selected_asset(report, release)
    manifest_raw = args.manifest.read_bytes() if args.manifest else None
    if asset["name"].endswith(".manifest.json") and args.fetch_manifest:
        manifest_raw = fetch_manifest(asset)
    identity = validate_release_report(report, release, manifest_raw)
    result = {"status": "PASS", "scope": "Original native bootstrap evidence admission",
              "native_execution_performed_by_validator": False, **identity,
              "report_sha256": hashlib.sha256(report_raw).hexdigest(),
              "release_sha256": hashlib.sha256(release_raw).hexdigest(),
              "manifest_sha256": hashlib.sha256(manifest_raw).hexdigest() if manifest_raw else None}
    require(not args.require_resume or args.phases_dir is not None,
            "Actual resume admission requires all three original phase reports")
    if args.phases_dir is not None:
        phases = {}
        for phase, filename in [("cancel", "cancel"), ("install", "install"), ("restore", "acceptance")]:
            path = args.phases_dir / ("otzaria-native-bootstrap-" + filename + ".json")
            raw = path.read_bytes()
            phases[phase] = decode(raw)
            result[phase + "_report_sha256"] = hashlib.sha256(raw).hexdigest()
        require(phases["restore"] == report, "Supplied report differs from original final restore")
        result["original_phases"] = validate_phases(
            phases["cancel"], phases["install"], phases["restore"],
            release, manifest_raw, args.require_resume)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if manifest_raw is not None:
        manifest_path = args.output.with_suffix(".manifest.json")
        require(manifest_path != args.report and manifest_path != args.release,
                "Manifest evidence would overwrite an input")
        manifest_path.write_bytes(manifest_raw)
        result["retained_manifest_file"] = manifest_path.name
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2) + "\n")
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
