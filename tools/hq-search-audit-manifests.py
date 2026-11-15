"""Audit saved metadata; optionally stream/hash payloads without writing index bytes."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs/hq-search"
parser = argparse.ArgumentParser()
parser.add_argument("--verify-payloads", action="store_true", help="Stream every saved-manifest part and verify its actual byte count/SHA256; no extraction or installation")
parser.add_argument("--output", default="v32-metadata-audit.json", help="Report filename inside docs/hq-search")
parser.add_argument("--component", choices=["all", "otzaria", "zayit"], default="all")
parser.add_argument("--zayit-fixture", help="Reconstruct a NEW isolated fixture under this worktree/build; download/verify canonical DB too, never install in app storage")
parser.add_argument("--finish-fixture", action="store_true", help="Finish an interrupted owned reconstruction after verifying every retained part and final size; no user installation paths")
options = parser.parse_args()
if options.finish_fixture and not options.zayit_fixture:
    parser.error("finish-fixture requires the explicitly owned fixture directory")
if Path(options.output).name != options.output:
    parser.error("output must be a filename inside docs/hq-search")
fixture = None
if options.zayit_fixture:
    if not options.verify_payloads or options.component != "zayit":
        parser.error("fixture requires --verify-payloads --component zayit")
    fixture = Path(options.zayit_fixture).resolve()
    if not fixture.is_relative_to((ROOT / "build").resolve()) or (fixture.exists() and not options.finish_fixture):
        parser.error("fixture must be a NEW directory within this assigned worktree/build")
    if not shutil.which("zstd"):
        parser.error("existing zstd CLI required; no dependency installation")
    if options.finish_fixture:
        owner = json.loads((fixture / "fixture-owner.json").read_text())
        if owner.get("purpose") != "S production acceptance fixture; not user installation":
            parser.error("existing path is not this tool's isolated fixture")


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


inventory = read(EVIDENCE / "release-inventory.json")
official = read(EVIDENCE / "database-release-v32.json")
upstream = read(ROOT / "Vendor/OtzariaSearchEngine/Upstream/UPSTREAM_MANIFEST.json")
report = {"date": "2026-11-15", "scope": "metadata only; no payload/installation/runtime verification", "checks": []}


def check(condition, description):
    report["checks"].append({"pass": bool(condition), "description": description})


manifests = {}
for component in ("otzaria", "zayit"):
    release = next(x for x in inventory if x["tag_name"].startswith(component + "-search-data-v32-"))
    filename = component + "-search-manifest.json"
    path = EVIDENCE / "manifests" / filename
    manifest = read(path)
    manifests[component] = manifest
    assets = {a["name"]: a for a in release["assets"]}
    metadata = assets[filename]
    check(path.stat().st_size == metadata["size"], component + " manifest byte count")
    check("sha256:" + hashlib.sha256(path.read_bytes()).hexdigest() == metadata["digest"], component + " manifest API SHA256")
    parts = manifest["lexicalArtifact"]["parts"] if component == "otzaria" else manifest["parts"]
    for part in parts:
        asset = assets.get(part["assetName"])
        check(asset is not None and asset["size"] == part["packagedBytes"]
              and asset["digest"] == "sha256:" + part["sha256"], component + " part API identity: " + part["assetName"])
    report[component] = {"release": release["html_url"], "immutable": release["immutable"],
                         "artifactIdentity": manifest["artifactIdentity"], "parts": len(parts)}

otzaria = manifests["otzaria"]
zayit = manifests["zayit"]
source = otzaria["sourceDatabase"]
required = zayit["requiredDatabase"]
asset = next(a for a in official["assets"] if a["name"] == source["assetName"])
check(official["id"] == source["releaseID"] and official["tag_name"] == source["releaseTag"], "official v32 release identity")
check(asset["id"] == source["assetID"] and asset["size"] == source["compressedBytes"]
      and asset["digest"] == source["sourceAssetDigest"], "official v32 compressed asset identity")
check(required["releaseTag"] == source["releaseTag"] and required["bytes"] == source["databaseBytes"]
      and required["canonicalSHA256"] == source["databaseSHA256"]
      and required["compressedAssetSHA256"] == source["sourceAssetDigest"].removeprefix("sha256:"), "Otzaria/Zayit canonical database agreement")
engine = otzaria["lexicalEngine"]
for manifest_key, upstream_key in [("commit", "commit"), ("engineVersion", "engine_package_version"),
                                  ("indexSchemaVersion", "index_schema_version"), ("defaultGenerationOrder", "default_generation_order")]:
    check(engine[manifest_key] == upstream[upstream_key], "Otzaria engine pin: " + manifest_key)
for resource in read(ROOT / "Vendor/OtzariaSearchEngine/Upstream/RESOURCE_MANIFEST.json")["resources"]:
    if resource["sha256"]:
        actual = hashlib.sha256((ROOT / resource["destination"]).read_bytes()).hexdigest()
        check(otzaria["resources"][resource["destination"]]["sha256"] == actual == resource["sha256"], "bundled resource: " + resource["destination"])
report["passed"] = sum(x["pass"] for x in report["checks"])
report["failed"] = len(report["checks"]) - report["passed"]
output = EVIDENCE / options.output
if not options.finish_fixture:
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"v32 metadata audit: {report['passed']} PASS, {report['failed']} FAIL; payload/runtime/device gates OPEN")
if options.verify_payloads and not report["failed"]:
    report["scope"] = "Actual compressed payload stream/hash verification; no extraction, installation, corpus query or device acceptance"
    report["payloads"] = []
    if options.finish_fixture:
        previous = read(output)
        if previous.get("fixtureDirectory") != str(fixture) or len(previous.get("payloads", [])) != len(zayit["parts"]) or any(p["status"] != "EXECUTED_PASS" for p in previous["payloads"]):
            raise SystemExit("Owned reconstruction report does not prove every retained part")
        report["payloads"] = previous["payloads"]
        report["fixtureDirectory"] = str(fixture)
        destinations = {}
        for part in zayit["parts"]:
            retained = fixture / "parts" / part["assetName"]
            digest = hashlib.sha256()
            with retained.open("rb") as stream:
                while chunk := stream.read(8 * 1024 * 1024): digest.update(chunk)
            if retained.stat().st_size != part["packagedBytes"] or digest.hexdigest() != part["sha256"]:
                raise ValueError("Retained reconstruction part differs from its manifest")
            destinations[part["destinationPath"]] = part["destinationOffset"] + part["uncompressedBytes"]
        for name, expected_bytes in destinations.items():
            destination = (fixture / "index" / name).resolve()
            if not destination.is_relative_to(fixture / "index") or destination.stat().st_size != expected_bytes:
                raise ValueError("Retained reconstructed index size/path mismatch")
        if sum(destinations.values()) != zayit["extractedBytes"]:
            raise ValueError("Retained reconstructed index total size mismatch")
    elif fixture:
        expected = zayit["extractedBytes"] + zayit["packagedBytes"] + source["databaseBytes"] + source["compressedBytes"] + 2_147_483_648
        if shutil.disk_usage(ROOT).free < expected:
            raise SystemExit("Not enough free space for isolated corpus fixture plus 2GiB reserve")
        fixture.mkdir(parents=True)
        (fixture / "parts").mkdir()
        (fixture / "index").mkdir()
        (fixture / "fixture-owner.json").write_text(json.dumps({"purpose":"S production acceptance fixture; not user installation", "sourceTag":source["releaseTag"]}))
        report["fixtureDirectory"] = str(fixture)
    for component, manifest in manifests.items():
        if options.finish_fixture:
            continue
        if options.component != "all" and component != options.component:
            continue
        release = next(x for x in inventory if x["tag_name"].startswith(component + "-search-data-v32-"))
        assets = {a["name"]: a for a in release["assets"]}
        parts = manifest["lexicalArtifact"]["parts"] if component == "otzaria" else manifest["parts"]
        for part in parts:
            started = time.monotonic()
            record = {"component": component, "asset": part["assetName"], "status": "NOT_RUN",
                      "expectedBytes": part["packagedBytes"], "expectedSHA256": part["sha256"]}
            try:
                digest, count = hashlib.sha256(), 0
                part_file = (fixture / "parts" / part["assetName"]).open("xb") if fixture else None
                request = urllib.request.Request(assets[part["assetName"]]["browser_download_url"], headers={"User-Agent": "Maktabah-source-payload-verification"})
                try:
                    with urllib.request.urlopen(request, timeout=60) as response:
                        while chunk := response.read(4 * 1024 * 1024):
                            count += len(chunk)
                            if count > part["packagedBytes"]:
                                raise ValueError("Payload exceeds manifest byte count")
                            digest.update(chunk)
                            if part_file:
                                part_file.write(chunk)
                finally:
                    if part_file:
                        part_file.close()
                record.update(bytes=count, sha256=digest.hexdigest())
                if count != part["packagedBytes"] or digest.hexdigest() != part["sha256"]:
                    raise ValueError("Payload byte count or SHA256 does not match manifest")
                if fixture:
                    destination = (fixture / "index" / part["destinationPath"]).resolve()
                    if not destination.is_relative_to(fixture / "index"):
                        raise ValueError("Manifest destination escapes the isolated fixture")
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    current = destination.stat().st_size if destination.exists() else 0
                    if current != part["destinationOffset"]:
                        raise ValueError("Manifest parts are not contiguous")
                    with destination.open("ab") as target:
                        subprocess.run(["zstd", "-d", "--no-progress", "-c", str(fixture / "parts" / part["assetName"])], stdout=target, check=True)
                    if destination.stat().st_size != current + part["uncompressedBytes"]:
                        raise ValueError("Reconstructed part size differs from manifest")
                    record["reconstructedBytes"] = part["uncompressedBytes"]
                record["status"] = "EXECUTED_PASS"
            except Exception as error:
                record.update(status="FAIL", error=type(error).__name__ + ": " + str(error))
                report["failed"] += 1
            record["elapsedSeconds"] = round(time.monotonic() - started, 2)
            report["payloads"].append(record)
            output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            print(f"{record['status']}: {component}/{part['assetName']} ({record.get('bytes',0)} bytes)", flush=True)
            if record["status"] != "EXECUTED_PASS":
                raise SystemExit(1)
    report["payloadGate"] = "ALL_COMPRESSED_PARTS_HASH_VERIFIED" if options.component == "all" else "SELECTED_COMPONENT_COMPRESSED_PARTS_HASH_VERIFIED"
    if fixture:
        compressed = fixture / source["assetName"]
        database_url = f"https://github.com/{source['repository']}/releases/download/{source['releaseTag']}/{source['assetName']}"
        digest, count = hashlib.sha256(), 0
        retained_source = compressed.exists()
        response = compressed.open("rb") if retained_source else urllib.request.urlopen(urllib.request.Request(database_url, headers={"User-Agent":"Maktabah-source-payload-verification"}), timeout=60)
        target = None if retained_source else compressed.open("xb")
        with response:
            while chunk := response.read(4 * 1024 * 1024):
                count += len(chunk)
                if count > source["compressedBytes"]:
                    raise ValueError("Canonical source download exceeds pinned size")
                digest.update(chunk)
                if target: target.write(chunk)
        if target: target.close()
        if count != source["compressedBytes"] or "sha256:" + digest.hexdigest() != source["sourceAssetDigest"]:
            raise ValueError("Canonical source compressed identity mismatch")
        database = fixture / "seforim.db"
        if not database.exists():
            subprocess.run(["zstd", "-d", "--long=31", "--no-progress", str(compressed), "-o", str(database)], check=True)
        digest = hashlib.sha256()
        with database.open("rb") as stream:
            while chunk := stream.read(8 * 1024 * 1024): digest.update(chunk)
        if database.stat().st_size != source["databaseBytes"] or digest.hexdigest() != source["databaseSHA256"]:
            raise ValueError("Reconstructed canonical DB identity mismatch")
        lexical = fixture / "lexical.db"
        if not lexical.exists():
            version = zayit["sharedLexicalDatabase"]["version"]
            url = f"https://github.com/Otzaria/SeforimMagicIndexer/releases/download/{version}/lexical.db"
            with urllib.request.urlopen(url, timeout=60) as response, lexical.open("xb") as target:
                while chunk := response.read(4 * 1024 * 1024): target.write(chunk)
        if lexical.stat().st_size != zayit["sharedLexicalDatabase"]["bytes"] or hashlib.sha256(lexical.read_bytes()).hexdigest() != zayit["sharedLexicalDatabase"]["sha256"]:
            raise ValueError("Bundled shared lexical database identity mismatch")
        report["reconstructionGate"] = "ZAYIT_INDEX_CANONICAL_DB_LEXICAL_VERIFIED_ISOLATED_FIXTURE"
        report["canonicalDatabase"] = {"bytes": database.stat().st_size, "sha256": digest.hexdigest()}
        (fixture / "fixture-ready.json").write_text(json.dumps({"database":str(database), "lexical":str(fixture / "lexical.db"), "index":str(fixture / "index"), "manifestIdentity":zayit["artifactIdentity"]}, indent=2))
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
raise SystemExit(1 if report["failed"] else 0)
