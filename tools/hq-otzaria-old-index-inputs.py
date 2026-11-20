#!/usr/bin/env python3
"""Verify original published265 archives and prepare an owned unopened index.

No engine is loaded, no index is built, and no database is downloaded.
Only the hardcoded project build root and explicit immutable release are used.
"""
from pathlib import Path, PurePosixPath
import argparse, datetime, hashlib, json, os, shutil, subprocess, time, urllib.request, uuid

ROOT = Path(__file__).resolve().parents[1]
OWNER = "original265-index-read-qualification-20261120-v1\n"
PRODUCER = "265a14ea54f959a3e266d6e8acfa3a3b98101d68"

def sha(path):
    result = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(4 * 1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def inventory(root):
    return {str(path.relative_to(root)).replace("\\", "/"):
            {"bytes": path.stat().st_size, "sha256": sha(path)}
            for path in sorted(root.rglob("*")) if path.is_file()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", required=True, choices=["miniTest10-v6", "full-v32"])
    parser.add_argument("--release-json", type=Path, required=True)
    parser.add_argument("--expected-manifest-sha256", required=True)
    parser.add_argument("--timeout-seconds", type=int, default=1200)
    args = parser.parse_args()
    driver_hash = sha(Path(__file__))
    start = time.monotonic()
    deadline = start + args.timeout_seconds
    out = ROOT / "build/index-read-qualification-20261120/artifacts" / args.profile
    out.mkdir(parents=True, exist_ok=True)
    owner = out / "OWNER"
    if owner.exists():
        assert owner.read_text(encoding="ascii") == OWNER
    else:
        owner.write_text(OWNER, encoding="ascii", newline="")
    release = json.loads(args.release_json.read_text(encoding="utf-8"))
    assert release["immutable"] is True
    expected_tag = "otzaria-miniTest10-v6" if args.profile == "miniTest10-v6" else "otzaria-search-data-v32-20261010190601-102293b3a63c"
    assert release["tag_name"] == expected_tag
    assets = {asset["name"]: asset for asset in release["assets"]}
    expected_url_prefix = "https://github.com/davidpovarsky/Maktabah/releases/download/" + expected_tag + "/"
    for name, asset in assets.items():
        assert asset["browser_download_url"] == expected_url_prefix + name
        assert name == Path(name).name and "/" not in name and "\\" not in name
        assert asset["digest"].startswith("sha256:") and len(asset["digest"]) == 71
    completed = []

    def download(asset):
        destination = out / asset["name"]
        expected = asset["digest"].split(":", 1)[1]
        if destination.exists():
            assert destination.stat().st_size == asset["size"] and sha(destination) == expected
            reused = True
        else:
            partial = destination.with_name(destination.name + ".partial")
            offset = partial.stat().st_size if partial.exists() else 0
            assert 0 <= offset < asset["size"]
            headers = {"User-Agent": "Otzaria-owned-original-index-qualification"}
            if offset:
                headers["Range"] = f"bytes={offset}-"
            request = urllib.request.Request(asset["browser_download_url"], headers=headers)
            with urllib.request.urlopen(request, timeout=45) as response:
                if offset:
                    assert response.status == 206
                    assert response.headers.get("Content-Range", "").startswith(f"bytes {offset}-")
                    assert response.headers.get("Content-Range", "").endswith("/" + str(asset["size"]))
                else:
                    assert response.status == 200
                with partial.open("ab" if offset else "wb") as sink:
                    while True:
                        assert time.monotonic() < deadline, "bounded transfer deadline reached; partial retained"
                        block = response.read(1024 * 1024)
                        if not block:
                            break
                        sink.write(block)
                        assert sink.tell() <= asset["size"], "unexpected archive length"
            assert partial.stat().st_size == asset["size"] and sha(partial) == expected
            partial.rename(destination)
            reused = False
        completed.append({"asset_id": asset["id"], "file": asset["name"], "bytes": asset["size"],
                          "sha256": expected, "reused_verified_file": reused})
        save(out / "DOWNLOAD_PROGRESS.json", {"files": completed, "engine_opened": False})
        return destination

    manifest_path = download(assets["otzaria-search-manifest.json"])
    assert sha(manifest_path) == args.expected_manifest_sha256
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    engine = manifest["lexicalEngine"]
    assert engine["repository"] == "Otzaria/otzaria_search_engine" and engine["commit"] == PRODUCER
    assert engine["engineVersion"] == "0.1.0" and engine["indexSchemaVersion"] == 4
    assert engine["tantivyVersion"] == "0.26.1" and engine["adapterVersion"] == "0.1.0"
    artifact = manifest["lexicalArtifact"]
    offsets = {}
    for part in artifact["parts"]:
        name = part["destinationPath"]
        assert name and not name.startswith("/") and "\\" not in name and ":" not in name
        assert all(component not in ("", ".", "..") for component in name.split("/"))
        assert part["compression"] == "zstd" and part["destinationOffset"] == offsets.get(name, 0)
        assert part["uncompressedBytes"] > 0 and part["packagedBytes"] > 0
        offsets[name] = part["destinationOffset"] + part["uncompressedBytes"]
        asset = assets[part["assetName"]]
        assert asset["size"] == part["packagedBytes"] and asset["digest"] == "sha256:" + part["sha256"]
    assert len(offsets) == artifact["fileCount"] and sum(offsets.values()) == artifact["extractedBytes"]
    assert sum(part["packagedBytes"] for part in artifact["parts"]) == artifact["packagedBytes"]
    remaining = sum(part["packagedBytes"] for part in artifact["parts"] if not (out / part["assetName"]).exists())
    # Reserve three complete payloads (pristine + independent265/d5 read copies)
    # and ten GiB for the active source builds, beyond authenticated archives.
    assert shutil.disk_usage(out).free >= remaining + 3 * artifact["extractedBytes"] + 10 * 1024**3
    for part in artifact["parts"]:
        download(assets[part["assetName"]])
    pristine = out / "pristine"
    receipt = out / "INPUT_VERIFIED.json"
    if pristine.exists():
        prior = json.loads(receipt.read_text(encoding="utf-8"))
        assert inventory(pristine) == prior["published_files"], "pristine input was modified"
        print(json.dumps({"status": "REUSED_VERIFIED_UNOPENED_INPUT", "receipt": str(receipt)}))
        return 0
    staging = out / ("pristine.extracting-" + uuid.uuid4().hex)
    staging.mkdir()
    zstd = shutil.which("zstd")
    assert zstd, "existing Zstd CLI required"
    extraction = []
    for part in artifact["parts"]:
        target = staging.joinpath(*PurePosixPath(part["destinationPath"]).parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        assert (target.stat().st_size if target.exists() else 0) == part["destinationOffset"]
        with target.open("ab") as sink:
            process = subprocess.run([zstd, "-d", "-q", "-c", str(out / part["assetName"])],
                                     stdout=sink, stderr=subprocess.PIPE, timeout=240)
        assert process.returncode == 0, process.stderr.decode("utf-8", "replace")
        assert target.stat().st_size == part["destinationOffset"] + part["uncompressedBytes"]
        extraction.append({"asset": part["assetName"], "destination": part["destinationPath"],
                           "offset": part["destinationOffset"], "extracted_bytes": part["uncompressedBytes"]})
    files = inventory(staging)
    assert len(files) == artifact["fileCount"] and sum(item["bytes"] for item in files.values()) == artifact["extractedBytes"]
    metadata = json.loads((staging / "meta.json").read_text(encoding="utf-8"))
    assert metadata["segments"] and metadata["schema"], "refuse empty index before engine open"
    metadata_documents = sum(segment["max_doc"] - ((segment.get("deletes") or {}).get("num_deleted_docs", 0))
                             for segment in metadata["segments"])
    assert metadata_documents == artifact["documentCount"] > 0
    staging.rename(pristine)
    result = {"observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "status": "VERIFIED_ORIGINAL_INPUT_NOT_RUNTIME_QUALIFICATION", "release": release["html_url"],
        "release_id": release["id"], "immutable_release": True, "manifest_sha256": sha(manifest_path),
        "producer": engine, "artifact_identity": manifest["artifactIdentity"], "archives": completed,
        "extraction": extraction, "published_files": files, "original_segments": metadata["segments"],
        "metadata_document_count_before_any_engine_open": metadata_documents,
        "pristine": str(pristine), "zstd": zstd, "engine_opened": False, "index_rebuilt": False,
        "driver_sha256": driver_hash,
        "database_downloaded": False, "seconds": round(time.monotonic() - start, 3)}
    save(receipt, result)
    print(json.dumps({"status": result["status"], "files": len(files), "bytes": artifact["extractedBytes"],
                      "metadata_document_count": metadata_documents, "receipt": str(receipt)}))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
