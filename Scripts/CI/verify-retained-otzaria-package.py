"""Verify retained full-corpus bytes and their completed native build receipts."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def digest_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        while chunk := handle.read(8 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def verify_publication(verification, release):
    if not __debug__:
        raise RuntimeError("Package verification requires Python assertions enabled")
    assert release["tag_name"] == verification["tag"] and not release["draft"] and release["immutable"]
    assets = {asset["name"]: asset for asset in release["assets"]}
    assert len(assets) == len(release["assets"]) and set(assets) == set(verification["assets"])
    for name, expected in verification["assets"].items():
        actual = assets[name]
        assert actual["state"] == "uploaded" and actual["size"] == expected["bytes"]
        assert actual["digest"] == "sha256:" + expected["sha256"], "Server asset digest mismatch"


def verify(package, reports, source_run, expected_builder):
    if not __debug__:
        raise RuntimeError("Package verification requires Python assertions enabled")
    package, reports = Path(package), Path(reports)
    run = read(source_run)
    assert re.fullmatch(r"[0-9a-f]{40}", expected_builder), "Invalid expected builder SHA"
    assert run["head_sha"] == expected_builder and run["status"] == "completed" and run["conclusion"] == "success", "Source build did not pass at the expected SHA"
    assert run["path"] == ".github/workflows/otzaria-search-artifacts.yml", "Foreign source workflow"
    manifest = read(package / "otzaria-search-manifest.json")
    assert manifest == read(reports / "otzaria-artifact/otzaria-search-manifest.json"), "Package/report manifest mismatch"
    identity = manifest["artifactIdentity"]
    assert re.fullmatch(r"[0-9a-f]{64}", identity), "Invalid artifact identity"
    source = manifest["sourceDatabase"]
    assert source["repository"] == "Otzaria/SeforimLibrary" and source["releaseTag"] == "v36-20261101064231"
    assert source["databaseSHA256"] == "c60fbd02b4cf7bda00dc5af16aa48b8bfe193b1121d29c9a048dc348ff42e9d6"
    assert source["databaseBytes"] == 4178067456 and source["documentCount"] == 7660127 and source["bookCount"] == 8148
    assert source["sourceAssetDigest"] == "sha256:9b1623035853f6d67f8553a953cf48de60643ece1bc6658e6a3fb80f379c47ba"
    engine = manifest["lexicalEngine"]
    assert engine["engineVersion"] == "7.0.1" and engine["indexSchemaVersion"] == 10
    assert engine["commit"] == "225a6d5d7265c478a64d3a609a536d0deed433e7"
    corpus = read(reports / "logs/otzaria-corpus-acceptance.json")
    assert corpus["passed"] and corpus["indexedDocuments"] == corpus["reopenedDocuments"] == 7660127
    assert corpus["committedBooks"] == 8148 and corpus["quarantinedBooks"] == 0
    for phase in ("install", "reopen"):
        receipt = read(reports / f"logs/otzaria-prebuilt-{phase}.json")
        assert receipt["passed"] and receipt["artifactIdentity"] == identity and receipt["documentCount"] == 7660127
        assert receipt["productionValidatorRan"] and not receipt["localIndexingRan"]
    parts = manifest["lexicalArtifact"]["parts"]
    expected_names = {"otzaria-search-manifest.json", "otzaria-search-build-metrics.json"}
    native_metadata, assets = {}, {}
    for part in parts:
        name = part["assetName"]
        assert re.fullmatch(r"otzaria-lexical-[0-9]{4}\.zst", name) and name not in expected_names, "Invalid or duplicate asset name"
        expected_names.add(name)
        path = package / name
        assert path.is_file() and not path.is_symlink() and path.stat().st_size == part["packagedBytes"], "Missing or wrong-sized part"
        digest = digest_file(path)
        assert digest == part["sha256"], "Corrupt package part"
        assert part["compression"] == "zstd" and part["uncompressedBytes"] > 0 and part["destinationOffset"] >= 0
        assets[name] = {"bytes": path.stat().st_size, "sha256": digest}
        destination = part["destinationPath"]
        assert "\\" not in destination and not Path(destination).is_absolute() and ".." not in Path(destination).parts, "Unsafe native destination"
        if destination in {"otzaria_index_meta.json", "otzaria_book_numbers.json", "otzaria_book_order.json"}:
            assert destination not in native_metadata and part["destinationOffset"] == 0
            raw = subprocess.check_output(["zstd", "--decompress", "--stdout", str(path)])
            assert len(raw) == part["uncompressedBytes"]
            native_metadata[destination] = json.loads(raw)
    assert set(native_metadata) == {"otzaria_index_meta.json", "otzaria_book_numbers.json", "otzaria_book_order.json"}
    meta = native_metadata["otzaria_index_meta.json"]
    assert meta["engine_version"] == "7.0.1" and meta["schema_version"] == 10
    assert {path.name for path in package.iterdir()} == expected_names, "Unexpected or missing release assets"
    assert sum(part["packagedBytes"] for part in parts) == manifest["lexicalArtifact"]["packagedBytes"]
    for name in ("otzaria-search-manifest.json", "otzaria-search-build-metrics.json"):
        path = package / name
        assert path.is_file() and not path.is_symlink()
        assets[name] = {"bytes": path.stat().st_size, "sha256": digest_file(path)}
    return {"tag": f"otzaria-search-data-{source['releaseTag']}-{identity[:12]}",
            "builderSHA": expected_builder, "sourceRun": run["id"], "artifactIdentity": identity,
            "assetCount": len(expected_names), "assets": assets, "packagedBytes": manifest["lexicalArtifact"]["packagedBytes"],
            "nativeEngineMetadata": meta, "publicationOnly": True,
            "httpReleaseAcceptance": "NOT_RUN"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True)
    parser.add_argument("--reports", required=True)
    parser.add_argument("--source-run", required=True)
    parser.add_argument("--expected-builder", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--published-release")
    args = parser.parse_args()
    result = verify(args.package, args.reports, args.source_run, args.expected_builder)
    if args.published_release:
        verify_publication(result, read(args.published_release))
        result["serverAssetsVerified"] = True
    Path(args.out).write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
