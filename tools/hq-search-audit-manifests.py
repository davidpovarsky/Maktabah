"""Audit saved metadata; optionally stream/hash payloads without writing index bytes."""
from pathlib import Path
import argparse
import hashlib
import json
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs/hq-search"
parser = argparse.ArgumentParser()
parser.add_argument("--verify-payloads", action="store_true", help="Stream every saved-manifest part and verify its actual byte count/SHA256; no extraction or installation")
parser.add_argument("--output", default="v32-metadata-audit.json", help="Report filename inside docs/hq-search")
options = parser.parse_args()
if Path(options.output).name != options.output:
    parser.error("output must be a filename inside docs/hq-search")


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
output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"v32 metadata audit: {report['passed']} PASS, {report['failed']} FAIL; payload/runtime/device gates OPEN")
if options.verify_payloads and not report["failed"]:
    report["scope"] = "Actual compressed payload stream/hash verification; no extraction, installation, corpus query or device acceptance"
    report["payloads"] = []
    for component, manifest in manifests.items():
        release = next(x for x in inventory if x["tag_name"].startswith(component + "-search-data-v32-"))
        assets = {a["name"]: a for a in release["assets"]}
        parts = manifest["lexicalArtifact"]["parts"] if component == "otzaria" else manifest["parts"]
        for part in parts:
            started = time.monotonic()
            record = {"component": component, "asset": part["assetName"], "status": "NOT_RUN",
                      "expectedBytes": part["packagedBytes"], "expectedSHA256": part["sha256"]}
            try:
                digest, count = hashlib.sha256(), 0
                request = urllib.request.Request(assets[part["assetName"]]["browser_download_url"], headers={"User-Agent": "Maktabah-source-payload-verification"})
                with urllib.request.urlopen(request, timeout=60) as response:
                    while chunk := response.read(4 * 1024 * 1024):
                        count += len(chunk)
                        if count > part["packagedBytes"]:
                            raise ValueError("Payload exceeds manifest byte count")
                        digest.update(chunk)
                record.update(bytes=count, sha256=digest.hexdigest())
                if count != part["packagedBytes"] or digest.hexdigest() != part["sha256"]:
                    raise ValueError("Payload byte count or SHA256 does not match manifest")
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
    report["payloadGate"] = "ALL_COMPRESSED_PARTS_HASH_VERIFIED"
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
raise SystemExit(1 if report["failed"] else 0)
